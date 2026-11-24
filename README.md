# Smart Taller – app interna del personal del taller

App Flutter para el personal administrativo del taller **Smart Taller** (Huancayo): órdenes de trabajo,
inventario, citas, clientes y vehículos, cobros, facturación electrónica y reportes.

La **lógica** es la de la app de referencia *Pizzas Dorgis* (`C:\flutter\parcial`), llevada a la
temática automotriz con la misma arquitectura: módulos en español, un repositorio genérico, **modo
local** (funciona sin backend), montos en céntimos (`int`), `ChangeNotifier` + `StreamBuilder`. El
backend es **Supabase** (Postgres + Auth + Realtime). La interfaz usa el sistema Industry del handoff
(`Aplicación móvil tienda automotriz/`); el diseño y el contenido final quedan para otra etapa.

## Estructura

```
lib/
├── main.dart            # Supabase (o modo local), sesión guardada, español (Perú), guardias
├── core/
│   ├── services/        # supabase_servicio (RepositorioSupabase, haySupabase, rpc, errores),
│   │                    # conexion (+ comprobacion_*), sesion_service, entorno
│   ├── utils/           # formatos (céntimos, km, placa, fechas ISO), validadores (placa, DNI, RUC…)
│   └── widgets/         # mensajes (SnackBar, Deshacer), guarda_conexion
├── modules/
│   ├── catalogo/        # servicios (precio por tipo de vehículo), repuestos (stock), adicionales,
│   │                    # categorías, códigos promocionales, config del taller, recomendaciones, favoritos
│   ├── ordenes/         # borrador (cotizacion_service), orden_service, reglas_orden,
│   │                    # calculadora_precios, pago_service, mercado_pago_service
│   ├── clientes/  citas/  avisos/  reportes/
│   └── cuentas/         # login del personal, roles/permisos, cierre por inactividad (Guía 12)
├── screens/  widgets/  theme/  state/
supabase/
├── esquema.sql          # tablas, RLS por rol, funciones (crear_orden, cambiar_estado_orden…),
│                        # tiempo real y vistas para Power BI (esquema reportes)
├── claves.ejemplo.json  # copia como claves.json con la URL y la clave pública
└── pruebas/             # prueba el esquema en Postgres (PGlite) sin crear un proyecto
```

## De Pizzas Dorgis a Smart Taller

| Pizzas Dorgis | Smart Taller |
|---|---|
| Menú: categorías, pizzas con **tamaños**, extras, descuento, disponible/agotado | Catálogo: servicios con **precio y minutos por tipo de vehículo** (auto, SUV, minivan), adicionales, descuento, disponible; repuestos con stock y mínimo |
| `MenuService` (Firestore en tiempo real o menú local) | `CatalogoService` (Supabase en tiempo real o catálogo local; "Cargar datos de ejemplo" en Perfil) |
| Carrito: agrupa combinaciones, cantidad, deslizar + **Deshacer**, promo que se revalida, recojo/delivery, "volver a pedir" | Borrador de la orden (`CotizacionService`): lo mismo, más **tope de stock**, recálculo al cambiar el tipo de vehículo, servicio a domicilio, **repetir servicio** con precios de hoy y entrega sugerida por tiempo de bahía |
| `PedidoService.crearPedido`: recalcula precios, transacción con `counters/orders` → `PZ-####` | `OrdenService.crearOrden` + función SQL `crear_orden`: correlativo `OT-1043…`, montos, stock y código promocional validados **en el servidor** |
| Estados `pending → … → delivered` con `statusHistory` | Etapas Recepción → Diagnóstico → Repuestos → Reparación → Listo → Entregado (o Anulada); saltar etapas registra las intermedias y **quién** hizo cada paso |
| Panel: solo admin cambia estado | Roles: solo el **jefe de taller** marca "Listo"; entregar y anular, jefe o administración (en la app y en el SQL) |
| — | **Salida de almacén**: al llegar a Repuestos descuenta el stock en la misma transacción; anular lo devuelve; aviso de stock crítico |
| Pagos: efectivo, Yape/Plin con N.° de operación, tarjeta con Mercado Pago o demo | Igual; efectivo en caja queda pagado; solo administración aprueba/rechaza Yape/Plin (`verificar_pago`) |
| IGV incluido (informativo) | Comprobante **B001/F001** con correlativo (`emitir_comprobante`), op. gravada + IGV 18 %; boleta ≥ S/ 700 pide DNI; factura pide RUC válido (dígito verificador, también en SQL) |
| Mis pedidos y seguimiento en tiempo real | Órdenes con filtros y búsqueda, detalle en tiempo real; se agregan/quitan ítems mientras está abierta (`actualizar_lineas_orden`) |
| Perfil + direcciones | Clientes (DNI/RUC) + vehículos; la base no repite documento ni placa; historial por placa y **mantenimiento pendiente** por km |
| Notificaciones de cambio de estado | Avisos internos con contador de no leídos (`marcar_avisos_leidos`) |
| Dashboard admin (`stats_calculator`) | Reportes: periodos, vs. anterior, barras, por estado, ticket, tiempo medio vs. meta, más pedidos |
| "Tu menú" | Catálogo de servicios e Inventario, más ingreso de mercadería e inventario físico (`mover_stock_repuesto`) |
| Login del panel (`admins/{uid}`), "¿Olvidaste tu contraseña?" | Login del personal (tabla `personal` con `rol`), recuperación con **código** por correo dentro de la app |
| Guía 12, Guía 14, pantalla sin conexión, favoritos | Igual (cierre por inactividad, "También suelen pedir", sin conexión solo con Supabase, servicios favoritos) |

No se trajeron (son de la app de clientes): portada animada y onboarding, registro de clientes y Google
Sign-In, mapa/GPS y rutas de delivery, "agita tu celular" (Guía 13), foto de perfil (Guía 15), íconos
de lanzador y el panel web en Vercel.

## Supabase

Sin URL ni clave la app compila y trabaja **en modo local** (datos de ejemplo en memoria, login demo
con el rol elegido). Para conectarla:

1. **Proyecto:** en tu organización → *New project* → nombre `smart-taller`, guarda la contraseña de la
   base (la pide Power BI), región **South America (São Paulo)**.
2. **Esquema:** *SQL Editor* → pega todo `supabase/esquema.sql` → *Run* (una sola vez).
3. **Login:** *Authentication → Sign In / Providers* → deja **Email** activo y apaga *Allow new users to
   sign up* (las cuentas las creas tú). *Authentication → Users → Add user* por cada persona, con
   **Auto confirm user**.
4. **Roles:** en *SQL Editor*, una fila en `personal` por cuenta:

   ```sql
   insert into personal (id, nombre, rol)
   select id, 'Giancarlo Guerreros', 'administracion' from auth.users where email = 'correo@ejemplo.com';
   -- rol: 'jefe_taller', 'mecanico' o 'administracion'
   ```

5. **Recuperar contraseña con código:** *Authentication → Emails → Reset Password* → en el mensaje
   incluye el código `{{ .Token }}` (la app lo pide junto con la contraseña nueva).
6. **Claves:** *Project Settings → API Keys* → copia la **Project URL** y la clave **publishable** (o la
   *anon* antigua) en `supabase/claves.json` (copia de `claves.ejemplo.json`; no se sube a git).
   **Nunca** pongas la clave `service_role` en la app.
7. **Ejecutar:**

   ```
   flutter run --dart-define-from-file=supabase/claves.json
   ```

8. **Datos de ejemplo:** entra con una cuenta de administración → Más → Perfil → **Cargar datos de
   ejemplo** (catálogo, configuración del taller y clientes).

Tablas: `personal`, `categorias`, `servicios`, `adicionales`, `repuestos`, `codigos_promocionales`,
`config`, `contadores`, `clientes`, `citas`, `avisos`, `ordenes`. Las políticas RLS dejan leer solo al
personal activo; el catálogo y el stock los edita gestión (jefe de taller o administración); las
órdenes **solo** se crean y cambian con las funciones SQL, que vuelven a comprobar el rol; no se borran,
se anulan. El rol `anon` no ve nada.

**Power BI:** *Connect* (arriba en el panel) → cadena de conexión *Session pooler* → en Power BI
*Obtener datos → PostgreSQL* con ese host, base `postgres`, usuario `postgres.<ref>` y la contraseña
del paso 1. Usa las vistas del esquema `reportes` (`ordenes`, `orden_lineas`, `orden_historial`,
`comprobantes`, `vehiculos`).

**Mercado Pago:** `--dart-define=PAGOS_URL=https://tu-servidor` (el backend de la app de referencia,
adaptado para marcar `ordenes.estado_pago = 'pagado'` con la clave `service_role` en el servidor). Sin
eso, modo demo. El envío a SUNAT (OSE/PSE) también está en modo demo: el comprobante queda aceptado.

El plan gratuito pausa el proyecto tras 7 días sin uso (se reactiva desde el panel) y da 500 MB de base.

## Ejecutar y probar

```
flutter pub get
flutter run                                              # modo local
flutter run --dart-define-from-file=supabase/claves.json # con Supabase
flutter analyze
flutter test
```

`flutter test` cubre la calculadora, el borrador, formatos y validaciones, recomendaciones, la orden en
modo local (OT-1043, permisos por rol, salida y devolución de stock, cobro, Yape, boleta/factura,
entrega), reportes, citas, clientes, el cierre por inactividad, los flujos principales de la interfaz
y el **contrato con el SQL** (`test/contrato/orden_supabase.json` es el JSON real de las funciones).

Para probar el esquema sin crear un proyecto (Postgres real en WebAssembly):

```
cd supabase/pruebas
npm install
npm test
```

Respaldo de la versión anterior (solo interfaz): `respaldo_antes_de_logica.zip` (queda en la PC, no
se sube al repositorio).

## Versión web (PC) y publicación en Vercel

Es el mismo código compilado para el navegador. Desde 840 px de ancho la app muestra el menú a la
izquierda y el contenido centrado; en celular, la barra inferior. Los cambios se ven al instante en
la web y en el celular porque los dos escuchan Supabase en tiempo real.

Probar en la PC:

```
flutter run -d chrome --dart-define-from-file=supabase/claves.json
flutter build web --release --dart-define-from-file=supabase/claves.json   # queda en build/web
```

Publicar (una sola vez):

1. Sube este proyecto a un repositorio de GitHub (`supabase/claves.json` no se sube: está en
   `.gitignore`).
2. En [Vercel](https://vercel.com): *Add New → Project* → importa el repositorio. `vercel.json` ya
   indica cómo instalar Flutter 3.47.4, compilar (`scripts/vercel_compilar.sh`) y publicar `build/web`.
3. Antes del primer despliegue, en *Settings → Environment Variables* agrega `SUPABASE_URL` y
   `SUPABASE_KEY` (la clave **publicable**, `sb_publishable_...`; el script rechaza la secreta). Sin
   ellas la compilación se detiene en lugar de publicar la web en modo demo.
4. Cada `push` a `main` vuelve a publicar la web sola.
5. En Supabase, *Authentication → URL Configuration*, pon la dirección de Vercel como *Site URL*.
