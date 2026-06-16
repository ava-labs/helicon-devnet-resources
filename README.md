# Helicon Devnet Resources

> **Private preview.** This repository supports institutional partners testing the upcoming
> Avalanche **Helicon** upgrade on a dedicated devnet. The devnet runs pre-release software and
> will be torn down once Helicon testing completes. Everything here applies to the devnet only —
> **not** to Fuji or Mainnet. Questions: reach out to your Ava Labs point of contact.

## What's running on this devnet

The devnet (network ID **76**) activated the Helicon upgrade at `2026-06-04T16:00:00Z`
(`heliconTime` in [`genesis/devnet76-upgrade.json`](genesis/devnet76-upgrade.json)).
Helicon activates the following ACPs:

| ACP | What it changes | What it means for you |
|-----|-----------------|-----------------------|
| [ACP-194: Streaming Asynchronous Execution](https://github.com/avalanche-foundation/ACPs/tree/main/ACPs/194-streaming-asynchronous-execution) | C-Chain consensus and execution are decoupled: blocks are **accepted** by consensus first and **settled** by a concurrent execution stream moments later. Implemented by `strevm`, the SAE VM ([`vms/saevm`](https://github.com/ava-labs/avalanchego/tree/helicon-devnet/vms/saevm)), integrated into the C-Chain. | Transaction outcomes (receipts, contract effects) are final at settlement, shortly after acceptance. Test deposit/withdrawal confirmation logic against this timing. |
| [ACP-236: Auto-Renewed Staking](https://github.com/avalanche-foundation/ACPs/tree/main/ACPs/236-auto-renewed-staking) | P-Chain primary-network validators can stake in auto-renewing cycles instead of fixed end dates, with configurable reward auto-compounding. | New staking transaction types and renewal semantics — see [guides/auto-renewed-staking.md](guides/auto-renewed-staking.md). |
| [ACP-273: Reduce Minimum Staking Duration](https://github.com/avalanche-foundation/ACPs/tree/main/ACPs/273-reduce-minimum-staking-duration) | Reduced minimum staking durations on the primary network. | On this devnet the post-Helicon minimum staking duration is **5 minutes**, so short staking periods and renewal cycles can be tested quickly. Listed for awareness — this repo contains no tokenomics walkthroughs. |
| [ACP-283: Dynamic Minimum Gas Price](https://github.com/avalanche-foundation/ACPs/tree/main/ACPs/283-dynamic-minimum-gas-price) | The C-Chain minimum gas price becomes dynamically adjustable based on validator preferences, replacing the fixed floor. | Do not hardcode gas-price floors in C-Chain tooling; fetch fee parameters from the network. |

## Network credentials

| Parameter | Value |
|-----------|-------|
| Network ID | `76` |
| Address HRP | `custom` (P-Chain addresses look like `P-custom1...`) |
| C-Chain chainId | `43117` (`0xa86d`) |
| RPC base URL | `https://api.avax-dev.network` |
| C-Chain RPC | `https://api.avax-dev.network/ext/bc/C/rpc` |
| P-Chain API | `https://api.avax-dev.network/ext/bc/P` |
| Faucet | <https://build.avax.network/console/primary-network/devnet-faucet> |
| AvalancheGo | branch [`helicon-devnet`](https://github.com/ava-labs/avalanchego/tree/helicon-devnet) — the devnet runs commit `1339ef45dc6c` |
| Genesis / upgrade files | [`genesis/`](genesis/) — byte-exact copies of the deployed manifests |

### Quick connect

Run the bundled check — it confirms the network IDs and tells you immediately if a web
filter is blocking you:

```bash
./scripts/check-connection.sh
```

Or check manually. Each call is its own block so it pastes cleanly into zsh. The commands
have **no inline `#` comments**, because interactive zsh treats `#` as a literal argument
rather than a comment (run `setopt interactive_comments` first if you paste commented
commands from elsewhere).

C-Chain chainId — returns `{"jsonrpc":"2.0","id":1,"result":"0xa86d"}` (43117):

```bash
curl -sS -X POST -H 'Content-Type: application/json' \
  --data '{"jsonrpc":"2.0","id":1,"method":"eth_chainId","params":[]}' \
  https://api.avax-dev.network/ext/bc/C/rpc
```

Network ID — returns `"networkID":"76"`:

```bash
curl -sS -X POST -H 'Content-Type: application/json' \
  --data '{"jsonrpc":"2.0","id":1,"method":"info.getNetworkID","params":{}}' \
  https://api.avax-dev.network/ext/info
```

P-Chain height:

```bash
curl -sS -X POST -H 'Content-Type: application/json' \
  --data '{"jsonrpc":"2.0","id":1,"method":"platform.getHeight","params":{}}' \
  https://api.avax-dev.network/ext/bc/P
```

> On an Ava-Labs-managed device these only work with **Jamf / Jamf Connect active** — it
> provides the access tunnel to the dev infra. If `check-connection.sh` reports a filter
> block, toggle Jamf on and re-run. External partners on their own networks are unaffected.

## Getting devnet AVAX

The [devnet faucet](https://build.avax.network/console/primary-network/devnet-faucet) drips up to
**2,000 AVAX** per request on the C-Chain. It currently requires signing in with an
`@avalabs.org` account; external partners receive funds through their Ava Labs point of contact
(a coupon-based redemption flow is planned).

Staking happens on the P-Chain, so after receiving funds you will move them across:
see [guides/c-to-p-transfer.md](guides/c-to-p-transfer.md).

## Staking parameters (devnet, post-Helicon)

Source: [`genesis/genesis_local.go`](https://github.com/ava-labs/avalanchego/blob/helicon-devnet/genesis/genesis_local.go)
on the `helicon-devnet` branch (custom networks use these parameters; the devnet's nodes run
without overrides).

| Parameter | Value |
|-----------|-------|
| Minimum validator stake | **2,000 AVAX** |
| Maximum validator stake | 3,000,000 AVAX |
| Minimum staking duration | **5 minutes** (`HeliconMinStakeDuration`) |
| Maximum staking duration | 365 days |
| Minimum delegator stake | 25 AVAX |
| Minimum delegation fee | 2% |

## Guides

1. [Run a devnet node](guides/run-a-node.md) — build the `helicon-devnet` branch and sync network 76.
2. [Move AVAX from C-Chain to P-Chain](guides/c-to-p-transfer.md) — import a key into platform-cli, fund it, and transfer (TypeScript/avalanchejs alternative included).
3. [Auto-renewed staking (ACP-236)](guides/auto-renewed-staking.md) — become a validator with the two new staking commands.

## Tooling status

ACP-236 support is not yet released in the standard tooling. Pinned, devnet-tested sources:

| Tool | Status | How to get it |
|------|--------|---------------|
| AvalancheGo `helicon-devnet` branch | devnet runs commit `1339ef45dc6c`; no published Docker image | build from source — [guides/run-a-node.md](guides/run-a-node.md) |
| `platform-cli` ACP-236 commands (`validator add-auto-renewed`, `validator set-auto-config`) | [PR #28](https://github.com/ava-labs/platform-cli/pull/28), unmerged; e2e-tested against this devnet | build from the PR branch — [guides/auto-renewed-staking.md](guides/auto-renewed-staking.md) |
| `@avalanche-sdk/client` ACP-236 helpers (`prepareAddAutoRenewedValidatorTxn`, `prepareSetAutoRenewedValidatorConfigTxn`) | [PR #379](https://github.com/ava-labs/avalanche-sdk-typescript/pull/379), unmerged; e2e-tested against this devnet | build from the PR branch — [guides/auto-renewed-staking.md](guides/auto-renewed-staking.md). For C→P transfers, the published `@avalanche-sdk/client` (v0.1.1) rejects custom networks — use platform-cli or the avalanchejs script ([guides/c-to-p-transfer.md](guides/c-to-p-transfer.md)). |

## Repository layout

```
├── genesis/
│   ├── devnet76-genesis.json    # byte-exact deployed genesis — do not regenerate or reformat
│   └── devnet76-upgrade.json    # byte-exact deployed upgrade schedule
├── guides/
│   ├── run-a-node.md
│   ├── c-to-p-transfer.md
│   └── auto-renewed-staking.md
└── scripts/
    ├── c-to-p-transfer/         # TypeScript C→P transfer via avalanchejs (programmatic alternative)
    └── stake-auto-renew.sh      # convenience wrapper around platform-cli add-auto-renewed
```
