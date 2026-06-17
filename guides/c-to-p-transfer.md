# Move AVAX from C-Chain to P-Chain

The [devnet faucet](https://build.avax.network/console/primary-network/devnet-faucet) delivers
AVAX on the **C-Chain**, but staking happens on the **P-Chain**. Moving funds across is a
two-step atomic operation: **export** from C, then **import** to P.

To stake one validator you need **2,000 AVAX** on the P-Chain, plus a little extra for
transaction fees — transferring **2,005 AVAX** is comfortable.

One key does both: a secp256k1 private key controls a C-Chain (`0x...`) address and a P-Chain
(`P-custom1...`) address on this network. The walkthrough below uses `platform-cli` end to end —
add that key to its keystore, fund it, and transfer — so the same key is ready to stake. A
TypeScript/avalanchejs alternative for programmatic use is at the end.

> Use throwaway keys on the devnet. Never reuse keys that hold funds on Mainnet.

## 1. Build platform-cli

[`platform-cli`](https://github.com/ava-labs/platform-cli) has a combined export+import command,
`transfer c-to-p`, on its `main` branch — a plain build works:

```bash
git clone https://github.com/ava-labs/platform-cli.git
cd platform-cli
go build -o platform .
```

Build it from a directory **outside** this repo; the build auto-fetches the Go toolchain it needs.
That produces a `platform` binary — run the commands below **from that directory** (or move the
binary onto your `PATH`), since `./platform` only resolves where the binary lives.

> Planning to stake afterward? Build the [ACP-236 PR branch](auto-renewed-staking.md) instead — it
> includes `transfer c-to-p` plus the staking commands, so you build only once.

## 2. Add your key to the keystore

Import the throwaway devnet key you want to stake with — `platform keys import` reads it from a
hidden prompt and accepts either the `0x...` hex or the CB58 `PrivateKey-...` form:

```bash
./platform keys import --name mykey --encrypt=false   # paste your key at the hidden prompt
```

Or generate a fresh one instead:

```bash
./platform keys generate --name mykey --encrypt=false
```

Either command prints the key's **EVM (C-Chain) address** — you fund that next. This is the key you
use for the transfer *and* for staking, so keep the name (`mykey`) handy. (`--encrypt=false` keeps
it non-interactive; omit it to encrypt the key with a password.)

## 3. Fund the C-Chain address

Drip devnet AVAX to the key's EVM address at the
[faucet](https://build.avax.network/console/primary-network/devnet-faucet) — you need **2,005 AVAX**
(2,000 to stake + a buffer for fees). Lost the address? Print it again:

```bash
./platform wallet address --key-name mykey --rpc-url https://api.avax-dev.network
```

## 4. Transfer C → P

Export from C and import to P in one step (`--network-id` is auto-detected as 76 from the RPC):

```bash
./platform transfer c-to-p \
  --amount 2005 \
  --key-name mykey \
  --rpc-url https://api.avax-dev.network
```

## 5. Confirm the balance

```bash
./platform wallet balance --key-name mykey --rpc-url https://api.avax-dev.network
```

This prints your key's P-Chain address and balance.

> **Prefer raw RPC?** To confirm the same balance without platform-cli, query the P-Chain directly
> for that `P-custom1...` address — `balance` comes back in nAVAX (1 AVAX = 1e9 nAVAX):
>
> ```bash
> curl -sS -X POST -H 'Content-Type: application/json' \
>   --data '{"jsonrpc":"2.0","id":1,"method":"platform.getBalance","params":{"addresses":["P-custom1..."]}}' \
>   https://api.avax-dev.network/ext/bc/P
> ```

That's it — `mykey` now holds the stake on the P-Chain. Continue to
[auto-renewed-staking.md](auto-renewed-staking.md), which signs with this same key.

## Programmatic alternative — TypeScript / avalanchejs

To embed C → P transfers in your own systems, a runnable script built on
[`@avalabs/avalanchejs`](https://www.npmjs.com/package/@avalabs/avalanchejs) lives in
[`scripts/c-to-p-transfer/`](../scripts/c-to-p-transfer/). It uses avalanchejs directly rather than
the higher-level `@avalanche-sdk/client`, whose published release resolves X/P/C blockchain IDs from
a hardcoded mainnet/fuji table and rejects custom networks like this devnet — avalanchejs takes every
chain ID from the live context instead.

Requires Node.js (≥ 18; tested on 20–24). If `npm` is missing but you use nvm, run `nvm use 24`
first. Then, from the repo root:

```bash
cd scripts/c-to-p-transfer
npm install
cp -n .env.example .env
npm run transfer
```

Set `PRIVATE_KEY` (a funded throwaway devnet key) and `AMOUNT_AVAX` in `.env` between the copy and
the run; the script refuses to run while `PRIVATE_KEY` is still the placeholder. It exports from C,
waits for the atomic transaction, imports to P, and prints balances before and after. Read
[`transfer.ts`](../scripts/c-to-p-transfer/transfer.ts) for the exact avalanchejs calls
(`Context.getContextFromURI`, `evm.newExportTxFromBaseFee`, `pvm.newImportTx`, `addTxSignatures`,
`issueSignedTx`).
