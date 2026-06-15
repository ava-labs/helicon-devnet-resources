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

A runnable script built on [`@avalabs/avalanchejs`](https://www.npmjs.com/package/@avalabs/avalanchejs)
lives in [`scripts/c-to-p-transfer/`](../scripts/c-to-p-transfer/). (It uses avalanchejs directly
rather than the higher-level `@avalanche-sdk/client`, whose published release resolves X/P/C
blockchain IDs from a hardcoded mainnet/fuji table and rejects custom networks like this devnet —
avalanchejs takes every chain ID from the live context instead.)

Requires Node.js (≥ 18; tested on 20–24). If `npm` is missing but you use nvm, run
`nvm use 24` first. Then, from the repo root:

```bash
cd scripts/c-to-p-transfer
npm install
cp -n .env.example .env
npm run transfer
```

Edit `.env` to set `PRIVATE_KEY` (a funded throwaway devnet key) and `AMOUNT_AVAX` between the
copy and the run. `cp -n` won't overwrite an existing `.env`, so it's safe to re-run; the script
refuses to run while `PRIVATE_KEY` is still the placeholder.

The script exports from C, waits for the atomic transaction to be accepted, imports to P, and
prints balances before and after. Read [`transfer.ts`](../scripts/c-to-p-transfer/transfer.ts)
to see the exact avalanchejs calls (`Context.getContextFromURI`, `evm.newExportTxFromBaseFee`,
`pvm.newImportTx`, `addTxSignatures`, and `issueSignedTx`) for embedding in your own systems.

## Path B — platform-cli

[`platform-cli`](https://github.com/ava-labs/platform-cli) has a combined export+import command.
`transfer c-to-p` is on the `main` branch, so a plain build works — you do **not** need the
ACP-236 PR branch for this (that branch only adds the staking commands, and includes this one too).

Build it from a directory **outside** this repo (the build auto-fetches the Go toolchain it needs):

```bash
git clone https://github.com/ava-labs/platform-cli.git
cd platform-cli
go build -o platform .
```

That produces a `platform` binary in the platform-cli directory. Run the commands below **from
that directory** (or move the binary onto your PATH) — `./platform` only resolves where the binary
lives.

Generate a throwaway devnet key in the keystore (`--encrypt=false` keeps it non-interactive; omit
it to encrypt with a password):

```bash
./platform keys generate --name mykey --encrypt=false
```

It prints the key's **EVM address**. Drip devnet AVAX to that address at the
[faucet](https://build.avax.network/console/primary-network/devnet-faucet), then transfer C → P
(export + import in one step; `--network-id` is auto-detected as 76 from the RPC):

```bash
./platform transfer c-to-p \
  --amount 2005 \
  --key-name mykey \
  --rpc-url https://api.avax-dev.network
```

Confirm the funds landed on the P-Chain:

```bash
./platform wallet balance --key-name mykey --rpc-url https://api.avax-dev.network
```

Already have a funded key? Import it instead of generating one — `./platform keys import --name
mykey` prompts for the `PrivateKey-...` value with hidden input (note the `--name` flag; there is
no positional form).

## Verify by RPC

You can confirm a transfer landed with `curl` alone — no platform-cli needed.

First, get the P-Chain address for your key. The transfer script (Path A) prints it on every run,
or derive it standalone from the key in `scripts/c-to-p-transfer/.env` (this prints only the public
address, never the key):

```bash
cd scripts/c-to-p-transfer
node --input-type=module -e "import 'dotenv/config'; import {privateKeyToAvalancheAccount} from '@avalanche-sdk/client/accounts'; console.log(privateKeyToAvalancheAccount(process.env.PRIVATE_KEY).getXPAddress('P','custom'));"
```

Then query the P-Chain balance for that address (in nAVAX; 1 AVAX = 1e9 nAVAX):

```bash
curl -sS -X POST -H 'Content-Type: application/json' \
  --data '{"jsonrpc":"2.0","id":1,"method":"platform.getBalance","params":{"addresses":["P-custom1..."]}}' \
  https://api.avax-dev.network/ext/bc/P
```

In the response, `balance` / `unlocked` are the total / spendable amounts and `utxoIDs` lists one
entry per imported deposit. For the C-Chain side, use the standard `eth_getBalance` (returns wei,
1 AVAX = 1e18 wei) against `https://api.avax-dev.network/ext/bc/C/rpc`.
