# C → P transfer script

Moves AVAX from the C-Chain to the P-Chain on the Helicon devnet (network 76) using the
published [`@avalanche-sdk/client`](https://www.npmjs.com/package/@avalanche-sdk/client).

```bash
npm install
cp .env.example .env   # set PRIVATE_KEY and AMOUNT_AVAX
npm run transfer
```

Use a throwaway devnet key. Fund its C-Chain address first — see
[guides/c-to-p-transfer.md](../../guides/c-to-p-transfer.md).
