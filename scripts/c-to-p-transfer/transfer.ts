/**
 * Transfer AVAX from C-Chain to P-Chain on the Helicon devnet (network 76).
 *
 * Flow: export from C (atomic tx) -> wait for acceptance -> import to P -> wait
 * for commitment. Prints balances before and after.
 *
 * Usage: cp .env.example .env, set PRIVATE_KEY + AMOUNT_AVAX, then `npm run transfer`.
 */
import "dotenv/config";
import { createAvalancheWalletClient } from "@avalanche-sdk/client";
import { privateKeyToAvalancheAccount } from "@avalanche-sdk/client/accounts";
import { avaxToNanoAvax } from "@avalanche-sdk/client/utils";
import { defineChain, formatEther } from "viem";
import { privateKeyToAccount } from "viem/accounts";
import { z } from "zod";

const HRP = "custom"; // address prefix for network 76 (a custom network)

const envSchema = z.object({
  PRIVATE_KEY: z
    .string()
    .regex(/^0x[0-9a-fA-F]{64}$/, "PRIVATE_KEY must be 0x + 64 hex chars"),
  AMOUNT_AVAX: z.coerce.number().positive(),
  RPC_URL: z.string().url().default("https://api.avax-dev.network"),
});

const env = envSchema.parse(process.env);

const heliconDevnet = defineChain({
  id: 43_117,
  name: "Helicon Devnet C-Chain",
  nativeCurrency: { decimals: 18, name: "Avalanche", symbol: "AVAX" },
  rpcUrls: { default: { http: [`${env.RPC_URL}/ext/bc/C/rpc`] } },
  testnet: true,
});

async function rpc<T>(path: string, method: string, params: unknown): Promise<T> {
  const response = await fetch(`${env.RPC_URL}${path}`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ jsonrpc: "2.0", id: 1, method, params }),
  });
  if (!response.ok) {
    throw new Error(`RPC ${method} failed: HTTP ${response.status}`);
  }
  const body = (await response.json()) as { result?: T; error?: { message: string } };
  if (body.error) {
    throw new Error(`RPC ${method} failed: ${body.error.message}`);
  }
  if (body.result === undefined) {
    throw new Error(`RPC ${method} returned no result`);
  }
  return body.result;
}

const sleep = (ms: number) => new Promise((resolve) => setTimeout(resolve, ms));

async function getCChainBalanceAvax(address: string): Promise<string> {
  const wei = await rpc<string>("/ext/bc/C/rpc", "eth_getBalance", [address, "latest"]);
  return formatEther(BigInt(wei));
}

async function getPChainBalanceNavax(address: string): Promise<bigint> {
  const result = await rpc<{ balance: string }>("/ext/bc/P", "platform.getBalance", {
    addresses: [address],
  });
  return BigInt(result.balance);
}

async function waitForCChainAtomicTx(txId: string, timeoutMs = 60_000): Promise<void> {
  const deadline = Date.now() + timeoutMs;
  while (Date.now() < deadline) {
    const { status } = await rpc<{ status: string }>("/ext/bc/C/avax", "avax.getAtomicTxStatus", {
      txID: txId,
    });
    if (status === "Accepted") return;
    if (status === "Dropped") throw new Error(`export tx ${txId} was dropped`);
    await sleep(2_000);
  }
  throw new Error(`timed out waiting for export tx ${txId} to be accepted`);
}

async function waitForPChainTx(txId: string, timeoutMs = 60_000): Promise<void> {
  const deadline = Date.now() + timeoutMs;
  while (Date.now() < deadline) {
    const { status } = await rpc<{ status: string }>("/ext/bc/P", "platform.getTxStatus", {
      txID: txId,
    });
    if (status === "Committed") return;
    if (status === "Dropped" || status === "Aborted") {
      throw new Error(`import tx ${txId} ended with status ${status}`);
    }
    await sleep(2_000);
  }
  throw new Error(`timed out waiting for import tx ${txId} to be committed`);
}

async function main(): Promise<void> {
  const account = privateKeyToAvalancheAccount(env.PRIVATE_KEY as `0x${string}`);
  const evmAddress = privateKeyToAccount(env.PRIVATE_KEY as `0x${string}`).address;
  const pAddress = account.getXPAddress("P", HRP);

  const walletClient = createAvalancheWalletClient({
    account,
    chain: heliconDevnet,
    transport: { type: "http", url: `${env.RPC_URL}/ext/bc/C/rpc` },
  });

  console.log(`C-Chain address: ${evmAddress}`);
  console.log(`P-Chain address: ${pAddress}`);
  console.log(`C balance: ${await getCChainBalanceAvax(evmAddress)} AVAX`);
  console.log(`P balance: ${await getPChainBalanceNavax(pAddress)} nAVAX`);
  console.log(`\nExporting ${env.AMOUNT_AVAX} AVAX from C-Chain...`);

  const exportRequest = await walletClient.cChain.prepareExportTxn({
    destinationChain: "P",
    fromAddress: evmAddress,
    exportedOutput: {
      addresses: [pAddress],
      amount: avaxToNanoAvax(env.AMOUNT_AVAX),
    },
  });
  const { txHash: exportTxId } = await walletClient.sendXPTransaction({
    tx: exportRequest.tx,
    chainAlias: exportRequest.chainAlias,
  });
  console.log(`Export tx: ${exportTxId}`);
  await waitForCChainAtomicTx(exportTxId);
  console.log("Export accepted. Importing to P-Chain...");

  // The exported UTXO can take a moment to appear in shared memory — retry the import.
  let importTxId: string | undefined;
  let lastError: unknown;
  for (let attempt = 1; attempt <= 10 && !importTxId; attempt++) {
    try {
      const importRequest = await walletClient.pChain.prepareImportTxn({
        sourceChain: "C",
        importedOutput: { addresses: [pAddress] },
      });
      const { txHash } = await walletClient.sendXPTransaction({
        tx: importRequest.tx,
        chainAlias: importRequest.chainAlias,
      });
      importTxId = txHash;
    } catch (error) {
      lastError = error;
      console.log(`Import attempt ${attempt}/10 not ready yet, retrying...`);
      await sleep(3_000);
    }
  }
  if (!importTxId) {
    throw new Error(`import failed after 10 attempts: ${String(lastError)}`);
  }
  console.log(`Import tx: ${importTxId}`);
  await waitForPChainTx(importTxId);

  console.log("\nTransfer complete.");
  console.log(`C balance: ${await getCChainBalanceAvax(evmAddress)} AVAX`);
  console.log(`P balance: ${await getPChainBalanceNavax(pAddress)} nAVAX`);
}

main().catch((error) => {
  console.error(`\nTransfer failed: ${error instanceof Error ? error.message : String(error)}`);
  process.exit(1);
});
