# Move AVAX from C-Chain to P-Chain

The [devnet faucet](https://build.avax.network/console/primary-network/devnet-faucet) delivers
AVAX on the **C-Chain**, but staking happens on the **P-Chain**. Moving funds across is a
two-step atomic operation: **export** from C, then **import** to P.

To stake one validator you need **2,000 AVAX** on the P-Chain, plus a little extra for
transaction fees — transferring **2,005 AVAX** is comfortable.

Both paths below use the same key: a secp256k1 private key controls a C-Chain (0x...) address
and a P-Chain (P-custom1...) address on this network.

> Use throwaway keys on the devnet. Never reuse keys that hold funds on Mainnet.

## Path A — TypeScript script (programmatic integration)

A runnable script using the published [`@avalanche-sdk/client`](https://www.npmjs.com/package/@avalanche-sdk/client)
lives in [`scripts/c-to-p-transfer/`](../scripts/c-to-p-transfer/):

```bash
cd scripts/c-to-p-transfer
npm install
cp .env.example .env       # set PRIVATE_KEY and AMOUNT_AVAX
npm run transfer
```

The script exports from C, waits for the atomic transaction to be accepted, imports to P, and
prints balances before and after. Read [`transfer.ts`](../scripts/c-to-p-transfer/transfer.ts)
to see the exact SDK calls (`cChain.prepareExportTxn`, `pChain.prepareImportTxn`,
`sendXPTransaction`) for embedding in your own systems.

## Path B — platform-cli one-liner

[`platform-cli`](https://github.com/ava-labs/platform-cli) has a combined export+import command.
If you are following the [auto-renewed staking guide](auto-renewed-staking.md) you will build it
from the ACP-236 PR branch anyway; that build includes this command too.

```bash
# one-time: store a key in the local keystore (or use the AVALANCHE_PRIVATE_KEY env var)
./platform keys import mykey

# transfer C → P (export + import in one step)
./platform transfer c-to-p \
  --amount 2005 \
  --key-name mykey \
  --rpc-url https://api.avax-dev.network

# check the P-Chain balance afterwards
./platform wallet balance --key-name mykey --rpc-url https://api.avax-dev.network
```

## Verify by RPC

```bash
# P-Chain balance for your address (in nAVAX; 1 AVAX = 1e9 nAVAX)
curl -s -X POST -H 'Content-Type: application/json' \
  --data '{"jsonrpc":"2.0","id":1,"method":"platform.getBalance","params":{"addresses":["P-custom1..."]}}' \
  https://api.avax-dev.network/ext/bc/P
```
