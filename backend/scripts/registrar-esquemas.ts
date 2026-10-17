/**
 * Registra los esquemas EAS firmando con la clave de Cloud KMS (la misma que
 * firma las attestations). Primero en OP Sepolia; en producción, en OP Mainnet.
 *
 *   npm run registrar-esquemas                       # OP Sepolia
 *   npm run registrar-esquemas -- --red optimism     # OP Mainnet
 *   npm run registrar-esquemas -- --direccion        # solo muestra la dirección y su saldo
 *
 * Necesita KMS_KEY_VERSION en backend/.env y un poco de ETH en la dirección
 * de la clave (en Sepolia, de un faucet).
 */
import { SCHEMA_REGISTRY_ADDRESS, esquemas, schemaUid } from "@trazacafe/eudr-eas-schemas";
import { createPublicClient, createWalletClient, formatEther, http, parseAbi, zeroAddress } from "viem";
import { optimism, optimismSepolia } from "viem/chains";
import { cuentaKms } from "../src/kms.ts";

const args = process.argv.slice(2);
const mainnet = args[args.indexOf("--red") + 1] === "optimism";
const chain = mainnet ? optimism : optimismSepolia;
const explorador = mainnet ? "https://optimism.easscan.org" : "https://optimism-sepolia.easscan.org";

const version = process.env.KMS_KEY_VERSION;
if (!version) {
  console.error("Falta KMS_KEY_VERSION en backend/.env.");
  process.exit(1);
}
const cuenta = await cuentaKms(version);
const transport = http(process.env.RPC_URL);
const publico = createPublicClient({ chain, transport });
const saldo = await publico.getBalance({ address: cuenta.address });
console.log(`Red: ${chain.name}\nDirección de la clave: ${cuenta.address}\nSaldo: ${formatEther(saldo)} ETH\n`);
if (args.includes("--direccion")) process.exit(0);
if (saldo === 0n) {
  console.error("La dirección no tiene ETH para pagar el registro.");
  process.exit(1);
}

const abi = parseAbi([
  "function register(string schema, address resolver, bool revocable) returns (bytes32)",
  "function getSchema(bytes32 uid) view returns ((bytes32 uid, address resolver, bool revocable, string schema))",
]);
const billetera = createWalletClient({ chain, transport, account: cuenta });

for (const e of esquemas) {
  const uid = schemaUid(e.schema, e.revocable);
  const existente = await publico.readContract({ address: SCHEMA_REGISTRY_ADDRESS, abi, functionName: "getSchema", args: [uid] });
  if (existente.uid === uid) {
    console.log(`${e.nombre}: ya registrado → ${explorador}/schema/view/${uid}`);
    continue;
  }
  const hash = await billetera.writeContract({
    address: SCHEMA_REGISTRY_ADDRESS,
    abi,
    functionName: "register",
    args: [e.schema, zeroAddress, e.revocable],
  });
  await publico.waitForTransactionReceipt({ hash });
  console.log(`${e.nombre}: registrado → ${explorador}/schema/view/${uid}`);
}
