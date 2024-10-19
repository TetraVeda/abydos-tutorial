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

#### Script Configuration ####
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
GATEKEEPER_REGISTRY=${GATEKEEPER_ALIAS}-registry

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
KERIA_PID=999999

#### HTTP and TCP Ports for keystores and agents
# Witness ports
WAN_WITNESS_HTTP_PORT=5642
WAN_WITNESS_TCP_PORT=5632
WIL_WITNESS_HTTP_PORT=5643
WIL_WITNESS_TCP_PORT=5633
WES_WITNESS_HTTP_PORT=5644
WES_WITNESS_TCP_PORT=5634
# Agent ports
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
  # Reads ACDC schema SAIDs and schema names from the schema results directory and
  # writes schema saids to the controller witness and OOBI bootstrap file.
  # creates a mapping of schema names to SAIDs like the following
  # EIxAox3KEhiQ_yCwXWeriQ3ruPWbgK94NDDkHAZCuP9l TreasureHuntingJourney
  # ELc8tMg_hhsAPfVbjUBBC-giEy5440oSb9EzFBZdAxHD JourneyMarkRequest
  # EBEefH4LNQswHSrXanb-3GbjCZK7I_UCL6BdD-zwJ4my JourneyMark
  # EEq0AkHV-i5-aCc1JMBGsd7G85HlBzI3BfyuS5lHOGjr JourneyCharter

  log "Reading in credential SAIDs from ${SCHEMA_RESULTS_DIR}"

  # Read in SAID and Credential Type
  IFS=$'\n' # read whole line
  read -r -d '' -a said_array < <(
    # shellcheck disable=SC2038
    find "$SCHEMA_RESULTS_DIR" -type f -name '*.json' -exec basename {} \; |
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
      mappings+=("{\"TreasureHuntingJourney\": \"$TREASURE_HUNTING_JOURNEY_SCHEMA_SAID\"}")

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
  # shellcheck disable=SC2086
  vLEI-server -s ${SCHEMA_RESULTS_DIR} -c "${ATHENA_DIR}"/cache/acdc -o "${ATHENA_DIR}"/cache/oobis >/dev/null 2>&1 &
  VLEI_SERVER_PID=$!
  waitfor ${VLEI_SERVER_URL} -t 3
  log "${BLGRN}Credential Cache Server started${EC}"
  log ""
}

function start_demo_keystores() {
  # Starts the witness network that comes with KERIpy
  # Six keystores: [wan, wil, wes, wit, wub, wyz]
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
  # Initializes keystores for three keystores: [wan, wil, wes]
  # Uses the same seeds as those for `kli witness demo` so that the prefixes are the same
  # Puts all keystore and database files in $HOME/.keri
  log "${BLGRY}Creating witnesses...${EC}"
  local pid_list=()
  make_witness() {
    local name=$1        # name of the AID, doubles as alias
    local salt=$2        # salt for the AID (kli salt)
    local config_dir=$3  # bootstrap config directory
    local config_file=$4 # bootstrap config file with OOBIs
    # Check if it exists already in $HOME/.keri and if so then skip
    if [ -d "$HOME/.keri/ks/${name}" ]; then
      log "AID ${YELLO}${name}${EC} already exists, skipping creation"
      return
    fi
    log "Creating AID ${name} with config file ${config_file}"
    kli init --name ${name} --salt "${salt}" --nopasscode \
      --config-dir "${config_dir}" --config-file "${config_file}" >/dev/null 2>&1 &
    pid_list+=($!) # add the PID to the list
  }

  make_witness wan 0AB3YW5uLXRoZS13aXRuZXNz "${CONFIG_DIR}" main/wan-witness
  make_witness wil 0AB3aWxsLXRoZS13aXRuZXNz "${CONFIG_DIR}" main/wil-witness
  make_witness wes 0AB3ZXNzLXRoZS13aXRuZXNz "${CONFIG_DIR}" main/wes-witness

  # Wait for all background processes to finish
  if [ ${#pid_list[@]} -gt 0 ]; then
      wait "${pid_list[@]}"
      log "${BLGRN}All witnesses have been created.${EC}"
  else
      log "${RED}No witnesses were started.${EC}"
      exit 1
  fi
  log "${BLGRN}Finished creating witnesses${EC}"
  log ""
}

function migrate_witnesses() {
  log "${BLGRY}Migrating witnesses...${EC}"
  keystores=(wan wil wes); printf '%s\n' "${keystores[@]}" | xargs -I {} kli migrate run --name {} >/dev/null 2>&1
}

function start_witnesses() {
  # Starts keystores on the
  log "${BLGRY}Starting Witness Network (3 witnesses)${EC}..."

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

function make_keystores() {
  local pid_list=()
  make_keystore() {
    local name=$1        # name of the AID, doubles as alias
    local salt=$2        # salt for the AID (kli salt)
    local config_dir=$3  # bootstrap config directory
    local config_file=$4 # bootstrap config file with OOBIs
    # Check if it exists already in $HOME/.keri and if so then skip
    if [ -d "$HOME/.keri/ks/${name}" ]; then
      log "AID ${YELLO}${name}${EC} already exists, skipping creation"
      return
    fi
    log "Creating AID ${name} with config file ${config_file}"
    kli init --name ${name} --salt "${salt}" --nopasscode \
      --config-dir "${config_dir}" --config-file "${config_file}" >/dev/null 2>&1 &
    pid_list+=($!) # add the PID to the list
  }
  make_keystore ${EXPLORER_KEYSTORE} ${EXPLORER_SALT} ${CONFIG_DIR} ${CONTROLLER_BOOTSTRAP_FILE}
  make_keystore ${LIBRARIAN_KEYSTORE} ${LIBRARIAN_SALT} ${CONFIG_DIR} ${CONTROLLER_BOOTSTRAP_FILE}
  make_keystore ${WISEMAN_KEYSTORE} ${WISEMAN_SALT} ${CONFIG_DIR} ${CONTROLLER_BOOTSTRAP_FILE}
  make_keystore ${GATEKEEPER_KEYSTORE} ${GATEKEEPER_SALT} ${CONFIG_DIR} ${CONTROLLER_BOOTSTRAP_FILE}

  # Wait for all background processes to finish
  if [ ${#pid_list[@]} -gt 0 ]; then
      wait "${pid_list[@]}"
      log "${BLGRN}All keystores have been created.${EC}"
  else
      log "${RED}No keystores were started.${EC}"
      exit 1
  fi
}

function migrate_keystores() {
  log "${BLGRY}Migrating keystores...${EC}"
  keystores=(wiseman explorer librarian gatekeeper); printf '%s\n' "${keystores[@]}" | xargs -I {} kli migrate run --name {} >/dev/null 2>&1
}

function incept_ids() {
  # Uses the KLI to create all needed keystores and perform the inception event for each person
  log "${BLGRY}Creating controller keystores with the KLI...${EC}"
  local pid_list=()

  # Explorer
  log "Performing ${YELLO}Explorer ${EXPLORER_ALIAS}${EC} initial inception event"
  kli incept --name ${EXPLORER_KEYSTORE} --alias ${EXPLORER_ALIAS} --file "${CONTROLLER_INCEPTION_CONFIG_FILE}" >/dev/null 2>&1 &
  pid_list+=($!)

  # Librarian
  log "Performing ${MAGNT}Librarian ${LIBRARIAN_ALIAS}${EC} initial inception event"
  kli incept --name ${LIBRARIAN_KEYSTORE} --alias ${LIBRARIAN_ALIAS} --file "${CONTROLLER_INCEPTION_CONFIG_FILE}" >/dev/null 2>&1 &
  pid_list+=($!)

  # Wise Man
  log "Performing  ${LCYAN}Wise Man ${WISEMAN_ALIAS}${EC} initial inception event"
  kli incept --name ${WISEMAN_KEYSTORE} --alias ${WISEMAN_ALIAS} --file "${CONTROLLER_INCEPTION_CONFIG_FILE}" >/dev/null 2>&1 &
  pid_list+=($!)

  # Gatekeeper
  log "Performing ${LTGRN}Gatekeeper ${GATEKEEPER_ALIAS}${EC} initial inception event"
  kli incept --name ${GATEKEEPER_KEYSTORE} --alias ${GATEKEEPER_ALIAS} --file "${CONTROLLER_INCEPTION_CONFIG_FILE}" >/dev/null 2>&1 &
  pid_list+=($!)

  # Wait for all background processes to finish
    if [ ${#pid_list[@]} -gt 0 ]; then
        wait "${pid_list[@]}"
        log "${BLGRN}All IDs are incepted.${EC}"
    else
        log "${RED}No IDs were incepted.${EC}"
    fi
}

function read_prefixes_kli() {
  # Read aliases into local variables for later usage in writing OOBI configuration and credentials
  log "${BLGRY}Reading in controller aliases using the KLI...${EC}"
  RICHARD_PREFIX=$(kli status --name ${EXPLORER_KEYSTORE} --alias ${EXPLORER_ALIAS} | awk '/Identifier:/ {print $2}')
  ELAYNE_PREFIX=$(kli status --name ${LIBRARIAN_KEYSTORE} --alias ${LIBRARIAN_ALIAS} | awk '/Identifier:/ {print $2}')
  WISEMAN_PREFIX=$(kli status --name ${WISEMAN_KEYSTORE} --alias ${WISEMAN_ALIAS} | awk '/Identifier:/ {print $2}')
  GATEKEEPER_PREFIX=$(kli status --name ${GATEKEEPER_KEYSTORE} --alias ${GATEKEEPER_ALIAS} | awk '/Identifier:/ {print $2}')

  log "${YELLO}Richard (Explorer)${EC}  prefix: $RICHARD_PREFIX"
  log "${MAGNT}Elayne (Librarian)${EC}  prefix: $ELAYNE_PREFIX"
  log "${LCYAN}Ramiel (Wise Man)${EC}   prefix: $WISEMAN_PREFIX"
  log "${LTGRN}Zaqiel (Gatekeeper)${EC} prefix: $GATEKEEPER_PREFIX"
}

function start_gatekeeper_server() {
  log "${BLGRY}Starting ${LTGRN}Gatekeeper${EC} ${BLGRY}server...${EC}"
  # TODO set sally home and config dir
  sally server start --name ${GATEKEEPER_KEYSTORE} --alias ${GATEKEEPER_ALIAS} \
    --web-hook http://127.0.0.1:9923 \
    --auth "${WISEMAN_PREFIX}" \
    --schema-mappings "${SCHEMA_MAPPING_FILE}" >/dev/null 2>&1 &
  SALLY_PID=$!
  waitfor localhost:9723 -t 2
  log "${BLGRN}Gatekeeper started${EC}"
  log ""
}

function make_introductions_kli() {
  # Add OOBI entries to each keystore database for all of the other controllers except the gatekeeper; gatekeeper only gets wise man
  # Example OOBI:
  #   http://localhost:8000/oobi/EJS0-vv_OPAQCdJLmkd5dT0EW-mOfhn_Cje4yzRjTv8q/witness/BLskRTInXnMxWaGqcpSyMgo0nYbalW99cGZESrz3zapM
  log "Pairwise out of band introductions (${LBLUE}OOBIs${EC}) with the KLI..."

  local pid_list=()

  log "Wise Man and Librarian -> Explorer"
  log "${LCYAN}Wise Man${EC} meets ${YELLO}Explorer${EC} | Witness: wan"
  kli oobi resolve --name ${WISEMAN_KEYSTORE} --oobi-alias ${EXPLORER_ALIAS} \
    --oobi ${WAN_WITNESS_URL}/oobi/${RICHARD_PREFIX}/witness/${WAN_PREFIX} &
  pid_list+=($!)

  log "${MAGNT}Librarian${EC} meets ${YELLO}Explorer${EC} | Witness: wan"
  kli oobi resolve --name ${LIBRARIAN_KEYSTORE} --oobi-alias ${EXPLORER_ALIAS} \
    --oobi ${WAN_WITNESS_URL}/oobi/${RICHARD_PREFIX}/witness/${WAN_PREFIX} &
  pid_list+=($!)

  log "Wise Man and Explorer -> Librarian"
  log "${LCYAN}Wise Man${EC} meets ${MAGNT}Librarian${EC} | Witness: wan"
  kli oobi resolve --name ${WISEMAN_KEYSTORE} --oobi-alias ${LIBRARIAN_ALIAS} \
    --oobi ${WAN_WITNESS_URL}/oobi/${ELAYNE_PREFIX}/witness/${WAN_PREFIX} &
  pid_list+=($!)

  log "${YELLO}Explorer${EC} meets ${MAGNT}Librarian${EC} | Witness: wan"
  kli oobi resolve --name ${EXPLORER_KEYSTORE} --oobi-alias ${LIBRARIAN_ALIAS} \
    --oobi ${WAN_WITNESS_URL}/oobi/${ELAYNE_PREFIX}/witness/${WAN_PREFIX} &
  pid_list+=($!)

  log "Librarian and Explorer -> Wise Man"
  log "${MAGNT}Librarian${EC} meets ${LCYAN}Wise Man${EC} | Witness: wan"
  kli oobi resolve --name ${LIBRARIAN_KEYSTORE} --oobi-alias ${WISEMAN_ALIAS} \
    --oobi ${WAN_WITNESS_URL}/oobi/${WISEMAN_PREFIX}/witness/${WAN_PREFIX} &
  pid_list+=($!)

  log "${YELLO}Explorer${EC} meets ${LCYAN}Wise Man${EC} | Witness: wan"
  kli oobi resolve --name ${EXPLORER_KEYSTORE} --oobi-alias ${WISEMAN_ALIAS} \
    --oobi ${WAN_WITNESS_URL}/oobi/${WISEMAN_PREFIX}/witness/${WAN_PREFIX} &
  pid_list+=($!)

  log "Gatekeeper -> Wise Man"
  log "Tell Gatekeeper who ${WISEMAN_ALIAS} is for later presentation support"
  kli oobi resolve --name ${GATEKEEPER_KEYSTORE} --oobi-alias ${GATEKEEPER_ALIAS} \
    --oobi ${WAN_WITNESS_URL}/oobi/${WISEMAN_PREFIX}/witness/${WAN_PREFIX} &
  pid_list+=($!)

  # Wait for all background processes to finish
    if [ ${#pid_list[@]} -gt 0 ]; then
        wait "${pid_list[@]}"
        log "${BLGRN}All OOBIs have been resolved.${EC}"
    else
        log "${RED}No OOBIs were resolved.${EC}"
    fi

  # This should not be necessary because IPEX Grant sends the presenter KEL to the receiver (Gatekeeper)
#  log "Explorer, Librarian, Wise Man -> Gatekeeper"
#  log "${YELLO}${EXPLORER_ALIAS}${EC} meets ${BLRED}Gatekeeper${EC} | Witness: wan"
#  kli oobi resolve --name ${EXPLORER_KEYSTORE} --oobi-alias ${GATEKEEPER_ALIAS} \
#    --oobi ${WAN_WITNESS_URL}/oobi/${GATEKEEPER_PREFIX}/witness/${WAN_PREFIX}
#
#  log "${YELLO}${LIBRARIAN_ALIAS}${EC} meets ${BLRED}Gatekeeper${EC} | Witness: wan"
#  kli oobi resolve --name ${LIBRARIAN_KEYSTORE} --oobi-alias ${GATEKEEPER_ALIAS} \
#    --oobi ${WAN_WITNESS_URL}/oobi/${GATEKEEPER_PREFIX}/witness/${WAN_PREFIX}
#
#  log "${YELLO}${WISEMAN_ALIAS}${EC} meets ${BLRED}Gatekeeper${EC} | Witness: wan"
#  kli oobi resolve --name ${WISEMAN_KEYSTORE} --oobi-alias ${GATEKEEPER_ALIAS} \
#    --oobi ${WAN_WITNESS_URL}/oobi/${GATEKEEPER_PREFIX}/witness/${WAN_PREFIX}
#  log ""
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
  local pid_list=()

  create_registry() {
    local keystore="$1"
    local alias="$2"
    local registry="$3"
    local color="$4"

    log "Make ${color}${alias}'s${EC} registry"
    kli vc registry incept --name "${keystore}" --alias "${alias}" --registry-name "${registry}" >/dev/null 2>&1 &
    pid_list+=($!) # add the PID to the list
  }

  create_registry "${EXPLORER_KEYSTORE}" "${EXPLORER_ALIAS}" "${EXPLORER_REGISTRY}" "${YELLO}"
  create_registry "${LIBRARIAN_KEYSTORE}" "${LIBRARIAN_ALIAS}" "${LIBRARIAN_REGISTRY}" "${MAGNT}"
  create_registry "${WISEMAN_KEYSTORE}" "${WISEMAN_ALIAS}" "${WISEMAN_REGISTRY}" "${LCYAN}"
  create_registry "${GATEKEEPER_KEYSTORE}" "${GATEKEEPER_ALIAS}" "${GATEKEEPER_REGISTRY}" "${LTGRN}"

  if [ ${#pid_list[@]} -gt 0 ]; then
    wait "${pid_list[@]}"
    log "${BLGRN}All registries created.${EC}"
  else
    log "${RED}No registries created${EC}"
  fi

  log ""
}

function wait_for_ipex_message() {
  local keystore="$1"
  local alias="$2"
  local ipex_type="$3"
  local said="$4"

  local max_attempts=10
  local sleep_interval=2
  local attempt=1
  local output=""

  log "Waiting for ${LTGRN}IPEX ${ipex_type}${EC} of said ${BLGRN}${said}${EC} for ${alias}..."
  while [[ $attempt -le $max_attempts ]]; do
    output=$(kli ipex list --name "${keystore}" --alias "${alias}" --type "${ipex_type}" --poll)
    if echo "$output" | grep -Eq "$said"; then
      log "${GREEN}Admit received for ${alias}${EC}"
      log "${LCYAN}kli ipex list output: $output${EC}"
      return 0
    fi
    log "Waiting for admit for ${alias} - attempt ${attempt}..."
    logv "failed output was $output"
    sleep $sleep_interval
    attempt=$((attempt + 1))
  done

  log "${RED}Admit not received for ${alias}${EC}"
  return 1
}

function wait_for_credentials() {
  local keystore="$1"
  local alias="$2"
  local schema="$3"
  local said="$4"

  local max_attempts=10
  local sleep_interval=2
  local attempt=1

  log "Waiting for ${LTGRN}credential ${schema}${EC} for ${alias}..."
  while [[ $attempt -le $max_attempts ]]; do
    output=$(kli vc list --name "${keystore}" --alias "${alias}" --schema "${schema}" --poll)

    if echo "$output" | grep -Eq "$said" && echo "$output" | grep -Eq "Status: Issued"; then
      log "${GREEN}Credential received for ${alias}${EC}"
      log "kli vc list output: $output"
      return 0
    fi
    log "Waiting for credential for ${alias} - attempt ${attempt}..."
    log "failed output was $output"
    sleep $sleep_interval
    attempt=$((attempt + 1))
  done

  log "${RED}Credential not received for ${alias}${EC}"
  exit 1
  return 1
}

function issue_treasurehuntingjourney_credentials() {
  log "Issue ${PURPL}TreasureHuntingJourney${EC} credential to ${YELLO}Richard${EC}"

  log "${LCYAN}${WISEMAN_ALIAS}${EC} ${GREEN}creates${EC} ${PURPL}TreasureHuntingJourney${EC} for ${YELLO}${EXPLORER_ALIAS}${EC}"
  kli vc create --name ${WISEMAN_KEYSTORE} --alias ${WISEMAN_ALIAS} --registry-name ${WISEMAN_REGISTRY} \
    --schema "${TREASURE_HUNTING_JOURNEY_SCHEMA_SAID}" \
    --recipient "${RICHARD_PREFIX}" \
    --data @"${ATHENA_DIR}"/credential_data/osireion-treasure-hunting-journey.json
  CRED_SAID=$(kli vc list --name ${WISEMAN_KEYSTORE} --alias ${WISEMAN_ALIAS} \
    --schema "${TREASURE_HUNTING_JOURNEY_SCHEMA_SAID}" --issued --said)
  log "Grant ${LCYAN}${WISEMAN_ALIAS}${EC} ${GREEN}issues (IPEX GRANT)${EC} ${PURPL}TreasureHuntingJourney${EC} to ${YELLO}${EXPLORER_ALIAS}${EC}"
  kli ipex grant --name ${WISEMAN_KEYSTORE} --alias ${WISEMAN_ALIAS} \
    --said ${CRED_SAID} --recipient ${RICHARD_PREFIX}

  IPEX_GRANT=$(kli ipex list --name ${EXPLORER_KEYSTORE} --alias ${EXPLORER_ALIAS} --type grant --poll --said)
  kli ipex admit --name ${EXPLORER_KEYSTORE} --alias ${EXPLORER_ALIAS} --said ${IPEX_GRANT}
  ADMIT=$(kli ipex list --name "${EXPLORER_KEYSTORE}" --alias "${EXPLORER_ALIAS}" --type admit --sent --poll --said | tail -1)
  wait_for_ipex_message "${WISEMAN_KEYSTORE}" "${WISEMAN_ALIAS}" "admit" "${ADMIT}"
  log "${YELLO}${EXPLORER_ALIAS}${EC} ${GREEN}sees${EC} ${PURPL}TreasureHuntingJourney${EC}"
  wait_for_credentials "${EXPLORER_KEYSTORE}" "${EXPLORER_ALIAS}" "${TREASURE_HUNTING_JOURNEY_SCHEMA_SAID}" ${CRED_SAID}

  log ""
}

function issue_treasurehuntingjourney_elayne() {
  log "Issue ${PURPL}TreasureHuntingJourney${EC} credential to ${MAGNT}Elayne${EC}"
  log "${LCYAN}${WISEMAN_ALIAS}${EC} ${GREEN}creates${EC} ${PURPL}TreasureHuntingJourney${EC} for ${MAGNT}${LIBRARIAN_ALIAS}${EC}"
  kli vc create --name ${WISEMAN_KEYSTORE} --alias ${WISEMAN_ALIAS} --registry-name ${WISEMAN_REGISTRY} \
    --schema "${TREASURE_HUNTING_JOURNEY_SCHEMA_SAID}" \
    --recipient "${ELAYNE_PREFIX}" \
    --data @"${ATHENA_DIR}"/credential_data/osireion-treasure-hunting-journey.json
  CRED_SAID=$(kli vc list --name ${WISEMAN_KEYSTORE} --alias ${WISEMAN_ALIAS} \
    --schema "${TREASURE_HUNTING_JOURNEY_SCHEMA_SAID}" \
    --issued --said | tail -1) # get the last said since the last one is the one we just issued
  log "Grant ${LCYAN}${WISEMAN_ALIAS}${EC} ${GREEN}issues (IPEX GRANT)${EC} ${PURPL}TreasureHuntingJourney${EC} with SAID ${SAID} to ${MAGNT}${LIBRARIAN_ALIAS}${EC}"
  kli ipex grant --name ${WISEMAN_KEYSTORE} --alias ${WISEMAN_ALIAS} \
    --said ${CRED_SAID} --recipient ${ELAYNE_PREFIX}

  IPEX_GRANT=$(kli ipex list --name ${LIBRARIAN_KEYSTORE} --alias ${LIBRARIAN_ALIAS} --type grant --poll --said)
  kli ipex admit --name ${LIBRARIAN_KEYSTORE} --alias ${LIBRARIAN_ALIAS} --said ${IPEX_GRANT}
  log "IPEX list for elayne"
  kli ipex list --name ${LIBRARIAN_KEYSTORE} --alias ${LIBRARIAN_ALIAS} --poll
  ADMIT=$(kli ipex list --name "${LIBRARIAN_KEYSTORE}" --alias "${LIBRARIAN_ALIAS}" --type admit --sent --poll --said | tail -1)
  wait_for_ipex_message "${WISEMAN_KEYSTORE}" "${WISEMAN_ALIAS}" "admit" "${ADMIT}"
  log "${MAGNT}${LIBRARIAN_ALIAS}${EC} ${GREEN}sees${EC} ${PURPL}TreasureHuntingJourney${EC} "
  kli vc list --name ${LIBRARIAN_KEYSTORE} --alias ${LIBRARIAN_ALIAS} --poll
  wait_for_credentials "${LIBRARIAN_KEYSTORE}" "${LIBRARIAN_ALIAS}" "${TREASURE_HUNTING_JOURNEY_SCHEMA_SAID}" ${CRED_SAID}

  log ""
}

function issue_journeymarkrequest_credentials() {
  log "Issue JourneyMarkRequest credentials"
  kli saidify --file "${ATHENA_DIR}"/credential_rules/journey-mark-request-rules.json

  # Richard JourneyMarkRequest
  log "Prepare ${YELLO}Richard's${EC} TreasureHuntingJourney edge."
  # load credential ID into edge file
  CHARTER_EDGE_FILTER=${ATHENA_DIR}/credential_edges/richard-journey-edge-filter.jq
  RICHARD_JOURNEY_EDGE=${ATHENA_DIR}/credential_edges/richard-journey-edge.json
  echo "{d: \"\", journey: {n: ., s: \"${TREASURE_HUNTING_JOURNEY_SCHEMA_SAID}\"}}" >"${CHARTER_EDGE_FILTER}"
  log "Prepare ${YELLO}Richard's${EC} TreasureHuntingJourney edge. ${CHARTER_EDGE_FILTER}"
  EXPLORER_JOURNEY_SAID=$(kli vc list --name ${EXPLORER_KEYSTORE} --alias ${EXPLORER_ALIAS} --said --schema "${TREASURE_HUNTING_JOURNEY_SCHEMA_SAID}")
  echo \""${EXPLORER_JOURNEY_SAID}"\" | jq -f "${CHARTER_EDGE_FILTER}" >"${RICHARD_JOURNEY_EDGE}"
  kli saidify --file "${RICHARD_JOURNEY_EDGE}"

  log "${YELLO}${EXPLORER_ALIAS}${EC} ${GREEN}creates${EC} ${PURPL}JourneyMarkRequest${EC} Credential for ${LCYAN}${WISEMAN_ALIAS}${EC}"
  kli vc create --name ${EXPLORER_KEYSTORE} --alias ${EXPLORER_ALIAS} --registry-name ${EXPLORER_REGISTRY} \
    --schema "${JOURNEY_MARK_REQUEST_SCHEMA_SAID}" \
    --recipient "${WISEMAN_PREFIX}" \
    --data @"${ATHENA_DIR}"/credential_data/journey-mark-request-data-richard.json \
    --edges @"${RICHARD_JOURNEY_EDGE}" \
    --rules @"${ATHENA_DIR}"/credential_rules/journey-mark-request-rules.json
  CRED_SAID=$(kli vc list --name ${EXPLORER_KEYSTORE} --alias ${EXPLORER_ALIAS} \
    --schema "${JOURNEY_MARK_REQUEST_SCHEMA_SAID}" \
    --issued --said)
  log "Grant ${YELLO}${EXPLORER_ALIAS}${EC} ${GREEN}issues (IPEX GRANT)${EC} ${PURPL}JourneyMarkRequest${EC} said ${CRED_SAID} to ${LCYAN}${WISEMAN_ALIAS}${EC}"
  kli ipex grant --name ${EXPLORER_KEYSTORE} --alias ${EXPLORER_ALIAS} \
    --said ${CRED_SAID} --recipient ${WISEMAN_PREFIX}

  IPEX_GRANT=$(kli ipex list --name ${WISEMAN_KEYSTORE} --alias ${WISEMAN_ALIAS} --type grant --poll --said)
  kli ipex admit --name ${WISEMAN_KEYSTORE} --alias ${WISEMAN_ALIAS} --said ${IPEX_GRANT}
  ADMIT=$(kli ipex list --name "${WISEMAN_KEYSTORE}" --alias "${WISEMAN_ALIAS}" --type admit --sent --poll --said | tail -1)
  wait_for_ipex_message "${EXPLORER_KEYSTORE}" "${EXPLORER_ALIAS}" "admit" "${ADMIT}"
  log "${LCYAN}${WISEMAN_ALIAS}${EC} ${GREEN}sees${EC} ${PURPL}JourneyMarkRequest${EC}"
  wait_for_credentials "${WISEMAN_KEYSTORE}" "${WISEMAN_ALIAS}" "${JOURNEY_MARK_REQUEST_SCHEMA_SAID}" ${CRED_SAID}

  log ""
}

function issue_journeymarkrequest_elayne() {
  log "Issue JourneyMarkRequest credential to Elayne"
  kli saidify --file "${ATHENA_DIR}"/credential_rules/journey-mark-request-rules.json
  # Elayne JourneyMarkRequest
  log "Prepare ${MAGNT}Elayne's${EC} TreasureHuntingJourney edge."
  # load credential ID into edge file
  ELAYNE_JOURNEY_EDGE_FILTER=${ATHENA_DIR}/credential_edges/elayne-journey-edge-filter.jq
  ELAYNE_JOURNEY_EDGE=${ATHENA_DIR}/credential_edges/elayne-journey-edge.json
  echo "{d: \"\", journey: {n: ., s: \"${TREASURE_HUNTING_JOURNEY_SCHEMA_SAID}\"}}" >"${ELAYNE_JOURNEY_EDGE_FILTER}"
  log "Prepare ${MAGNT}Elayne's${EC} TreasureHuntingJourney edge. ${ELAYNE_JOURNEY_EDGE_FILTER}"
  LIBRARIAN_JOURNEY_SAID=$(kli vc list --name ${LIBRARIAN_KEYSTORE} --alias ${LIBRARIAN_ALIAS} --said --schema "${TREASURE_HUNTING_JOURNEY_SCHEMA_SAID}")
  echo \""${LIBRARIAN_JOURNEY_SAID}"\" | jq -f "${ELAYNE_JOURNEY_EDGE_FILTER}" >"${ELAYNE_JOURNEY_EDGE}"
  kli saidify --file "${ELAYNE_JOURNEY_EDGE}"

  log "${MAGNT}${LIBRARIAN_ALIAS}${EC} ${GREEN}creates${EC} ${PURPL}JourneyMarkRequest${EC} Credential for ${LCYAN}${WISEMAN_ALIAS}${EC}"
  kli vc create --name ${LIBRARIAN_KEYSTORE} --alias ${LIBRARIAN_ALIAS} --registry-name ${LIBRARIAN_REGISTRY} \
    --schema "${JOURNEY_MARK_REQUEST_SCHEMA_SAID}" \
    --recipient "${WISEMAN_PREFIX}" \
    --data @"${ATHENA_DIR}"/credential_data/journey-mark-request-data-elayne.json \
    --edges @"${ELAYNE_JOURNEY_EDGE}" \
    --rules @"${ATHENA_DIR}"/credential_rules/journey-mark-request-rules.json
  CRED_SAID=$(kli vc list --name ${LIBRARIAN_KEYSTORE} --alias ${LIBRARIAN_ALIAS} \
    --schema "${JOURNEY_MARK_REQUEST_SCHEMA_SAID}" \
    --issued --said)
  log "Grant ${MAGNT}${LIBRARIAN_ALIAS}${EC} ${GREEN}issues (IPEX GRANT)${EC} ${PURPL}JourneyMarkRequest${EC} to ${LCYAN}${WISEMAN_ALIAS}${EC}"
  kli ipex grant --name ${LIBRARIAN_KEYSTORE} --alias ${LIBRARIAN_ALIAS} \
    --said ${CRED_SAID} --recipient ${WISEMAN_PREFIX}

  IPEX_GRANT=$(kli ipex list --name ${WISEMAN_KEYSTORE} --alias ${WISEMAN_ALIAS} --type grant --poll --said | tail -1)
  kli ipex admit --name ${WISEMAN_KEYSTORE} --alias ${WISEMAN_ALIAS} --said ${IPEX_GRANT}
  ADMIT=$(kli ipex list --name "${WISEMAN_KEYSTORE}" --alias "${WISEMAN_ALIAS}" --type admit --sent --poll --said | tail -1)
  wait_for_ipex_message "${LIBRARIAN_KEYSTORE}" "${LIBRARIAN_ALIAS}" "admit" "${ADMIT}"
  log "${LCYAN}${WISEMAN_ALIAS}${EC} ${GREEN}sees${EC} ${PURPL}JourneyMarkRequest${EC}"
  wait_for_credentials "${WISEMAN_KEYSTORE}" "${WISEMAN_ALIAS}" "${JOURNEY_MARK_REQUEST_SCHEMA_SAID}" ${CRED_SAID}

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

  log "${LCYAN}${WISEMAN_ALIAS}${EC} ${GREEN}creates${EC} ${PURPL}JourneyMark${EC} Credential for ${YELLO}${EXPLORER_ALIAS}${EC}"
  kli vc create --name ${WISEMAN_KEYSTORE} --alias ${WISEMAN_ALIAS} --registry-name ${WISEMAN_REGISTRY} \
    --schema "${JOURNEY_MARK_SCHEMA_SAID}" \
    --recipient "${RICHARD_PREFIX}" \
    --data @"${ATHENA_DIR}"/credential_data/journey-mark-data-richard.json \
    --edges @"${RICHARD_MARK_EDGE}" \
    --rules @"${ATHENA_DIR}"/credential_rules/journey-mark-rules.json
  CRED_SAID=$(kli vc list --name ${WISEMAN_KEYSTORE} --alias ${WISEMAN_ALIAS} \
    --schema "${JOURNEY_MARK_SCHEMA_SAID}" \
    --issued --said)
  log "Grant ${LCYAN}${WISEMAN_ALIAS}${EC} ${GREEN}issues (IPEX GRANT)${EC} ${PURPL}JourneyMark${EC} said ${CRED_SAID} to ${YELLO}${EXPLORER_ALIAS}${EC}"
  kli ipex grant --name ${WISEMAN_KEYSTORE} --alias ${WISEMAN_ALIAS} \
    --said ${CRED_SAID} --recipient ${RICHARD_PREFIX}

  log "IPEX grant list for richard JourneyMark"
  kli ipex list --name ${EXPLORER_KEYSTORE} --alias ${EXPLORER_ALIAS} --type grant --poll

  IPEX_GRANT=$(kli ipex list --name ${EXPLORER_KEYSTORE} --alias ${EXPLORER_ALIAS} --type grant --poll --said | tail -1)
  kli ipex admit --name ${EXPLORER_KEYSTORE} --alias ${EXPLORER_ALIAS} --said ${IPEX_GRANT}
  ADMIT=$(kli ipex list --name "${EXPLORER_KEYSTORE}" --alias "${EXPLORER_ALIAS}" --type admit --sent --poll --said | tail -1)
  wait_for_ipex_message "${WISEMAN_KEYSTORE}" "${WISEMAN_ALIAS}" "admit" "${ADMIT}"
  log "${YELLO}${EXPLORER_ALIAS}${EC} ${GREEN}sees${EC} ${PURPL}JourneyMark${EC}"
  wait_for_credentials "${EXPLORER_KEYSTORE}" "${EXPLORER_ALIAS}" "${JOURNEY_MARK_SCHEMA_SAID}" ${CRED_SAID}

  log ""
}

function issue_journeymark_elayne() {
  log "Issue JourneyMark credential to Elayne"
  kli saidify --file "${ATHENA_DIR}"/credential_rules/journey-mark-rules.json

  log "Prepare ${MAGNT}Elayne's${EC} JourneyMarkRequest edge."
  # load credential ID into edge file
  ELAYNE_REQUEST_EDGE_FILTER=${ATHENA_DIR}/credential_edges/elayne-request-edge-filter.jq
  ELAYNE_REQUEST_EDGE=${ATHENA_DIR}/credential_edges/elayne-request-edge.json
  echo "{d: \"\", request: {n: ., s: \"${JOURNEY_MARK_REQUEST_SCHEMA_SAID}\"}}" >"${ELAYNE_REQUEST_EDGE_FILTER}"
  LIBRARIAN_REQUEST_SAID=$(kli vc list --name ${LIBRARIAN_KEYSTORE} --alias ${LIBRARIAN_ALIAS} \
    --said --issued --schema "${JOURNEY_MARK_REQUEST_SCHEMA_SAID}")
  echo \""${LIBRARIAN_REQUEST_SAID}"\" | jq -f "${ELAYNE_REQUEST_EDGE_FILTER}" >"${ELAYNE_REQUEST_EDGE}"
  kli saidify --file "${ELAYNE_REQUEST_EDGE}"

  log "${LCYAN}${WISEMAN_ALIAS}${EC} ${GREEN}creates${EC} ${PURPL}JourneyMark${EC} Credential for ${MAGNT}${LIBRARIAN_ALIAS}${EC}"
  kli vc create --name ${WISEMAN_KEYSTORE} --alias ${WISEMAN_ALIAS} --registry-name ${WISEMAN_REGISTRY} \
    --schema "${JOURNEY_MARK_SCHEMA_SAID}" \
    --recipient "${ELAYNE_PREFIX}" \
    --data @"${ATHENA_DIR}"/credential_data/journey-mark-data-elayne.json \
    --edges @"${ELAYNE_REQUEST_EDGE}" \
    --rules @"${ATHENA_DIR}"/credential_rules/journey-mark-rules.json
  CRED_SAID=$(kli vc list \
    --name ${WISEMAN_KEYSTORE} \
    --alias ${WISEMAN_ALIAS} \
    --schema "${JOURNEY_MARK_SCHEMA_SAID}" \
    --issued --said | tail -1) # get the last said since the last one is the one we just issued
  log "Grant ${LCYAN}${WISEMAN_ALIAS}${EC} ${GREEN}issues (IPEX GRANT)${EC} ${PURPL}JourneyMark${EC} to ${MAGNT}${LIBRARIAN_ALIAS}${EC}"
  kli ipex grant --name ${WISEMAN_KEYSTORE} --alias ${WISEMAN_ALIAS} \
    --said ${CRED_SAID} --recipient ${ELAYNE_PREFIX}

  IPEX_GRANT=$(kli ipex list --name ${LIBRARIAN_KEYSTORE} --alias ${LIBRARIAN_ALIAS} --type grant --poll --said | tail -1)
  kli ipex admit --name ${LIBRARIAN_KEYSTORE} --alias ${LIBRARIAN_ALIAS} --said ${IPEX_GRANT}
  ADMIT=$(kli ipex list --name "${LIBRARIAN_KEYSTORE}" --alias "${LIBRARIAN_ALIAS}" --type admit --sent --poll --said | tail -1)
  wait_for_ipex_message "${WISEMAN_KEYSTORE}" "${WISEMAN_ALIAS}" "admit" "${ADMIT}"
  log "${MAGNT}${LIBRARIAN_ALIAS}${EC} ${GREEN}sees${EC} ${PURPL}JourneyMark${EC}"
  wait_for_credentials "${LIBRARIAN_KEYSTORE}" "${LIBRARIAN_ALIAS}" "${JOURNEY_MARK_SCHEMA_SAID}" ${CRED_SAID}

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

  log "${LCYAN}${WISEMAN_ALIAS}${EC} ${GREEN}creates${EC} JourneyCharter Credential for ${YELLO}${EXPLORER_ALIAS}${EC}"
  kli vc create --name ${WISEMAN_KEYSTORE} --alias ${WISEMAN_ALIAS} --registry-name ${WISEMAN_REGISTRY} \
    --schema "${JOURNEY_CHARTER_SCHEMA_SAID}" \
    --recipient "${RICHARD_PREFIX}" \
    --data @"${ATHENA_DIR}"/credential_data/journey-charter-data-richard.json \
    --edges @"${RICHARD_CHARTER_EDGE}" \
    --rules @"${ATHENA_DIR}"/credential_rules/journey-charter-rules.json
  CRED_SAID=$(kli vc list --name ${WISEMAN_KEYSTORE} --alias ${WISEMAN_ALIAS} \
    --schema "${JOURNEY_CHARTER_SCHEMA_SAID}" --issued --said)
  log "Grant ${LCYAN}${WISEMAN_ALIAS}${EC} ${GREEN}issues (IPEX GRANT)${EC} JourneyCharter Credential said ${CRED_SAID} to ${YELLO}${EXPLORER_ALIAS}${EC}"
  kli ipex grant --name ${WISEMAN_KEYSTORE} --alias ${WISEMAN_ALIAS} \
    --said ${CRED_SAID} --recipient ${RICHARD_PREFIX}

  IPEX_GRANT=$(kli ipex list --name ${EXPLORER_KEYSTORE} --alias ${EXPLORER_ALIAS} --type grant --poll --said | tail -1)
  kli ipex admit --name ${EXPLORER_KEYSTORE} --alias ${EXPLORER_ALIAS} --said ${IPEX_GRANT}
  ADMIT=$(kli ipex list --name "${EXPLORER_KEYSTORE}" --alias "${EXPLORER_ALIAS}" --type admit --sent --poll --said | tail -1)
  wait_for_ipex_message "${WISEMAN_KEYSTORE}" "${WISEMAN_ALIAS}" "admit" "${ADMIT}"
  log "${YELLO}${EXPLORER_ALIAS}${EC} ${GREEN}sees${EC} JourneyCharter Credential"
  wait_for_credentials "${EXPLORER_KEYSTORE}" "${EXPLORER_ALIAS}" "${JOURNEY_CHARTER_SCHEMA_SAID}" ${CRED_SAID}

  log ""
}

function issue_journeycharter_elayne() {
  log "Issue JourneyCharter credential to Elayne"

  # Same rules used for both Richard and Elayne
  kli saidify --file "${ATHENA_DIR}"/credential_rules/journey-charter-rules.json

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
  kli vc create --name ${WISEMAN_KEYSTORE} --alias ${WISEMAN_ALIAS} --registry-name ${WISEMAN_REGISTRY} \
    --schema "${JOURNEY_CHARTER_SCHEMA_SAID}" \
    --recipient "${ELAYNE_PREFIX}" \
    --data @"${ATHENA_DIR}"/credential_data/journey-charter-data-elayne.json \
    --edges @"${ELAYNE_CHARTER_EDGE}" \
    --rules @"${ATHENA_DIR}"/credential_rules/journey-charter-rules.json
  CRED_SAID=$(kli vc list --name ${WISEMAN_KEYSTORE} --alias ${WISEMAN_ALIAS} \
    --schema "${JOURNEY_CHARTER_SCHEMA_SAID}" --issued --said)
  log "Grant ${LCYAN}${WISEMAN_ALIAS}${EC} ${GREEN}issues (IPEX GRANT)${EC} JourneyCharter Credential said ${CRED_SAID} to ${MAGNT}${LIBRARIAN_ALIAS}${EC}"
  kli ipex grant --name ${WISEMAN_KEYSTORE} --alias ${WISEMAN_ALIAS} \
    --said ${CRED_SAID} --recipient ${ELAYNE_PREFIX}

  IPEX_GRANT=$(kli ipex list --name ${LIBRARIAN_KEYSTORE} --alias ${LIBRARIAN_ALIAS} --type grant --poll --said | tail -1)
  kli ipex admit --name ${LIBRARIAN_KEYSTORE} --alias ${LIBRARIAN_ALIAS} --said ${IPEX_GRANT}
  ADMIT=$(kli ipex list --name "${LIBRARIAN_KEYSTORE}" --alias "${LIBRARIAN_ALIAS}" --type admit --sent --poll --said | tail -1)
  wait_for_ipex_message "${WISEMAN_KEYSTORE}" "${WISEMAN_ALIAS}" "admit" "${ADMIT}"
  log "${MAGNT}${LIBRARIAN_ALIAS}${EC} ${GREEN}sees${EC} JourneyCharter Credential"
  wait_for_credentials "${LIBRARIAN_KEYSTORE}" "${LIBRARIAN_ALIAS}" "${JOURNEY_CHARTER_SCHEMA_SAID}" ${CRED_SAID}

  log ""
}

function issue_credentials() {
  log "${BLGRY}Issuing Credentials...${EC}"
  issue_treasurehuntingjourney_credentials
#  issue_treasurehuntingjourney_elayne
  issue_journeymarkrequest_credentials
#  issue_journeymarkrequest_elayne
  issue_journeymark_credentials
#  issue_journeymark_elayne
  issue_journeycharter_credentials
#  issue_journeycharter_elayne
  log "${BLGRN}Finished issuing credentials${EC}"
  log ""
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

function revoke_credentials() {
  log "${BLRED}Revoking${EC} JourneyCharter for ${YELLO}Richard${EC}"
  RICHARD_JOURNEY_CHARTER_CRED_SAID=$(kli vc list --name ${EXPLORER_KEYSTORE} --alias ${EXPLORER_ALIAS} --said --schema ${JOURNEY_CHARTER_SCHEMA_SAID})
  kli vc revoke --name ${WISEMAN_KEYSTORE} --alias ${WISEMAN_ALIAS} --registry-name ${WISEMAN_REGISTRY} --said "${RICHARD_JOURNEY_CHARTER_CRED_SAID}" --send ${GATEKEEPER_ALIAS}
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
  log "${LTGRN}Control-C${EC} to exit (will shut down keystores, agents, and Gatekeeper  if started, and will clear .keri and .sally)"
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

  # the three keystores
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

function main_kli_flow() {
  # The main flow for using the KLI
  # Start Here for understanding
  start_vlei_server # Schema and Credential caching server

  create_witnesses
  migrate_witnesses
  start_witnesses
  read_witness_prefixes_and_configure

  make_keystores
  migrate_keystores
  incept_ids
  read_prefixes_kli
  start_gatekeeper_server
  start_webhook

  make_introductions_kli
  # resolve_credential_oobis - not needed

  create_credential_registries
  issue_credentials
  exit 0
  present_credentials
}

function services_only_flow() {
  # This is a KLI-based flow for experimenting with different steps
  start_vlei_server

  start_witnesses
  read_witness_prefixes_and_configure

  read_prefixes_kli
  start_gatekeeper_server
  start_webhook

  # place next item here
}

function main() {
  log "Hello ${GREEN}Abydos${EC} Adventurers!"
  log ""
  check_dependencies
  generate_credential_schemas
  read_schema_saids

  if [ -n "$SERVICES_ONLY" ]; then
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
  h)
    log "Abydos workflow script"
    log "workflow.sh [-v VERBOSE] [-h HELP] [-s SERVICES_ONLY] [-a AGENTS]"
    exit
    ;;
  c)
    CLEAR_KEYSTORES=true
    log "CLEAR_KEYSTORES set to true"
    ;;
  v)
    VERBOSE=true
    log "VERBOSE set to true"
    ;;
  s)
    SERVICES_ONLY=true
    log "SERVICES_ONLY set to true"
    ;;
  \?)
    log "Invalid option $option"
    exit
    ;;
  esac
done

main
