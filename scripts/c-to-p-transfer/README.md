# C → P transfer script

Moves AVAX from the C-Chain to the P-Chain on the Helicon devnet (network 76) using
[`@avalabs/avalanchejs`](https://www.npmjs.com/package/@avalabs/avalanchejs) directly — it is
network-agnostic, unlike the published `@avalanche-sdk/client`, which rejects custom networks.

Requires Node.js ≥ 18 (tested on 20–24). If `npm` is missing but you use nvm: `nvm use 24`.

```bash
npm install
cp -n .env.example .env
npm run transfer
```

Set `PRIVATE_KEY` and `AMOUNT_AVAX` in `.env` between the copy and the run. Use a throwaway
devnet key, and fund its C-Chain address first — see
[guides/c-to-p-transfer.md](../../guides/c-to-p-transfer.md).
