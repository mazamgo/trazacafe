import { secp256k1 } from "@noble/curves/secp256k1";
import { keccak256, recoverAddress, recoverMessageAddress, toHex, type Hex } from "viem";
import { privateKeyToAccount } from "viem/accounts";
import { describe, expect, it } from "vitest";
import { cuentaKms, direccionDesdePem, firmaDesdeDer } from "../src/kms.ts";

// Clave de prueba fija (no tiene fondos ni se usa fuera de esta prueba).
const privada = "0x4c0883a69102937d6231471b5dbb6204fe5129617082792ae468d01a3f362318" as const;
const direccion = privateKeyToAccount(privada).address;
const N = secp256k1.CURVE.n;

/** PEM SPKI de la clave pública, como lo devuelve Cloud KMS. */
function pem(): string {
  const punto = secp256k1.getPublicKey(privada.slice(2), false);
  // Cabecera SPKI de id-ecPublicKey + secp256k1 (23 bytes) seguida del BIT STRING.
  const cabecera = Buffer.from("3056301006072a8648ce3d020106052b8104000a034200", "hex");
  const b64 = Buffer.concat([cabecera, Buffer.from(punto)]).toString("base64");
  return `-----BEGIN PUBLIC KEY-----\n${b64}\n-----END PUBLIC KEY-----\n`;
}

/** Firma DER como la de KMS: con `s` alto la mitad de las veces. */
function firmaDer(hash: Hex, sAlto = false): Uint8Array {
  const f = secp256k1.sign(hash.slice(2), privada.slice(2), { lowS: true });
  const conS = sAlto ? new secp256k1.Signature(f.r, N - f.s) : f;
  return conS.toDERRawBytes();
}

/** Cliente de KMS falso que firma con la clave de prueba. */
const kmsFalso = {
  async getPublicKey() {
    return [{ pem: pem() }];
  },
  async asymmetricSign({ digest }: { digest: { sha256: Uint8Array } }) {
    return [{ signature: firmaDer(toHex(digest.sha256), true) }];
  },
} as unknown as ConstructorParameters<typeof Object>[0];

describe("firma con Cloud KMS", () => {
  it("obtiene la dirección desde la clave pública PEM", () => {
    expect(direccionDesdePem(pem())).toBe(direccion);
  });

  it("convierte la firma DER (también con s alto) en una firma de Ethereum válida", async () => {
    const hash = keccak256(toHex("TrazaCafé"));
    for (const sAlto of [false, true]) {
      const firma = await firmaDesdeDer(hash, firmaDer(hash, sAlto), direccion);
      expect(BigInt(firma.s) <= N / 2n).toBe(true);
      expect(await recoverAddress({ hash, signature: firma })).toBe(direccion);
    }
  });

  it("rechaza una firma de otra clave", async () => {
    const hash = keccak256(toHex("x"));
    const otra = privateKeyToAccount("0x8da4ef21b864d2cc526dbdb2a120bd2874c36c9d0a1fb7f8c63d7f7a8b41de8f").address;
    await expect(firmaDesdeDer(hash, firmaDer(hash), otra)).rejects.toThrow("no corresponde");
  });

  it("la cuenta firma mensajes y transacciones que se recuperan a su dirección", async () => {
    const cuenta = await cuentaKms("projects/p/locations/l/keyRings/k/cryptoKeys/c/cryptoKeyVersions/1", kmsFalso as never);
    expect(cuenta.address).toBe(direccion);
    const mensaje = "hola";
    expect(await recoverMessageAddress({ message: mensaje, signature: await cuenta.signMessage({ message: mensaje }) })).toBe(direccion);

    const tx = { chainId: 11155420, nonce: 0, to: direccion, value: 0n, maxFeePerGas: 1n, maxPriorityFeePerGas: 1n, gas: 21000n, type: "eip1559" } as const;
    const firmada = await cuenta.signTransaction(tx);
    const local = await privateKeyToAccount(privada).signTransaction(tx);
    expect(firmada).toBe(local);
  });
});
