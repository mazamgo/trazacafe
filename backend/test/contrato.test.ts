import ejemplo from "@trazacafe/eudr-eas-schemas/fixtures/sync-ejemplo.json" with { type: "json" };
import { describe, expect, it } from "vitest";
import { syncSchema } from "../src/sync.ts";

// La app Flutter genera exactamente este JSON (app/test/sync_service_test.dart).
// Si alguno de los dos lados cambia el formato, falla una de las dos pruebas.
describe("contrato app ↔ API", () => {
  it("la API acepta el payload que envía la app", () => {
    const r = syncSchema.safeParse(ejemplo);
    expect(r.success, JSON.stringify(r.error?.issues)).toBe(true);
  });
});
