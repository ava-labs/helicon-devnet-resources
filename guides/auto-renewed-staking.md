# Auto-Renewed Staking (ACP-236)

[ACP-236](https://github.com/avalanche-foundation/ACPs/tree/main/ACPs/236-auto-renewed-staking)
replaces fixed staking end dates with **auto-renewing cycles** for primary-network validators.
This guide registers an auto-renewed validator on the devnet and updates its configuration —
the two new user-facing commands.

## How auto-renewal works

Source: [`vms/platformvm/docs/validators_auto_renewed.md`](https://github.com/ava-labs/avalanchego/blob/helicon-devnet/vms/platformvm/docs/validators_auto_renewed.md)
on the `helicon-devnet` branch.

- **`AddAutoRenewedValidatorTx`** creates the validator with a cycle duration (`period`) and an
  auto-compound ratio. Stake weight, delegation fee, and period are validated against the
  [devnet staking parameters](../README.md#staking-parameters-devnet-post-helicon) —
  on this devnet the minimum period is **5 minutes**, so full renewal cycles can be observed
  quickly.
- **At each cycle end** the block builder issues a `RewardAutoRenewedValidatorTx` automatically
  (it is consensus-issued — there is nothing to call, and it is not a user-facing command):
  - **Sufficient uptime, period > 0:** rewards are split by the auto-compound ratio — the
    restake portion increases validator weight (capped at the maximum validator stake; overflow
    is paid out), the rest is paid out as UTXOs. A new cycle starts immediately.
  - **Sufficient uptime, period = 0 (graceful exit):** principal plus all pending rewards are
    returned and the validator is removed.
  - **Insufficient uptime:** forced exit — principal and previously accrued rewards are
    returned, but the current cycle's reward is forfeited, regardless of period.
- **`SetAutoRenewedValidatorConfigTx`** updates `period` and the auto-compound ratio for the
  *next* cycle. It must be signed by the validator's configured **owner**. Setting
  `--period 0` is the graceful-exit signal.
- Delegations do **not** auto-renew — only the validator's own stake renews. Delegator rewards
  are tracked and paid per cycle (the validator's delegation fee applies as usual).

## Prerequisites

1. A synced devnet node you control — see [run-a-node.md](run-a-node.md). Validators must keep
   ≥80% uptime per cycle to renew, so the node should stay online.
2. **2,000 devnet AVAX on the P-Chain** (+ a small buffer for fees) — see
   [c-to-p-transfer.md](c-to-p-transfer.md).
3. The `platform-cli` build with ACP-236 support (next step).

## 1. Build platform-cli with the ACP-236 commands

The two commands ship in [PR #28](https://github.com/ava-labs/platform-cli/pull/28) (unmerged —
it depends on unreleased AvalancheGo APIs). Build from the PR branch:

```bash
git clone https://github.com/ava-labs/platform-cli.git
cd platform-cli
git fetch origin pull/28/head:acp236
git checkout acp236
go build -o platform .
./platform validator add-auto-renewed --help
```

The build needs Go 1.25.11; recent Go toolchains fetch it automatically.

## 2. Get your node's identity (NodeID + BLS proof of possession)

Your node generated a BLS key on first start. Fetch the NodeID and proof of possession from the
node's local API:

```bash
curl -sS -X POST -H 'Content-Type: application/json' \
  --data '{"jsonrpc":"2.0","id":1,"method":"info.getNodeID","params":{}}' \
  http://127.0.0.1:9650/ext/info
```

The response contains `nodeID`, `nodePOP.publicKey`, and `nodePOP.proofOfPossession` — the
three values used below.

## 3. Register the auto-renewed validator

```bash
./platform validator add-auto-renewed \
  --rpc-url https://api.avax-dev.network \
  --key-name mykey \
  --node-id NodeID-... \
  --bls-public-key 0x... \
  --bls-pop 0x... \
  --stake 2000 \
  --period 24h \
  --auto-compound 1 \
  --delegation-fee 0.02
```

- `--period` is the cycle duration. Mainnet-style values (`336h` = 14 days) work, but on the
  devnet anything from `5m` up is valid — short periods let you watch renewals happen.
- `--auto-compound 1` restakes 100% of rewards; `0.3` restakes 30% and pays out the rest each
  cycle.
- `--owner-address` / `--reward-address` default to your own address; set them explicitly for
  custodial setups where the config owner differs from the reward recipient.
- Alternatively, `--node-endpoint http://127.0.0.1:9650` fetches the BLS proof of possession
  from your node instead of `--bls-public-key`/`--bls-pop` — or use
  [`scripts/stake-auto-renew.sh`](../scripts/stake-auto-renew.sh), which does the lookup and
  invocation for you.

**Save the transaction ID it prints** — it identifies the validator for configuration updates.

Verify the validator is active and inspect its auto-renew state:

```bash
curl -sS -X POST -H 'Content-Type: application/json' \
  --data '{"jsonrpc":"2.0","id":1,"method":"platform.getCurrentValidators","params":{"nodeIDs":["NodeID-..."]}}' \
  https://api.avax-dev.network/ext/bc/P
```

Auto-renewed validators report `period`, `autoCompoundRewardShares` (parts per million, e.g.
`400000` = 40%), and `validatorAuthority` (the config owner) in the response.

## 4. Update the configuration — or exit

Both operations use the same command, signed by the owner key:

Change next-cycle settings (here: 48h cycles, compound 30%):

```bash
./platform validator set-auto-config \
  --rpc-url https://api.avax-dev.network \
  --key-name mykey \
  --tx-id <AddAutoRenewedValidatorTx-ID> \
  --period 48h \
  --auto-compound 0.3
```

Graceful exit — finish the current cycle, then stop and withdraw everything (`--period 0`):

```bash
./platform validator set-auto-config \
  --rpc-url https://api.avax-dev.network \
  --key-name mykey \
  --tx-id <AddAutoRenewedValidatorTx-ID> \
  --period 0 \
  --auto-compound 0
```

Changes take effect at the next cycle boundary. Re-run the `getCurrentValidators` query above to
confirm the new `period` / `autoCompoundRewardShares`.

These flows are the same ones e2e-tested against this devnet in the PR — see the
[PR #28 test notes](https://github.com/ava-labs/platform-cli/pull/28) for accepted transaction
IDs.

## Programmatic path — TypeScript SDK

[PR #379](https://github.com/ava-labs/avalanche-sdk-typescript/pull/379) (unmerged) adds the
equivalent helpers to `@avalanche-sdk/client`: `pChain.prepareAddAutoRenewedValidatorTxn` and
`pChain.prepareSetAutoRenewedValidatorConfigTxn`, both e2e-tested against this devnet. Until it
merges, build the package from the PR branch:

```bash
git clone https://github.com/ava-labs/avalanche-sdk-typescript.git
cd avalanche-sdk-typescript
git fetch origin pull/379/head:acp236-sdk
git checkout acp236-sdk
cd client
npm install && npm run build:types && npm run build:esm
npm pack    # → install the resulting .tgz in your project
```

Adapted from the SDK's ACP-236 e2e test
([`e2e/test/acp236-auto-renewed-validator.integration.test.ts`](https://github.com/ava-labs/avalanche-sdk-typescript/blob/anish/acp236-auto-renewed-validator-docs/e2e/test/acp236-auto-renewed-validator.integration.test.ts)):

```ts
const txnRequest = await walletClient.pChain.prepareAddAutoRenewedValidatorTxn({
  changeAddresses: [ownerPAddr],
  stakeInNanoAvax: 2_000_000_000_000n,   // 2,000 AVAX
  nodeId,                                 // NodeID-...
  period: 24n * 3600n,                    // seconds
  rewardAddresses: [ownerPAddr],
  delegatorRewardAddresses: [ownerPAddr],
  ownerAddresses: [ownerPAddr],
  publicKey,                              // BLS public key from info.getNodeID
  signature,                              // BLS proof of possession
  delegatorRewardPercentage: 2,           // 0–100
  autoCompoundRewardPercentage: 100,      // 0–100
});
const { txHash } = await walletClient.sendXPTransaction({
  tx: txnRequest.tx,
  chainAlias: txnRequest.chainAlias,
});
```

For config updates, `prepareSetAutoRenewedValidatorConfigTxn({ validatorTxId, auth: [0],
period, autoCompoundRewardPercentage })` followed by `sendXPTransaction` with the returned
`autoRenewedValidatorOwners` / `autoRenewedValidatorAuth` fields — see the e2e test for the full
sequence.
