-- Migración del 24/11/2026: el taller se muestra como "Smart Taller" en lugar
-- de "Auto Siglo" (nombre comercial, razón social de ejemplo y taller del personal).
update public.config
  set datos = datos || '{"nombre": "Smart Taller", "razon_social": "Smart Taller E.I.R.L. (ejemplo)"}'::jsonb
  where id = 'taller';
update public.personal set taller = 'Smart Taller · Huancayo' where taller = 'Auto Siglo · Huancayo';
alter table public.personal alter column taller set default 'Smart Taller · Huancayo';
