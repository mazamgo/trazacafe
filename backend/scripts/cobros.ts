/**
 * Cobros, mientras no exista la consola del propietario (Fase 3).
 *
 * Contrato de una organización (uno vigente a la vez; montos en USD):
 *   npm run contrato -- --organizacion <uuid> --plan exportador --inicio 2026-11-01 --fin 2027-10-31 \
 *     --cuota 1500 --incluidos 20 --precio 50 --estado activo [--nota "Precio de fundador"]
 *
 * Ajuste (cortesía, error): monto negativo = descuento; nunca se borra un consumo.
 *   npm run ajuste-cobro -- --organizacion <uuid> --monto -50 --motivo "Primer contenedor de cortesía"
 *
 * Estado de cuenta del mes (todas las organizaciones con contrato o consumos, o una):
 *   npm run estado-de-cuenta -- --mes 2026-11 [--organizacion <uuid>] [--csv estado-2026-11.csv]
 *
 * Lo que se cobra es el contenedor cerrado (se anota solo al cerrarlo). Las
 * facturas fiscales salen del sistema autorizado de la DGI; esto solo da los
 * números y el enlace al verificador de cada contenedor.
 */
import { writeFileSync } from "node:fs";
import { parseArgs } from "node:util";
import { ajusteSchema, CobrosPg, contratoSchema, type EstadoDeCuenta } from "../src/cobros.ts";
import { crearPool } from "../src/db.ts";

const VERIFICADOR = process.env.VERIFICADOR_URL ?? "https://trazacafe-dev.web.app";
const [comando, ...resto] = process.argv.slice(2);
const { values } = parseArgs({
  args: resto,
  options: {
    organizacion: { type: "string" },
    plan: { type: "string" },
    inicio: { type: "string" },
    fin: { type: "string" },
    cuota: { type: "string" },
    incluidos: { type: "string" },
    precio: { type: "string" },
    estado: { type: "string" },
    nota: { type: "string" },
    monto: { type: "string" },
    motivo: { type: "string" },
    mes: { type: "string" },
    csv: { type: "string" },
  },
});

function salir(mensaje: string): never {
  console.error(mensaje);
  process.exit(1);
}
const errores = (issues: { path: PropertyKey[]; message: string }[]) =>
  issues.map((i) => `  --${String(i.path[0] ?? "")}: ${i.message}`).join("\n");
const usd = (n: number) => `US$${n.toLocaleString("es-NI", { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`;

if (!["contrato", "ajuste", "estado"].includes(comando ?? "")) {
  salir("Uso: npm run contrato | ajuste-cobro | estado-de-cuenta -- [opciones] (ver backend/scripts/cobros.ts)");
}

const { pool, cerrar } = await crearPool();
const cobros = new CobrosPg(pool);
try {
  if (comando === "contrato") {
    const r = contratoSchema.safeParse({
      organizacionId: values.organizacion,
      plan: values.plan,
      inicio: values.inicio,
      fin: values.fin,
      cuotaUsd: values.cuota,
      contenedoresIncluidos: values.incluidos,
      precioContenedorUsd: values.precio,
      estado: values.estado,
      nota: values.nota,
    });
    if (!r.success) salir(`Contrato inválido:\n${errores(r.error.issues)}`);
    const id = await cobros.crearContrato(r.data, "script");
    if (!id) salir("Ya hay un contrato de esa organización en esas fechas.");
    console.log(`Contrato ${id} creado.`);
  } else if (comando === "ajuste") {
    const r = ajusteSchema.safeParse({ organizacionId: values.organizacion, montoUsd: values.monto, motivo: values.motivo });
    if (!r.success) salir(`Ajuste inválido:\n${errores(r.error.issues)}`);
    console.log(`Ajuste ${await cobros.registrarAjuste(r.data, "script")} registrado: ${usd(r.data.montoUsd)}.`);
  } else {
    const mes = values.mes ?? salir("Falta --mes AAAA-MM.");
    if (!/^\d{4}-(0[1-9]|1[0-2])$/.test(mes)) salir("--mes debe ser AAAA-MM, por ejemplo 2026-11.");
    const filas: string[][] = [];
    const organizaciones = await cobros.organizacionesDelMes(mes, values.organizacion);
    if (organizaciones.length === 0) console.log(`Nada que cobrar en ${mes}.`);
    for (const o of organizaciones) {
      const e = await cobros.estadoDeCuenta(o.id, mes);
      imprimir(o.nombre, e);
      filas.push(...csv(o.nombre, e));
    }
    if (values.csv) {
      const encabezado = ["Organización", "Mes", "Concepto", "Código", "Contenedor", "Fecha", "Kg", "En la bolsa", "Monto USD", "Verificador"];
      const texto = [encabezado, ...filas].map((f) => f.map((c) => `"${c.replaceAll('"', '""')}"`).join(",")).join("\r\n");
      // Con BOM: Excel abre bien las tildes.
      writeFileSync(values.csv, `﻿${texto}\r\n`);
      console.log(`\nCSV para Excel: ${values.csv}`);
    }
  }
} finally {
  await cerrar();
}

const enlace = (uid: string | null) => (uid ? `${VERIFICADOR}/v/${uid}` : "sin firmar (falta la referencia DDS)");
const dia = (d: Date) => new Date(d.getTime() - 6 * 3_600_000).toISOString().slice(0, 10);

function imprimir(nombre: string, e: EstadoDeCuenta) {
  console.log(`\n=== ${nombre} · ${e.mes} ===`);
  for (const r of e.contratos) {
    const c = r.contrato;
    console.log(
      `Contrato ${c.plan} (${c.estado}) ${c.inicio} a ${c.fin}: cuota ${usd(c.cuotaUsd)}, ` +
        `${c.contenedoresIncluidos} contenedores incluidos, adicional ${usd(c.precioContenedorUsd)}.`,
    );
    if (r.cuotaEsteMes) console.log(`  Cuota del período (por adelantado): ${usd(c.cuotaUsd)}`);
    console.log(`  Bolsa: ${r.usados} usados, quedan ${r.quedan}.`);
  }
  if (e.contratos.length === 0) console.log("Sin contrato vigente.");
  for (const c of e.contenedores) {
    const cobro = c.cobroUsd === null ? "SIN CONTRATO" : c.incluido ? "en la bolsa" : usd(c.cobroUsd);
    console.log(`  ${dia(c.fecha)}  ${c.codigo}  ${c.numeroContenedor ?? ""}  ${c.kg ?? 0} kg  ${cobro}  ${enlace(c.attestationUid)}`);
  }
  for (const a of e.ajustes) console.log(`  ${dia(a.fecha)}  Ajuste: ${a.motivo}  ${usd(a.montoUsd ?? 0)}`);
  if (e.sinContrato > 0) console.log(`  ¡${e.sinContrato} contenedores sin contrato! Acordar el precio y registrar un ajuste.`);
  console.log(`  TOTAL A FACTURAR: ${usd(e.totalUsd)}`);
}

function csv(nombre: string, e: EstadoDeCuenta): string[][] {
  const filas: string[][] = [];
  for (const r of e.contratos) {
    if (r.cuotaEsteMes) {
      filas.push([nombre, e.mes, `Cuota ${r.contrato.plan} ${r.contrato.inicio} a ${r.contrato.fin}`, "", "", r.contrato.inicio, "", "", r.contrato.cuotaUsd.toFixed(2), ""]);
    }
  }
  for (const c of e.contenedores) {
    filas.push([
      nombre, e.mes, "Contenedor cerrado", c.codigo ?? "", c.numeroContenedor ?? "", dia(c.fecha), String(c.kg ?? 0),
      c.incluido ? "sí" : "no", c.cobroUsd === null ? "SIN CONTRATO" : c.cobroUsd.toFixed(2), enlace(c.attestationUid),
    ]);
  }
  for (const a of e.ajustes) {
    filas.push([nombre, e.mes, `Ajuste: ${a.motivo}`, "", "", dia(a.fecha), "", "", (a.montoUsd ?? 0).toFixed(2), ""]);
  }
  filas.push([nombre, e.mes, "TOTAL", "", "", "", "", "", e.totalUsd.toFixed(2), ""]);
  return filas;
}
