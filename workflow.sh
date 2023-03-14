#! /usr/bin/env bash
# abydos-workflow.sh
# Runs through the entire Abydos workflow from start to finish.
# Refer to this script for an overall view of the whole process you are building by hand.
# This script makes heavy use of variables for overall readability
#
# WARNING: Expects to be run from the root directory of the abydos-tutorial source code repository.
#          This script will not work without adjustment if run from some other location.

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

function log() {
  # see Why is Printf Better than echo : https://unix.stackexchange.com/questions/65803/why-is-printf-better-than-echo/65819#65819
  IFS=" "
  #  printf '%s\n' "$*"
  printf "$1\n"
}


##### KERI Configuration #####
# Names and Aliases
EXPLORER_KEYSTORE=explorer
LIBRARIAN_KEYSTORE=librarian
WISEMAN_KEYSTORE=wiseman
GATEKEEPER_KEYSTORE=gatekeeper

EXPLORER_ALIAS=richard
LIBRARIAN_ALIAS=elayne
WISEMAN_ALIAS=ramiel # Ramiel See https://en.wikipedia.org/wiki/Ramiel
GATEKEEPER_ALIAS=zaqiel # See Zaqiel https://en.wikipedia.org/wiki/Zaqiel

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

# Bootstrap witness_config files and directories
LOCAL_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
ATHENA_DIR=${LOCAL_DIR}/athena
SCHEMAS_DIR=${ATHENA_DIR}/schemas
WITNESS_BOOTSTRAP_OOBIS_FILENAME=athena-witness-and-schema-oobis
CONTROLLER_BOOTSTRAP_FILE=${KERI_SCRIPT_DIR}/keri/cf/${WITNESS_BOOTSTRAP_OOBIS_FILENAME}.json
WITNESS_INCEPTION_CONFIG_FILE=${ATHENA_DIR}/athena-witnesses.json

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
WIL_WITNESS_HTTP_PORT=5643
WES_WITNESS_HTTP_PORT=5644
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
HELLO_KERI_SCHEMA_SAID=""
HELLO_ACDC_SCHEMA_SAID=""
HELLO_ADMIT_SCHEMA_SAID=""
HELLO_ATTEND_SCHEMA_SAID=""

function generate_credential_schemas() {
  # TODO set up KASLCred as a python binary package
  log "generating schemas"
  mkdir -p ${ATHENA_DIR}/saidified_schemas
  python -m kaslcred ${SCHEMAS_DIR} ${ATHENA_DIR}/saidified_schemas ${SCHEMAS_DIR}/athena-schema-map.json
}


function start_agents() {
  kli agent start --admin-http-port 5620 --config-dir ${ATHENA_DIR}
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
    kill $WITNESS_NETWORK_PID
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
  rm -rfv "${HOME}"/.keri
}


function main() {
  log "Hello ${GREEN}KERI${EC} Adventurers!"
  log ""
  check_dependencies
  generate_credential_schemas
#  read_schema_saids
#  start_vlei_server
  # start_witnesses
#  create_witnesses
#  alt_start_witnesses
#  read_witness_prefixes_and_configure
#  start_agents
  # make_keystores
  # read_aliases
  # make_introductions
  # resolve_credential_oobis
  # create_credential_registries
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

main