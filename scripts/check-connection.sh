#!/usr/bin/env bash
#
# Check connectivity to the Helicon devnet (network 76).
#
# Verifies the public RPC is reachable and reports the expected chain/network IDs,
# and best-effort checks that your machine can reach the bootstrap nodes' p2p port
# (needed if you intend to sync your own node).
#
# Usage:
#   ./check-connection.sh
#
# Environment:
#   RPC_URL   devnet RPC base (default: https://api.avax-dev.network)

set -uo pipefail   # deliberately NOT -e: report every check, don't abort on the first failure

RPC_URL="${RPC_URL:-https://api.avax-dev.network}"
EXPECTED_CHAIN_ID="0xa86d"   # 43117
EXPECTED_NETWORK_ID="76"
BOOTSTRAP_IPS="52.201.126.172 34.233.248.130 107.21.11.213 35.170.144.5 98.82.41.186"
P2P_PORT=9651

fail=0

# rpc_call PATH JSON_BODY -> sets HTTP_CODE, REDIRECT, BODY
rpc_call() {
  local path="$1" body="$2" tmp meta
  tmp="$(mktemp)"
  meta="$(curl -sS -m 15 -o "$tmp" -w '%{http_code} %{redirect_url}' \
    -X POST -H 'Content-Type: application/json' --data "$body" \
    "${RPC_URL}${path}" 2>/dev/null)"
  HTTP_CODE="${meta%% *}"
  REDIRECT="${meta#* }"
  BODY="$(cat "$tmp")"
  rm -f "$tmp"
}

# detect a corporate web filter / proxy interception
is_filtered() {
  case "$REDIRECT" in
    *wandera*|*access-assist*|*block.*|*.blockpage.*) return 0 ;;
  esac
  return 1
}

print_filter_notice() {
  echo "   ⚠  Request was intercepted by a network/web filter."
  echo "      (redirected to: ${REDIRECT})"
  echo "      On an Ava-Labs-managed device: make sure Jamf / Jamf Connect is ACTIVE — it"
  echo "      provides the access tunnel to dev infra. When it is off, the Wandera filter"
  echo "      blocks ${RPC_URL#https://}. Toggle Jamf on and re-run."
  echo "      External partners on their own networks will not see this block."
}

echo "Checking Helicon devnet RPC at ${RPC_URL}"
echo

echo "1) C-Chain chainId  (expect ${EXPECTED_CHAIN_ID} = 43117)"
rpc_call "/ext/bc/C/rpc" '{"jsonrpc":"2.0","id":1,"method":"eth_chainId","params":[]}'
if is_filtered; then
  print_filter_notice; fail=1
elif printf '%s' "$BODY" | grep -q "\"result\":\"${EXPECTED_CHAIN_ID}\""; then
  echo "   ✅ ${BODY}"
else
  echo "   ❌ HTTP ${HTTP_CODE} — unexpected response: ${BODY:-<empty body>}"; fail=1
fi
echo

echo "2) Network ID  (expect \"networkID\":\"${EXPECTED_NETWORK_ID}\")"
rpc_call "/ext/info" '{"jsonrpc":"2.0","id":1,"method":"info.getNetworkID","params":{}}'
if is_filtered; then
  print_filter_notice; fail=1
elif printf '%s' "$BODY" | grep -q "\"networkID\":\"${EXPECTED_NETWORK_ID}\""; then
  echo "   ✅ ${BODY}"
else
  echo "   ❌ HTTP ${HTTP_CODE} — unexpected response: ${BODY:-<empty body>}"; fail=1
fi
echo

echo "3) P-Chain height"
rpc_call "/ext/bc/P" '{"jsonrpc":"2.0","id":1,"method":"platform.getHeight","params":{}}'
if is_filtered; then
  print_filter_notice; fail=1
elif printf '%s' "$BODY" | grep -q "\"height\""; then
  echo "   ✅ ${BODY}"
else
  echo "   ❌ HTTP ${HTTP_CODE} — unexpected response: ${BODY:-<empty body>}"; fail=1
fi
echo

echo "4) Bootstrap p2p reachability on TCP ${P2P_PORT}  (only needed to sync your own node)"
if command -v nc >/dev/null 2>&1; then
  for ip in $BOOTSTRAP_IPS; do
    if nc -z -w 5 "$ip" "$P2P_PORT" >/dev/null 2>&1; then
      echo "   ✅ ${ip}:${P2P_PORT} reachable"
    else
      echo "   ⚠  ${ip}:${P2P_PORT} not reachable — filter, firewall, or you are not on a"
      echo "      network with a route to the bootstrap infra. Not needed for RPC-only use."
    fi
  done
else
  echo "   (skipped — 'nc' not installed)"
fi
echo

if [ "$fail" -eq 0 ]; then
  echo "✅ RPC reachable and reporting the Helicon devnet (network ${EXPECTED_NETWORK_ID})."
else
  echo "❌ One or more RPC checks failed (see above)."
  echo "   A web-filter block is a local network restriction, not a devnet outage."
  exit 1
fi
