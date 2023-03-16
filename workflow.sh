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
LCYAN="\e[1;36m" # Wise Man
GREEN="\e[32m"
YELLO="\e[33m"   # Explorer
MAGNT="\e[35m"   # Librarian
LTGRN="\e[1;32m" # Gatekeeper
PURPL="\e[35m"
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

SERVICES_ONLY=
AGENTS=false
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
SCHEMA_MAPPING_FILTER_FILE=${SCHEMAS_DIR}/schema-mappings-filter.jq
SCHEMA_MAPPING_FILE=${SCHEMAS_DIR}/schema-mappings.json
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
GATEKEEPER_AGENT_PID=99999

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
GATEKEEPER_AGENT_HTTP_PORT=5626
GATEKEEPER_AGENT_TCP_PORT=5627

# URLs
WAN_WITNESS_URL=http://127.0.0.1:5642
VLEI_SERVER_URL=127.0.0.1:7723
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
  mappings=()
  # Load into local vars
  for i in "${said_array[@]}"; do
    SCHEMA_PARTS=($i)
    CREDENTIAL_NAME=${SCHEMA_PARTS[1]}
    CREDENTIAL_SAID=${SCHEMA_PARTS[0]}
    saids+=($CREDENTIAL_SAID)

    if [[ "$CREDENTIAL_NAME" == "TreasureHuntingJourney" ]]; then
      TREASURE_HUNTING_JOURNEY_SCHEMA_SAID="$CREDENTIAL_SAID"
      mappings+=({"TreasureHuntingJourney": $TREASURE_HUNTING_JOURNEY_SCHEMA_SAID})

    elif [[ "$CREDENTIAL_NAME" == "JourneyMarkRequest" ]]; then
      JOURNEY_MARK_REQUEST_SCHEMA_SAID="$CREDENTIAL_SAID"
      mappings+=("{\"JourneyMarkRequest\": \"$JOURNEY_MARK_REQUEST_SCHEMA_SAID\"}")

    elif [[ "$CREDENTIAL_NAME" == "JourneyMark" ]]; then
      JOURNEY_MARK_SCHEMA_SAID="$CREDENTIAL_SAID"
      mappings+=("{\"JourneyMark\": \"$JOURNEY_MARK_SCHEMA_SAID\"}")

    elif [[ "$CREDENTIAL_NAME" == "JourneyCharter" ]]; then
      JOURNEY_CHARTER_SCHEMA_SAID="$CREDENTIAL_SAID"
      mappings+=("{\"JourneyCharter\": \"$JOURNEY_CHARTER_SCHEMA_SAID\"}")

    else
      log "${RED}unrecognized schema parts${EC}"
      log "${LBLUE}SCHEMA_PARTS $CREDENTIAL_SAID $CREDENTIAL_NAME${EC}"
    fi
  done

  # Update mappings in schema mappings file
  # shellcheck disable=SC2086 disable=SC2005
  echo "$(jq --null-input \
    --arg journey $TREASURE_HUNTING_JOURNEY_SCHEMA_SAID \
    --arg request $JOURNEY_MARK_REQUEST_SCHEMA_SAID \
    --arg mark $JOURNEY_MARK_SCHEMA_SAID \
    --arg charter $JOURNEY_CHARTER_SCHEMA_SAID \
    -f ${SCHEMA_MAPPING_FILTER_FILE})" >"${SCHEMA_MAPPING_FILE}"

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
  waitfor ${VLEI_SERVER_URL} -t 3
  log "${BLGRN}Credential Cache Server started${EC}"
  log ""
}

function start_agents() {
  log "Starting ${YELLO}${EXPLORER_KEYSTORE} agent${EC}"

  kli agent start --insecure --admin-http-port ${EXPLORER_AGENT_HTTP_PORT} --tcp ${EXPLORER_AGENT_TCP_PORT} \
    --config-dir ${CONFIG_DIR} --config-file ${AGENT_CONFIG_FILENAME} \
    --path ${ATHENA_DIR}/agent_static &
  EXPLORER_AGENT_PID=$!

  log "Starting ${MAGNT}${LIBRARIAN_KEYSTORE} agent${EC}"
  kli agent start --insecure --admin-http-port ${LIBRARIAN_AGENT_HTTP_PORT} --tcp ${LIBRARIAN_AGENT_TCP_PORT} \
    --config-dir ${CONFIG_DIR} --config-file ${AGENT_CONFIG_FILENAME} \
    --path ${ATHENA_DIR}/agent_static &
  LIBRARIAN_AGENT_PID=$!

  log "Starting ${LCYAN}${WISEMAN_KEYSTORE} agent${EC}"
  kli agent start --insecure --admin-http-port ${WISEMAN_AGENT_HTTP_PORT} --tcp ${WISEMAN_AGENT_TCP_PORT} \
    --config-dir ${CONFIG_DIR} --config-file ${AGENT_CONFIG_FILENAME} \
    --path ${ATHENA_DIR}/agent_static &
  WISEMAN_AGENT_PID=$!

  log "Starting ${LTGRN}${GATEKEEPER_KEYSTORE} agent${EC}"
  kli agent start --insecure --admin-http-port ${GATEKEEPER_AGENT_HTTP_PORT} --tcp ${GATEKEEPER_AGENT_TCP_PORT} \
    --config-dir ${CONFIG_DIR} --config-file ${AGENT_CONFIG_FILENAME} \
    --path ${ATHENA_DIR}/agent_static &
  GATEKEEPER_AGENT_PID=$!

  # Pipelined to run them all in parallel
  # /codes endpoint is the only one I found that allows a GET request to return a 200 success without being unlocked.
  waitfor http://127.0.0.1:${EXPLORER_AGENT_HTTP_PORT}/codes -t 5 |
    waitfor http://127.0.0.1:${LIBRARIAN_AGENT_HTTP_PORT}/codes -t 5 |
    waitfor http://127.0.0.1:${WISEMAN_AGENT_HTTP_PORT}/codes -t 5 |
    waitfor http://127.0.0.1:${GATEKEEPER_AGENT_HTTP_PORT}/codes -t 5

  log "Agents started."
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
    --config-dir "${CONFIG_DIR}" \
    --config-file main/wan-witness
  log "Creating witness ${LCYAN}wil${EC}"
  kli init --name wil --salt 0AB3aWxsLXRoZS13aXRuZXNz --nopasscode \
    --config-dir "${CONFIG_DIR}" \
    --config-file main/wil-witness
  log "Creating witness ${LCYAN}wes${EC}"
  kli init --name wes --salt 0AB3ZXNzLXRoZS13aXRuZXNz --nopasscode \
    --config-dir "${CONFIG_DIR}" \
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
  kli init --name ${EXPLORER_KEYSTORE} --salt "${EXPLORER_SALT}" --nopasscode \
    --config-dir "${CONFIG_DIR}" --config-file "${CONTROLLER_BOOTSTRAP_FILE}"
  kli incept --name ${EXPLORER_KEYSTORE} --alias ${EXPLORER_ALIAS} --file "${WITNESS_INCEPTION_CONFIG_FILE}"

  log ""
  log "Creating ${MAGNT}Librarian ${LIBRARIAN_ALIAS}${EC}"
  # Librarian
  kli init --name ${LIBRARIAN_KEYSTORE} --salt "${LIBRARIAN_SALT}" --nopasscode \
    --config-dir "${CONFIG_DIR}" --config-file "${CONTROLLER_BOOTSTRAP_FILE}"
  kli incept --name ${LIBRARIAN_KEYSTORE} --alias ${LIBRARIAN_ALIAS} --file "${WITNESS_INCEPTION_CONFIG_FILE}"

  log ""
  log "Creating ${LCYAN}Wiseman ${WISEMAN_ALIAS}${EC}"
  # Wise Man
  kli init --name ${WISEMAN_KEYSTORE} --salt "${WISEMAN_SALT}" --nopasscode \
    --config-dir "${CONFIG_DIR}" --config-file "${CONTROLLER_BOOTSTRAP_FILE}"
  kli incept --name ${WISEMAN_KEYSTORE} --alias ${WISEMAN_ALIAS} --file "${WITNESS_INCEPTION_CONFIG_FILE}"
  log ""

  log "Create ${LTGRN}${GATEKEEPER_ALIAS}'s${EC} keystore\n"
  kli init --name ${GATEKEEPER_KEYSTORE} --salt ${GATEKEEPER_SALT} --nopasscode \
    --config-dir "${CONFIG_DIR}" --config-file "${CONTROLLER_BOOTSTRAP_FILE}"
  kli incept --name ${GATEKEEPER_KEYSTORE} --alias ${GATEKEEPER_ALIAS} --file ${WITNESS_INCEPTION_CONFIG_FILE}
  log ""
}

function read_prefixes() {
  # Read aliases into local variables for later usage in writing OOBI configuration and credentials
  log "${BLGRY}Reading in aliases...${EC}"
  RICHARD_PREFIX=$(kli status --name ${EXPLORER_KEYSTORE} --alias ${EXPLORER_ALIAS} | awk '/Identifier:/ {print $2}')
  ELAYNE_PREFIX=$(kli status --name ${LIBRARIAN_KEYSTORE} --alias ${LIBRARIAN_ALIAS} | awk '/Identifier:/ {print $2}')
  WISEMAN_PREFIX=$(kli status --name ${WISEMAN_KEYSTORE} --alias ${WISEMAN_ALIAS} | awk '/Identifier:/ {print $2}')
  GATEKEEPER_PREFIX=$(kli status --name ${GATEKEEPER_KEYSTORE} --alias ${GATEKEEPER_ALIAS} | awk '/Identifier:/ {print $2}')

  log "RICHARD prefix: $RICHARD_PREFIX"
  log "ELAYNE prefix: $ELAYNE_PREFIX"
  log "WISEMAN prefix: $WISEMAN_PREFIX"
  log "Gatekeeper prefix: $GATEKEEPER_PREFIX"
}

function start_gatekeeper_server() {
  log "Starting Gatekeeper server..."
  # TODO set sally home and config dir
  sally server start --name ${GATEKEEPER_KEYSTORE} --alias ${GATEKEEPER_ALIAS} \
    --web-hook http://127.0.0.1:9923 \
    --auth "${WISEMAN_PREFIX}" \
    --schema-mappings "${SCHEMA_MAPPING_FILE}" &
  SALLY_PID=$!
  waitfor localhost:9723 -t 2
  log ""
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

  log "Tell Gatekeeper who ${WISEMAN_ALIAS} is for later presentation support"
  kli oobi resolve --name ${GATEKEEPER_KEYSTORE} --oobi-alias ${GATEKEEPER_ALIAS} \
    --oobi ${WAN_WITNESS_URL}/oobi/${WISEMAN_PREFIX}/witness/${WAN_PREFIX}

  log "${YELLO}${EXPLORER_ALIAS}${EC} meets ${BLRED}Gatekeeper${EC} | Witness: wan"
  kli oobi resolve --name ${EXPLORER_KEYSTORE} --oobi-alias ${GATEKEEPER_ALIAS} \
    --oobi ${WAN_WITNESS_URL}/oobi/${GATEKEEPER_PREFIX}/witness/${WAN_PREFIX}

  log ""

  log "${YELLO}${LIBRARIAN_ALIAS}${EC} meets ${BLRED}Gatekeeper${EC} | Witness: wan"
  kli oobi resolve --name ${LIBRARIAN_KEYSTORE} --oobi-alias ${GATEKEEPER_ALIAS} \
    --oobi ${WAN_WITNESS_URL}/oobi/${GATEKEEPER_PREFIX}/witness/${WAN_PREFIX}

  log ""

  log "${YELLO}${WISEMAN_ALIAS}${EC} meets ${BLRED}Gatekeeper${EC} | Witness: wan"
  kli oobi resolve --name ${WISEMAN_KEYSTORE} --oobi-alias ${GATEKEEPER_ALIAS} \
    --oobi ${WAN_WITNESS_URL}/oobi/${GATEKEEPER_PREFIX}/witness/${WAN_PREFIX}

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
    --oobi http://"${CREDENTIAL_SERVER}"/oobi/"${CREDENTIAL_SAID}"
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

function issue_treasurehuntingjourney_credentials() {
  log "Issue TreasureHuntingJourney credentials as welcomes"
  log "${LCYAN}${WISEMAN_ALIAS}${EC} ${GREEN}issues${EC} TreasureHuntingJourney to ${YELLO}${EXPLORER_ALIAS}${EC}"
  kli vc issue --name ${WISEMAN_KEYSTORE} --alias ${WISEMAN_ALIAS} --registry-name ${WISEMAN_REGISTRY} \
    --schema "${TREASURE_HUNTING_JOURNEY_SCHEMA_SAID}" \
    --recipient "${RICHARD_PREFIX}" \
    --data @"${ATHENA_DIR}"/credential_data/osireion-treasure-hunting-journey.json

  kli vc list --name ${EXPLORER_KEYSTORE} --alias ${EXPLORER_ALIAS} --poll

  log "${LCYAN}${WISEMAN_ALIAS}${EC} ${GREEN}issues${EC} TreasureHuntingJourney to ${MAGNT}${LIBRARIAN_ALIAS}${EC}"
  kli vc issue --name ${WISEMAN_KEYSTORE} --alias ${WISEMAN_ALIAS} --registry-name ${WISEMAN_REGISTRY} \
    --schema "${TREASURE_HUNTING_JOURNEY_SCHEMA_SAID}" \
    --recipient "${ELAYNE_PREFIX}" \
    --data @"${ATHENA_DIR}"/credential_data/osireion-treasure-hunting-journey.json

  kli vc list --name ${LIBRARIAN_KEYSTORE} --alias ${LIBRARIAN_ALIAS} --poll
  log ""
}

function issue_journeymarkrequest_credentials() {
  log "Issue JourneyMarkRequest credentials"
  # Richard JourneyMarkRequest
  log "Prepare ${YELLO}Richard's${EC} TreasureHuntingJourney edge."
  # load credential ID into edge file
  RICHARD_JOURNEY_EDGE_FILTER=${ATHENA_DIR}/credential_edges/richard-journey-edge-filter.jq
  RICHARD_JOURNEY_EDGE=${ATHENA_DIR}/credential_edges/richard-journey-edge.json
  echo "{d: \"\", journey: {n: ., s: \"${TREASURE_HUNTING_JOURNEY_SCHEMA_SAID}\"}}" >"${RICHARD_JOURNEY_EDGE_FILTER}"
  EXPLORER_JOURNEY_SAID=$(kli vc list --name ${EXPLORER_KEYSTORE} --alias ${EXPLORER_ALIAS} --said --schema "${TREASURE_HUNTING_JOURNEY_SCHEMA_SAID}")
  echo \""${EXPLORER_JOURNEY_SAID}"\" | jq -f "${RICHARD_JOURNEY_EDGE_FILTER}" >"${RICHARD_JOURNEY_EDGE}"
  kli saidify --file "${RICHARD_JOURNEY_EDGE}"

  kli saidify --file "${ATHENA_DIR}"/credential_rules/journey-mark-request-rules.json

  log "${YELLO}${EXPLORER_ALIAS}${EC} ${GREEN}issues${EC} JourneyMarkRequest Credential to ${LCYAN}${WISEMAN_ALIAS}${EC}"
  kli vc issue --name ${EXPLORER_KEYSTORE} --alias ${EXPLORER_ALIAS} --registry-name ${EXPLORER_REGISTRY} \
    --schema "${JOURNEY_MARK_REQUEST_SCHEMA_SAID}" \
    --recipient "${WISEMAN_PREFIX}" \
    --data @"${ATHENA_DIR}"/credential_data/journey-mark-request-data-richard.json \
    --edges @"${RICHARD_JOURNEY_EDGE}" \
    --rules @"${ATHENA_DIR}"/credential_rules/journey-mark-request-rules.json

  kli vc list --name ${WISEMAN_KEYSTORE} --alias ${WISEMAN_ALIAS} --schema "${JOURNEY_MARK_REQUEST_SCHEMA_SAID}" --poll
  log ""

  # Elayne JourneyMarkRequest
  log "Prepare ${MAGNT}Elayne's${EC} TreasureHuntingJourney edge."
  # load credential ID into edge file
  ELAYNE_JOURNEY_EDGE_FILTER=${ATHENA_DIR}/credential_edges/elayne-journey-edge-filter.jq
  ELAYNE_JOURNEY_EDGE=${ATHENA_DIR}/credential_edges/elayne-journey-edge.json
  echo "{d: \"\", journey: {n: ., s: \"${TREASURE_HUNTING_JOURNEY_SCHEMA_SAID}\"}}" >"${ELAYNE_JOURNEY_EDGE_FILTER}"
  LIBRARIAN_JOURNEY_SAID=$(kli vc list --name ${LIBRARIAN_KEYSTORE} --alias ${LIBRARIAN_ALIAS} --said --schema "${TREASURE_HUNTING_JOURNEY_SCHEMA_SAID}")
  echo \""${LIBRARIAN_JOURNEY_SAID}"\" | jq -f "${ELAYNE_JOURNEY_EDGE_FILTER}" >"${ELAYNE_JOURNEY_EDGE}"
  kli saidify --file "${ELAYNE_JOURNEY_EDGE}"

  kli saidify --file "${ATHENA_DIR}"/credential_rules/journey-mark-request-rules.json

  log "${MAGNT}${LIBRARIAN_ALIAS}${EC} ${GREEN}issues${EC} JourneyMarkRequest Credential to ${LCYAN}${WISEMAN_ALIAS}${EC}"
  kli vc issue --name ${LIBRARIAN_KEYSTORE} --alias ${LIBRARIAN_ALIAS} --registry-name ${LIBRARIAN_REGISTRY} \
    --schema "${JOURNEY_MARK_REQUEST_SCHEMA_SAID}" \
    --recipient "${WISEMAN_PREFIX}" \
    --data @"${ATHENA_DIR}"/credential_data/journey-mark-request-data-elayne.json \
    --edges @"${ELAYNE_JOURNEY_EDGE}" \
    --rules @"${ATHENA_DIR}"/credential_rules/journey-mark-request-rules.json

  kli vc list --name ${WISEMAN_KEYSTORE} --alias ${WISEMAN_ALIAS} --schema "${JOURNEY_MARK_REQUEST_SCHEMA_SAID}" --poll
}

function issue_journeymark_credentials() {
  log "Issue JourneyMark credentials"
  log "Prepare ${YELLO}Richard's${EC} JourneyMarkRequest edge."
  # load credential ID into edge file
  RICHARD_REQUEST_EDGE_FILTER=${ATHENA_DIR}/credential_edges/richard-request-edge-filter.jq
  RICHARD_REQUEST_EDGE=${ATHENA_DIR}/credential_edges/richard-request-edge.json
  echo "{d: \"\", request: {n: ., s: \"${JOURNEY_MARK_REQUEST_SCHEMA_SAID}\"}}" >"${RICHARD_REQUEST_EDGE_FILTER}"
  # TODO replace this AWK line number hack with a filter to `kli vc list` in a PR.
  EXPLORER_REQUEST_SAID=$(kli vc list --name ${WISEMAN_KEYSTORE} --alias ${WISEMAN_ALIAS} \
    --said --schema "${JOURNEY_MARK_REQUEST_SCHEMA_SAID}" | awk 'NR==1{print $1; exit}')
  echo \""${EXPLORER_REQUEST_SAID}"\" | jq -f "${RICHARD_REQUEST_EDGE_FILTER}" >"${RICHARD_REQUEST_EDGE}"
  kli saidify --file "${RICHARD_REQUEST_EDGE}"

  kli saidify --file "${ATHENA_DIR}"/credential_rules/journey-mark-rules.json

  log "${LCYAN}${WISEMAN_ALIAS}${EC} ${GREEN}issues${EC} JourneyMark Credential to ${YELLO}${EXPLORER_ALIAS}${EC}"
  kli vc issue --name ${WISEMAN_KEYSTORE} --alias ${WISEMAN_ALIAS} --registry-name ${WISEMAN_REGISTRY} \
    --schema "${JOURNEY_MARK_SCHEMA_SAID}" \
    --recipient "${RICHARD_PREFIX}" \
    --data @"${ATHENA_DIR}"/credential_data/journey-mark-data-richard.json \
    --edges @"${RICHARD_REQUEST_EDGE}" \
    --rules @"${ATHENA_DIR}"/credential_rules/journey-mark-rules.json

  kli vc list --name ${EXPLORER_KEYSTORE} --alias ${EXPLORER_ALIAS} --schema "${JOURNEY_MARK_SCHEMA_SAID}" --poll
  log ""

  log "Prepare ${MAGNT}Elayne's${EC} JourneyMarkRequest edge."
  # load credential ID into edge file
  ELAYNE_REQUEST_EDGE_FILTER=${ATHENA_DIR}/credential_edges/elayne-request-edge-filter.jq
  ELAYNE_REQUEST_EDGE=${ATHENA_DIR}/credential_edges/elayne-request-edge.json
  echo "{d: \"\", request: {n: ., s: \"${JOURNEY_MARK_REQUEST_SCHEMA_SAID}\"}}" >"${ELAYNE_REQUEST_EDGE_FILTER}"
  # TODO replace this AWK line number hack with a filter to `kli vc list` in a PR.
  LIBRARIAN_REQUEST_SAID=$(kli vc list --name ${WISEMAN_KEYSTORE} --alias ${WISEMAN_ALIAS} \
    --said --schema "${JOURNEY_MARK_REQUEST_SCHEMA_SAID}" | awk 'NR==2{print $1; exit}')
  echo \""${LIBRARIAN_REQUEST_SAID}"\" | jq -f "${ELAYNE_REQUEST_EDGE_FILTER}" >"${ELAYNE_REQUEST_EDGE}"
  kli saidify --file "${ELAYNE_REQUEST_EDGE}"

  kli saidify --file "${ATHENA_DIR}"/credential_rules/journey-mark-rules.json

  log "${LCYAN}${WISEMAN_ALIAS}${EC} ${GREEN}issues${EC} JourneyMark Credential to ${MAGNT}${LIBRARIAN_ALIAS}${EC}"
  kli vc issue --name ${WISEMAN_KEYSTORE} --alias ${WISEMAN_ALIAS} --registry-name ${WISEMAN_REGISTRY} \
    --schema "${JOURNEY_MARK_SCHEMA_SAID}" \
    --recipient "${ELAYNE_PREFIX}" \
    --data @"${ATHENA_DIR}"/credential_data/journey-mark-data-elayne.json \
    --edges @"${ELAYNE_REQUEST_EDGE}" \
    --rules @"${ATHENA_DIR}"/credential_rules/journey-mark-rules.json

  kli vc list --name ${LIBRARIAN_KEYSTORE} --alias ${LIBRARIAN_ALIAS} --schema "${JOURNEY_MARK_SCHEMA_SAID}" --poll
  log ""
}

function issue_journeycharter_credentials() {
  log "Issue JourneyCharter credentials"

  # Same rules used for both Richard and Elayne
  kli saidify --file "${ATHENA_DIR}"/credential_rules/journey-charter-rules.json

  # Richard JourneyCharter
  log "Prepare ${YELLO}Richard's${EC} JourneyMark edge."
  # load credential ID into edge file
  CHARTER_EDGE_FILTER=${ATHENA_DIR}/credential_edges/journey-charter-edge-filter.jq
  RICHARD_CHARTER_EDGE=${ATHENA_DIR}/credential_edges/richard-charter-edges.json
  # TODO replace this AWK line number hack with a filter to `kli vc list` in a PR.
  EXPLORER_MARK_SAID=$(kli vc list --name ${EXPLORER_KEYSTORE} --alias ${EXPLORER_ALIAS} \
    --said --schema "${JOURNEY_MARK_SCHEMA_SAID}" | awk 'NR==1{print $1; exit}')
  EXPLORER_JOURNEY_SAID=$(kli vc list --name ${EXPLORER_KEYSTORE} --alias ${EXPLORER_ALIAS} \
    --said --schema "${TREASURE_HUNTING_JOURNEY_SCHEMA_SAID}" | awk 'NR==1{print $1; exit}')
  # shellcheck disable=SC2005 disable=SC2086
  echo "$(jq --null-input \
    --arg mark_said ${EXPLORER_MARK_SAID} --arg mark_schema ${JOURNEY_MARK_SCHEMA_SAID} \
    --arg journey_said ${EXPLORER_JOURNEY_SAID} --arg journey_schema ${TREASURE_HUNTING_JOURNEY_SCHEMA_SAID} \
    -f ${CHARTER_EDGE_FILTER})" >"${RICHARD_CHARTER_EDGE}"
  kli saidify --file "${RICHARD_CHARTER_EDGE}"

  log "${LCYAN}${WISEMAN_ALIAS}${EC} ${GREEN}issues${EC} JourneyCharter Credential to ${YELLO}${EXPLORER_ALIAS}${EC}"
  kli vc issue --name ${WISEMAN_KEYSTORE} --alias ${WISEMAN_ALIAS} --registry-name ${WISEMAN_REGISTRY} \
    --schema "${JOURNEY_CHARTER_SCHEMA_SAID}" \
    --recipient "${RICHARD_PREFIX}" \
    --data @"${ATHENA_DIR}"/credential_data/journey-charter-data-richard.json \
    --edges @"${RICHARD_CHARTER_EDGE}" \
    --rules @"${ATHENA_DIR}"/credential_rules/journey-charter-rules.json

  kli vc list --name ${EXPLORER_KEYSTORE} --alias ${EXPLORER_ALIAS} --schema "${JOURNEY_CHARTER_SCHEMA_SAID}" --poll

  # Elayne JourneyCharter
  log "Prepare ${MAGNT}Elayne's${EC} JourneyMark edge."
  # load credential ID into edge file
  CHARTER_EDGE_FILTER=${ATHENA_DIR}/credential_edges/journey-charter-edge-filter.jq
  ELAYNE_CHARTER_EDGE=${ATHENA_DIR}/credential_edges/elayne-charter-edges.json
  # TODO replace this AWK line number hack with a filter to `kli vc list` in a PR.
  LIBRARIAN_MARK_SAID=$(kli vc list --name ${LIBRARIAN_KEYSTORE} --alias ${LIBRARIAN_ALIAS} \
    --said --schema "${JOURNEY_MARK_SCHEMA_SAID}" | awk 'NR==1{print $1; exit}')
  LIBRARIAN_JOURNEY_SAID=$(kli vc list --name ${LIBRARIAN_KEYSTORE} --alias ${LIBRARIAN_ALIAS} \
    --said --schema "${TREASURE_HUNTING_JOURNEY_SCHEMA_SAID}" | awk 'NR==1{print $1; exit}')
  # shellcheck disable=SC2005 disable=SC2086
  echo "$(jq --null-input \
    --arg mark_said ${LIBRARIAN_MARK_SAID} --arg mark_schema ${JOURNEY_MARK_SCHEMA_SAID} \
    --arg journey_said ${LIBRARIAN_JOURNEY_SAID} --arg journey_schema ${TREASURE_HUNTING_JOURNEY_SCHEMA_SAID} \
    -f ${CHARTER_EDGE_FILTER})" >"${ELAYNE_CHARTER_EDGE}"
  kli saidify --file "${ELAYNE_CHARTER_EDGE}"

  log "${LCYAN}${WISEMAN_ALIAS}${EC} ${GREEN}issues${EC} JourneyCharter Credential to ${YELLO}${LIBRARIAN_ALIAS}${EC}"
  kli vc issue --name ${WISEMAN_KEYSTORE} --alias ${WISEMAN_ALIAS} --registry-name ${WISEMAN_REGISTRY} \
    --schema "${JOURNEY_CHARTER_SCHEMA_SAID}" \
    --recipient "${ELAYNE_PREFIX}" \
    --data @"${ATHENA_DIR}"/credential_data/journey-charter-data-elayne.json \
    --edges @"${ELAYNE_CHARTER_EDGE}" \
    --rules @"${ATHENA_DIR}"/credential_rules/journey-charter-rules.json

  kli vc list --name ${LIBRARIAN_KEYSTORE} --alias ${LIBRARIAN_ALIAS} --schema "${JOURNEY_CHARTER_SCHEMA_SAID}" --poll
}

function issue_credentials() {
  log "${BLGRY}Issuing Credentials...${EC}"
  issue_treasurehuntingjourney_credentials
  issue_journeymarkrequest_credentials
  issue_journeymark_credentials
  issue_journeycharter_credentials
  log "Finished issuing credentials"
}

function start_webhook() {
  log "Starting Webhook to listen for presentation events"
  sally hook demo &
  GATEKEEPER_WEBHOOK_PID=$!
  waitfor localhost:9923 -t 1
}

function present_credentials() {
  log "Presenting ${YELLO}${EXPLORER_ALIAS}'s${EC} JourneyCharter ${LBLUE}credential${EC} to ${LTGRN}Gatekeeper${EC}"
  RICHARD_CRED_SAID=$(kli vc list --name ${EXPLORER_KEYSTORE} --alias ${EXPLORER_ALIAS} --said --schema ${JOURNEY_CHARTER_SCHEMA_SAID})
  kli vc present --name ${EXPLORER_KEYSTORE} --alias ${EXPLORER_ALIAS} --said "${RICHARD_CRED_SAID}" --recipient ${GATEKEEPER_ALIAS} --include

  log "Presenting ${MAGNT}${LIBRARIAN_ALIAS}'s${EC} JourneyCharter ${LBLUE}credential${EC} to ${LTGRN}Gatekeeper${EC}"
  ELAYNE_CRED_SAID=$(kli vc list --name ${LIBRARIAN_KEYSTORE} --alias ${LIBRARIAN_ALIAS} --said --schema ${JOURNEY_CHARTER_SCHEMA_SAID})
  kli vc present --name ${LIBRARIAN_KEYSTORE} --alias ${LIBRARIAN_ALIAS} --said "${ELAYNE_CRED_SAID}" --recipient ${GATEKEEPER_ALIAS} --include

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
  if [ $GATEKEEPER_AGENT_PID != 99999 ]; then
    log "${DGREY}Shutting down ${GATEKEEPER_KEYSTORE} agent${EC}"
    kill $GATEKEEPER_AGENT_PID
  else
    log "${BLGRY}${GATEKEEPER_KEYSTORE} Agent not started${EC} so not shutting down"
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

  if [ -f "./credential.json" ]; then
    rm -v "./credential.json"
  fi

  if [ -n "$SERVICES_ONLY" ]; then
    :
  else
    clear_keystores
  fi
}

function clear_keystores() {
  # Clean out KERI home
  log "${RED}Clearing ~/.keri${EC}"
  if [ "$VERBOSE" = true ]; then
    rm -rfv "${HOME}"/.keri
  else
    rm -rf "${HOME}"/.keri
  fi

  # Clean out Sally home
  log "Clearing ~/.sally"
  rm -rfv "${HOME}"/.sally
}

function main() {
  log "Hello ${GREEN}Abydos${EC} Adventurers!"
  log ""
  check_dependencies
  generate_credential_schemas
  read_schema_saids
  if [ "$AGENTS" = true ]; then
    start_vlei_server

    create_witnesses
    start_witnesses
    read_witness_prefixes_and_configure

    #    make_keystores_and_incept_kli
    #    read_prefixes
    start_agents
    #    start_gatekeeper_server
    start_webhook

    #    make_introductions
    #    resolve_credential_oobis

    #    create_credential_registries
    #    issue_credentials
  elif [ -n "$SERVICES_ONLY" ]; then
    start_vlei_server

    start_witnesses
    read_witness_prefixes_and_configure

    read_prefixes
    start_agents
    start_gatekeeper_server
    start_webhook

    # place next item here
    present_credentials
  else
    start_vlei_server

    create_witnesses
    start_witnesses
    read_witness_prefixes_and_configure

    make_keystores_and_incept_kli
    read_prefixes
    start_agents
    start_gatekeeper_server
    start_webhook

    make_introductions
    resolve_credential_oobis

    create_credential_registries
    issue_credentials
    present_credentials
  fi

  log "${LBLUE}Let your Journey begin${EC}!"
  waitloop
}

trap cleanup SIGTERM EXIT

while getopts ":hvsa" option; do
  case $option in
  h)
    log "Abydos workflow script"
    log "workflow.sh [-v VERBOSE] [-h HELP] [-s SERVICES_ONLY] [-a AGENTS]"
    exit
    ;;
  v)
    VERBOSE=true
    log "VERBOSE set to true"
    ;;
  s)
    SERVICES_ONLY=true
    log "SERVICES_ONLY set to true"
    main
    ;;
  a)
    AGENTS=true
    log "Using Agents rather than the KLI to manage keystores"
    main
    ;;
  \?)
    log "Invalid option $option"
    exit
    ;;
  esac
done

main
