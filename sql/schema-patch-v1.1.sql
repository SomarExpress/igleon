-- =====================================================================
-- ADULAM · PARCHE v1.1
-- Ejecutar en SQL Editor de Supabase DESPUÉS del schema.sql original.
-- Agrega: Casas de Pan, corrección del bucket de storage,
--         campo ministerio_id deprecated (se usa member_teams).
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. CASAS DE PAN
-- ---------------------------------------------------------------------
create table if not exists public.houses (
  id          uuid primary key default uuid_generate_v4(),
  nombre      text not null,
  anfitrion_id uuid references public.members(id) on delete set null,
  direccion   text,
  dia_reunion text, -- 'lunes','martes', etc.
  hora        text, -- '19:00'
  descripcion text,
  iglesia_id  uuid references public.churches(id) default '00000000-0000-0000-0000-000000000001',
  created_at  timestamptz not null default now()
);

-- Relación muchos-a-muchos: miembros pueden estar en varias casas
create table if not exists public.member_houses (
  member_id uuid references public.members(id) on delete cascade,
  house_id  uuid references public.houses(id)  on delete cascade,
  primary key (member_id, house_id)
);

-- RLS Casas de Pan (mismas políticas que el resto)
alter table public.houses        enable row level security;
alter table public.member_houses enable row level security;

do $$
declare
  t text;
  tablas text[] := array['houses','member_houses'];
begin
  foreach t in array tablas loop
    execute format('drop policy if exists "%1$s_select" on public.%1$s', t);
    execute format('drop policy if exists "%1$s_insert" on public.%1$s', t);
    execute format('drop policy if exists "%1$s_update" on public.%1$s', t);
    execute format('drop policy if exists "%1$s_delete" on public.%1$s', t);

    execute format($p$
      create policy "%1$s_select" on public.%1$s for select
      using (auth.role() = 'authenticated')
    $p$, t);

    execute format($p$
      create policy "%1$s_insert" on public.%1$s for insert
      with check (public.get_my_role() in ('pastor','lider','servidor'))
    $p$, t);

    execute format($p$
      create policy "%1$s_update" on public.%1$s for update
      using (public.get_my_role() in ('pastor','lider'))
    $p$, t);

    execute format($p$
      create policy "%1$s_delete" on public.%1$s for delete
      using (public.get_my_role() = 'pastor')
    $p$, t);
  end loop;
end $$;

-- ---------------------------------------------------------------------
-- 2. STORAGE BUCKET (arreglar 400 Bad Request)
-- ---------------------------------------------------------------------
-- Crear bucket si no existe
insert into storage.buckets (id, name, public)
values ('member-photos', 'member-photos', true)
on conflict (id) do update set public = true;

-- Limpiar y recrear políticas de Storage
drop policy if exists "auth_upload_photos"    on storage.objects;
drop policy if exists "public_read_photos"    on storage.objects;
drop policy if exists "auth_update_photos"    on storage.objects;
drop policy if exists "auth_delete_photos"    on storage.objects;

create policy "public_read_photos" on storage.objects
  for select using (bucket_id = 'member-photos');

create policy "auth_upload_photos" on storage.objects
  for insert to authenticated
  with check (bucket_id = 'member-photos');

create policy "auth_update_photos" on storage.objects
  for update to authenticated
  using (bucket_id = 'member-photos');

create policy "auth_delete_photos" on storage.objects
  for delete to authenticated
  using (bucket_id = 'member-photos');

-- ---------------------------------------------------------------------
-- 3. DATOS SEMILLA (opcional)
-- ---------------------------------------------------------------------
insert into public.houses (nombre, direccion, dia_reunion, hora) values
  ('Casa de Pan López Norte','Sector López, Bloque 3','martes','19:00'),
  ('Casa de Pan Arellano Sur','Col. Arellano, Calle Principal','jueves','19:30')
on conflict do nothing;

-- =====================================================================
-- FIN DEL PARCHE
-- =====================================================================
