function start_agents() {
  # Deprecated -- do not use
  # TODO convert to KERIA
  log "Starting ${YELLO}${EXPLORER_KEYSTORE} agent${EC}"
  kli agent start --insecure --admin-http-port ${EXPLORER_AGENT_HTTP_PORT} --tcp ${EXPLORER_AGENT_TCP_PORT} \
    --config-dir ${CONFIG_DIR} --config-file ${AGENT_CONFIG_FILENAME} \
    --path ${ATHENA_DIR}/agent_static/ &
  EXPLORER_AGENT_PID=$!
  sleep 1

  log "Starting ${MAGNT}${LIBRARIAN_KEYSTORE} agent${EC}"
  kli agent start --insecure --admin-http-port ${LIBRARIAN_AGENT_HTTP_PORT} --tcp ${LIBRARIAN_AGENT_TCP_PORT} \
    --config-dir ${CONFIG_DIR} --config-file ${AGENT_CONFIG_FILENAME} \
    --path ${ATHENA_DIR}/agent_static/ &
  LIBRARIAN_AGENT_PID=$!
  sleep 1

  log "Starting ${LCYAN}${WISEMAN_KEYSTORE} agent${EC}"
  kli agent start --insecure --admin-http-port ${WISEMAN_AGENT_HTTP_PORT} --tcp ${WISEMAN_AGENT_TCP_PORT} \
    --config-dir ${CONFIG_DIR} --config-file ${AGENT_CONFIG_FILENAME} \
    --path ${ATHENA_DIR}/agent_static/ &
  WISEMAN_AGENT_PID=$!
  sleep 1

  log "Starting ${LTGRN}${GATEKEEPER_KEYSTORE} agent${EC}"
  kli agent start --insecure --admin-http-port ${GATEKEEPER_AGENT_HTTP_PORT} --tcp ${GATEKEEPER_AGENT_TCP_PORT} \
    --config-dir ${CONFIG_DIR} --config-file ${AGENT_CONFIG_FILENAME} \
    --path ${ATHENA_DIR}/agent_static/ &
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

function issue_credentials_agent() {
  log "${BLGRY}Issuing Credentials${EC}"
  issue_treasurehuntingjourney_credentials_agent
  issue_journeymarkrequest_credentials_agent
  issue_journeymark_credentials_agent
  issue_journeycharter_credentials_agent
  log "${BLGRN}Finished issuing credentials${EC}"
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

function revoke_credentials_agent() {
  log "${BLRED}Revoking${EC} JourneyCharter for ${YELLO}Richard${EC}"

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

function services_only_flow() {
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

function main() {
  log "Hello ${GREEN}Abydos${EC} Adventurers!"
  log ""
  check_dependencies
  generate_credential_schemas
  read_schema_saids

  if [ -n "$SERVICES_ONLY" ]; then
    services_only_flow
  else
    agent_flow
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
