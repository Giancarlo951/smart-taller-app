-- =============================================================================
-- Smart Taller — esquema de Supabase (Postgres)
--
-- Pégalo completo en Supabase → SQL Editor → Run (una sola vez, en un
-- proyecto nuevo). Crea las tablas, las políticas RLS por rol, las funciones
-- que hacen en el servidor lo que antes hacían las transacciones de
-- Firestore (código OT-####, salida de stock, cobro, comprobantes), el tiempo
-- real y las vistas para Power BI (esquema `reportes`).
--
-- Solo entra el personal: quien tenga una fila en `personal` con su rol
-- (jefe_taller, mecanico o administracion). Ver README.md.
-- =============================================================================

-- ---------------------------------------------------------------- Personal

create table public.personal (
  id uuid primary key references auth.users (id) on delete cascade,
  nombre text not null default '',
  rol text not null check (rol in ('jefe_taller', 'mecanico', 'administracion')),
  taller text not null default 'Auto Siglo · Huancayo',
  activo boolean not null default true,
  favoritos text[] not null default '{}',
  -- Borrador de la orden que se está armando (líneas en JSON).
  borrador jsonb not null default '[]',
  created_at timestamptz not null default now()
);

-- Rol del usuario con sesión (null si no es personal activo).
create or replace function public.rol_actual()
returns text
language sql stable security definer set search_path = public
as $$
  select rol from public.personal where id = auth.uid() and activo
$$;

create or replace function public.es_personal()
returns boolean
language sql stable set search_path = public
as $$
  select public.rol_actual() is not null
$$;

-- Jefe de taller o administración.
create or replace function public.es_gestion()
returns boolean
language sql stable set search_path = public
as $$
  select coalesce(public.rol_actual() in ('jefe_taller', 'administracion'), false)
$$;

-- ---------------------------------------------------------------- Catálogo

create table public.categorias (
  id text primary key,
  nombre text not null,
  tipo text not null default 'servicio' check (tipo in ('servicio', 'repuesto')),
  orden int not null default 0,
  activa boolean not null default true
);

create table public.servicios (
  id text primary key default gen_random_uuid()::text,
  nombre text not null,
  subtitulo text not null default '',
  descripcion text not null default '',
  categoria_ids text[] not null default '{}',
  -- {"auto": {"precio_centimos": 4000, "minutos": 45}, "suv": {...}}
  precios jsonb not null default '{}',
  descuento_porcentaje int check (descuento_porcentaje between 1 and 99),
  disponible boolean not null default true,
  popular boolean not null default false,
  adicional_ids text[] not null default '{}',
  garantia_dias int not null default 0,
  intervalo_km int not null default 0,
  created_at timestamptz not null default now()
);

create table public.adicionales (
  id text primary key,
  nombre text not null,
  precio_centimos int not null check (precio_centimos >= 0),
  disponible boolean not null default true
);

create table public.repuestos (
  codigo text primary key,
  nombre text not null,
  categoria_id text not null default '',
  marca text not null default '',
  precio_centimos int not null check (precio_centimos > 0),
  stock int not null default 0 check (stock >= 0),
  minimo int not null default 0 check (minimo >= 0),
  activo boolean not null default true,
  updated_at timestamptz not null default now()
);

create table public.codigos_promocionales (
  codigo text primary key,
  tipo text not null check (tipo in ('porcentaje', 'fijo')),
  valor int not null check (valor > 0),
  minimo_subtotal_centimos int not null default 0,
  activo boolean not null default true,
  vence_en timestamptz,
  max_usos int not null default 0,
  usados int not null default 0,
  descripcion text not null default ''
);

-- Fila 'taller' con los datos del local (nombre, horario, series...).
create table public.config (
  id text primary key,
  datos jsonb not null default '{}'
);

-- Correlativos: ordenes (OT-####), boletas (B001) y facturas (F001).
create table public.contadores (
  id text primary key,
  ultimo int not null
);

insert into public.contadores (id, ultimo) values
  ('ordenes', 1042),  -- la primera orden será OT-1043
  ('boletas', 247),   -- la primera boleta será B001-00248
  ('facturas', 0);

-- ------------------------------------------------- Clientes, citas y avisos

create table public.clientes (
  id uuid primary key default gen_random_uuid(),
  nombre text not null,
  tipo_documento text not null check (tipo_documento in ('DNI', 'RUC')),
  numero_documento text not null unique,
  telefono text not null default '',
  correo text not null default '',
  -- [{"placa": "V2K-841", "marca": "Toyota", "modelo": "Yaris", "anio": 2019,
  --   "tipo": "auto", "km": 78420, "ultimo_servicio": "2026-07-14T..."}]
  vehiculos jsonb not null default '[]',
  -- Se llena solo (trigger) para buscar y para no repetir placas.
  placas text[] not null default '{}',
  servicios int not null default 0,
  created_at timestamptz not null default now()
);

create index clientes_placas_idx on public.clientes using gin (placas);

-- Una placa pertenece a un solo cliente.
create or replace function public._clientes_placas()
returns trigger
language plpgsql set search_path = public
as $$
declare
  v_duplicada text;
begin
  new.placas := coalesce(
    (select array_agg(upper(v ->> 'placa')) from jsonb_array_elements(new.vehiculos) v),
    '{}'
  );
  select p into v_duplicada
  from public.clientes c, unnest(c.placas) p
  where c.id <> new.id and p = any (new.placas)
  limit 1;
  if v_duplicada is not null then
    raise exception 'La placa % ya está registrada a otro cliente', v_duplicada;
  end if;
  return new;
end
$$;

create trigger clientes_placas
before insert or update on public.clientes
for each row execute function public._clientes_placas();

create table public.citas (
  id uuid primary key default gen_random_uuid(),
  fecha timestamptz not null,
  servicio text not null,
  placa text not null,
  cliente text not null,
  telefono text not null default '',
  estado text not null default 'confirmada'
    check (estado in ('confirmada', 'enTaller', 'atendida', 'cancelada', 'noAsistio')),
  orden_id uuid,
  nota text not null default '',
  created_at timestamptz not null default now()
);

create index citas_fecha_idx on public.citas (fecha);

create table public.avisos (
  id uuid primary key default gen_random_uuid(),
  tipo text not null,
  texto text not null,
  orden_id uuid,
  -- uid de quienes ya lo vieron ('*' = todos).
  leido_por text[] not null default '{}',
  created_at timestamptz not null default now()
);

create index avisos_fecha_idx on public.avisos (created_at desc);

-- ------------------------------------------------------------------ Órdenes

create table public.ordenes (
  id uuid primary key default gen_random_uuid(),
  codigo text not null unique,
  cliente_id text not null default '',
  cliente_nombre text not null,
  documento_cliente text not null default '',
  telefono text not null default '',
  placa text not null,
  vehiculo text not null default '',
  tipo_vehiculo text not null default 'auto',
  km int not null default 0,
  motivo text not null default '',
  -- Lo que encontró el mecánico al revisar el vehículo (registrar_diagnostico).
  diagnostico text not null default '' check (length(diagnostico) <= 1000),
  mecanico text not null default '',
  entrega_estimada timestamptz,
  -- [{"tipo": "servicio"|"repuesto", "ref_id", "nombre", "variante",
  --   "adicionales": [...], "precio_unitario_centimos", "cantidad", "total_centimos"}]
  lineas jsonb not null default '[]',
  subtotal_centimos int not null check (subtotal_centimos >= 0),
  descuento_centimos int not null default 0 check (descuento_centimos >= 0),
  recargo_centimos int not null default 0 check (recargo_centimos >= 0),
  total_centimos int not null check (total_centimos >= 0),
  moneda text not null default 'PEN',
  codigo_promo text,
  a_domicilio boolean not null default false,
  metodo_pago text check (metodo_pago in ('efectivo', 'yape', 'plin', 'tarjeta')),
  estado_pago text not null default 'por_cobrar'
    check (estado_pago in ('por_cobrar', 'verificando', 'pagado', 'rechazado')),
  referencia_pago text,
  pagado_en timestamptz,
  estado text not null default 'recepcion'
    check (estado in ('recepcion', 'diagnostico', 'repuestos', 'reparacion', 'listo', 'entregado', 'cancelado')),
  -- [{"estado", "fecha", "por", "nota"}]
  historial jsonb not null default '[]',
  stock_descontado boolean not null default false,
  comprobante jsonb,
  creado_por uuid,
  creado_por_nombre text not null default '',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (total_centimos = subtotal_centimos - descuento_centimos + recargo_centimos)
);

create index ordenes_created_idx on public.ordenes (created_at desc);
create index ordenes_estado_idx on public.ordenes (estado);
create index ordenes_placa_idx on public.ordenes (placa);

-- ===================================================== Funciones internas

-- Repuestos que usa una lista de líneas: código → unidades.
create or replace function public._repuestos_de(p_lineas jsonb)
returns table (codigo text, cantidad int)
language sql immutable
as $$
  select l ->> 'ref_id', sum((l ->> 'cantidad')::int)::int
  from jsonb_array_elements(coalesce(p_lineas, '[]'::jsonb)) l
  where l ->> 'tipo' = 'repuesto'
  group by l ->> 'ref_id'
$$;

-- Mueve stock ({"BAT-7500": -1}). Falla si algo quedaría negativo.
-- Devuelve los repuestos que acaban de quedar en stock crítico.
create or replace function public._mover_stock(p_delta jsonb)
returns jsonb
language plpgsql security definer set search_path = public
as $$
declare
  r record;
  v_rep public.repuestos;
  v_faltan text[] := '{}';
  v_criticos jsonb := '[]';
begin
  for r in
    select key as cod, value::int as delta
    from jsonb_each_text(coalesce(p_delta, '{}'::jsonb))
    where value::int <> 0
    order by key
  loop
    select * into v_rep from public.repuestos where codigo = r.cod for update;
    if not found then
      raise exception 'El repuesto % ya no existe', r.cod;
    end if;
    if v_rep.stock + r.delta < 0 then
      v_faltan := v_faltan || format('%s: hay %s, se necesitan %s', v_rep.nombre, v_rep.stock, -r.delta);
    end if;
  end loop;
  if coalesce(array_length(v_faltan, 1), 0) > 0 then
    raise exception 'Stock insuficiente. %', array_to_string(v_faltan, '; ');
  end if;

  for r in
    select key as cod, value::int as delta
    from jsonb_each_text(coalesce(p_delta, '{}'::jsonb))
    where value::int <> 0
    order by key
  loop
    select * into v_rep from public.repuestos where codigo = r.cod;
    update public.repuestos
      set stock = stock + r.delta, updated_at = now()
      where codigo = r.cod;
    if v_rep.stock >= v_rep.minimo and v_rep.stock + r.delta < v_rep.minimo then
      v_criticos := v_criticos || jsonb_build_object(
        'codigo', v_rep.codigo,
        'nombre', v_rep.nombre,
        'stock', v_rep.stock + r.delta,
        'minimo', v_rep.minimo
      );
    end if;
  end loop;
  return v_criticos;
end
$$;

-- Dígito verificador del RUC (SUNAT, módulo 11).
create or replace function public._ruc_valido(p text)
returns boolean
language plpgsql immutable
as $$
declare
  f int[] := array[5, 4, 3, 2, 7, 6, 5, 4, 3, 2];
  s int := 0;
  d int;
begin
  if p is null or p !~ '^(10|15|17|20)\d{9}$' then
    return false;
  end if;
  for i in 1..10 loop
    s := s + substr(p, i, 1)::int * f[i];
  end loop;
  d := 11 - (s % 11);
  if d = 10 then d := 0; elsif d = 11 then d := 1; end if;
  return d = substr(p, 11, 1)::int;
end
$$;

-- Descuento que corresponde al código con ese subtotal (0 si no aplica).
create or replace function public._descuento_promo(p_promo public.codigos_promocionales, p_subtotal int)
returns int
language sql immutable
as $$
  select case
    when p_subtotal < p_promo.minimo_subtotal_centimos then 0
    when p_promo.tipo = 'porcentaje' then least(round(p_subtotal * p_promo.valor / 100.0)::int, p_subtotal)
    else least(p_promo.valor, p_subtotal)
  end
$$;

create or replace function public._suma_lineas(p_lineas jsonb)
returns int
language sql immutable
as $$
  select coalesce(sum((l ->> 'precio_unitario_centimos')::int * (l ->> 'cantidad')::int), 0)::int
  from jsonb_array_elements(coalesce(p_lineas, '[]'::jsonb)) l
$$;

-- ============================================== Funciones de la app (RPC)

-- Crea la orden con el correlativo OT-#### en la misma transacción (antes:
-- runTransaction con counters/orders). Valida montos, stock disponible y el
-- código promocional, y suma su uso.
create or replace function public.crear_orden(p jsonb)
returns jsonb
language plpgsql security definer set search_path = public
as $$
declare
  v_rol text := public.rol_actual();
  v_lineas jsonb := coalesce(p -> 'lineas', '[]'::jsonb);
  v_subtotal int := coalesce((p ->> 'subtotal_centimos')::int, 0);
  v_descuento int := coalesce((p ->> 'descuento_centimos')::int, 0);
  v_recargo int := coalesce((p ->> 'recargo_centimos')::int, 0);
  v_total int := coalesce((p ->> 'total_centimos')::int, 0);
  v_promo public.codigos_promocionales;
  v_numero int;
  v_orden public.ordenes;
  r record;
begin
  if v_rol is null then
    raise exception 'Solo el personal del taller registra órdenes';
  end if;
  if jsonb_array_length(v_lineas) = 0 and coalesce(trim(p ->> 'motivo'), '') = '' then
    raise exception 'Agrega un servicio o describe el motivo de ingreso';
  end if;
  if coalesce(p ->> 'placa', '') !~ '^[A-Z0-9]{3}-\d{3}$' then
    raise exception 'La placa debe tener el formato ABC-123';
  end if;
  if public._suma_lineas(v_lineas) <> v_subtotal
     or v_total <> v_subtotal - v_descuento + v_recargo
     or v_descuento < 0 or v_recargo < 0 or v_descuento > v_subtotal then
    raise exception 'Los montos de la orden no cuadran';
  end if;

  for r in select * from public._repuestos_de(v_lineas) loop
    if not exists (
      select 1 from public.repuestos
      where codigo = r.codigo and activo and stock >= r.cantidad
    ) then
      raise exception 'No hay stock suficiente de %', r.codigo;
    end if;
  end loop;

  if nullif(p ->> 'codigo_promo', '') is not null then
    select * into v_promo from public.codigos_promocionales
      where codigo = p ->> 'codigo_promo' for update;
    if not found or not v_promo.activo then
      raise exception 'El código % no está activo', p ->> 'codigo_promo';
    end if;
    if v_promo.vence_en is not null and now() > v_promo.vence_en then
      raise exception 'El código % ya venció', v_promo.codigo;
    end if;
    if v_promo.max_usos > 0 and v_promo.usados >= v_promo.max_usos then
      raise exception 'El código % alcanzó su límite de usos', v_promo.codigo;
    end if;
    if public._descuento_promo(v_promo, v_subtotal) <> v_descuento then
      raise exception 'El descuento no corresponde al código %', v_promo.codigo;
    end if;
    update public.codigos_promocionales set usados = usados + 1 where codigo = v_promo.codigo;
  elsif v_descuento > 0 then
    raise exception 'Hay un descuento sin código promocional';
  end if;

  update public.contadores set ultimo = ultimo + 1 where id = 'ordenes' returning ultimo into v_numero;
  if v_numero is null then
    insert into public.contadores (id, ultimo) values ('ordenes', 1043) returning ultimo into v_numero;
  end if;

  insert into public.ordenes (
    codigo, cliente_id, cliente_nombre, documento_cliente, telefono, placa,
    vehiculo, tipo_vehiculo, km, motivo, mecanico, entrega_estimada, lineas,
    subtotal_centimos, descuento_centimos, recargo_centimos, total_centimos,
    codigo_promo, a_domicilio, estado, estado_pago, historial,
    creado_por, creado_por_nombre
  ) values (
    'OT-' || v_numero,
    coalesce(p ->> 'cliente_id', ''),
    p ->> 'cliente_nombre',
    coalesce(p ->> 'documento_cliente', ''),
    coalesce(p ->> 'telefono', ''),
    p ->> 'placa',
    coalesce(p ->> 'vehiculo', ''),
    coalesce(p ->> 'tipo_vehiculo', 'auto'),
    coalesce((p ->> 'km')::int, 0),
    coalesce(p ->> 'motivo', ''),
    coalesce(p ->> 'mecanico', ''),
    (p ->> 'entrega_estimada')::timestamptz,
    v_lineas,
    v_subtotal, v_descuento, v_recargo, v_total,
    v_promo.codigo,
    coalesce((p ->> 'a_domicilio')::boolean, false),
    'recepcion', 'por_cobrar',
    jsonb_build_array(jsonb_build_object(
      'estado', 'recepcion', 'fecha', now(),
      'por', coalesce(p ->> 'creado_por_nombre', ''), 'nota', ''
    )),
    auth.uid(),
    coalesce(p ->> 'creado_por_nombre', '')
  )
  returning * into v_orden;

  -- La orden ya se creó: se vacía el borrador.
  update public.personal set borrador = '[]' where id = auth.uid();
  return to_jsonb(v_orden);
end
$$;

-- Registrar avance, entregar o anular. Solo el jefe de taller marca "listo";
-- entregar (con cobro) y anular son de gestión. Al llegar a "repuestos" sale
-- el stock; al anular vuelve. Saltar etapas registra las intermedias.
create or replace function public.cambiar_estado_orden(
  p_orden uuid,
  p_estado text,
  p_nota text default '',
  p_por text default ''
)
returns jsonb
language plpgsql security definer set search_path = public
as $$
declare
  v_rol text := public.rol_actual();
  v_flujo text[] := array['recepcion', 'diagnostico', 'repuestos', 'reparacion', 'listo', 'entregado'];
  v_o public.ordenes;
  v_desde int;
  v_hasta int;
  v_pasos text[];
  v_delta jsonb := '{}'::jsonb;
  v_criticos jsonb := '[]'::jsonb;
  v_historial jsonb;
  v_descontado boolean;
begin
  if v_rol is null then
    raise exception 'Solo el personal del taller cambia órdenes';
  end if;
  select * into v_o from public.ordenes where id = p_orden for update;
  if not found then
    raise exception 'La orden ya no existe';
  end if;
  if v_o.estado in ('entregado', 'cancelado') then
    raise exception 'La orden % ya está cerrada', v_o.codigo;
  end if;

  if p_estado = 'cancelado' then
    if v_rol not in ('jefe_taller', 'administracion') then
      raise exception 'Solo el jefe de taller o administración pueden anular una orden';
    end if;
    if v_o.estado_pago = 'pagado' or v_o.comprobante is not null then
      raise exception 'La orden ya tiene un cobro registrado: emite una nota de crédito';
    end if;
    v_pasos := array['cancelado'];
    if v_o.stock_descontado then
      select coalesce(jsonb_object_agg(codigo, cantidad), '{}'::jsonb)
        into v_delta from public._repuestos_de(v_o.lineas);
    end if;
    v_descontado := false;
  else
    v_desde := array_position(v_flujo, v_o.estado);
    v_hasta := array_position(v_flujo, p_estado);
    if v_hasta is null then
      raise exception 'Estado no válido: %', p_estado;
    end if;
    if v_hasta <= v_desde then
      raise exception 'La orden ya pasó por %', p_estado;
    end if;
    if p_estado = 'entregado' then
      if v_o.estado <> 'listo' then
        raise exception 'El vehículo se entrega cuando la orden está lista';
      end if;
      if v_rol not in ('jefe_taller', 'administracion') then
        raise exception 'Solo el jefe de taller o administración entregan el vehículo';
      end if;
      if v_o.estado_pago <> 'pagado' then
        raise exception 'Registra el cobro antes de entregar el vehículo';
      end if;
    end if;
    if p_estado = 'listo' and v_rol <> 'jefe_taller' then
      raise exception 'Solo el jefe de taller puede marcar la orden como lista para entrega';
    end if;
    if jsonb_array_length(v_o.lineas) = 0 and v_hasta >= 4 then
      raise exception 'Agrega los servicios y repuestos antes de pasar a reparación';
    end if;
    v_pasos := v_flujo[v_desde + 1 : v_hasta];
    v_descontado := v_o.stock_descontado or v_hasta >= 3;
    if not v_o.stock_descontado and v_hasta >= 3 then
      select coalesce(jsonb_object_agg(codigo, -cantidad), '{}'::jsonb)
        into v_delta from public._repuestos_de(v_o.lineas);
    end if;
  end if;

  if v_delta <> '{}'::jsonb then
    v_criticos := public._mover_stock(v_delta);
  end if;

  select coalesce(jsonb_agg(jsonb_build_object(
      'estado', t.e,
      'fecha', now(),
      'por', coalesce(p_por, ''),
      'nota', case when t.e = p_estado then coalesce(p_nota, '') else '' end
    ) order by t.i), '[]'::jsonb)
    into v_historial
    from unnest(v_pasos) with ordinality as t(e, i);

  update public.ordenes
    set estado = p_estado,
        historial = historial || v_historial,
        stock_descontado = v_descontado,
        updated_at = now()
    where id = p_orden
    returning * into v_o;

  return jsonb_build_object('orden', to_jsonb(v_o), 'criticos', v_criticos);
end
$$;

-- Agregar o quitar servicios y repuestos de una orden abierta. Si los
-- repuestos ya salieron del almacén, mueve la diferencia de stock.
create or replace function public.actualizar_lineas_orden(
  p_orden uuid,
  p_lineas jsonb,
  p_subtotal int,
  p_descuento int,
  p_total int
)
returns jsonb
language plpgsql security definer set search_path = public
as $$
declare
  v_o public.ordenes;
  v_promo public.codigos_promocionales;
  v_delta jsonb;
  v_criticos jsonb := '[]'::jsonb;
  r record;
begin
  if public.rol_actual() is null then
    raise exception 'Solo el personal del taller cambia órdenes';
  end if;
  select * into v_o from public.ordenes where id = p_orden for update;
  if not found then
    raise exception 'La orden ya no existe';
  end if;
  if v_o.estado not in ('recepcion', 'diagnostico', 'repuestos', 'reparacion') then
    raise exception 'La orden % ya no se puede editar', v_o.codigo;
  end if;
  if v_o.estado_pago not in ('por_cobrar', 'rechazado') then
    raise exception 'La orden ya tiene un cobro registrado';
  end if;
  if public._suma_lineas(p_lineas) <> p_subtotal
     or p_total <> p_subtotal - p_descuento + v_o.recargo_centimos
     or p_descuento < 0 then
    raise exception 'Los montos de la orden no cuadran';
  end if;
  if v_o.codigo_promo is null then
    if p_descuento <> 0 then
      raise exception 'Hay un descuento sin código promocional';
    end if;
  else
    select * into v_promo from public.codigos_promocionales where codigo = v_o.codigo_promo;
    if found and public._descuento_promo(v_promo, p_subtotal) <> p_descuento then
      raise exception 'El descuento no corresponde al código %', v_o.codigo_promo;
    end if;
  end if;

  if v_o.stock_descontado then
    select coalesce(jsonb_object_agg(cod, dif), '{}'::jsonb) into v_delta
    from (
      select coalesce(a.codigo, b.codigo) as cod,
             coalesce(a.cantidad, 0) - coalesce(b.cantidad, 0) as dif
      from public._repuestos_de(v_o.lineas) a
      full join public._repuestos_de(p_lineas) b on a.codigo = b.codigo
    ) d
    where dif <> 0;
    v_criticos := public._mover_stock(v_delta);
  else
    for r in select * from public._repuestos_de(p_lineas) loop
      if not exists (
        select 1 from public.repuestos where codigo = r.codigo and activo and stock >= r.cantidad
      ) then
        raise exception 'No hay stock suficiente de %', r.codigo;
      end if;
    end loop;
  end if;

  update public.ordenes
    set lineas = p_lineas,
        subtotal_centimos = p_subtotal,
        descuento_centimos = p_descuento,
        total_centimos = p_total,
        codigo_promo = case when p_descuento > 0 then codigo_promo else null end,
        updated_at = now()
    where id = p_orden
    returning * into v_o;
  return jsonb_build_object('orden', to_jsonb(v_o), 'criticos', v_criticos);
end
$$;

-- Diagnóstico escrito por el personal (normalmente el mecánico). Se puede
-- corregir mientras el vehículo siga en el taller.
create or replace function public.registrar_diagnostico(p_orden uuid, p_diagnostico text)
returns jsonb
language plpgsql security definer set search_path = public
as $$
declare
  v_o public.ordenes;
  v_texto text := btrim(coalesce(p_diagnostico, ''));
begin
  if public.rol_actual() is null then
    raise exception 'Solo el personal del taller cambia órdenes';
  end if;
  if length(v_texto) < 5 then
    raise exception 'Escribe el diagnóstico (mínimo 5 caracteres)';
  end if;
  if length(v_texto) > 1000 then
    raise exception 'El diagnóstico es muy largo (máximo 1000 caracteres)';
  end if;
  select * into v_o from public.ordenes where id = p_orden for update;
  if not found then
    raise exception 'La orden ya no existe';
  end if;
  if v_o.estado not in ('recepcion', 'diagnostico', 'repuestos', 'reparacion') then
    raise exception 'La orden % ya no se puede editar', v_o.codigo;
  end if;
  update public.ordenes
    set diagnostico = v_texto, updated_at = now()
    where id = p_orden
    returning * into v_o;
  return to_jsonb(v_o);
end
$$;

-- Cobro de una orden lista: efectivo queda pagado; Yape/Plin, por verificar
-- (con N.° de operación); tarjeta, pagada (demo) o por cobrar (Mercado Pago).
create or replace function public.registrar_cobro(
  p_orden uuid,
  p_metodo text,
  p_estado_pago text,
  p_referencia text default null
)
returns jsonb
language plpgsql security definer set search_path = public
as $$
declare
  v_o public.ordenes;
begin
  if not public.es_gestion() then
    raise exception 'Solo el jefe de taller o administración cobran';
  end if;
  select * into v_o from public.ordenes where id = p_orden for update;
  if not found then
    raise exception 'La orden ya no existe';
  end if;
  if v_o.estado <> 'listo' then
    raise exception 'Se cobra cuando la orden está lista para entrega';
  end if;
  if v_o.estado_pago in ('pagado', 'verificando') then
    raise exception 'La orden % ya tiene un cobro registrado', v_o.codigo;
  end if;
  if not (
    (p_metodo = 'efectivo' and p_estado_pago = 'pagado')
    or (p_metodo in ('yape', 'plin') and p_estado_pago = 'verificando'
        and coalesce(p_referencia, '') ~ '^\d{6,12}$')
    or (p_metodo = 'tarjeta' and p_estado_pago in ('pagado', 'por_cobrar'))
  ) then
    raise exception 'Medio de pago o N.° de operación no válido';
  end if;
  update public.ordenes
    set metodo_pago = p_metodo,
        estado_pago = p_estado_pago,
        referencia_pago = nullif(p_referencia, ''),
        pagado_en = case when p_estado_pago = 'pagado' then now() end,
        updated_at = now()
    where id = p_orden
    returning * into v_o;
  return to_jsonb(v_o);
end
$$;

-- Administración aprueba o rechaza un Yape/Plin.
create or replace function public.verificar_pago(p_orden uuid, p_aprobar boolean)
returns jsonb
language plpgsql security definer set search_path = public
as $$
declare
  v_o public.ordenes;
begin
  if coalesce(public.rol_actual(), '') <> 'administracion' then
    raise exception 'Solo administración verifica los pagos';
  end if;
  select * into v_o from public.ordenes where id = p_orden for update;
  if not found or v_o.estado_pago <> 'verificando' then
    raise exception 'La orden no tiene un pago por verificar';
  end if;
  update public.ordenes
    set estado_pago = case when p_aprobar then 'pagado' else 'rechazado' end,
        pagado_en = case when p_aprobar then now() end,
        updated_at = now()
    where id = p_orden
    returning * into v_o;
  return to_jsonb(v_o);
end
$$;

-- Boleta (B001) o factura (F001) con el correlativo siguiente. Boletas desde
-- S/ 700 piden DNI; facturas, RUC válido y razón social. IGV 18 % incluido.
create or replace function public.emitir_comprobante(
  p_orden uuid,
  p_tipo text,
  p_documento text default '',
  p_razon_social text default ''
)
returns jsonb
language plpgsql security definer set search_path = public
as $$
declare
  v_o public.ordenes;
  v_config jsonb;
  v_serie text;
  v_numero int;
  v_igv int;
  v_doc text := trim(coalesce(p_documento, ''));
begin
  if not public.es_gestion() then
    raise exception 'Solo el jefe de taller o administración facturan';
  end if;
  select * into v_o from public.ordenes where id = p_orden for update;
  if not found then
    raise exception 'La orden ya no existe';
  end if;
  if v_o.comprobante is not null then
    raise exception 'La orden ya tiene el comprobante %', v_o.comprobante ->> 'codigo';
  end if;
  if v_o.estado_pago <> 'pagado' then
    raise exception 'Registra el cobro antes de emitir el comprobante';
  end if;
  if p_tipo = 'factura' then
    if not public._ruc_valido(v_doc) then
      raise exception 'El RUC no es válido';
    end if;
    if length(trim(coalesce(p_razon_social, ''))) < 3 then
      raise exception 'Ingrese la razón social';
    end if;
  elsif p_tipo = 'boleta' then
    if v_doc = '' and v_o.total_centimos >= 70000 then
      raise exception 'Boletas desde S/ 700.00 requieren el DNI del cliente';
    end if;
    if v_doc <> '' and v_doc !~ '^\d{8}$' then
      raise exception 'El DNI debe tener 8 dígitos';
    end if;
  else
    raise exception 'Seleccione boleta o factura';
  end if;

  select datos into v_config from public.config where id = 'taller';
  v_serie := case when p_tipo = 'factura'
    then coalesce(v_config ->> 'serie_factura', 'F001')
    else coalesce(v_config ->> 'serie_boleta', 'B001') end;

  update public.contadores set ultimo = ultimo + 1
    where id = case when p_tipo = 'factura' then 'facturas' else 'boletas' end
    returning ultimo into v_numero;
  if v_numero is null then
    raise exception 'Falta el contador de comprobantes';
  end if;

  v_igv := round(v_o.total_centimos - v_o.total_centimos / 1.18)::int;
  update public.ordenes
    set comprobante = jsonb_build_object(
          'tipo', p_tipo,
          'serie', v_serie,
          'numero', v_numero,
          'codigo', v_serie || '-' || lpad(v_numero::text, 5, '0'),
          'documento', v_doc,
          'razon_social', case when p_tipo = 'factura' then trim(p_razon_social) else v_o.cliente_nombre end,
          'op_gravada_centimos', v_o.total_centimos - v_igv,
          'igv_centimos', v_igv,
          'total_centimos', v_o.total_centimos,
          'emitido_en', now(),
          -- Envío a SUNAT (OSE/PSE) en modo demo: queda aceptado.
          'estado_sunat', 'aceptado'
        ),
        updated_at = now()
    where id = p_orden
    returning * into v_o;
  return to_jsonb(v_o);
end
$$;

-- Ingreso de mercadería (p_delta > 0) o inventario físico (p_stock).
create or replace function public.mover_stock_repuesto(
  p_codigo text,
  p_delta int default null,
  p_stock int default null
)
returns jsonb
language plpgsql security definer set search_path = public
as $$
declare
  v_actual int;
begin
  if not public.es_gestion() then
    raise exception 'Solo el jefe de taller o administración mueven el stock';
  end if;
  select stock into v_actual from public.repuestos where codigo = p_codigo for update;
  if not found then
    raise exception 'El repuesto % no existe', p_codigo;
  end if;
  if p_stock is not null then
    if p_stock < 0 then
      raise exception 'El stock no puede ser negativo';
    end if;
    return public._mover_stock(jsonb_build_object(p_codigo, p_stock - v_actual));
  end if;
  if coalesce(p_delta, 0) <= 0 then
    raise exception 'Ingrese una cantidad mayor a 0';
  end if;
  return public._mover_stock(jsonb_build_object(p_codigo, p_delta));
end
$$;

-- Marca como leídos los avisos para quien tiene la sesión.
create or replace function public.marcar_avisos_leidos()
returns void
language plpgsql security definer set search_path = public
as $$
begin
  if public.rol_actual() is null then
    return;
  end if;
  update public.avisos
    set leido_por = array_append(leido_por, auth.uid()::text)
    where not (auth.uid()::text = any (leido_por))
      and not ('*' = any (leido_por));
end
$$;

-- ================================================================== Permisos

revoke all on function public._repuestos_de(jsonb) from public;
revoke all on function public._mover_stock(jsonb) from public;
revoke all on function public._ruc_valido(text) from public;
revoke all on function public._descuento_promo(public.codigos_promocionales, int) from public;
revoke all on function public._suma_lineas(jsonb) from public;

revoke all on function public.crear_orden(jsonb) from public, anon;
revoke all on function public.cambiar_estado_orden(uuid, text, text, text) from public, anon;
revoke all on function public.actualizar_lineas_orden(uuid, jsonb, int, int, int) from public, anon;
revoke all on function public.registrar_diagnostico(uuid, text) from public, anon;
revoke all on function public.registrar_cobro(uuid, text, text, text) from public, anon;
revoke all on function public.verificar_pago(uuid, boolean) from public, anon;
revoke all on function public.emitir_comprobante(uuid, text, text, text) from public, anon;
revoke all on function public.mover_stock_repuesto(text, int, int) from public, anon;
revoke all on function public.marcar_avisos_leidos() from public, anon;

grant execute on function public.crear_orden(jsonb) to authenticated;
grant execute on function public.cambiar_estado_orden(uuid, text, text, text) to authenticated;
grant execute on function public.actualizar_lineas_orden(uuid, jsonb, int, int, int) to authenticated;
grant execute on function public.registrar_diagnostico(uuid, text) to authenticated;
grant execute on function public.registrar_cobro(uuid, text, text, text) to authenticated;
grant execute on function public.verificar_pago(uuid, boolean) to authenticated;
grant execute on function public.emitir_comprobante(uuid, text, text, text) to authenticated;
grant execute on function public.mover_stock_repuesto(text, int, int) to authenticated;
grant execute on function public.marcar_avisos_leidos() to authenticated;

-- RLS: sin política no hay acceso. El rol `anon` no tiene ninguna.
alter table public.personal enable row level security;
alter table public.categorias enable row level security;
alter table public.servicios enable row level security;
alter table public.adicionales enable row level security;
alter table public.repuestos enable row level security;
alter table public.codigos_promocionales enable row level security;
alter table public.config enable row level security;
alter table public.contadores enable row level security;
alter table public.clientes enable row level security;
alter table public.citas enable row level security;
alter table public.avisos enable row level security;
alter table public.ordenes enable row level security;

-- Permisos de tabla explícitos: el rol anon (sin sesión) no toca nada y el
-- personal con sesión pasa por las políticas RLS. Así funciona aunque el
-- proyecto se haya creado sin "dar acceso a la API a las tablas nuevas".
revoke all on all tables in schema public from anon;
grant select, insert, update, delete on all tables in schema public to authenticated;

-- Personal: cada uno lee su fila (gestión, todas) y solo edita sus
-- favoritos y su borrador. El rol se asigna desde el SQL Editor.
create policy personal_lee on public.personal for select to authenticated
  using (id = auth.uid() or public.es_gestion());
create policy personal_edita on public.personal for update to authenticated
  using (id = auth.uid()) with check (id = auth.uid());
revoke insert, update, delete on public.personal from authenticated, anon;
grant update (favoritos, borrador) on public.personal to authenticated;

-- Catálogo: lo lee el personal; lo edita gestión.
create policy categorias_lee on public.categorias for select to authenticated using (public.es_personal());
create policy categorias_edita on public.categorias for all to authenticated
  using (public.es_gestion()) with check (public.es_gestion());
create policy servicios_lee on public.servicios for select to authenticated using (public.es_personal());
create policy servicios_edita on public.servicios for all to authenticated
  using (public.es_gestion()) with check (public.es_gestion());
create policy adicionales_lee on public.adicionales for select to authenticated using (public.es_personal());
create policy adicionales_edita on public.adicionales for all to authenticated
  using (public.es_gestion()) with check (public.es_gestion());
create policy config_lee on public.config for select to authenticated using (public.es_personal());
create policy config_edita on public.config for all to authenticated
  using (public.es_gestion()) with check (public.es_gestion());
create policy promos_lee on public.codigos_promocionales for select to authenticated using (public.es_personal());
create policy promos_edita on public.codigos_promocionales for all to authenticated
  using (public.es_gestion()) with check (public.es_gestion());

-- Repuestos: el stock de las órdenes lo mueven las funciones.
create policy repuestos_lee on public.repuestos for select to authenticated using (public.es_personal());
create policy repuestos_edita on public.repuestos for all to authenticated
  using (public.es_gestion()) with check (public.es_gestion());

-- Clientes: todo el personal registra y edita; solo administración borra.
create policy clientes_lee on public.clientes for select to authenticated using (public.es_personal());
create policy clientes_crea on public.clientes for insert to authenticated with check (public.es_personal());
create policy clientes_edita on public.clientes for update to authenticated
  using (public.es_personal()) with check (public.es_personal());
create policy clientes_borra on public.clientes for delete to authenticated
  using (public.rol_actual() = 'administracion');

create policy citas_lee on public.citas for select to authenticated using (public.es_personal());
create policy citas_crea on public.citas for insert to authenticated with check (public.es_personal());
create policy citas_edita on public.citas for update to authenticated
  using (public.es_personal()) with check (public.es_personal());

create policy avisos_lee on public.avisos for select to authenticated using (public.es_personal());
create policy avisos_crea on public.avisos for insert to authenticated with check (public.es_personal());

-- Órdenes: el personal las lee; se crean y cambian solo con las funciones.
-- No se borran: se anulan.
create policy ordenes_lee on public.ordenes for select to authenticated using (public.es_personal());

-- ============================================================ Tiempo real

alter publication supabase_realtime add table
  public.categorias, public.servicios, public.adicionales, public.repuestos,
  public.config, public.clientes, public.citas, public.avisos, public.ordenes;

-- ====================================================== Vistas (Power BI)
-- Esquema aparte: la API de la app no lo expone. Power BI se conecta con el
-- usuario postgres (Project Settings → Database → Connection string).

create schema if not exists reportes;

create or replace view reportes.ordenes as
  select id, codigo, cliente_id, cliente_nombre, placa, vehiculo, tipo_vehiculo, km,
         mecanico, estado, estado_pago, metodo_pago, subtotal_centimos / 100.0 as subtotal,
         descuento_centimos / 100.0 as descuento, recargo_centimos / 100.0 as recargo,
         total_centimos / 100.0 as total, codigo_promo, a_domicilio, created_at, pagado_en, updated_at,
         diagnostico
  from public.ordenes;

create or replace view reportes.orden_lineas as
  select o.id as orden_id, o.codigo as orden_codigo, o.created_at, o.estado as estado_orden,
         l.tipo, l.ref_id, l.nombre, l.variante, l.cantidad,
         l.precio_unitario_centimos / 100.0 as precio_unitario,
         l.total_centimos / 100.0 as total
  from public.ordenes o,
       jsonb_to_recordset(o.lineas) as l(
         tipo text, ref_id text, nombre text, variante text,
         precio_unitario_centimos int, cantidad int, total_centimos int
       );

create or replace view reportes.orden_historial as
  select o.id as orden_id, o.codigo as orden_codigo, h.estado, h.fecha, h.por, h.nota
  from public.ordenes o,
       jsonb_to_recordset(o.historial) as h(estado text, fecha timestamptz, por text, nota text);

create or replace view reportes.comprobantes as
  select o.id as orden_id, o.codigo as orden_codigo, c.tipo, c.serie, c.numero, c.codigo,
         c.documento, c.razon_social, c.op_gravada_centimos / 100.0 as op_gravada,
         c.igv_centimos / 100.0 as igv, c.total_centimos / 100.0 as total, c.emitido_en, c.estado_sunat
  from public.ordenes o,
       jsonb_to_record(o.comprobante) as c(
         tipo text, serie text, numero int, codigo text, documento text, razon_social text,
         op_gravada_centimos int, igv_centimos int, total_centimos int,
         emitido_en timestamptz, estado_sunat text
       )
  where o.comprobante is not null;

create or replace view reportes.vehiculos as
  select c.id as cliente_id, c.nombre as cliente, v.placa, v.marca, v.modelo, v.anio, v.tipo, v.km,
         v.ultimo_servicio
  from public.clientes c,
       jsonb_to_recordset(c.vehiculos) as v(
         placa text, marca text, modelo text, anio int, tipo text, km int, ultimo_servicio timestamptz
       );
