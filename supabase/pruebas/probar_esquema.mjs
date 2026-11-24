// Prueba supabase/esquema.sql en PGlite (Postgres real en WASM) con stubs de Supabase.
// Uso (en esta carpeta): npm install  y luego  npm test
// Carga ../esquema.sql en PGlite (Postgres real en WebAssembly) con stubs de
// Supabase (auth.uid(), roles anon/authenticated, publicación de tiempo real) y
// prueba permisos, RLS, correlativos, stock y comprobantes. Además guarda el
// JSON de contrato que usa test/contrato_supabase_test.dart.
import { readFileSync } from 'node:fs';
import { PGlite } from '@electric-sql/pglite';

const rutaEsquema = new URL('../esquema.sql', import.meta.url);
const rutaContrato = new URL('../../test/contrato/orden_supabase.json', import.meta.url);
const db = new PGlite();

let fallos = 0;
const ok = (cond, msg) => {
  console.log(`${cond ? 'OK  ' : 'FALLA'} ${msg}`);
  if (!cond) fallos++;
};

async function como(uid, sql, params = []) {
  // Simula una petición de la app: rol authenticated + jwt con el uid.
  await db.exec(`reset role; select set_config('request.jwt.claim.sub', '${uid ?? ''}', false);`);
  await db.exec(uid ? 'set role authenticated' : 'set role anon');
  try {
    return await db.query(sql, params);
  } finally {
    await db.exec('reset role');
  }
}

async function falla(uid, sql, params, esperado, msg) {
  try {
    await como(uid, sql, params);
    ok(false, `${msg} (no falló)`);
  } catch (e) {
    ok(String(e.message).includes(esperado), `${msg} → ${e.message}`);
  }
}

// --- Stubs de lo que trae un proyecto de Supabase ---
await db.exec(`
  create role anon nologin;
  create role authenticated nologin;
  create schema auth;
  create table auth.users (id uuid primary key, email text);
  create function auth.uid() returns uuid language sql stable as $$
    select nullif(current_setting('request.jwt.claim.sub', true), '')::uuid
  $$;
  grant usage on schema auth to anon, authenticated;
  create publication supabase_realtime;
  grant usage on schema public to anon, authenticated;
  alter default privileges in schema public grant all on tables to anon, authenticated;
  alter default privileges in schema public grant all on functions to anon, authenticated;
`);

await db.exec(readFileSync(rutaEsquema, 'utf8'));
console.log('Esquema cargado sin errores');

const JEFE = '11111111-1111-1111-1111-111111111111';
const MEC = '22222222-2222-2222-2222-222222222222';
const ADM = '33333333-3333-3333-3333-333333333333';
const EXTRANO = '44444444-4444-4444-4444-444444444444';
await db.exec(`
  insert into auth.users values ('${JEFE}', 'jefe@t.pe'), ('${MEC}', 'mec@t.pe'), ('${ADM}', 'adm@t.pe'), ('${EXTRANO}', 'x@t.pe');
  insert into personal (id, nombre, rol) values
    ('${JEFE}', 'Jefe', 'jefe_taller'), ('${MEC}', 'Mecánico', 'mecanico'), ('${ADM}', 'Admin', 'administracion');
`);

// Catálogo de ejemplo como lo sube la app (gestión).
await como(JEFE, `insert into repuestos (codigo, nombre, precio_centimos, stock, minimo) values
  ('LUB-1040', 'Aceite 10W-40 sintético 1L', 3700, 48, 20),
  ('BAT-7500', 'Batería 12V 75Ah', 35000, 11, 6)`);
await como(ADM, `insert into config (id, datos) values ('taller', '{"serie_boleta":"B001","serie_factura":"F001"}')`);
await como(ADM, `insert into codigos_promocionales (codigo, tipo, valor, minimo_subtotal_centimos)
  values ('AUTOSIGLO10', 'porcentaje', 10, 15000)`);
await falla(MEC, `insert into servicios (nombre) values ('x')`, [], 'row-level security', 'el mecánico no edita el catálogo');

// --- Crear orden ---
const lineas = [
  { tipo: 'repuesto', ref_id: 'LUB-1040', nombre: 'Aceite', variante: '', adicionales: [], precio_unitario_centimos: 3700, cantidad: 4, total_centimos: 14800 },
  { tipo: 'servicio', ref_id: 'cambio-aceite', nombre: 'Cambio de aceite', variante: 'auto', adicionales: [], precio_unitario_centimos: 4000, cantidad: 1, total_centimos: 4000 },
];
const base = {
  cliente_nombre: 'Rosa Paucar', telefono: '964112480', placa: 'V2K-841', vehiculo: 'Toyota Yaris 2019',
  tipo_vehiculo: 'auto', km: 80000, motivo: 'Mantenimiento', lineas,
  subtotal_centimos: 18800, descuento_centimos: 1880, recargo_centimos: 0, total_centimos: 16920,
  codigo_promo: 'AUTOSIGLO10', creado_por_nombre: 'Mecánico',
};
const r1 = await como(MEC, 'select crear_orden($1) as o', [base]);
const o1 = r1.rows[0].o;
ok(o1.codigo === 'OT-1043', `crear_orden → ${o1.codigo}, estado ${o1.estado}, pago ${o1.estado_pago}`);
ok((await db.query(`select usados from codigos_promocionales`)).rows[0].usados === 1, 'suma un uso al código');
await falla(MEC, 'select crear_orden($1)', [{ ...base, total_centimos: 1 }], 'no cuadran', 'rechaza montos que no cuadran');
await falla(MEC, 'select crear_orden($1)', [{ ...base, descuento_centimos: 5000, total_centimos: 13800 }], 'no corresponde', 'rechaza un descuento inventado');
await falla(EXTRANO, 'select crear_orden($1)', [base], 'Solo el personal', 'una cuenta sin fila en personal no crea órdenes');
await falla(null, 'select crear_orden($1)', [base], 'permission denied', 'anon no puede llamar a las funciones');
await falla(MEC, `insert into ordenes (codigo, cliente_nombre, placa, subtotal_centimos, total_centimos) values ('OT-9', 'x', 'AAA-111', 0, 0)`,
  [], 'row-level security', 'nadie inserta órdenes directo');
await falla(null, 'select count(*) from ordenes', [], 'permission denied', 'anon no puede leer órdenes');
ok((await como(MEC, 'select count(*)::int as n from ordenes')).rows[0].n === 1, 'el personal sí las ve');

// --- Etapas, stock y permisos ---
const cambiar = (uid, id, estado, nota = '') =>
  como(uid, 'select cambiar_estado_orden($1, $2, $3, $4) as r', [id, estado, nota, 'X']).then((r) => r.rows[0].r);
let r = await cambiar(MEC, o1.id, 'repuestos');
ok(r.orden.historial.map((h) => h.estado).join(',') === 'recepcion,diagnostico,repuestos', `saltar etapas registra las intermedias (${r.orden.historial.length})`);
ok((await db.query(`select stock from repuestos where codigo='LUB-1040'`)).rows[0].stock === 44, 'repuestos descuenta stock 48 → 44');
await cambiar(MEC, o1.id, 'reparacion');

// --- Diagnóstico escrito ---
const diag = (await como(MEC, 'select registrar_diagnostico($1, $2) as o', [o1.id, '  Pastillas gastadas al 80 %  '])).rows[0].o;
ok(diag.diagnostico === 'Pastillas gastadas al 80 %', 'el mecánico registra el diagnóstico (sin espacios de más)');
await falla(MEC, 'select registrar_diagnostico($1, $2)', [o1.id, 'ok'], 'mínimo 5', 'el diagnóstico no puede quedar casi vacío');
await falla(MEC, 'select registrar_diagnostico($1, $2)', [o1.id, 'x'.repeat(1001)], 'muy largo', 'máximo 1000 caracteres');
await falla(EXTRANO, 'select registrar_diagnostico($1, $2)', [o1.id, 'Algo raro'], 'Solo el personal', 'una cuenta ajena no escribe diagnósticos');
await falla(null, 'select registrar_diagnostico($1, $2)', [o1.id, 'Algo raro'], 'permission denied', 'anon no escribe diagnósticos');
ok((await como(MEC, `update ordenes set diagnostico = 'x' where id = '${o1.id}'`)).affectedRows === 0,
  'nadie cambia el diagnóstico sin la función');

await falla(MEC, 'select cambiar_estado_orden($1, $2)', [o1.id, 'listo'], 'Solo el jefe', 'el mecánico no marca listo');
r = await cambiar(JEFE, o1.id, 'listo');
ok(r.orden.estado === 'listo', 'el jefe marca listo');
await falla(ADM, 'select cambiar_estado_orden($1, $2)', [o1.id, 'entregado'], 'Registra el cobro', 'no se entrega sin cobro');

// --- Cobro, verificación y comprobante ---
await falla(MEC, `select registrar_cobro($1, 'efectivo', 'pagado')`, [o1.id], 'Solo el jefe', 'el mecánico no cobra');
await falla(JEFE, `select registrar_cobro($1, 'yape', 'verificando', '12')`, [o1.id], 'no válido', 'Yape exige N.° de operación');
let c = (await como(JEFE, `select registrar_cobro($1, 'yape', 'verificando', '123456') as o`, [o1.id])).rows[0].o;
ok(c.estado_pago === 'verificando', 'Yape queda por verificar');
await falla(JEFE, 'select verificar_pago($1, true)', [o1.id], 'Solo administración', 'solo administración verifica');
c = (await como(ADM, 'select verificar_pago($1, true) as o', [o1.id])).rows[0].o;
ok(c.estado_pago === 'pagado' && c.pagado_en, 'administración aprueba el pago');
c = (await como(ADM, `select emitir_comprobante($1, 'boleta') as o`, [o1.id])).rows[0].o;
ok(c.comprobante.codigo === 'B001-00248' && c.comprobante.igv_centimos + c.comprobante.op_gravada_centimos === 16920,
  `boleta ${c.comprobante.codigo}, IGV ${c.comprobante.igv_centimos}`);
await falla(ADM, `select emitir_comprobante($1, 'boleta')`, [o1.id], 'ya tiene el comprobante', 'no repite el comprobante');
r = await cambiar(ADM, o1.id, 'entregado');
ok(r.orden.estado === 'entregado', 'se entrega pagada');
await falla(MEC, 'select registrar_diagnostico($1, $2)', [o1.id, 'Otro diagnóstico'], 'ya no se puede editar',
  'una orden entregada no cambia su diagnóstico');
// Contrato con la app: el JSON real que devuelven las funciones.
{
  const { writeFileSync } = await import('node:fs');
  writeFileSync(rutaContrato, JSON.stringify({ orden: r.orden, crear: o1 }, null, 2));
  console.log("JSON de contrato actualizado: test/contrato/orden_supabase.json");
}

// --- Anular devuelve stock; boleta ≥ S/ 700 pide DNI; factura con RUC ---
const bateria = [{ tipo: 'repuesto', ref_id: 'BAT-7500', nombre: 'Batería', variante: '', adicionales: [], precio_unitario_centimos: 35000, cantidad: 2, total_centimos: 70000 }];
const o2 = (await como(JEFE, 'select crear_orden($1) as o', [{ ...base, lineas: bateria, subtotal_centimos: 70000, descuento_centimos: 0, total_centimos: 70000, codigo_promo: null }])).rows[0].o;
ok(o2.codigo === 'OT-1044', 'el correlativo sigue: OT-1044');
await cambiar(JEFE, o2.id, 'repuestos');
ok((await db.query(`select stock from repuestos where codigo='BAT-7500'`)).rows[0].stock === 9, 'batería 11 → 9');
// Agregar una batería más con el stock ya descontado mueve la diferencia.
const tres = [{ ...bateria[0], cantidad: 3, total_centimos: 105000 }];
r = (await como(MEC, 'select actualizar_lineas_orden($1, $2, 105000, 0, 105000) as r', [o2.id, JSON.stringify(tres)])).rows[0].r;
ok(r.orden.total_centimos === 105000 && (await db.query(`select stock from repuestos where codigo='BAT-7500'`)).rows[0].stock === 8,
  'actualizar_lineas mueve la diferencia (9 → 8)');
await falla(MEC, 'select cambiar_estado_orden($1, $2, $3)', [o2.id, 'cancelado', 'x'], 'Solo el jefe', 'el mecánico no anula');
r = await cambiar(JEFE, o2.id, 'cancelado', 'El cliente desistió');
ok(r.orden.estado === 'cancelado' && (await db.query(`select stock from repuestos where codigo='BAT-7500'`)).rows[0].stock === 11,
  'anular devuelve el stock (8 → 11)');

const o3 = (await como(JEFE, 'select crear_orden($1) as o', [{ ...base, lineas: bateria, subtotal_centimos: 70000, descuento_centimos: 0, total_centimos: 70000, codigo_promo: null }])).rows[0].o;
for (const e of ['repuestos', 'listo']) await cambiar(JEFE, o3.id, e);
await como(JEFE, `select registrar_cobro($1, 'efectivo', 'pagado')`, [o3.id]);
await falla(JEFE, `select emitir_comprobante($1, 'boleta')`, [o3.id], 'requieren el DNI', 'boleta ≥ S/ 700 pide DNI');
await falla(JEFE, `select emitir_comprobante($1, 'factura', '20486112095', 'X SAC')`, [o3.id], 'RUC no es válido', 'factura valida el RUC');
c = (await como(JEFE, `select emitir_comprobante($1, 'factura', '20486112094', 'Transportes Mantaro S.A.C.') as o`, [o3.id])).rows[0].o;
ok(c.comprobante.codigo === 'F001-00001', `factura ${c.comprobante.codigo}`);
// Stock crítico: sacar 30 aceites deja 14 < 20.
const aceite = [{ ...lineas[0], cantidad: 30, total_centimos: 111000 }];
const o4 = (await como(MEC, 'select crear_orden($1) as o', [{ ...base, lineas: aceite, subtotal_centimos: 111000, descuento_centimos: 0, total_centimos: 111000, codigo_promo: null }])).rows[0].o;
r = await cambiar(MEC, o4.id, 'repuestos');
ok(r.criticos.length === 1 && r.criticos[0].stock === 14, `avisa stock crítico (${JSON.stringify(r.criticos)})`);
const o5 = (await como(MEC, 'select crear_orden($1) as o', [{ ...base, lineas: [{ ...lineas[0], cantidad: 14, total_centimos: 51800 }], subtotal_centimos: 51800, descuento_centimos: 0, total_centimos: 51800, codigo_promo: null }])).rows[0].o;
await como(ADM, `select mover_stock_repuesto('LUB-1040', null, 5)`);
await falla(MEC, 'select cambiar_estado_orden($1, $2)', [o5.id, 'repuestos'], 'Stock insuficiente', 'frena si no alcanza el stock');
await falla(MEC, `select mover_stock_repuesto('LUB-1040', 10)`, [], 'Solo el jefe', 'el mecánico no hace ingresos');
await como(JEFE, `select mover_stock_repuesto('LUB-1040', 10)`);
ok((await db.query(`select stock from repuestos where codigo='LUB-1040'`)).rows[0].stock === 15, 'ingreso de mercadería 5 → 15');
const sinTocar = await como(MEC, `update repuestos set stock = 0 where codigo = 'LUB-1040'`);
ok(sinTocar.affectedRows === 0, 'el mecánico no cambia stock a mano');

// --- Clientes, personal y avisos ---
await como(MEC, `insert into clientes (nombre, tipo_documento, numero_documento, telefono, vehiculos)
  values ('Rosa', 'DNI', '45120884', '964112480', '[{"placa":"V2K-841","marca":"Toyota","modelo":"Yaris","anio":2019,"tipo":"auto","km":78420}]')`);
ok((await db.query('select placas from clientes')).rows[0].placas[0] === 'V2K-841', 'el trigger llena placas');
await falla(MEC, `insert into clientes (nombre, tipo_documento, numero_documento, vehiculos)
  values ('Otro', 'DNI', '40000001', '[{"placa":"V2K-841"}]')`, [], 'ya está registrada', 'no repite placa');
await falla(MEC, `insert into clientes (nombre, tipo_documento, numero_documento) values ('Otro', 'DNI', '45120884')`, [], 'duplicate key', 'no repite documento');
ok((await como(MEC, `delete from clientes`)).affectedRows === 0, 'el mecánico no borra clientes');
await falla(MEC, `update personal set rol = 'administracion' where id = '${MEC}'`, [], 'permission denied', 'nadie se cambia el rol');
ok((await como(MEC, `update personal set favoritos = '{cambio-aceite}' where id = '${MEC}'`)).affectedRows === 1, 'cada uno guarda sus favoritos');
ok((await como(MEC, `update personal set favoritos = '{}' where id = '${JEFE}'`)).affectedRows === 0, 'no edita los favoritos de otro');
await como(MEC, `insert into avisos (tipo, texto) values ('orden', 'hola')`);
await como(MEC, 'select marcar_avisos_leidos()');
ok((await db.query('select leido_por from avisos')).rows[0].leido_por[0] === MEC, 'marcar_avisos_leidos');

// --- Vistas para Power BI ---
const vistas = await db.query(`select (select count(*)::int from reportes.orden_lineas) as l,
  (select count(*)::int from reportes.comprobantes) as c, (select count(*)::int from reportes.orden_historial) as h,
  (select count(*)::int from reportes.vehiculos) as v, (select sum(total)::float from reportes.ordenes) as t`);
ok(vistas.rows[0].c === 2 && vistas.rows[0].l > 0 && vistas.rows[0].v === 1, `vistas reportes: ${JSON.stringify(vistas.rows[0])}`);

console.log(fallos === 0 ? '\nTODO OK' : `\n${fallos} FALLAS`);
process.exit(fallos === 0 ? 0 : 1);
