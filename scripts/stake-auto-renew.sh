#!/usr/bin/env bash
#
# Register an auto-renewed validator (ACP-236) on the Helicon devnet.
#
# Fetches the NodeID and BLS proof of possession from your own node, then calls
# `platform validator add-auto-renewed` (platform-cli built from PR #28 — see
# guides/auto-renewed-staking.md).
#
# Usage:
#   KEY_NAME=mykey ./stake-auto-renew.sh
#
# Environment:
#   KEY_NAME       platform-cli keystore key to sign with (required, unless
#                  AVALANCHE_PRIVATE_KEY is exported for platform-cli instead)
#   NODE_ENDPOINT  your node's API endpoint        (default: http://127.0.0.1:9650)
#   RPC_URL        devnet RPC                      (default: https://api.avax-dev.network)
#   STAKE_AVAX     stake amount in AVAX            (default: 2000, the devnet minimum)
#   PERIOD         auto-renewal cycle duration     (default: 24h; devnet minimum is 5m)
#   AUTO_COMPOUND  reward fraction to restake, 0-1 (default: 1)
#   PLATFORM_BIN   path to the platform binary     (default: ./platform)

set -euo pipefail

NODE_ENDPOINT="${NODE_ENDPOINT:-http://127.0.0.1:9650}"
RPC_URL="${RPC_URL:-https://api.avax-dev.network}"
STAKE_AVAX="${STAKE_AVAX:-2000}"
PERIOD="${PERIOD:-24h}"
AUTO_COMPOUND="${AUTO_COMPOUND:-1}"
PLATFORM_BIN="${PLATFORM_BIN:-./platform}"

command -v jq >/dev/null || { echo "error: jq is required" >&2; exit 1; }
command -v "$PLATFORM_BIN" >/dev/null || [ -x "$PLATFORM_BIN" ] || {
  echo "error: platform-cli not found at '$PLATFORM_BIN' (set PLATFORM_BIN or build it: see guides/auto-renewed-staking.md)" >&2
  exit 1
}
if [ -z "${KEY_NAME:-}" ] && [ -z "${AVALANCHE_PRIVATE_KEY:-}" ]; then
  echo "error: set KEY_NAME (platform-cli keystore) or AVALANCHE_PRIVATE_KEY" >&2
  exit 1
fi

echo "Fetching node identity from ${NODE_ENDPOINT} ..."
NODE_INFO=$(curl -sf -X POST -H 'Content-Type: application/json' \
  --data '{"jsonrpc":"2.0","id":1,"method":"info.getNodeID","params":{}}' \
  "${NODE_ENDPOINT}/ext/info") || {
  echo "error: could not reach ${NODE_ENDPOINT}/ext/info — is your node running?" >&2
  exit 1
}

NODE_ID=$(jq -er '.result.nodeID' <<<"$NODE_INFO")
BLS_PUBLIC_KEY=$(jq -er '.result.nodePOP.publicKey' <<<"$NODE_INFO")
BLS_POP=$(jq -er '.result.nodePOP.proofOfPossession' <<<"$NODE_INFO")

echo
echo "  Node ID:        ${NODE_ID}"
echo "  BLS public key: ${BLS_PUBLIC_KEY}"
echo "  Stake:          ${STAKE_AVAX} AVAX"
echo "  Period:         ${PERIOD}"
echo "  Auto-compound:  ${AUTO_COMPOUND}"
echo "  RPC:            ${RPC_URL}"
echo

if [ "${YES:-}" != "1" ]; then
  read -r -p "Submit AddAutoRenewedValidatorTx with these settings? [y/N] " answer
  case "$answer" in [yY]*) ;; *) echo "aborted"; exit 1 ;; esac
fi

"$PLATFORM_BIN" validator add-auto-renewed \
  --rpc-url "$RPC_URL" \
  ${KEY_NAME:+--key-name "$KEY_NAME"} \
  --node-id "$NODE_ID" \
  --bls-public-key "$BLS_PUBLIC_KEY" \
  --bls-pop "$BLS_POP" \
  --stake "$STAKE_AVAX" \
  --period "$PERIOD" \
  --auto-compound "$AUTO_COMPOUND"

echo
echo "Done. Save the transaction ID above — you need it for 'platform validator set-auto-config'"
echo "(update next-cycle settings, or '--period 0' for a graceful exit)."
