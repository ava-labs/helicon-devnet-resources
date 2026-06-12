# Run a Helicon Devnet Node

This guide brings up a **non-validator (tracking) node** on the Helicon devnet (network ID 76).
A tracking node is enough to follow the chain, serve local RPC, and obtain the node identity
(NodeID + BLS proof of possession) you will later need to become a validator.

## Prerequisites

- **Go 1.25.10+** (the branch's `go.mod`; newer Go toolchains download it automatically)
- `git`, `curl`
- ~50 GiB free disk. For reference, the devnet's own nodes run with 1 CPU / 2 GiB RAM / 50 GiB volumes.
- Outbound TCP to port `9651` (staking/p2p) on the bootstrap IPs below

## 1. Build AvalancheGo from the `helicon-devnet` branch

There is no published release or Docker image for this branch — build from source:

```bash
git clone https://github.com/ava-labs/avalanchego.git
cd avalanchego
git checkout helicon-devnet   # the devnet runs commit 1339ef45dc6c
./scripts/build.sh
# → binary at ./build/avalanchego
```

## 2. Get the network files

Copy [`genesis/devnet76-genesis.json`](../genesis/devnet76-genesis.json) and
[`genesis/devnet76-upgrade.json`](../genesis/devnet76-upgrade.json) from this repository.

> **Important:** these are byte-exact copies of the deployed manifests. The node only joins the
> network if its genesis byte-matches the network's. Do **not** regenerate, reformat, or edit
> them.

```bash
cp /path/to/helicon-devnet-resources/genesis/devnet76-genesis.json /tmp/
cp /path/to/helicon-devnet-resources/genesis/devnet76-upgrade.json /tmp/
```

## 3. Start the node

```bash
./build/avalanchego \
    --network-id=76 \
    --genesis-file=/tmp/devnet76-genesis.json \
    --upgrade-file=/tmp/devnet76-upgrade.json \
    --bootstrap-ips=52.201.126.172:9651,34.233.248.130:9651,107.21.11.213:9651,35.170.144.5:9651,98.82.41.186:9651 \
    --bootstrap-ids=NodeID-7Sh8EhHBbCFLdCWNZ8HNKxrAbx3Sfd6Z7,NodeID-Mc8tr74qzgdMbBk7zMYTrQi6T34LAJVMS,NodeID-2yCYFACGMZUodkJbDQEmjFh2XySKCXi8r,NodeID-RzMHUYevUej1KVZhv55tmRbU5tTnanwS,NodeID-2rY57hF6jKYvKB4Ttw8rSV1AxAxwLppYc \
    --data-dir=$HOME/.avalanchego-devnet76 \
    --http-host=127.0.0.1
```

Notes:

- Use a dedicated `--data-dir` so the devnet database never collides with a Mainnet/Fuji node on
  the same machine.
- `--http-host=127.0.0.1` keeps the node's API local. Expose it only if you know what you are
  doing.
- The node generates its staking identity (TLS + BLS keys) in the data directory on first start.
  Back up `$HOME/.avalanchego-devnet76/staking/` if this node will become a validator.

## 4. Wait for bootstrap

```bash
# P-Chain bootstrapped? — expect {"isBootstrapped":true} once synced
curl -s -X POST -H 'Content-Type: application/json' \
  --data '{"jsonrpc":"2.0","id":1,"method":"info.isBootstrapped","params":{"chain":"P"}}' \
  http://127.0.0.1:9650/ext/info

# Compare your local P-Chain height with the shared RPC — they should match
curl -s -X POST -H 'Content-Type: application/json' \
  --data '{"jsonrpc":"2.0","id":1,"method":"platform.getHeight","params":{}}' \
  http://127.0.0.1:9650/ext/bc/P
curl -s -X POST -H 'Content-Type: application/json' \
  --data '{"jsonrpc":"2.0","id":1,"method":"platform.getHeight","params":{}}' \
  https://api.avax-dev.network/ext/bc/P
```

## Optional: match the devnet's C-Chain configuration

The devnet's nodes run the C-Chain with the following chain config:

```json
{
  "gas-target": 1500000,
  "min-delay-target": 1000
}
```

To mirror it, place that JSON at `$HOME/.avalanchego-devnet76/configs/chains/C/config.json`
before starting the node.

## Troubleshooting

- **Stuck at bootstrap / no peers:** confirm outbound TCP 9651 to the bootstrap IPs is allowed
  from your environment. If the peers are unreachable from your network, contact your Ava Labs
  point of contact.
- **Genesis mismatch errors on startup:** re-copy the files from this repo; do not pretty-print
  or re-encode them.
