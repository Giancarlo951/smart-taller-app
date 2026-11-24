-- Migración del 23/11/2026: diagnóstico escrito en las órdenes.
-- Para una base que ya tenía esquema.sql aplicado (esquema.sql ya lo incluye).

alter table public.ordenes
  add column if not exists diagnostico text not null default '' check (length(diagnostico) <= 1000);

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

revoke all on function public.registrar_diagnostico(uuid, text) from public, anon;
grant execute on function public.registrar_diagnostico(uuid, text) to authenticated;

create or replace view reportes.ordenes as
  select id, codigo, cliente_id, cliente_nombre, placa, vehiculo, tipo_vehiculo, km,
         mecanico, estado, estado_pago, metodo_pago, subtotal_centimos / 100.0 as subtotal,
         descuento_centimos / 100.0 as descuento, recargo_centimos / 100.0 as recargo,
         total_centimos / 100.0 as total, codigo_promo, a_domicilio, created_at, pagado_en, updated_at,
         diagnostico
  from public.ordenes;
