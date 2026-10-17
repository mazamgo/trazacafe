import { KeyManagementServiceClient } from "@google-cloud/kms";
import {
  bytesToHex,
  hashMessage,
  hashTypedData,
  hexToBytes,
  keccak256,
  recoverAddress,
  serializeTransaction,
  type Address,
  type Hex,
  type LocalAccount,
} from "viem";
import { publicKeyToAddress, toAccount } from "viem/accounts";

/** Orden de la curva secp256k1. */
const N = 0xfffffffffffffffffffffffffffffffebaaedce6af48a03bbfd25e8cd0364141n;

/** Lee un entero ASN.1 DER desde [i]; devuelve el valor y la posición siguiente. */
function leerEntero(der: Uint8Array, i: number): [bigint, number] {
  if (der[i] !== 0x02) throw new Error("Firma DER inválida: se esperaba un INTEGER");
  const largo = der[i + 1];
  const bytes = der.subarray(i + 2, i + 2 + largo);
  return [BigInt(bytesToHex(bytes)), i + 2 + largo];
}

/**
 * Convierte la firma DER de Cloud KMS en una firma de Ethereum: `s` bajo
 * (EIP-2) y el `yParity` que recupera [direccion] sobre [hash].
 */
export async function firmaDesdeDer(
  hash: Hex,
  der: Uint8Array,
  direccion: Address,
): Promise<{ r: Hex; s: Hex; yParity: 0 | 1 }> {
  if (der[0] !== 0x30) throw new Error("Firma DER inválida: se esperaba un SEQUENCE");
  let [r, i] = leerEntero(der, 2);
  let [s] = leerEntero(der, i);
  if (s > N / 2n) s = N - s;
  const hex = (n: bigint) => `0x${n.toString(16).padStart(64, "0")}` as Hex;
  for (const yParity of [0, 1] as const) {
    const firma = { r: hex(r), s: hex(s), yParity };
    const recuperada = await recoverAddress({ hash, signature: firma });
    if (recuperada.toLowerCase() === direccion.toLowerCase()) return firma;
  }
  throw new Error("La firma de KMS no corresponde a la dirección de la clave");
}

/** Dirección de Ethereum de una clave pública SPKI en PEM (secp256k1). */
export function direccionDesdePem(pem: string): Address {
  const der = Buffer.from(pem.replace(/-----[^-]+-----/g, "").replace(/\s+/g, ""), "base64");
  // La clave sin comprimir son los últimos 65 bytes: 0x04 || X || Y.
  const punto = der.subarray(der.length - 65);
  if (punto[0] !== 0x04) throw new Error("Se esperaba una clave pública sin comprimir");
  return publicKeyToAddress(bytesToHex(punto));
}

/**
 * Cuenta de viem que firma con una versión de clave de Cloud KMS
 * (EC_SIGN_SECP256K1_SHA256, protección HSM). La clave privada nunca sale de
 * Google; la cuenta de servicio necesita `cloudkms.signerVerifier` y
 * `cloudkms.publicKeyViewer` sobre la clave.
 *
 * [versionClave]: projects/…/locations/…/keyRings/…/cryptoKeys/…/cryptoKeyVersions/1
 */
export async function cuentaKms(
  versionClave: string,
  cliente = new KeyManagementServiceClient(),
): Promise<LocalAccount> {
  const [publica] = await cliente.getPublicKey({ name: versionClave });
  if (!publica.pem) throw new Error("Cloud KMS no devolvió la clave pública");
  const address = direccionDesdePem(publica.pem);

  const firmarHash = async (hash: Hex) => {
    // KMS firma los 32 bytes tal cual: se le pasa el keccak256 como "sha256".
    const [r] = await cliente.asymmetricSign({ name: versionClave, digest: { sha256: hexToBytes(hash) } });
    if (!r.signature) throw new Error("Cloud KMS no devolvió la firma");
    return firmaDesdeDer(hash, new Uint8Array(r.signature as Uint8Array), address);
  };
  const aHex = ({ r, s, yParity }: { r: Hex; s: Hex; yParity: 0 | 1 }) =>
    `${r}${s.slice(2)}${yParity === 0 ? "1b" : "1c"}` as Hex;

  return toAccount({
    address,
    async signMessage({ message }) {
      return aHex(await firmarHash(hashMessage(message)));
    },
    async signTypedData(datos) {
      return aHex(await firmarHash(hashTypedData(datos)));
    },
    async signTransaction(tx, { serializer = serializeTransaction } = {}) {
      const firma = await firmarHash(keccak256(await serializer(tx)));
      return serializer(tx, firma);
    },
  });
}
