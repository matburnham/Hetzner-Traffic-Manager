#!/bin/bash

# Configuration
: "${API_TOKEN:?API_TOKEN is required}" # Hetzner Cloud API token, read from env, fallback to empty
: "${SERVER_ID:?SERVER_ID is required}" # Hetzner Server ID, read from env, fallback to empty
LIMIT_TB_OFFSET="${LIMIT_TB_OFFSET:--1}"
LIMIT_GB_OFFSET="${LIMIT_GB_OFFSET:-0}"

echo Hetzner Traffic Manager
echo Server ID: $SERVER_ID
echo Limit offset: $LIMIT_TB_OFFSET TB + $LIMIT_GB_OFFSET GB

# Calculation basis (1 TB = 1024^4 Bytes, 1 GB = 1024^3 Bytes)
LIMIT_BYTES_OFFSET=$((LIMIT_TB_OFFSET * 1024**4 + LIMIT_GB_OFFSET * 1024**3))

# Function to get server information in JSON format
function get_servers_json() {
    curl -s -H "Authorization: Bearer $API_TOKEN" \
        "https://api.hetzner.cloud/v1/servers/$SERVER_ID"
}

# Function to get the server's status
function get_status() {
        echo $SERVERS_JSON | \
        jq -r '.server.status'
}

# Function to get outgoing traffic
function get_traffic() {
        echo $SERVERS_JSON | \
        jq -r '.server.outgoing_traffic'
}

# Function to get traffic limit
function get_traffic_limit() {
        echo $SERVERS_JSON | \
        jq -r '.server.included_traffic'
}

# Function to shut down the server
function shutdown_server() {
    echo "Shutting down server with ID $SERVER_ID ..."
    curl -s -X POST -H "Authorization: Bearer $API_TOKEN" \
        "https://api.hetzner.cloud/v1/servers/$SERVER_ID/actions/shutdown"
}

# Main program
SERVERS_JSON=$(get_servers_json)
STATUS=$(get_status)
TRAFFIC_BYTES=$(get_traffic)
TRAFFIC_BYTES_LIMIT=$(get_traffic_limit)

# Hetzner API has a bug which shows "server.included_traffic" as "0" for the first few days of  the month
# See https://github.com/JanisPlayer/Hetzner-Traffic-Manager/issues/1#issuecomment-3832043583
if [[ "$TRAFFIC_BYTES_LIMIT" == "0" ]]; then
    echo "server.included_traffic response is 0 (Hetzner API bug). Falling back to 20 TB."
    TRAFFIC_BYTES_LIMIT=$((20 * 1024**4))
fi

LIMIT_BYTES=$((TRAFFIC_BYTES_LIMIT+LIMIT_BYTES_OFFSET))

echo "Current outgoing traffic: $((TRAFFIC_BYTES / 1024**3)) GB"
echo "Outgoing traffic limit: $((TRAFFIC_BYTES_LIMIT / 1024**4)) TB (including offset): $((LIMIT_BYTES / 1024**4)) TB"

# Check server status and if traffic exceeds the limit
if [[ "$STATUS" == "running" ]]; then
  if ((TRAFFIC_BYTES >= LIMIT_BYTES)); then
      echo "Traffic limit of $((LIMIT_BYTES / 1024**4)) TB reached! The server will be shut down."
      shutdown_server
  else
      echo "Traffic limit not reached yet. Current traffic: $TRAFFIC_BYTES Bytes of $LIMIT_BYTES Bytes"
  fi
else
  echo "Server is stopped"
fi

