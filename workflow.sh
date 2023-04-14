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
BLGRY="\e[1;90m" # Witnesses
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
CLEAR_KEYSTORES=false
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
CONTROLLER_BOOTSTRAP_FILE=${CONFIG_DIR}/keri/cf/controller-oobi-bootstrap.json
AGENT_CONFIG_FILENAME=agent-oobi-bootstrap
AGENT_CONFIG_FILE=${CONFIG_DIR}/keri/cf/${AGENT_CONFIG_FILENAME}.json
CONTROLLER_INCEPTION_CONFIG_FILE=${CONFIG_DIR}/inception-config.json

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
LIBRARIAN_AGENT_URL=http://127.0.0.1:${LIBRARIAN_AGENT_HTTP_PORT}
WISEMAN_AGENT_URL=http://127.0.0.1:${WISEMAN_AGENT_HTTP_PORT}
GATEKEEPER_AGENT_URL=http://127.0.0.1:${GATEKEEPER_AGENT_HTTP_PORT}

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
  log "${BLGRY}Generating ACDC Schemas via KASLcred...${EC}"
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
  sleep 1

  log "Starting ${MAGNT}${LIBRARIAN_KEYSTORE} agent${EC}"
  kli agent start --insecure --admin-http-port ${LIBRARIAN_AGENT_HTTP_PORT} --tcp ${LIBRARIAN_AGENT_TCP_PORT} \
    --config-dir ${CONFIG_DIR} --config-file ${AGENT_CONFIG_FILENAME} \
    --path ${ATHENA_DIR}/agent_static &
  LIBRARIAN_AGENT_PID=$!
  sleep 1

  log "Starting ${LCYAN}${WISEMAN_KEYSTORE} agent${EC}"
  kli agent start --insecure --admin-http-port ${WISEMAN_AGENT_HTTP_PORT} --tcp ${WISEMAN_AGENT_TCP_PORT} \
    --config-dir ${CONFIG_DIR} --config-file ${AGENT_CONFIG_FILENAME} \
    --path ${ATHENA_DIR}/agent_static &
  WISEMAN_AGENT_PID=$!
  sleep 1

  log "Starting ${LTGRN}${GATEKEEPER_KEYSTORE} agent${EC}"
  kli agent start --insecure --admin-http-port ${GATEKEEPER_AGENT_HTTP_PORT} --tcp ${GATEKEEPER_AGENT_TCP_PORT} \
    --config-dir ${CONFIG_DIR} --config-file ${AGENT_CONFIG_FILENAME} \
    --path ${ATHENA_DIR}/agent_static &
  GATEKEEPER_AGENT_PID=$!
  sleep 1

  # Pipelined to run them all in parallel
  # /codes endpoint is the only one I found that allows a GET request to return a 200 success without being unlocked.
  waitfor http://127.0.0.1:${EXPLORER_AGENT_HTTP_PORT}/codes -t 5 |
    waitfor http://127.0.0.1:${LIBRARIAN_AGENT_HTTP_PORT}/codes -t 5 |
    waitfor http://127.0.0.1:${WISEMAN_AGENT_HTTP_PORT}/codes -t 5 |
    waitfor http://127.0.0.1:${GATEKEEPER_AGENT_HTTP_PORT}/codes -t 5

  log "${BLGRN}Agents started.${EC}"
  log ""
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

function create_witnesses_if_not_exists() {
  log ""
  log "${BLGRY}Checking if witnesses exist${EC}"
  kli status --name wan --alias wan
  WAN_EXISTS=$?
  kli status --name wil --alias wil
  WIL_EXISTS=$?
  kli status --name wes --alias wes
  WES_EXISTS=$?
  if [ "$WAN_EXISTS" -ne 0 ] && [ "$WIL_EXISTS" -ne 0 ] && [ "$WES_EXISTS" -ne 0 ]; then
    log "${BLGRN}Witnesses do not exist, creating${EC}"
    create_witnesses
  else
    log "${LCYAN}Witnesses exist, not creating${EC}"
  fi
  log ""
}

function create_witnesses() {
  # Initializes keystores for three witnesses: [wan, wil, wes]
  # Uses the same seeds as those for `kli witness demo` so that the prefixes are the same
  # Puts all keystore and database files in $HOME/.keri
  log "${BLGRY}Creating witnesses...${EC}"
  log "Creating witness ${BLGRY}wan${EC}"
  kli init --name wan --salt 0AB3YW5uLXRoZS13aXRuZXNz --nopasscode \
    --config-dir "${CONFIG_DIR}" \
    --config-file main/wan-witness
  log "Creating witness ${BLGRY}wil${EC}"
  kli init --name wil --salt 0AB3aWxsLXRoZS13aXRuZXNz --nopasscode \
    --config-dir "${CONFIG_DIR}" \
    --config-file main/wil-witness
  log "Creating witness ${BLGRY}wes${EC}"
  kli init --name wes --salt 0AB3ZXNzLXRoZS13aXRuZXNz --nopasscode \
    --config-dir "${CONFIG_DIR}" \
    --config-file main/wes-witness
  log "${BLGRN}Finished creating witnesses' keystores${EC}"
  log ""
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

  log "${BLGRN}Witness network started${EC}"
  log ""
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

function read_witness_prefixes_and_configure() {
  # Writes the witness prefixes to the controller witness and OOBI bootstrap file.
  log "${BLGRY}Reading witness prefixes and writing configuration file...${EC}"
  WAN_PREFIX=$(kli status --name wan --alias wan | awk '/Identifier:/ {print $2}')
  WIL_PREFIX=$(kli status --name wil --alias wil | awk '/Identifier:/ {print $2}')
  WES_PREFIX=$(kli status --name wes --alias wes | awk '/Identifier:/ {print $2}')
  log "WAN prefix: $WAN_PREFIX"
  log "WIL prefix: $WIL_PREFIX"
  log "WES prefix: $WES_PREFIX"

  # Update data OOBIs in controller config file
  log "Writing ${CONTROLLER_BOOTSTRAP_FILE}"
  update_config_with_witness_oobis "$CONTROLLER_BOOTSTRAP_FILE"
  log "Writing ${AGENT_CONFIG_FILE}"
  update_config_with_witness_oobis "${AGENT_CONFIG_FILE}"
}

function make_keystores_and_incept_kli() {
  # Uses the KLI to create all needed keystores and perform the inception event for each person
  log "${BLGRY}Creating controller keystores with the KLI...${EC}"

  # Explorer
  log "Creating ${YELLO}Explorer ${EXPLORER_ALIAS}${EC} keystore (wallet)"
  kli init --name ${EXPLORER_KEYSTORE} --salt "${EXPLORER_SALT}" --nopasscode \
    --config-dir "${CONFIG_DIR}" --config-file "${CONTROLLER_BOOTSTRAP_FILE}"
  log "Performing ${YELLO}Explorer ${EXPLORER_ALIAS}${EC} initial inception event"
  kli incept --name ${EXPLORER_KEYSTORE} --alias ${EXPLORER_ALIAS} --file "${CONTROLLER_INCEPTION_CONFIG_FILE}"
  log ""

  # Librarian
  log "Creating ${MAGNT}Librarian ${LIBRARIAN_ALIAS}${EC} keystore (wallet)"
  kli init --name ${LIBRARIAN_KEYSTORE} --salt "${LIBRARIAN_SALT}" --nopasscode \
    --config-dir "${CONFIG_DIR}" --config-file "${CONTROLLER_BOOTSTRAP_FILE}"
  log "Performing ${MAGNT}Librarian ${LIBRARIAN_ALIAS}${EC} initial inception event"
  kli incept --name ${LIBRARIAN_KEYSTORE} --alias ${LIBRARIAN_ALIAS} --file "${CONTROLLER_INCEPTION_CONFIG_FILE}"
  log ""

  # Wise Man
  log "Creating ${LCYAN}Wise Man ${WISEMAN_ALIAS}${EC} keystore (wallet)"
  kli init --name ${WISEMAN_KEYSTORE} --salt "${WISEMAN_SALT}" --nopasscode \
    --config-dir "${CONFIG_DIR}" --config-file "${CONTROLLER_BOOTSTRAP_FILE}"
  log "Performing  ${LCYAN}Wise Man ${WISEMAN_ALIAS}${EC} initial inception event"
  kli incept --name ${WISEMAN_KEYSTORE} --alias ${WISEMAN_ALIAS} --file "${CONTROLLER_INCEPTION_CONFIG_FILE}"
  log ""

  # Gatekeeper
  log "Create ${LTGRN}${GATEKEEPER_ALIAS}'s${EC} keystore (wallet)"
  kli init --name ${GATEKEEPER_KEYSTORE} --salt ${GATEKEEPER_SALT} --nopasscode \
    --config-dir "${CONFIG_DIR}" --config-file "${CONTROLLER_BOOTSTRAP_FILE}"

  log "Perform ${LTGRN}${GATEKEEPER_ALIAS}'s${EC} initial inception event"
  kli incept --name ${GATEKEEPER_KEYSTORE} --alias ${GATEKEEPER_ALIAS} --file "${CONTROLLER_INCEPTION_CONFIG_FILE}"
  log ""
}

function make_keystores_and_incept_agent() {
  # Makes all of the needed keystores using the Mark 1 KERIpy Agent HTTP interface
  log "${BLGRY}Making Keystores...${EC}"

  log "Creating ${YELLO}Explorer ${EXPLORER_ALIAS}${EC} keystore (wallet)"
  curl -s -X POST "${EXPLORER_AGENT_URL}/boot" -H 'accept: */*' -H 'Content-Type: application/json' \
    --data "{\"name\": \"${EXPLORER_KEYSTORE}\",\"salt\": \"${EXPLORER_SALT}\"}" | jq '.["msg"]' | tr -d '"'
  log ""
  sleep 1
  log "Creating ${MAGNT}Librarian ${LIBRARIAN_ALIAS}${EC} keystore (wallet)"
  curl -s -X POST "${LIBRARIAN_AGENT_URL}/boot" -H 'accept: */*' -H 'Content-Type: application/json' \
    --data "{\"name\": \"${LIBRARIAN_KEYSTORE}\",\"salt\": \"${LIBRARIAN_SALT}\"}" | jq '.["msg"]' | tr -d '"'
  log ""
  sleep 1
  log "Creating ${LCYAN}Wise Man ${WISEMAN_ALIAS}${EC} keystore (wallet)"
  curl -s -X POST "${WISEMAN_AGENT_URL}/boot" -H 'accept: */*' -H 'Content-Type: application/json' \
    --data "{\"name\": \"${WISEMAN_KEYSTORE}\",\"salt\": \"${WISEMAN_SALT}\"}" | jq '.["msg"]' | tr -d '"'
  log ""
  sleep 1
  log "Create ${LTGRN}${GATEKEEPER_ALIAS}'s${EC} keystore (wallet)"
  curl -s -X POST "${GATEKEEPER_AGENT_URL}/boot" -H 'accept: */*' -H 'Content-Type: application/json' \
    --data "{\"name\": \"${GATEKEEPER_KEYSTORE}\",\"salt\": \"${GATEKEEPER_SALT}\"}" | jq '.["msg"]' | tr -d '"'
  log ""
  sleep 1

  log "Unlock keystores"
  log "Unlock ${YELLO}Explorer ${EXPLORER_KEYSTORE}${EC} keystore"
  curl -s -X PUT "${EXPLORER_AGENT_URL}/boot" -H 'accept: */*' -H 'Content-Type: application/json' \
    --data "{\"name\": \"${EXPLORER_KEYSTORE}\",\"salt\": \"${EXPLORER_SALT}\"}" | jq '.["msg"]' | tr -d '"'
  log ""
  sleep 5
  log "Unlock ${MAGNT}Librarian ${LIBRARIAN_KEYSTORE}${EC} keystore"
  curl -s -X PUT "${LIBRARIAN_AGENT_URL}/boot" -H 'accept: */*' -H 'Content-Type: application/json' \
    --data "{\"name\": \"${LIBRARIAN_KEYSTORE}\",\"salt\": \"${LIBRARIAN_SALT}\"}" | jq '.["msg"]' | tr -d '"'
  log ""
  sleep 5
  log "Unlock ${LCYAN}Wise Man ${WISEMAN_KEYSTORE}${EC} keystore"
  curl -s -X PUT "${WISEMAN_AGENT_URL}/boot" -H 'accept: */*' -H 'Content-Type: application/json' \
    --data "{\"name\": \"${WISEMAN_KEYSTORE}\",\"salt\": \"${WISEMAN_SALT}\"}" | jq '.["msg"]' | tr -d '"'
  log ""
  sleep 5
  log "Unlock ${LTGRN}${GATEKEEPER_ALIAS}'s${EC} agent - triggers bootstrap config processing"
  curl -s -X PUT "${GATEKEEPER_AGENT_URL}/boot" -H 'accept: */*' -H 'Content-Type: application/json' \
    --data "{\"name\": \"${GATEKEEPER_KEYSTORE}\",\"salt\": \"${GATEKEEPER_SALT}\"}" | jq '.["msg"]' | tr -d '"'
  log ""
  sleep 5

  log "${BLGRY}Incept keystores${EC}"

  log "Perform ${YELLO}${EXPLORER_ALIAS}'s${EC} initial inception event"
  RICHARD_PREFIX=$(curl -s -X POST "${EXPLORER_AGENT_URL}/ids/${EXPLORER_ALIAS}" -H 'accept: */*' -H 'Content-Type: application/json' \
    --data @${CONTROLLER_INCEPTION_CONFIG_FILE} | jq '.["d"]' | tr -d '"')
  sleep 2
  log ""
  log "Perform ${MAGNT}${LIBRARIAN_ALIAS}'s${EC} initial inception event"
  ELAYNE_PREFIX=$(curl -s -X POST "${LIBRARIAN_AGENT_URL}/ids/${LIBRARIAN_ALIAS}" -H 'accept: */*' -H 'Content-Type: application/json' \
    --data @${CONTROLLER_INCEPTION_CONFIG_FILE} | jq '.["d"]' | tr -d '"')
  sleep 2
  log ""
  log "Perform ${LCYAN}${WISEMAN_ALIAS}'s${EC} initial inception event"
  WISEMAN_PREFIX=$(curl -s -X POST "${WISEMAN_AGENT_URL}/ids/${WISEMAN_ALIAS}" -H 'accept: */*' -H 'Content-Type: application/json' \
    --data @${CONTROLLER_INCEPTION_CONFIG_FILE} | jq '.["d"]' | tr -d '"')
  sleep 2
  log ""
  log "Perform ${LTGRN}${GATEKEEPER_ALIAS}'s${EC} initial inception event"
  GATEKEEPER_PREFIX=$(curl -s -X POST "${GATEKEEPER_AGENT_URL}/ids/${GATEKEEPER_ALIAS}" -H 'accept: */*' -H 'Content-Type: application/json' \
    --data @${CONTROLLER_INCEPTION_CONFIG_FILE} | jq '.["d"]' | tr -d '"')
  sleep 2
  log ""

  log "${YELLO}Richard (Explorer)  prefix: $RICHARD_PREFIX${EC}"
  log "${MAGNT}Elayne (Librarian)  prefix: $ELAYNE_PREFIX${EC}"
  log "${LCYAN}Ramiel (Wise Man)   prefix: $WISEMAN_PREFIX${EC}"
  log "${LTGRN}Zaqiel (Gatekeeper) prefix: $GATEKEEPER_PREFIX${EC}"
  log ""
}

function read_prefixes_kli() {
  # Read aliases into local variables for later usage in writing OOBI configuration and credentials
  log "${BLGRY}Reading in controller aliases using the KLI...${EC}"
  RICHARD_PREFIX=$(kli status --name ${EXPLORER_KEYSTORE} --alias ${EXPLORER_ALIAS} | awk '/Identifier:/ {print $2}')
  ELAYNE_PREFIX=$(kli status --name ${LIBRARIAN_KEYSTORE} --alias ${LIBRARIAN_ALIAS} | awk '/Identifier:/ {print $2}')
  WISEMAN_PREFIX=$(kli status --name ${WISEMAN_KEYSTORE} --alias ${WISEMAN_ALIAS} | awk '/Identifier:/ {print $2}')
  GATEKEEPER_PREFIX=$(kli status --name ${GATEKEEPER_KEYSTORE} --alias ${GATEKEEPER_ALIAS} | awk '/Identifier:/ {print $2}')

  log "Richard (Explorer)  prefix: $RICHARD_PREFIX"
  log "Elayne (Librarian)  prefix: $ELAYNE_PREFIX"
  log "Ramiel (Wise Man)   prefix: $WISEMAN_PREFIX"
  log "Zaqiel (Gatekeeper) prefix: $GATEKEEPER_PREFIX"
}

function start_gatekeeper_server() {
  log "${BLGRY}Starting ${LTGRN}Gatekeeper${EC} ${BLGRY}server...${EC}"
  # TODO set sally home and config dir
  sally server start --name ${GATEKEEPER_KEYSTORE} --alias ${GATEKEEPER_ALIAS} \
    --web-hook http://127.0.0.1:9923 \
    --auth "${WISEMAN_PREFIX}" \
    --schema-mappings "${SCHEMA_MAPPING_FILE}" &
  SALLY_PID=$!
  waitfor localhost:9723 -t 2
  log "${BLGRN}Gatekeeper started${EC}"
  log ""
}

function make_introductions_kli() {
  # Add OOBI entries to each keystore database for all of the other controllers
  # Example OOBI:
  #   http://localhost:8000/oobi/EJS0-vv_OPAQCdJLmkd5dT0EW-mOfhn_Cje4yzRjTv8q/witness/BLskRTInXnMxWaGqcpSyMgo0nYbalW99cGZESrz3zapM
  log "Pairwise out of band introductions (${LBLUE}OOBIs${EC}) with the KLI..."

  log "Wise Man and Librarian -> Explorer"
  log "${LCYAN}Wise Man${EC} meets ${YELLO}Explorer${EC} | Witness: wan"
  kli oobi resolve --name ${WISEMAN_KEYSTORE} --oobi-alias ${EXPLORER_ALIAS} \
    --oobi ${WAN_WITNESS_URL}/oobi/${RICHARD_PREFIX}/witness/${WAN_PREFIX}

  log "${MAGNT}Librarian${EC} meets ${YELLO}Explorer${EC} | Witness: wan"
  kli oobi resolve --name ${LIBRARIAN_KEYSTORE} --oobi-alias ${EXPLORER_ALIAS} \
    --oobi ${WAN_WITNESS_URL}/oobi/${RICHARD_PREFIX}/witness/${WAN_PREFIX}
  log ""

  log "Wise Man and Explorer -> Librarian"
  log "${LCYAN}Wise Man${EC} meets ${MAGNT}Librarian${EC} | Witness: wan"
  kli oobi resolve --name ${WISEMAN_KEYSTORE} --oobi-alias ${LIBRARIAN_ALIAS} \
    --oobi ${WAN_WITNESS_URL}/oobi/${ELAYNE_PREFIX}/witness/${WAN_PREFIX}

  log "${YELLO}Explorer${EC} meets ${MAGNT}Librarian${EC} | Witness: wan"
  kli oobi resolve --name ${EXPLORER_KEYSTORE} --oobi-alias ${LIBRARIAN_ALIAS} \
    --oobi ${WAN_WITNESS_URL}/oobi/${ELAYNE_PREFIX}/witness/${WAN_PREFIX}
  log ""

  log "Librarian and Explorer -> Wise Man"
  log "${MAGNT}Librarian${EC} meets ${LCYAN}Wise Man${EC} | Witness: wan"
  kli oobi resolve --name ${LIBRARIAN_KEYSTORE} --oobi-alias ${WISEMAN_ALIAS} \
    --oobi ${WAN_WITNESS_URL}/oobi/${WISEMAN_PREFIX}/witness/${WAN_PREFIX}

  log "${YELLO}Explorer${EC} meets ${LCYAN}Wise Man${EC} | Witness: wan"
  kli oobi resolve --name ${EXPLORER_KEYSTORE} --oobi-alias ${WISEMAN_ALIAS} \
    --oobi ${WAN_WITNESS_URL}/oobi/${WISEMAN_PREFIX}/witness/${WAN_PREFIX}
  log ""

  log "Gatekeeper -> Wise Man"
  log "Tell Gatekeeper who ${WISEMAN_ALIAS} is for later presentation support"
  kli oobi resolve --name ${GATEKEEPER_KEYSTORE} --oobi-alias ${GATEKEEPER_ALIAS} \
    --oobi ${WAN_WITNESS_URL}/oobi/${WISEMAN_PREFIX}/witness/${WAN_PREFIX}

  log "Explorer, Librarian, Wise Man -> Gatekeeper"
  log "${YELLO}${EXPLORER_ALIAS}${EC} meets ${BLRED}Gatekeeper${EC} | Witness: wan"
  kli oobi resolve --name ${EXPLORER_KEYSTORE} --oobi-alias ${GATEKEEPER_ALIAS} \
    --oobi ${WAN_WITNESS_URL}/oobi/${GATEKEEPER_PREFIX}/witness/${WAN_PREFIX}

  log "${YELLO}${LIBRARIAN_ALIAS}${EC} meets ${BLRED}Gatekeeper${EC} | Witness: wan"
  kli oobi resolve --name ${LIBRARIAN_KEYSTORE} --oobi-alias ${GATEKEEPER_ALIAS} \
    --oobi ${WAN_WITNESS_URL}/oobi/${GATEKEEPER_PREFIX}/witness/${WAN_PREFIX}

  log "${YELLO}${WISEMAN_ALIAS}${EC} meets ${BLRED}Gatekeeper${EC} | Witness: wan"
  kli oobi resolve --name ${WISEMAN_KEYSTORE} --oobi-alias ${GATEKEEPER_ALIAS} \
    --oobi ${WAN_WITNESS_URL}/oobi/${GATEKEEPER_PREFIX}/witness/${WAN_PREFIX}
  log ""
}

function make_introductions_agent() {
  # Perform all OOBI requests with the Agent API
  log "${BLGRY}Performing OOBI requests${EC}"
  log ""

  log "Wise Man -> Explorer"
  log "${LCYAN}Wise Man${EC} meets ${YELLO}Explorer${EC} | Witness: wan"
  curl -s -X POST "${WISEMAN_AGENT_URL}/oobi" -H "accept: */*" -H "Content-Type: application/json" \
    -d "{\"oobialias\": \"${EXPLORER_ALIAS}\", \"url\":\"${WAN_WITNESS_URL}/oobi/${RICHARD_PREFIX}/witness/${WAN_PREFIX}\"}" | jq
  sleep 1

  log "Wise Man -> Librarian"
  curl -s -X POST "${WISEMAN_AGENT_URL}/oobi" -H "accept: */*" -H "Content-Type: application/json" \
    -d "{\"oobialias\": \"${LIBRARIAN_ALIAS}\", \"url\":\"${WAN_WITNESS_URL}/oobi/${ELAYNE_PREFIX}/witness/${WAN_PREFIX}\"}" | jq
  sleep 1

  log "Explorer, Librarian -> Wise Man"
  curl -s -X POST "${EXPLORER_AGENT_URL}/oobi" -H "accept: */*" -H "Content-Type: application/json" \
    -d "{\"oobialias\": \"${WISEMAN_ALIAS}\", \"url\":\"${WAN_WITNESS_URL}/oobi/${WISEMAN_PREFIX}/witness/${WAN_PREFIX}\"}" | jq
  sleep 1

  curl -s -X POST "${LIBRARIAN_AGENT_URL}/oobi" -H "accept: */*" -H "Content-Type: application/json" \
    -d "{\"oobialias\": \"${WISEMAN_ALIAS}\", \"url\":\"${WAN_WITNESS_URL}/oobi/${WISEMAN_PREFIX}/witness/${WAN_PREFIX}\"}" | jq
  sleep 1

  log "Explorer, Librarian -> Gatekeeper"
  curl -s -X POST "${EXPLORER_AGENT_URL}/oobi" -H "accept: */*" -H "Content-Type: application/json" \
    -d "{\"oobialias\": \"${GATEKEEPER_ALIAS}\", \"url\":\"${WAN_WITNESS_URL}/oobi/${GATEKEEPER_PREFIX}/witness/${WAN_PREFIX}\"}" | jq
  sleep 1

  curl -s -X POST "${LIBRARIAN_AGENT_URL}/oobi" -H "accept: */*" -H "Content-Type: application/json" \
    -d "{\"oobialias\": \"${GATEKEEPER_ALIAS}\", \"url\":\"${WAN_WITNESS_URL}/oobi/${GATEKEEPER_PREFIX}/witness/${WAN_PREFIX}\"}" | jq
  sleep 1
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
      # performs kli oobi resolve --name keystore --oobi-alias alias --oobi http://server/oobi/SAID
      resolve_credential_oobi ${EXPLORER_KEYSTORE} "${SCHEMA_PARTS[1]}" ${VLEI_SERVER_URL} "${SCHEMA_PARTS[0]}"
    done
  done

  log ""
}

function resolve_credential_oobi() {
  # Performas an OOBI resolution for the target keystore with the alias and URL parts passed in
  KEYSTORE=$1
  CREDENTIAL_OOBI_ALIAS=$2
  CREDENTIAL_SERVER=$3
  CREDENTIAL_SAID=$4
  kli oobi resolve --name "${KEYSTORE}" --oobi-alias "${CREDENTIAL_OOBI_ALIAS}" \
    --oobi http://"${CREDENTIAL_SERVER}"/oobi/"${CREDENTIAL_SAID}"
}

function create_credential_registries() {
  log "${BLGRY}making credential registries${EC}"
  log "Make ${YELLO}${EXPLORER_ALIAS}'s${EC} registry"
  kli vc registry incept --name ${EXPLORER_KEYSTORE} --alias ${EXPLORER_ALIAS} --registry-name ${EXPLORER_REGISTRY}

  log "Make ${MAGNT}${LIBRARIAN_ALIAS}'s${EC} registry"
  kli vc registry incept --name ${LIBRARIAN_KEYSTORE} --alias ${LIBRARIAN_ALIAS} --registry-name ${LIBRARIAN_REGISTRY}

  log "Make ${LCYAN}${WISEMAN_ALIAS}'s${EC} registry"
  kli vc registry incept --name ${WISEMAN_KEYSTORE} --alias ${WISEMAN_ALIAS} --registry-name ${WISEMAN_REGISTRY}

  log ""
}

function create_credential_registries_agent() {
  log "${BLGRY}Making credential registries${EC}"
  log "Make ${YELLO}${EXPLORER_ALIAS}'s${EC} registry"
  curl -s -X POST "${EXPLORER_AGENT_URL}/registries" -H "accept: */*" -H "Content-Type: application/json" -d "{\"alias\":\"${EXPLORER_ALIAS}\",\"baks\":[],\"estOnly\":false,\"name\":\"${EXPLORER_REGISTRY}\",\"noBackers\":true,\"toad\":0}" | jq
  sleep 2

  log "Make ${MAGNT}${LIBRARIAN_ALIAS}'s${EC} registry"
  curl -s -X POST "${LIBRARIAN_AGENT_URL}/registries" -H "accept: */*" -H "Content-Type: application/json" -d "{\"alias\":\"${LIBRARIAN_ALIAS}\",\"baks\":[],\"estOnly\":false,\"name\":\"${LIBRARIAN_REGISTRY}\",\"noBackers\":true,\"toad\":0}" | jq
  sleep 2

  log "Make ${LCYAN}${WISEMAN_ALIAS}'s${EC} registry"
  curl -s -X POST "${WISEMAN_AGENT_URL}/registries" -H "accept: */*" -H "Content-Type: application/json" -d "{\"alias\":\"${WISEMAN_ALIAS}\",\"baks\":[],\"estOnly\":false,\"name\":\"${WISEMAN_REGISTRY}\",\"noBackers\":true,\"toad\":0}" | jq
  sleep 2

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

function issue_treasurehuntingjourney_credentials_agent() {
  log "Issue TreasureHuntingJourney credentials as welcomes"
  log "${LCYAN}${WISEMAN_ALIAS}${EC} ${GREEN}issues${EC} TreasureHuntingJourney to ${YELLO}${EXPLORER_ALIAS}${EC}"
  JOURNEY_DATA=$(cat "${ATHENA_DIR}"/credential_data/osireion-treasure-hunting-journey.json)
  curl -s -X POST "${WISEMAN_AGENT_URL}/credentials/${WISEMAN_ALIAS}" -H "accept: application/json" -H "Content-Type: application/json" \
    -d "{\"credentialData\":${JOURNEY_DATA},
         \"recipient\":\"${RICHARD_PREFIX}\",
         \"registry\":\"${WISEMAN_REGISTRY}\",
         \"schema\":\"${TREASURE_HUNTING_JOURNEY_SCHEMA_SAID}\"}" | jq '.["d"]' | tr -d '"'
  sleep 5

  EXPLORER_JOURNEY_CRED_SAID=$(curl -s -X GET "${EXPLORER_AGENT_URL}/credentials/${EXPLORER_ALIAS}?type=received&schema=${TREASURE_HUNTING_JOURNEY_SCHEMA_SAID}" | jq '.[0] | .sad.d' | tr -d '"')
  log "Explorer show TreasureHuntingJourney credential SAID: ${YELLO}${EXPLORER_JOURNEY_CRED_SAID}${EC}"
  sleep 1
  log ""

  log "${LCYAN}${WISEMAN_ALIAS}${EC} ${GREEN}issues${EC} TreasureHuntingJourney to ${MAGNT}${LIBRARIAN_ALIAS}${EC}"
  curl -s -X POST "${WISEMAN_AGENT_URL}/credentials/${WISEMAN_ALIAS}" -H "accept: application/json" -H "Content-Type: application/json" \
    -d "{\"credentialData\":${JOURNEY_DATA},
         \"recipient\":\"${ELAYNE_PREFIX}\",
         \"registry\":\"${WISEMAN_REGISTRY}\",
         \"schema\":\"${TREASURE_HUNTING_JOURNEY_SCHEMA_SAID}\"}" | jq '.["d"]' | tr -d '"'
  sleep 5
  LIBRARIAN_JOURNEY_CRED_SAID=$(curl -s -X GET "${LIBRARIAN_AGENT_URL}/credentials/${LIBRARIAN_ALIAS}?type=received&schema=${TREASURE_HUNTING_JOURNEY_SCHEMA_SAID}" | jq '.[0] | .sad.d' | tr -d '"')
  log "Librarian show TreasureHuntingJourney credential SAID: ${MAGNT}${LIBRARIAN_JOURNEY_CRED_SAID}${EC}"
  sleep 1
  log ""
}

function issue_journeymarkrequest_credentials() {
  log "Issue JourneyMarkRequest credentials"
  # Richard JourneyMarkRequest
  log "Prepare ${YELLO}Richard's${EC} TreasureHuntingJourney edge."
  # load credential ID into edge file
  CHARTER_EDGE_FILTER=${ATHENA_DIR}/credential_edges/richard-journey-edge-filter.jq
  RICHARD_JOURNEY_EDGE=${ATHENA_DIR}/credential_edges/richard-journey-edge.json
  echo "{d: \"\", journey: {n: ., s: \"${TREASURE_HUNTING_JOURNEY_SCHEMA_SAID}\"}}" >"${CHARTER_EDGE_FILTER}"
  EXPLORER_JOURNEY_SAID=$(kli vc list --name ${EXPLORER_KEYSTORE} --alias ${EXPLORER_ALIAS} --said --schema "${TREASURE_HUNTING_JOURNEY_SCHEMA_SAID}")
  echo \""${EXPLORER_JOURNEY_SAID}"\" | jq -f "${CHARTER_EDGE_FILTER}" >"${RICHARD_JOURNEY_EDGE}"
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

  log "Show ${LCYAN}Wise Man${EC} received requests"
  kli vc list --name ${WISEMAN_KEYSTORE} --alias ${WISEMAN_ALIAS} --schema "${JOURNEY_MARK_REQUEST_SCHEMA_SAID}" --poll
  log ""
}

function issue_journeymarkrequest_credentials_agent() {
  log "${BLGRY}Issue JourneyMarkRequest credentials${EC}"
  kli saidify --file "${ATHENA_DIR}"/credential_rules/journey-mark-request-rules.json

  REQUEST_RULES=$(cat "${ATHENA_DIR}"/credential_rules/journey-mark-request-rules.json)
  # Richard
  log "Prepare ${YELLO}Richard's${EC} TreasureHuntingJourney edge."
  RICHARD_JOURNEY_EDGE_FILTER=${ATHENA_DIR}/credential_edges/richard-journey-edge-filter.jq
  RICHARD_JOURNEY_EDGE=${ATHENA_DIR}/credential_edges/richard-journey-edge.json
  echo "{d: \"\", journey: {n: ., s: \"${TREASURE_HUNTING_JOURNEY_SCHEMA_SAID}\"}}" >"${RICHARD_JOURNEY_EDGE_FILTER}"
  EXPLORER_JOURNEY_SAID=$(curl -s \
    -X GET "${EXPLORER_AGENT_URL}/credentials/${EXPLORER_ALIAS}?type=received&schema=${TREASURE_HUNTING_JOURNEY_SCHEMA_SAID}" \
    | jq '.[0] | .sad.d' | tr -d '"')
  echo \""${EXPLORER_JOURNEY_SAID}"\" | jq -f "${RICHARD_JOURNEY_EDGE_FILTER}" >"${RICHARD_JOURNEY_EDGE}"

  log "${YELLO}${EXPLORER_ALIAS}${EC} ${GREEN}issues${EC} JourneyMarkRequest Credential to ${LCYAN}${WISEMAN_ALIAS}${EC}"
  RICHARD_MARK_DATA=$(cat "${ATHENA_DIR}"/credential_data/journey-mark-request-data-richard.json)
  RICHARD_EDGE_DATA=$(cat "${RICHARD_JOURNEY_EDGE}")
  curl -s -X POST "${EXPLORER_AGENT_URL}/credentials/${EXPLORER_ALIAS}" -H "accept: application/json" -H "Content-Type: application/json" \
    -d "{\"credentialData\":${RICHARD_MARK_DATA},
         \"recipient\":\"${WISEMAN_PREFIX}\",
         \"registry\":\"${EXPLORER_REGISTRY}\",
         \"schema\":\"${JOURNEY_MARK_REQUEST_SCHEMA_SAID}\",
         \"source\":${RICHARD_EDGE_DATA},
         \"rules\":${REQUEST_RULES}}" | jq '.d' | tr -d '"'
  sleep 5

  EXPLORER_REQUEST_CRED_SAID=$(curl -s -X GET "${EXPLORER_AGENT_URL}/credentials/${EXPLORER_ALIAS}?type=issued&schema=${JOURNEY_MARK_REQUEST_SCHEMA_SAID}" | jq '.[0] | .sad.d' | tr -d '"')
  log "Explorer show JourneyMarkRequest credential SAID: ${YELLO}${EXPLORER_REQUEST_CRED_SAID}${EC}"
  sleep 1
  log ""

  # Elayne
  log "Prepare ${MAGNT}Elayne's${EC} TreasureHuntingJourney edge."
  ELAYNE_JOURNEY_EDGE_FILTER=${ATHENA_DIR}/credential_edges/elayne-journey-edge-filter.jq
  ELAYNE_JOURNEY_EDGE=${ATHENA_DIR}/credential_edges/elayne-journey-edge.json
  echo "{d: \"\", journey: {n: ., s: \"${TREASURE_HUNTING_JOURNEY_SCHEMA_SAID}\"}}" >"${ELAYNE_JOURNEY_EDGE_FILTER}"
  LIBRARIAN_JOURNEY_SAID=$(curl -s -X GET "${LIBRARIAN_AGENT_URL}/credentials/${LIBRARIAN_ALIAS}?type=received&schema=${TREASURE_HUNTING_JOURNEY_SCHEMA_SAID}" | jq '.[0] | .sad.d' | tr -d '"')
  echo \""${LIBRARIAN_JOURNEY_SAID}"\" | jq -f "${ELAYNE_JOURNEY_EDGE_FILTER}" >"${ELAYNE_JOURNEY_EDGE}"

  log "${MAGNT}${LIBRARIAN_ALIAS}${EC} ${GREEN}issues${EC} JourneyMarkRequest Credential to ${LCYAN}${WISEMAN_ALIAS}${EC}"
  ELAYNE_REQUEST_DATA=$(cat "${ATHENA_DIR}"/credential_data/journey-mark-request-data-elayne.json)
  ELAYNE_EDGE_DATA=$(cat "${ELAYNE_JOURNEY_EDGE}")
  curl -s -X POST "${LIBRARIAN_AGENT_URL}/credentials/${LIBRARIAN_ALIAS}" -H "accept: application/json" -H "Content-Type: application/json" \
    -d "{\"credentialData\":${ELAYNE_REQUEST_DATA},
         \"recipient\":\"${WISEMAN_PREFIX}\",
         \"registry\":\"${LIBRARIAN_REGISTRY}\",
         \"schema\":\"${JOURNEY_MARK_REQUEST_SCHEMA_SAID}\",
         \"source\":${ELAYNE_EDGE_DATA},
         \"rules\":${REQUEST_RULES}}" | jq '.d' | tr -d '"'
  sleep 5

  LIBRARIAN_REQUEST_CRED_SAID=$(curl -s -X GET "${LIBRARIAN_AGENT_URL}/credentials/${LIBRARIAN_ALIAS}?type=issued&schema=${JOURNEY_MARK_REQUEST_SCHEMA_SAID}" | jq '.[0] | .sad.d' | tr -d '"')
  log "Librarian show JourneyMarkRequest credential SAID: ${MAGNT}${LIBRARIAN_REQUEST_CRED_SAID}${EC}"
  sleep 1
  log ""
}

function issue_journeymark_credentials() {
  log "Issue JourneyMark credentials"
  kli saidify --file "${ATHENA_DIR}"/credential_rules/journey-mark-rules.json

  log "Prepare ${YELLO}Richard's${EC} JourneyMarkRequest edge."
  # load credential ID into edge file
  RICHARD_REQUEST_EDGE_FILTER=${ATHENA_DIR}/credential_edges/richard-request-edge-filter.jq
  RICHARD_MARK_EDGE=${ATHENA_DIR}/credential_edges/richard-request-edge.json
  echo "{d: \"\", request: {n: ., s: \"${JOURNEY_MARK_REQUEST_SCHEMA_SAID}\"}}" >"${RICHARD_REQUEST_EDGE_FILTER}"
  EXPLORER_REQUEST_SAID=$(kli vc list --name ${EXPLORER_KEYSTORE} --alias ${EXPLORER_ALIAS} \
    --said --issued --schema "${JOURNEY_MARK_REQUEST_SCHEMA_SAID}")
  echo \""${EXPLORER_REQUEST_SAID}"\" | jq -f "${RICHARD_REQUEST_EDGE_FILTER}" >"${RICHARD_MARK_EDGE}"
  kli saidify --file "${RICHARD_MARK_EDGE}"

  log "${LCYAN}${WISEMAN_ALIAS}${EC} ${GREEN}issues${EC} JourneyMark Credential to ${YELLO}${EXPLORER_ALIAS}${EC}"
  kli vc issue --name ${WISEMAN_KEYSTORE} --alias ${WISEMAN_ALIAS} --registry-name ${WISEMAN_REGISTRY} \
    --schema "${JOURNEY_MARK_SCHEMA_SAID}" \
    --recipient "${RICHARD_PREFIX}" \
    --data @"${ATHENA_DIR}"/credential_data/journey-mark-data-richard.json \
    --edges @"${RICHARD_MARK_EDGE}" \
    --rules @"${ATHENA_DIR}"/credential_rules/journey-mark-rules.json

  kli vc list --name ${EXPLORER_KEYSTORE} --alias ${EXPLORER_ALIAS} --schema "${JOURNEY_MARK_SCHEMA_SAID}" --poll
  log ""

  log "Prepare ${MAGNT}Elayne's${EC} JourneyMarkRequest edge."
  # load credential ID into edge file
  ELAYNE_REQUEST_EDGE_FILTER=${ATHENA_DIR}/credential_edges/elayne-request-edge-filter.jq
  ELAYNE_REQUEST_EDGE=${ATHENA_DIR}/credential_edges/elayne-request-edge.json
  echo "{d: \"\", request: {n: ., s: \"${JOURNEY_MARK_REQUEST_SCHEMA_SAID}\"}}" >"${ELAYNE_REQUEST_EDGE_FILTER}"
  LIBRARIAN_REQUEST_SAID=$(kli vc list --name ${LIBRARIAN_KEYSTORE} --alias ${LIBRARIAN_ALIAS} \
    --said --issued --schema "${JOURNEY_MARK_REQUEST_SCHEMA_SAID}")
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

function issue_journeymark_credentials_agent() {
  log "${BLGRY}Issue JourneyMark credentials${EC}"
  CHARTER_RULES=$(cat "${ATHENA_DIR}"/credential_rules/journey-mark-rules.json)
  # Richard
  log "Prepare ${YELLO}Richard's${EC} JourneyMarkRequest edge."
  CHARTER_EDGE_FILTER=${ATHENA_DIR}/credential_edges/richard-request-edge-filter.jq
  RICHARD_REQUEST_EDGE=${ATHENA_DIR}/credential_edges/richard-request-edge.json
  echo "{d: \"\", request: {n: ., s: \"${JOURNEY_MARK_REQUEST_SCHEMA_SAID}\"}}" >"${CHARTER_EDGE_FILTER}"
  EXPLORER_REQUEST_SAID=$(curl -s -X GET "${EXPLORER_AGENT_URL}/credentials/${EXPLORER_ALIAS}?type=issued&schema=${JOURNEY_MARK_REQUEST_SCHEMA_SAID}" | jq '.[0] | .sad.d' | tr -d '"')
  echo \""${EXPLORER_REQUEST_SAID}"\" | jq -f "${CHARTER_EDGE_FILTER}" >"${RICHARD_REQUEST_EDGE}"

  log "${LCYAN}${WISEMAN_ALIAS}${EC} ${GREEN}issues${EC} JourneyMark Credential to ${YELLO}${EXPLORER_ALIAS}${EC}"
  RICHARD_MARK_DATA=$(cat "${ATHENA_DIR}"/credential_data/journey-mark-data-richard.json)
  RICHARD_EDGE_DATA=$(cat "${RICHARD_REQUEST_EDGE}")
  curl -s -X POST "${WISEMAN_AGENT_URL}/credentials/${WISEMAN_ALIAS}" -H "accept: application/json" -H "Content-Type: application/json" \
    -d "{\"credentialData\":${RICHARD_MARK_DATA},
         \"recipient\":\"${RICHARD_PREFIX}\",
         \"registry\":\"${WISEMAN_REGISTRY}\",
         \"schema\":\"${JOURNEY_MARK_SCHEMA_SAID}\",
         \"source\":${RICHARD_EDGE_DATA},
         \"rules\":${CHARTER_RULES}}" | jq '.d' | tr -d '"'
  sleep 7

  EXPLORER_MARK_CRED_SAID=$(curl -s -X GET "${EXPLORER_AGENT_URL}/credentials/${EXPLORER_ALIAS}?type=received&schema=${JOURNEY_MARK_SCHEMA_SAID}" | jq '.[0] | .sad.d' | tr -d '"')
  log "Explorer show JourneyMark credential SAID: ${YELLO}${EXPLORER_MARK_CRED_SAID}${EC}"
  sleep 1
  log ""

  # Elayne
  log "Prepare ${MAGNT}Elayne's${EC} JourneyMarkRequest edge."
  ELAYNE_REQUEST_EDGE_FILTER=${ATHENA_DIR}/credential_edges/elayne-request-edge-filter.jq
  ELAYNE_REQUEST_EDGE=${ATHENA_DIR}/credential_edges/elayne-request-edge.json
  echo "{d: \"\", request: {n: ., s: \"${JOURNEY_MARK_REQUEST_SCHEMA_SAID}\"}}" >"${ELAYNE_REQUEST_EDGE_FILTER}"
  LIBRARIAN_REQUEST_SAID=$(curl -s -X GET "${LIBRARIAN_AGENT_URL}/credentials/${LIBRARIAN_ALIAS}?type=issued&schema=${JOURNEY_MARK_REQUEST_SCHEMA_SAID}" | jq '.[0] | .sad.d' | tr -d '"')
  echo \""${LIBRARIAN_REQUEST_SAID}"\" | jq -f "${ELAYNE_REQUEST_EDGE_FILTER}" >"${ELAYNE_REQUEST_EDGE}"

  log "${LCYAN}${WISEMAN_ALIAS}${EC} ${GREEN}issues${EC} JourneyMark Credential to ${MAGNT}${LIBRARIAN_ALIAS}${EC}"
  ELAYNE_MARK_DATA=$(cat "${ATHENA_DIR}"/credential_data/journey-mark-data-elayne.json)
  ELAYNE_EDGE_DATA=$(cat "${ELAYNE_REQUEST_EDGE}")
  curl -s -X POST "${WISEMAN_AGENT_URL}/credentials/${WISEMAN_ALIAS}" -H "accept: application/json" -H "Content-Type: application/json" \
    -d "{\"credentialData\":${ELAYNE_MARK_DATA},
         \"recipient\":\"${ELAYNE_PREFIX}\",
         \"registry\":\"${WISEMAN_REGISTRY}\",
         \"schema\":\"${JOURNEY_MARK_SCHEMA_SAID}\",
         \"source\":${ELAYNE_EDGE_DATA},
         \"rules\":${CHARTER_RULES}}" | jq '.d' | tr -d '"'
  sleep 7

  LIBRARIAN_MARK_CRED_SAID=$(curl -s -X GET "${LIBRARIAN_AGENT_URL}/credentials/${LIBRARIAN_ALIAS}?type=received&schema=${JOURNEY_MARK_SCHEMA_SAID}" | jq '.[0] | .sad.d' | tr -d '"')
  log "Librarian show JourneyMark credential SAID: ${MAGNT}${LIBRARIAN_MARK_CRED_SAID}${EC}"
  sleep 1
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
  LIBRARIAN_REQUEST_SAID=$(kli vc list --name ${LIBRARIAN_KEYSTORE} --alias ${LIBRARIAN_ALIAS} \
    --said --schema "${TREASURE_HUNTING_JOURNEY_SCHEMA_SAID}" | awk 'NR==1{print $1; exit}')
  # shellcheck disable=SC2005 disable=SC2086
  echo "$(jq --null-input \
    --arg mark_said ${LIBRARIAN_MARK_SAID} --arg mark_schema ${JOURNEY_MARK_SCHEMA_SAID} \
    --arg journey_said ${LIBRARIAN_REQUEST_SAID} --arg journey_schema ${TREASURE_HUNTING_JOURNEY_SCHEMA_SAID} \
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

function issue_journeycharter_credentials_agent() {
  log "${BLGRY}Issue JourneyCharter credentials${EC}"
  # Same rules used for both Richard and Elayne
  kli saidify --file "${ATHENA_DIR}"/credential_rules/journey-charter-rules.json
  CHARTER_RULES=$(cat "${ATHENA_DIR}"/credential_rules/journey-charter-rules.json)
  CHARTER_EDGE_FILTER=${ATHENA_DIR}/credential_edges/journey-charter-edge-filter.jq

  # Richard
  log "Prepare ${YELLO}Richard's${EC} JourneyMark and TreasureHuntingJourney edges."
  RICHARD_CHARTER_EDGE=${ATHENA_DIR}/credential_edges/richard-charter-edges.json
  EXPLORER_MARK_CRED_SAID=$(curl -s -X GET "${EXPLORER_AGENT_URL}/credentials/${EXPLORER_ALIAS}?type=received&schema=${JOURNEY_MARK_SCHEMA_SAID}" | jq '.[0] | .sad.d' | tr -d '"')
  EXPLORER_JOURNEY_CRED_SAID=$(curl -s -X GET "${EXPLORER_AGENT_URL}/credentials/${EXPLORER_ALIAS}?type=received&schema=${TREASURE_HUNTING_JOURNEY_SCHEMA_SAID}" | jq '.[0] | .sad.d' | tr -d '"')
  # shellcheck disable=SC2005 disable=SC2086
  echo "$(jq --null-input \
    --arg mark_said ${EXPLORER_MARK_CRED_SAID} --arg mark_schema ${JOURNEY_MARK_SCHEMA_SAID} \
    --arg journey_said ${EXPLORER_JOURNEY_CRED_SAID} --arg journey_schema ${TREASURE_HUNTING_JOURNEY_SCHEMA_SAID} \
    -f ${CHARTER_EDGE_FILTER})" >"${RICHARD_CHARTER_EDGE}"
  #  kli saidify --file "${RICHARD_CHARTER_EDGE}"

  log "${LCYAN}${WISEMAN_ALIAS}${EC} ${GREEN}issues${EC} JourneyCharter Credential to ${YELLO}${EXPLORER_ALIAS}${EC}"
  RICHARD_CHARTER_DATA=$(cat "${ATHENA_DIR}"/credential_data/journey-charter-data-richard.json)
  RICHARD_CHARTER_EDGE_DATA=$(cat "${RICHARD_CHARTER_EDGE}")
  curl -s -X POST "${WISEMAN_AGENT_URL}/credentials/${WISEMAN_ALIAS}" -H "accept: application/json" -H "Content-Type: application/json" \
    -d "{\"credentialData\":${RICHARD_CHARTER_DATA},
         \"recipient\":\"${RICHARD_PREFIX}\",
         \"registry\":\"${WISEMAN_REGISTRY}\",
         \"schema\":\"${JOURNEY_CHARTER_SCHEMA_SAID}\",
         \"source\":${RICHARD_CHARTER_EDGE_DATA},
         \"rules\":${CHARTER_RULES}}" | jq '.d' | tr -d '"'
  sleep 10

  EXPLORER_CHARTER_CRED_SAID=$(curl -s -X GET "${EXPLORER_AGENT_URL}/credentials/${EXPLORER_ALIAS}?type=received&schema=${JOURNEY_CHARTER_SCHEMA_SAID}" | jq '.[0] | .sad.d' | tr -d '"')
  log "Explorer show JourneyCharter credential SAID: ${YELLO}${EXPLORER_CHARTER_CRED_SAID}${EC}"
  sleep 1
  log ""

  # Elayne
  log "Prepare ${MAGNT}Elayne's${EC} JourneyMark and TreasureHuntingJourney edges."
  ELAYNE_CHARTER_EDGE=${ATHENA_DIR}/credential_edges/elayne-charter-edges.json
  LIBRARIAN_MARK_CRED_SAID=$(curl -s -X GET "${LIBRARIAN_AGENT_URL}/credentials/${LIBRARIAN_ALIAS}?type=received&schema=${JOURNEY_MARK_SCHEMA_SAID}" | jq '.[0] | .sad.d' | tr -d '"')
  LIBRARIAN_JOURNEY_CRED_SAID=$(curl -s -X GET "${LIBRARIAN_AGENT_URL}/credentials/${LIBRARIAN_ALIAS}?type=received&schema=${TREASURE_HUNTING_JOURNEY_SCHEMA_SAID}" | jq '.[0] | .sad.d' | tr -d '"')
  # shellcheck disable=SC2005 disable=SC2086
  echo "$(jq --null-input \
    --arg mark_said ${LIBRARIAN_MARK_CRED_SAID} --arg mark_schema ${JOURNEY_MARK_SCHEMA_SAID} \
    --arg journey_said ${LIBRARIAN_JOURNEY_CRED_SAID} --arg journey_schema ${TREASURE_HUNTING_JOURNEY_SCHEMA_SAID} \
    -f ${CHARTER_EDGE_FILTER})" >"${ELAYNE_CHARTER_EDGE}"

  log "${LCYAN}${WISEMAN_ALIAS}${EC} ${GREEN}issues${EC} JourneyCharter Credential to ${MAGNT}${LIBRARIAN_ALIAS}${EC}"
  ELAYNE_CHARTER_DATA=$(cat "${ATHENA_DIR}"/credential_data/journey-charter-data-elayne.json)
  ELAYNE_CHARTER_EDGE_DATA=$(cat "${ELAYNE_CHARTER_EDGE}")
  curl -s -X POST "${WISEMAN_AGENT_URL}/credentials/${WISEMAN_ALIAS}" -H "accept: application/json" -H "Content-Type: application/json" \
    -d "{\"credentialData\":${ELAYNE_CHARTER_DATA},
         \"recipient\":\"${ELAYNE_PREFIX}\",
         \"registry\":\"${WISEMAN_REGISTRY}\",
         \"schema\":\"${JOURNEY_CHARTER_SCHEMA_SAID}\",
         \"source\":${ELAYNE_CHARTER_EDGE_DATA},
         \"rules\":${CHARTER_RULES}}" | jq '.d' | tr -d '"'
  sleep 5

  LIBRARIAN_CHARTER_CRED_SAID=$(curl -s -X GET "${LIBRARIAN_AGENT_URL}/credentials/${LIBRARIAN_ALIAS}?type=received&schema=${JOURNEY_CHARTER_SCHEMA_SAID}" | jq '.[0] | .sad.d' | tr -d '"')
  sleep 1
  log "Librarian show JourneyCharter credential SAID: ${MAGNT}${LIBRARIAN_CHARTER_CRED_SAID}${EC}"
  log ""
}

function issue_credentials() {
  log "${BLGRY}Issuing Credentials...${EC}"
  issue_treasurehuntingjourney_credentials
  issue_journeymarkrequest_credentials
  issue_journeymark_credentials
  issue_journeycharter_credentials
  log "${BLGRN}Finished issuing credentials${EC}"
  log ""
}

function issue_credentials_agent() {
  log "${BLGRY}Issuing Credentials${EC}"
  issue_treasurehuntingjourney_credentials_agent
  issue_journeymarkrequest_credentials_agent
  issue_journeymark_credentials_agent
  issue_journeycharter_credentials_agent
  log "${BLGRN}Finished issuing credentials${EC}"
}

function start_webhook() {
  log "${BLGRY}Starting Webhook to listen for presentation events${EC}"
  sally hook demo &
  GATEKEEPER_WEBHOOK_PID=$!
  waitfor localhost:9923 -t 1
  log "${BLGRN}Webhook started${EC}"
}

function present_credentials() {
  log "${BLGRY}Presenting Credentials to the ${LTGRN}Gatekeeper${EC}"

  log "Presenting ${YELLO}${EXPLORER_ALIAS}'s${EC} JourneyCharter ${LBLUE}credential${EC} to ${LTGRN}Gatekeeper${EC}"
  RICHARD_CRED_SAID=$(kli vc list --name ${EXPLORER_KEYSTORE} --alias ${EXPLORER_ALIAS} --said --schema ${JOURNEY_CHARTER_SCHEMA_SAID})
  kli vc present --name ${EXPLORER_KEYSTORE} --alias ${EXPLORER_ALIAS} --said "${RICHARD_CRED_SAID}" --recipient ${GATEKEEPER_ALIAS} --include
  sleep 9

  log "Presenting ${MAGNT}${LIBRARIAN_ALIAS}'s${EC} JourneyCharter ${LBLUE}credential${EC} to ${LTGRN}Gatekeeper${EC}"
  ELAYNE_CRED_SAID=$(kli vc list --name ${LIBRARIAN_KEYSTORE} --alias ${LIBRARIAN_ALIAS} --said --schema ${JOURNEY_CHARTER_SCHEMA_SAID})
  kli vc present --name ${LIBRARIAN_KEYSTORE} --alias ${LIBRARIAN_ALIAS} --said "${ELAYNE_CRED_SAID}" --recipient ${GATEKEEPER_ALIAS} --include
  sleep 9

  log "${BLGRN}Credential presentations finished${EC}"
}

function present_credentials_agent() {
  log "${BLGRY}Presenting Credentials to the ${LTGRN}Gatekeeper${EC}"

  log "Presenting ${YELLO}${EXPLORER_ALIAS}'s${EC} JourneyCharter ${LBLUE}credential${EC} to ${LTGRN}Gatekeeper${EC}"
  EXPLORER_CHARTER_CRED_SAID=$(curl -s -X GET "${EXPLORER_AGENT_URL}/credentials/${EXPLORER_ALIAS}?type=received&schema=${JOURNEY_CHARTER_SCHEMA_SAID}" | jq '.[0] | .sad.d' | tr -d '"')
  curl -s -X POST "${EXPLORER_AGENT_URL}/credentials/${EXPLORER_ALIAS}/presentations" -H 'accept: */*' -H 'Content-Type: application/json' \
    -d "{
        \"recipient\": \"${GATEKEEPER_ALIAS}\",
        \"said\": \"${EXPLORER_CHARTER_CRED_SAID}\",
        \"schema\": \"${JOURNEY_CHARTER_SCHEMA_SAID}\",
        \"include\": true
    }"
  sleep 11

  log "Presenting ${MAGNT}${LIBRARIAN_ALIAS}'s${EC} JourneyCharter ${LBLUE}credential${EC} to ${LTGRN}Gatekeeper${EC}"
  LIBRARIAN_CHARTER_CRED_SAID=$(curl -s -X GET "${LIBRARIAN_AGENT_URL}/credentials/${LIBRARIAN_ALIAS}?type=received&schema=${JOURNEY_CHARTER_SCHEMA_SAID}" | jq '.[0] | .sad.d' | tr -d '"')
  curl -s -X POST "${LIBRARIAN_AGENT_URL}/credentials/${LIBRARIAN_ALIAS}/presentations" -H 'accept: */*' -H 'Content-Type: application/json' \
    -d "{
        \"recipient\": \"${GATEKEEPER_ALIAS}\",
        \"said\": \"${LIBRARIAN_CHARTER_CRED_SAID}\",
        \"schema\": \"${JOURNEY_CHARTER_SCHEMA_SAID}\",
        \"include\": true
    }"
  sleep 11
}

function revoke_credentials() {
  log "${BLRED}Revoking${EC} JourneyCharter for ${YELLO}Richard${EC}"
  RICHARD_JOURNEY_CHARTER_CRED_SAID=$(kli vc list --name ${EXPLORER_KEYSTORE} --alias ${EXPLORER_ALIAS} --said --schema ${JOURNEY_CHARTER_SCHEMA_SAID})
  kli vc revoke --name ${WISEMAN_KEYSTORE} --alias ${WISEMAN_ALIAS} --registry-name ${WISEMAN_REGISTRY} --said "${RICHARD_JOURNEY_CHARTER_CRED_SAID}" --send ${GATEKEEPER_ALIAS}
}

function revoke_credentials_agent() {
  log "${BLRED}Revoking${EC} JourneyCharter for ${YELLO}Richard${EC}"

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
  log "${LTGRN}Control-C${EC} to exit (will shut down witnesses, agents, and Gatekeeper  if started, and will clear .keri and .sally)"
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
  log "${BLGRY}Shutting down services${EC}"

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

  if [ "$CLEAR_KEYSTORES" = true ]; then
    clear_keystores
  fi
  log "${BLGRN}All services shut down and keystores cleared${EC}"
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

function agents_and_services_flow() {
  # This flow is for experimenting with the Postman REST Collection
  # Remember to start the Gatekeeper Manually when using this flow
  start_vlei_server
  create_witnesses_if_not_exists
  start_witnesses
  read_witness_prefixes_and_configure
  start_agents
  start_webhook
  log "${BLRED}REMEMBER TO START THE GATEKEEPER MANUALLY AFTER INITIALIZING THE GATEKEEPER KEYSTORE!${EC}"
}

function agent_flow() {
  start_vlei_server
  start_webhook

  create_witnesses
  start_witnesses
  read_witness_prefixes_and_configure

  start_agents
  make_keystores_and_incept_agent
  start_gatekeeper_server

  make_introductions_agent
  create_credential_registries_agent

  issue_credentials_agent
  present_credentials_agent
}

function services_only_flow() {
  # This is a KLI-based flow for experimenting with different steps
  start_vlei_server

  start_witnesses
  read_witness_prefixes_and_configure

  read_prefixes_kli
  start_agents
  start_gatekeeper_server
  start_webhook

  # place next item here
  issue_credentials
}

function main_kli_flow() {
  # The main flow for using the KLI
  # Start Here for understanding
  start_vlei_server # Schema and Credential caching server

  create_witnesses
  start_witnesses
  read_witness_prefixes_and_configure

  make_keystores_and_incept_kli
  read_prefixes_kli
  start_agents
  start_gatekeeper_server
  start_webhook

  make_introductions_kli
  # resolve_credential_oobis - not needed

  create_credential_registries
  issue_credentials
  present_credentials
}

function main() {
  log "Hello ${GREEN}Abydos${EC} Adventurers!"
  log ""
  check_dependencies
  generate_credential_schemas
  read_schema_saids

  if [ -n "$SERVICES_ONLY" ] && [ "$AGENTS" = true ]; then
    agents_and_services_flow
  elif [ "$AGENTS" = true ]; then
    log "agents setup"
    agent_flow
  elif [ -n "$SERVICES_ONLY" ]; then
    services_only_flow
  else
    main_kli_flow
  fi

  log "${LBLUE}Let your Journey begin${EC}!"
  waitloop
}

trap cleanup SIGTERM EXIT

while getopts "h:v:s:a:c:" option; do
  case $option in
  c)
    CLEAR_KEYSTORES=true
    log "CLEAR_KEYSTORES set to true"
    ;;
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
    ;;
  a)
    AGENTS=true
    log "Using Agents rather than the KLI to manage keystores"
    ;;
  \?)
    log "Invalid option $option"
    exit
    ;;
  esac
done

main
