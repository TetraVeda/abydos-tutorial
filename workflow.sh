#! /usr/bin/env bash
# abydos-workflow.sh
# Runs through the entire Abydos workflow from start to finish.
# Refer to this script for an overall view of the whole process you are building by hand.
# This script makes heavy use of variables for overall readability
#
# WARNING: Expects to be run from the root directory of the abydos-tutorial source code repository.
#          This script will not work without adjustment if run from some other location.

LOCAL_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)

##### Colors and Printing #####
# see https://www.shellhacks.com/bash-colors/
export CLICOLOR=1
export LSCOLORS=GxFxCxDxBxegedabagaced
RED="\e[31m"
LCYAN="\e[1;46m" # Wise Man
GREEN="\e[32m"
YELLO="\e[33m" # Explorer
MAGNT="\e[35m" # Librarian
PURPL="\e[35m" # Gatekeeper
LBLUE="\e[94m"
BLRED="\e[1;31m"
BLGRN="\e[3;32m"
BLGRY="\e[1;90m"
DGREY="\e[1;40m"
EC="\e[0m"

VERBOSE=false
function log() {
  # see Why is Printf Better than echo : https://unix.stackexchange.com/questions/65803/why-is-printf-better-than-echo/65819#65819
  IFS=" "
  printf "$1\n"
}

function logv() {
  # log verbose
  if [ $VERBOSE = true ]; then
    printf "$1\n"
  else
    :
  fi
}

##### KERI Configuration #####
# Names and Aliases
EXPLORER_KEYSTORE=explorer
LIBRARIAN_KEYSTORE=librarian
WISEMAN_KEYSTORE=wiseman
GATEKEEPER_KEYSTORE=gatekeeper

EXPLORER_ALIAS=richard
LIBRARIAN_ALIAS=elayne
WISEMAN_ALIAS=ramiel    # Ramiel See https://en.wikipedia.org/wiki/Ramiel
GATEKEEPER_ALIAS=zaqiel # See Zaqiel https://en.wikipedia.org/wiki/Zaqiel

EXPLORER_REGISTRY=${EXPLORER_ALIAS}-registry
LIBRARIAN_REGISTRY=${LIBRARIAN_ALIAS}-registry
WISEMAN_REGISTRY=${WISEMAN_ALIAS}-registry

EXPLORER_SALT=0ACGZkoQexMCRRl4f21Itekh
LIBRARIAN_SALT=0ABcbj6VhID17F_wmgzsYSec
WISEMAN_SALT=0ABuZBlF30Rn09UhoNpsPek3
GATEKEEPER_SALT=0ACDXyMzq1Nxc4OWxtbm9fle

##### Prefixes #####
# these values start empty and are written to in later from the read_aliases function
# Participants
RICHARD_PREFIX=
ELAYNE_PREFIX=
WISEMAN_PREFIX=
GATEKEEPER_PREFIX=

# Witnesses
WAN_PREFIX=
WES_PREFIX=
WIL_PREFIX=

# Config files and directories
ATHENA_DIR=${LOCAL_DIR}/athena
CONFIG_DIR=${ATHENA_DIR}/conf
SCHEMAS_DIR=${ATHENA_DIR}/schemas
SCHEMA_RESULTS_DIR=${ATHENA_DIR}/saidified_schemas
WITNESS_BOOTSTRAP_OOBIS_FILENAME=witness-oobi-bootstrap
CONTROLLER_BOOTSTRAP_FILE=${CONFIG_DIR}/keri/cf/${WITNESS_BOOTSTRAP_OOBIS_FILENAME}.json
AGENT_CONFIG_FILENAME=agent-oobi-bootstrap
AGENT_CONFIG_FILE=${CONFIG_DIR}/keri/cf/${AGENT_CONFIG_FILENAME}.json
WITNESS_INCEPTION_CONFIG_FILE=${CONFIG_DIR}/inception-config.json

# Process IDs (PIDs)
WAN_WITNESS_PID=99999
WIL_WITNESS_PID=99999
WES_WITNESS_PID=99999
DEMO_WITNESS_NETWORK_PID=8888888
VLEI_SERVER_PID=7777777
SALLY_PID=9999999
GATEKEEPER_WEBHOOK_PID=99999
EXPLORER_AGENT_PID=99999
LIBRARIAN_AGENT_PID=99999
WISEMAN_AGENT_PID=99999

# HTTP and TCP Ports for witnesses and agents
WAN_WITNESS_HTTP_PORT=5642
WAN_WITNESS_TCP_PORT=5632
WIL_WITNESS_HTTP_PORT=5643
WIL_WITNESS_TCP_PORT=5633
WES_WITNESS_HTTP_PORT=5644
WES_WITNESS_TCP_PORT=5634
EXPLORER_AGENT_HTTP_PORT=5620
EXPLORER_AGENT_TCP_PORT=5621
LIBRARIAN_AGENT_HTTP_PORT=5622
LIBRARIAN_AGENT_TCP_PORT=5623
WISEMAN_AGENT_HTTP_PORT=5624
WISEMAN_AGENT_TCP_PORT=5625
GATEKEEPER_AGENT_HTTP_PORT=5627
GATEKEEPER_AGENT_TCP_PORT=5628

# URLs
WAN_WITNESS_URL=http://127.0.0.1:5642
VLEI_SERVER_URL=http://127.0.0.1:7723
EXPLORER_AGENT_URL=http://127.0.0.1:${EXPLORER_AGENT_HTTP_PORT}

# Credential SAID variables - needed for issuance
TREASURE_HUNTING_JOURNEY_SCHEMA_SAID=""
JOURNEY_MARK_REQUEST_SCHEMA_SAID=""
JOURNEY_MARK_SCHEMA_SAID=""
JOURNEY_CHARTER_SCHEMA_SAID=""

function waitfor() {
  # Utility function wrapper for the wait-for script
  # Passes all arguments passed to this function through to the wait-for script with "$@"
  # See https://github.com/eficode/wait-for
  "${LOCAL_DIR}"/scripts/wait-for "$@"
}

function generate_credential_schemas() {
  log "generating schemas"
  mkdir -p ${ATHENA_DIR}/saidified_schemas
  python -m kaslcred ${SCHEMAS_DIR} ${SCHEMA_RESULTS_DIR} ${SCHEMAS_DIR}/athena-schema-map.json
}

function read_schema_saids() {
  # Reads ACDC schema SAIDs from the schema results directory and
  # writes schema saids to the controller witness and OOBI bootstrap file.
  log "Reading in credential SAIDs from ${SCHEMA_RESULTS_DIR}"

  # Read in SAID and Credential Type
  IFS=$'\n' # read whole line
  read -r -d '' -a said_array < <(
    # shellcheck disable=SC2038
    find "$SCHEMA_RESULTS_DIR" -type f -exec basename {} \; |
      xargs -I {} cat "${SCHEMA_RESULTS_DIR}"/{} |
      jq '[."$id", ."credentialType"]|@sh' |
      tr -d '"' |
      tr -d "'" && printf '\0'
  )

  log "" # Need this printf call to take care of the trailing null terminator from interfering with the next command
  saids=()
  # Load into local vars
  for i in "${said_array[@]}"; do
    SCHEMA_PARTS=($i)
    CREDENTIAL_NAME=${SCHEMA_PARTS[1]}
    CREDENTIAL_SAID=${SCHEMA_PARTS[0]}
    saids+=($CREDENTIAL_SAID)

    if [[ "$CREDENTIAL_NAME" == "TreasureHuntingJourney" ]]; then
      TREASURE_HUNTING_JOURNEY_SCHEMA_SAID="$CREDENTIAL_SAID"

    elif [[ "$CREDENTIAL_NAME" == "JourneyMarkRequest" ]]; then
      JOURNEY_MARK_REQUEST_SCHEMA_SAID="$CREDENTIAL_SAID"

    elif [[ "$CREDENTIAL_NAME" == "JourneyMark" ]]; then
      JOURNEY_MARK_SCHEMA_SAID="$CREDENTIAL_SAID"

    elif [[ "$CREDENTIAL_NAME" == "JourneyCharter" ]]; then
      JOURNEY_CHARTER_SCHEMA_SAID="$CREDENTIAL_SAID"

    else
      log "${RED}unrecognized schema parts${EC}"
      log "${LBLUE}SCHEMA_PARTS $CREDENTIAL_SAID $CREDENTIAL_NAME${EC}"
    fi
  done

  # Update data OOBIs in witness config file
  IFS=$'\n'
  durl_new=()
  for said in "${saids[@]}"; do
    durl_new+=("http://127.0.0.1:7723/oobi/${said}")
  done
  printf '%s\n' "${durl_new[@]}" | jq -R . | jq -s --argjson witconfig "$(cat ${CONTROLLER_BOOTSTRAP_FILE})" '
    . as $durl_new | $witconfig | .durls = $durl_new
  ' >${CONTROLLER_BOOTSTRAP_FILE}

  # Update data OOBIs in agent config file
  printf '%s\n' "${durl_new[@]}" | jq -R . | jq -s --argjson witconfig "$(cat ${AGENT_CONFIG_FILE})" '
    . as $durl_new | $witconfig | .durls = $durl_new
  ' >${AGENT_CONFIG_FILE}

  log "TREASURE_HUNTING_JOURNEY_SCHEMA_SAID set to $TREASURE_HUNTING_JOURNEY_SCHEMA_SAID"
  log "JOURNEY_MARK_REQUEST_SCHEMA_SAID     set to $JOURNEY_MARK_REQUEST_SCHEMA_SAID"
  log "JOURNEY_MARK_SCHEMA_SAID             set to $JOURNEY_MARK_SCHEMA_SAID"
  log "JOURNEY_CHARTER_SCHEMA_SAID          set to $JOURNEY_CHARTER_SCHEMA_SAID"
  log ""
}

function start_vlei_server() {
  # Starts the credential caching server, the vLEI-server
  log "${BLGRY}Starting Credential Cache Server (vLEI-server)...${EC}"
  ACDC_HOME=${ATHENA_DIR}
  # shellcheck disable=SC2086
  vLEI-server -s ${SCHEMA_RESULTS_DIR} -c "${ATHENA_DIR}"/cache/acdc -o "${ATHENA_DIR}"/cache/oobis &
  VLEI_SERVER_PID=$!
  waitfor ${VLEI_SERVER_URL} -t 2
  log "${BLGRN}Credential Cache Server started${EC}"
  log ""
}

function start_agents() {
  kli agent start --admin-http-port 5620 --config-dir ${ATHENA_DIR}
}

function start_demo_witnesses() {
  # Starts the witness network that comes with KERIpy
  # Six witnesses: [wan, wil, wes, wit, wub, wyz]
  # Puts all keystore and database files in $HOME/.keri
  log "${BLGRY}Starting Demo Witness Network${EC}..."
  pushd "${LOCAL_DIR}"/demo_wits || exit
  kli witness demo &
  DEMO_WITNESS_NETWORK_PID=$!
  popd || exit
  waitfor localhost:5632 -t 2
  waitfor localhost:5633 -t 2
  waitfor localhost:5634 -t 2
  waitfor localhost:5635 -t 2
  waitfor localhost:5636 -t 2
  waitfor localhost:5637 -t 2

  log "${BLGRN}Demo Witness Network Started${EC}"
  log ""
}

function create_witnesses() {
  # Initializes keystores for three witnesses: [wan, wil, wes]
  # Uses the same seeds as those for `kli witness demo` so that the prefixes are the same
  # Puts all keystore and database files in $HOME/.keri
  log "${BLGRY}Creating witnesses...${EC}"
  log "Creating witness ${LCYAN}wan${EC}"
  kli init --name wan --salt 0AB3YW5uLXRoZS13aXRuZXNz --nopasscode \
    --config-dir "${HK_CONFIG_DIR}" \
    --config-file main/wan-witness
  log "Creating witness ${LCYAN}wil${EC}"
  kli init --name wil --salt 0AB3aWxsLXRoZS13aXRuZXNz --nopasscode \
    --config-dir "${HK_CONFIG_DIR}" \
    --config-file main/wil-witness
  log "Creating witness ${LCYAN}wes${EC}"
  kli init --name wes --salt 0AB3ZXNzLXRoZS13aXRuZXNz --nopasscode \
    --config-dir "${HK_CONFIG_DIR}" \
    --config-file main/wes-witness
  log "${BLGRN}Finished creating witnesses${EC}"
}

function start_witnesses() {
  # Starts witnesses on the
  log "${BLGRY}Starting Witness Network${EC}..."

  kli witness start --name wan --alias wan -T ${WAN_WITNESS_TCP_PORT} -H ${WAN_WITNESS_HTTP_PORT} \
    --config-dir "${CONFIG_DIR}" \
    --config-file wan-witness &
  WAN_WITNESS_PID=$!

  kli witness start --name wil --alias wil -T ${WIL_WITNESS_TCP_PORT} -H ${WIL_WITNESS_HTTP_PORT} \
    --config-dir "${CONFIG_DIR}" \
    --config-file wil-witness &
  WIL_WITNESS_PID=$!

  kli witness start --name wes --alias wes -T ${WES_WITNESS_TCP_PORT} -H ${WES_WITNESS_HTTP_PORT} \
    --config-dir "${CONFIG_DIR}" \
    --config-file wes-witness &
  WES_WITNESS_PID=$!

  waitfor localhost:${WAN_WITNESS_TCP_PORT} -t 2
  waitfor localhost:${WIL_WITNESS_TCP_PORT} -t 2
  waitfor localhost:${WES_WITNESS_TCP_PORT} -t 2

  log "${BLGRN}Witness Network Started${EC}"
  log ""
}

function read_witness_prefixes_and_configure() {
  # Writes the witness prefixes to the controller witness and OOBI bootstrap file.
  log "reading witness prefixes and writing configuration file..."
  WAN_PREFIX=$(kli status --name wan --alias wan | awk '/Identifier:/ {print $2}')
  WIL_PREFIX=$(kli status --name wil --alias wil | awk '/Identifier:/ {print $2}')
  WES_PREFIX=$(kli status --name wes --alias wes | awk '/Identifier:/ {print $2}')
  log "WAN prefix: $WAN_PREFIX"
  log "WIL prefix: $WIL_PREFIX"
  log "WES prefix: $WES_PREFIX"

  # Update data OOBIs in controller config file
  update_config_with_witness_oobis "$CONTROLLER_BOOTSTRAP_FILE"
  update_config_with_witness_oobis "${CONFIG_DIR}"/keri/cf/"${AGENT_CONFIG_FILENAME}".json
}

function update_config_with_witness_oobis() {
  # Update data OOBIs in controller config file
  CONFIG_FILE=$1
  IFS=$'\n'
  iurl_new=()
  iurl_new+=("http://127.0.0.1:${WAN_WITNESS_HTTP_PORT}/oobi/${WAN_PREFIX}")
  iurl_new+=("http://127.0.0.1:${WIL_WITNESS_HTTP_PORT}/oobi/${WIL_PREFIX}")
  iurl_new+=("http://127.0.0.1:${WES_WITNESS_HTTP_PORT}/oobi/${WES_PREFIX}")
  printf '%s\n' "${iurl_new[@]}" | jq -R . | jq -s --argjson witconfig "$(cat ${CONFIG_FILE})" '
    . as $iurl_new | $witconfig | .iurls = $iurl_new
  ' >${CONFIG_FILE}

  log ""
}

function make_keystores_and_incept_kli() {
  # Uses the KLI to create all needed keystores and perform the inception event for each person
  log "${BLGRY}Creating keystores${EC}"

  # Explorer
  log "Creating ${YELLO}Explorer ${EXPLORER_ALIAS}${EC}"
  kli init --name ${EXPLORER_KEYSTORE} --salt "${EXPLORER_SALT}" --nopasscode --config-dir "${CONFIG_DIR}" --config-file "${CONTROLLER_BOOTSTRAP_FILE}"
  kli incept --name ${EXPLORER_KEYSTORE} --alias ${EXPLORER_ALIAS} --file "${WITNESS_INCEPTION_CONFIG_FILE}"

  log ""
  log "Creating ${MAGNT}Librarian ${LIBRARIAN_ALIAS}${EC}"
  # Librarian
  kli init --name ${LIBRARIAN_KEYSTORE} --salt "${LIBRARIAN_SALT}" --nopasscode --config-dir "${CONFIG_DIR}" --config-file "${CONTROLLER_BOOTSTRAP_FILE}"
  kli incept --name ${LIBRARIAN_KEYSTORE} --alias ${LIBRARIAN_ALIAS} --file "${WITNESS_INCEPTION_CONFIG_FILE}"

  log ""
  log "Creating ${LCYAN}Wiseman ${WISEMAN_ALIAS}${EC}"
  # Wise Man
  kli init --name ${WISEMAN_KEYSTORE} --salt "${WISEMAN_SALT}" --nopasscode --config-dir "${CONFIG_DIR}" --config-file "${CONTROLLER_BOOTSTRAP_FILE}"
  kli incept --name ${WISEMAN_KEYSTORE} --alias ${WISEMAN_ALIAS} --file "${WITNESS_INCEPTION_CONFIG_FILE}"
  log ""
}

function read_aliases() {
  # Read aliases into local variables for later usage in writing OOBI configuration and credentials
  log "${BLGRY}Reading in aliases...${EC}"
  RICHARD_PREFIX=$(kli status --name ${EXPLORER_KEYSTORE} --alias ${EXPLORER_ALIAS} | awk '/Identifier:/ {print $2}')
  ELAYNE_PREFIX=$(kli status --name ${LIBRARIAN_KEYSTORE} --alias ${LIBRARIAN_ALIAS} | awk '/Identifier:/ {print $2}')
  WISEMAN_PREFIX=$(kli status --name ${WISEMAN_KEYSTORE} --alias ${WISEMAN_ALIAS} | awk '/Identifier:/ {print $2}')

  log "RICHARD prefix: $RICHARD_PREFIX"
  log "ELAYNE prefix: $ELAYNE_PREFIX"
  log "WISEMAN prefix: $WISEMAN_PREFIX"
}

function make_introductions() {
  # Add OOBI entries to each keystore database for all of the other controllers
  # Example OOBI:
  #   http://localhost:8000/oobi/EJS0-vv_OPAQCdJLmkd5dT0EW-mOfhn_Cje4yzRjTv8q/witness/BLskRTInXnMxWaGqcpSyMgo0nYbalW99cGZESrz3zapM
  log "Pairwise out of band introductions ${LBLUE}OOBIs${EC}"

  log "${LCYAN}Wiseman${EC} meets ${YELLO}Explorer${EC} | Witness: wan"
  kli oobi resolve --name ${WISEMAN_KEYSTORE} --oobi-alias ${EXPLORER_ALIAS} \
    --oobi ${WAN_WITNESS_URL}/oobi/${RICHARD_PREFIX}/witness/${WAN_PREFIX}

  log "${MAGNT}Librarian${EC} meets ${YELLO}Explorer${EC} | Witness: wan"
  kli oobi resolve --name ${LIBRARIAN_KEYSTORE} --oobi-alias ${EXPLORER_ALIAS} \
    --oobi ${WAN_WITNESS_URL}/oobi/${RICHARD_PREFIX}/witness/${WAN_PREFIX}

  log "${LCYAN}Wiseman${EC} meets ${MAGNT}Librarian${EC} | Witness: wan"
  kli oobi resolve --name ${WISEMAN_KEYSTORE} --oobi-alias ${LIBRARIAN_ALIAS} \
    --oobi ${WAN_WITNESS_URL}/oobi/${ELAYNE_PREFIX}/witness/${WAN_PREFIX}

  log "${YELLO}Explorer${EC} meets ${MAGNT}Librarian${EC} | Witness: wan"
  kli oobi resolve --name ${EXPLORER_KEYSTORE} --oobi-alias ${LIBRARIAN_ALIAS} \
    --oobi ${WAN_WITNESS_URL}/oobi/${ELAYNE_PREFIX}/witness/${WAN_PREFIX}

  log "${MAGNT}Librarian${EC} meets ${LCYAN}Wiseman${EC} | Witness: wan"
  kli oobi resolve --name ${LIBRARIAN_KEYSTORE} --oobi-alias ${WISEMAN_ALIAS} \
    --oobi ${WAN_WITNESS_URL}/oobi/${WISEMAN_PREFIX}/witness/${WAN_PREFIX}

  log "${YELLO}Explorer${EC} meets ${LCYAN}Wiseman${EC} | Witness: wan"
  kli oobi resolve --name ${EXPLORER_KEYSTORE} --oobi-alias ${WISEMAN_ALIAS} \
    --oobi ${WAN_WITNESS_URL}/oobi/${WISEMAN_PREFIX}/witness/${WAN_PREFIX}

  log ""
}

function resolve_credential_oobis() {
  # Constructs OOBIs based on the list of controllers and list of ACDC schema SAIDs
  # and performs an OOBI resolution for each pair.
  #
  # Depends on the "said_array" variable populated in the read_schema_saids function
  log "Resolve ${BLGRN}Credential OOBIs${EC}"

  controllers_array=(${EXPLORER_KEYSTORE} ${LIBRARIAN_KEYSTORE} ${WISEMAN_KEYSTORE})
  for i in "${said_array[@]}"; do
    SCHEMA_PARTS=($i)
    log "**** Resolve ${GREEN}${SCHEMA_PARTS[1]}${EC} Credential Schema for all controllers ****"
    for c in "${controllers_array[@]}"; do
      log "Tell ${LBLUE}${c}${EC} about ${BLGRN}${SCHEMA_PARTS[1]}${EC}"
      resolve_credential_oobi ${EXPLORER_KEYSTORE} "${SCHEMA_PARTS[1]}" ${VLEI_SERVER_URL} "${SCHEMA_PARTS[0]}"
    done
  done

  log ""
}

function resolve_credential_oobi() {
  KEYSTORE=$1
  CREDENTIAL_OOBI_ALIAS=$2
  CREDENTIAL_SERVER=$3
  CREDENTIAL_SAID=$4
  kli oobi resolve --name "${KEYSTORE}" --oobi-alias "${CREDENTIAL_OOBI_ALIAS}" \
    --oobi "${CREDENTIAL_SERVER}"/oobi/"${CREDENTIAL_SAID}"
}

function create_credential_registries() {
  log "making credential registries"
  log "Make ${YELLO}${EXPLORER_ALIAS}'s${EC} registry"
  kli vc registry incept --name ${EXPLORER_KEYSTORE} --alias ${EXPLORER_ALIAS} --registry-name ${EXPLORER_REGISTRY}

  log "Make ${MAGNT}${LIBRARIAN_ALIAS}'s${EC} registry"
  kli vc registry incept --name ${LIBRARIAN_KEYSTORE} --alias ${LIBRARIAN_ALIAS} --registry-name ${LIBRARIAN_REGISTRY}

  log "Make ${LCYAN}${WISEMAN_ALIAS}'s${EC} registry"
  kli vc registry incept --name ${WISEMAN_KEYSTORE} --alias ${WISEMAN_ALIAS} --registry-name ${WISEMAN_REGISTRY}

  log ""
}

function check_dependencies() {
  # Checks for [sally, kli, vLEI-server] to exist locally
  # Checks whether the KASLcred Python module is installed.
  python check_kaslcred.py
  KASLCRED=$?
  if [ $KASLCRED == 1 ]; then
    log "${RED}kaslcred is not installed${EC}. Install and retry. Exiting."
    exit 1
  fi
  # Checks for [sally, kli, vLEI-server] to exist locally
  if ! command -v sally &>/dev/null; then
    log "${RED}sally command not found.${EC} Install sally and retry. Exiting"
    exit 1
  fi
  if ! command -v kli &>/dev/null; then
    log "${RED}kli command not found.${EC} Install KERI and retry. Exiting"
    exit 1
  fi
  if ! command -v vLEI-server &>/dev/null; then
    log "${RED}vLEI-server command not found.${EC} Install vLEI-server and retry. Exiting"
    exit 1
  fi
}

function waitloop() {
  log "Control-C to exit (will shut down witnesses, agents, and Sally if started and clear .keri and .sally)"
  log ""
  quit=0
  while [ "$quit" -ne 1 ]; do
    sleep 1
  done
}

function cleanup() {
  # Shuts down any services used by PID
  # Clears out temporary directories $HOME/.sally and $HOME/.keri
  log ""
  log "Shutting down services"

  # Agents
  if [ $EXPLORER_AGENT_PID != 99999 ]; then
    log "${DGREY}Shutting down ${EXPLORER_KEYSTORE} agent${EC}"
    kill $EXPLORER_AGENT_PID
  else
    log "${BLGRY}${EXPLORER_KEYSTORE} Agent not started${EC} so not shutting down"
  fi
  if [ $LIBRARIAN_AGENT_PID != 99999 ]; then
    log "${DGREY}Shutting down ${LIBRARIAN_KEYSTORE} agent${EC}"
    kill $LIBRARIAN_AGENT_PID
  else
    log "${BLGRY}${LIBRARIAN_KEYSTORE} Agent not started${EC} so not shutting down"
  fi
  if [ $WISEMAN_AGENT_PID != 99999 ]; then
    log "${DGREY}Shutting down ${WISEMAN_KEYSTORE} agent${EC}"
    kill $WISEMAN_AGENT_PID
  else
    log "${BLGRY}${WISEMAN_KEYSTORE} Agent not started${EC} so not shutting down"
  fi

  # Webhook
  if [ $GATEKEEPER_WEBHOOK_PID != 99999 ]; then
    log "${DGREY}Shutting down Webhook server${EC}"
    kill $GATEKEEPER_WEBHOOK_PID
  else
    log "${BLGRY}Webhook not started${EC} so not shutting down"
  fi

  # Verification Server
  if [ $SALLY_PID != 9999999 ]; then
    log "${DGREY}Shutting down Sally Verification server${EC}"
    kill $SALLY_PID
    log "Clearing ~/.sally"
    rm -rfv "${HOME}"/.sally
  else
    log "${BLGRY}Sally not started${EC} so not shutting down"
  fi

  # witness network
  if [ $DEMO_WITNESS_NETWORK_PID != 8888888 ]; then
    log "${DGREY}Shutting down witness network${EC}"
    kill $DEMO_WITNESS_NETWORK_PID
  else
    log "${BLGRY}Witness network not started${EC} so not shutting down."
  fi

  # the three witnesses
  if [ $WAN_WITNESS_PID != 99999 ]; then
    log "${DGREY}Shutting down wan witness${EC}"
    kill $WAN_WITNESS_PID
  else
    log "${BLGRY}wan witness not started${EC} so not shutting down."
  fi
  if [ $WIL_WITNESS_PID != 99999 ]; then
    log "${DGREY}Shutting down wil witness${EC}"
    kill $WIL_WITNESS_PID
  else
    log "${BLGRY}wil witness not started${EC} so not shutting down."
  fi
  if [ $WES_WITNESS_PID != 99999 ]; then
    log "${DGREY}Shutting down wes witness${EC}"
    kill $WES_WITNESS_PID
  else
    log "${BLGRY}wes witness not started${EC} so not shutting down."
  fi

  # vLEI Credential Caching server
  if [ $VLEI_SERVER_PID != 7777777 ]; then
    log "${DGREY}Shutting down credential cache server${EC}"
    kill $VLEI_SERVER_PID
  else
    log "${BLGRY}Credential cache server not started${EC} so not shutting down."
  fi

  # Clean out KERI home
  log "${RED}Clearing ~/.keri${EC}"
  if [ "$VERBOSE" = true ]; then
    rm -rfv "${HOME}"/.keri
  else
    rm -rf "${HOME}"/.keri
  fi
}

function main() {
  log "Hello ${GREEN}KERI${EC} Adventurers!"
  log ""
  check_dependencies
  generate_credential_schemas
  read_schema_saids
  start_vlei_server
  #  start_demo_witnesses
  create_witnesses
  start_witnesses
  read_witness_prefixes_and_configure
  #  start_agents
  make_keystores_and_incept_kli
  read_aliases
  make_introductions
  resolve_credential_oobis
  create_credential_registries
  # issue_credentials
  #  setup_sally_verification_server
  # introduce_sally
  #  start_verification_server
  #  add_mappings
  #  start_webhook
  # present_credential
  log "${LBLUE}Let your Journey begin${EC}!"
  waitloop
}

trap cleanup SIGTERM EXIT

while getopts ":hv" option; do
  case $option in
  h)
    log "Abydos workflow script"
    log "workflow.sh [-v] [-h]"
    exit
    ;;
  v)
    VERBOSE=true
    log "VERBOSE set to true"
    main
    ;;
  \?)
    log "Invalid option $option"
    exit
    ;;
  esac
done
main
