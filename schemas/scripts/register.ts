/**
 * Registra los esquemas EAS en OP Sepolia u OP Mainnet.
 *
 *   npm run register -- --dry-run            # solo muestra strings y UIDs
 *   npm run register                         # registra en OP Sepolia
 *   npm run register -- --network mainnet    # registra en OP Mainnet
 *
 * Para registrar necesita PRIVATE_KEY en schemas/.env (una wallet de pruebas
 * con un poco de ETH). En producción la firma se hará con Cloud KMS.
 */
import { createPublicClient, createWalletClient, http, parseAbi, zeroAddress, type Hex } from "viem";
import { privateKeyToAccount } from "viem/accounts";
import { optimism, optimismSepolia } from "viem/chains";
import { SCHEMA_REGISTRY_ADDRESS, esquemas, schemaUid } from "../src/index.ts";

const abi = parseAbi([
  "function register(string schema, address resolver, bool revocable) returns (bytes32)",
  "function getSchema(bytes32 uid) view returns ((bytes32 uid, address resolver, bool revocable, string schema))",
]);

const args = process.argv.slice(2);
const dryRun = args.includes("--dry-run");
const network = args[args.indexOf("--network") + 1] === "mainnet" ? "mainnet" : "sepolia";
const chain = network === "mainnet" ? optimism : optimismSepolia;
const explorer = network === "mainnet" ? "https://optimism.easscan.org" : "https://optimism-sepolia.easscan.org";

console.log(`Red: ${chain.name}${dryRun ? " (dry-run)" : ""}\n`);
for (const e of esquemas) {
  console.log(`${e.nombre}\n  schema: ${e.schema}\n  uid:    ${schemaUid(e.schema, e.revocable)}\n`);
}
if (dryRun) process.exit(0);

const privateKey = process.env.PRIVATE_KEY as Hex | undefined;
if (!privateKey) {
  console.error("Falta PRIVATE_KEY en schemas/.env (ver .env.example).");
  process.exit(1);
}

const transport = http(process.env.RPC_URL);
const publicClient = createPublicClient({ chain, transport });
const wallet = createWalletClient({ chain, transport, account: privateKeyToAccount(privateKey) });

for (const e of esquemas) {
  const uid = schemaUid(e.schema, e.revocable);
  const existente = await publicClient.readContract({
    address: SCHEMA_REGISTRY_ADDRESS,
    abi,
    functionName: "getSchema",
    args: [uid],
  });
  if (existente.uid === uid) {
    console.log(`${e.nombre}: ya registrado → ${explorer}/schema/view/${uid}`);
    continue;
  }
  const hash = await wallet.writeContract({
    address: SCHEMA_REGISTRY_ADDRESS,
    abi,
    functionName: "register",
    args: [e.schema, zeroAddress, e.revocable],
  });
  await publicClient.waitForTransactionReceipt({ hash });
  console.log(`${e.nombre}: registrado → ${explorer}/schema/view/${uid}`);
}
