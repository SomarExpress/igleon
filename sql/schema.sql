-- =====================================================================
-- ADULAM · Sistema de Administración Pastoral
-- Script completo para Supabase (PostgreSQL 15+)
-- =====================================================================
-- Ejecutar este script en el SQL Editor de Supabase.
-- Incluye: tablas, relaciones, RLS, funciones, triggers y datos semilla.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 0. EXTENSIONES
-- ---------------------------------------------------------------------
create extension if not exists "uuid-ossp";

-- ---------------------------------------------------------------------
-- 1. TABLA DE PERFILES (vinculada a auth.users)
-- ---------------------------------------------------------------------
-- Cada usuario autenticado en Supabase tiene un perfil con rol.
create table if not exists public.profiles (
  id           uuid primary key references auth.users(id) on delete cascade,
  nombre       text not null,
  email        text unique,
  rol          text not null default 'miembro'
               check (rol in ('pastor','lider','servidor','miembro')),
  iglesia_id   uuid, -- preparado para multi-iglesia (SaaS futuro)
  created_at   timestamptz not null default now()
);

-- ---------------------------------------------------------------------
-- 2. IGLESIAS (preparado para multi-tenant futuro)
-- ---------------------------------------------------------------------
create table if not exists public.churches (
  id         uuid primary key default uuid_generate_v4(),
  nombre     text not null default 'ADULAM',
  direccion  text,
  created_at timestamptz not null default now()
);

-- Insertar iglesia por defecto
insert into public.churches (id, nombre)
values ('00000000-0000-0000-0000-000000000001', 'ADULAM')
on conflict do nothing;

-- ---------------------------------------------------------------------
-- 3. FAMILIAS
-- ---------------------------------------------------------------------
create table if not exists public.families (
  id             uuid primary key default uuid_generate_v4(),
  nombre_familia text not null,
  iglesia_id     uuid references public.churches(id) default '00000000-0000-0000-0000-000000000001',
  created_at     timestamptz not null default now()
);

-- ---------------------------------------------------------------------
-- 4. EQUIPOS / MINISTERIOS
-- ---------------------------------------------------------------------
create table if not exists public.teams (
  id          uuid primary key default uuid_generate_v4(),
  nombre      text not null,
  descripcion text,
  lider_id    uuid, -- FK a members se agrega después
  iglesia_id  uuid references public.churches(id) default '00000000-0000-0000-0000-000000000001',
  created_at  timestamptz not null default now()
);

-- ---------------------------------------------------------------------
-- 5. MIEMBROS
-- ---------------------------------------------------------------------
create table if not exists public.members (
  id                uuid primary key default uuid_generate_v4(),
  nombre            text not null,
  telefono          text,
  direccion         text,
  lat               numeric(10,7),
  lng               numeric(10,7),
  familia_id        uuid references public.families(id) on delete set null,
  ministerio_id     uuid references public.teams(id) on delete set null,
  estado_espiritual text not null default 'nuevo'
                    check (estado_espiritual in ('nuevo','discipulado','bautizado','lider','inactivo')),
  foto_url          text,
  fecha_nacimiento  date,
  notas             text,
  iglesia_id        uuid references public.churches(id) default '00000000-0000-0000-0000-000000000001',
  user_id           uuid references auth.users(id) on delete set null, -- si el miembro tiene login
  created_at        timestamptz not null default now()
);

-- FK diferida para teams.lider_id
alter table public.teams
  drop constraint if exists teams_lider_fk,
  add constraint teams_lider_fk
  foreign key (lider_id) references public.members(id) on delete set null;

-- ---------------------------------------------------------------------
-- 6. RELACIÓN MUCHOS-A-MUCHOS MIEMBROS ↔ EQUIPOS
-- ---------------------------------------------------------------------
create table if not exists public.member_teams (
  member_id uuid references public.members(id) on delete cascade,
  team_id   uuid references public.teams(id) on delete cascade,
  rol       text default 'integrante',
  primary key (member_id, team_id)
);

-- ---------------------------------------------------------------------
-- 7. ASISTENCIA
-- ---------------------------------------------------------------------
create table if not exists public.attendance (
  id            uuid primary key default uuid_generate_v4(),
  member_id     uuid not null references public.members(id) on delete cascade,
  fecha         date not null,
  tipo_reunion  text not null check (tipo_reunion in ('lunes','miercoles','viernes','domingo','especial')),
  asistio       boolean not null default false,
  iglesia_id    uuid references public.churches(id) default '00000000-0000-0000-0000-000000000001',
  created_at    timestamptz not null default now(),
  unique (member_id, fecha, tipo_reunion)
);

create index if not exists idx_attendance_fecha on public.attendance(fecha);
create index if not exists idx_attendance_member on public.attendance(member_id);

-- ---------------------------------------------------------------------
-- 8. DISCIPULADO
-- ---------------------------------------------------------------------
create table if not exists public.discipleship (
  id              uuid primary key default uuid_generate_v4(),
  discipulador_id uuid references public.members(id) on delete set null,
  discipulo_id    uuid not null references public.members(id) on delete cascade,
  nivel           text default 'inicial'
                  check (nivel in ('inicial','intermedio','avanzado','completado')),
  progreso        integer default 0 check (progreso between 0 and 100),
  notas           text,
  ultima_reunion  date,
  iglesia_id      uuid references public.churches(id) default '00000000-0000-0000-0000-000000000001',
  created_at      timestamptz not null default now(),
  unique (discipulo_id)
);

-- ---------------------------------------------------------------------
-- 9. TESORERÍA
-- ---------------------------------------------------------------------
create table if not exists public.treasury (
  id          uuid primary key default uuid_generate_v4(),
  tipo        text not null check (tipo in ('ingreso','egreso')),
  categoria   text not null, -- diezmo, ofrenda, gasto, servicios, etc.
  monto       numeric(12,2) not null check (monto >= 0),
  descripcion text,
  fecha       date not null default current_date,
  registrado_por uuid references public.profiles(id) on delete set null,
  iglesia_id  uuid references public.churches(id) default '00000000-0000-0000-0000-000000000001',
  created_at  timestamptz not null default now()
);

create index if not exists idx_treasury_fecha on public.treasury(fecha);

-- ---------------------------------------------------------------------
-- 10. PLANIFICACIÓN DE SERVICIOS
-- ---------------------------------------------------------------------
create table if not exists public.service_plans (
  id           uuid primary key default uuid_generate_v4(),
  fecha        date not null,
  tipo_reunion text not null check (tipo_reunion in ('lunes','miercoles','viernes','domingo','especial')),
  tema         text,
  predicador   text,
  iglesia_id   uuid references public.churches(id) default '00000000-0000-0000-0000-000000000001',
  created_at   timestamptz not null default now()
);

create table if not exists public.service_tasks (
  id              uuid primary key default uuid_generate_v4(),
  service_plan_id uuid not null references public.service_plans(id) on delete cascade,
  nombre_tarea    text not null,
  responsable_id  uuid references public.members(id) on delete set null,
  estado          text not null default 'pendiente'
                  check (estado in ('pendiente','en_proceso','completado')),
  created_at      timestamptz not null default now()
);

-- ---------------------------------------------------------------------
-- 11. REDES SOCIALES
-- ---------------------------------------------------------------------
create table if not exists public.social_posts (
  id               uuid primary key default uuid_generate_v4(),
  titulo           text not null,
  descripcion      text,
  fecha_programada date,
  estado           text not null default 'pendiente'
                   check (estado in ('pendiente','en_diseno','aprobado','publicado')),
  plataforma       text default 'instagram', -- instagram, facebook, tiktok, whatsapp
  responsable_id   uuid references public.members(id) on delete set null,
  imagen_url       text,
  iglesia_id       uuid references public.churches(id) default '00000000-0000-0000-0000-000000000001',
  created_at       timestamptz not null default now()
);

-- ---------------------------------------------------------------------
-- 12. AUTOMATIZACIONES (logs preparado para BuilderBot)
-- ---------------------------------------------------------------------
create table if not exists public.automation_logs (
  id          uuid primary key default uuid_generate_v4(),
  tipo        text not null, -- 'inactividad','nuevo_miembro','sin_discipulador'
  member_id   uuid references public.members(id) on delete cascade,
  mensaje     text,
  enviado     boolean default false,
  created_at  timestamptz not null default now()
);

-- =====================================================================
-- FUNCIONES Y TRIGGERS
-- =====================================================================

-- ---------------------------------------------------------------------
-- Función: crear perfil automático al registrarse un usuario
-- ---------------------------------------------------------------------
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, nombre, email, rol)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'nombre', split_part(new.email,'@',1)),
    new.email,
    coalesce(new.raw_user_meta_data->>'rol', 'miembro')
  );
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- ---------------------------------------------------------------------
-- Función: obtener rol del usuario autenticado
-- ---------------------------------------------------------------------
create or replace function public.get_my_role()
returns text
language sql
security definer
stable
set search_path = public
as $$
  select rol from public.profiles where id = auth.uid();
$$;

-- ---------------------------------------------------------------------
-- Automatización 1: marcar inactivo si falta 3 veces seguidas
-- ---------------------------------------------------------------------
create or replace function public.auto_mark_inactive()
returns void
language plpgsql
as $$
declare
  m record;
  faltas int;
begin
  for m in select id from public.members where estado_espiritual <> 'inactivo' loop
    select count(*) into faltas
    from (
      select asistio
      from public.attendance
      where member_id = m.id
      order by fecha desc
      limit 3
    ) t
    where asistio = false;

    if faltas = 3 then
      update public.members set estado_espiritual = 'inactivo' where id = m.id;
      insert into public.automation_logs (tipo, member_id, mensaje)
      values ('inactividad', m.id, 'Miembro marcado como inactivo por 3 faltas consecutivas');
    end if;
  end loop;
end;
$$;

-- ---------------------------------------------------------------------
-- Automatización 2: alertar miembros nuevos sin discipulador
-- ---------------------------------------------------------------------
create or replace function public.auto_alert_sin_discipulador()
returns void
language plpgsql
as $$
declare
  m record;
begin
  for m in
    select mb.id, mb.nombre
    from public.members mb
    left join public.discipleship d on d.discipulo_id = mb.id
    where mb.estado_espiritual in ('nuevo','discipulado')
      and d.id is null
  loop
    insert into public.automation_logs (tipo, member_id, mensaje)
    values ('sin_discipulador', m.id,
            'El miembro ' || m.nombre || ' no tiene discipulador asignado');
  end loop;
end;
$$;

-- ---------------------------------------------------------------------
-- Vista: dashboard rápido
-- ---------------------------------------------------------------------
create or replace view public.v_dashboard as
select
  (select count(*) from public.members where estado_espiritual <> 'inactivo') as total_miembros,
  (select count(*) from public.members where estado_espiritual = 'nuevo'
     and created_at > now() - interval '30 days')                             as nuevos_miembros,
  (select count(*) from public.members where estado_espiritual = 'discipulado') as en_discipulado,
  (select count(*) from public.members where estado_espiritual = 'inactivo')    as inactivos,
  (select count(distinct member_id) from public.attendance
     where asistio = true and fecha > now() - interval '7 days')              as asistencia_semanal,
  (select coalesce(sum(case when tipo='ingreso' then monto else -monto end),0)
     from public.treasury
     where fecha >= date_trunc('month', current_date))                        as balance_mes;

-- =====================================================================
-- ROW LEVEL SECURITY (RLS)
-- =====================================================================
alter table public.profiles       enable row level security;
alter table public.churches       enable row level security;
alter table public.families       enable row level security;
alter table public.teams          enable row level security;
alter table public.members        enable row level security;
alter table public.member_teams   enable row level security;
alter table public.attendance     enable row level security;
alter table public.discipleship   enable row level security;
alter table public.treasury       enable row level security;
alter table public.service_plans  enable row level security;
alter table public.service_tasks  enable row level security;
alter table public.social_posts   enable row level security;
alter table public.automation_logs enable row level security;

-- Política genérica: usuarios autenticados pueden leer
-- Solo pastor/lider pueden escribir en la mayoría de tablas
-- Tesorería: solo pastor

-- PROFILES: cada uno ve su propio perfil; pastor ve todos
drop policy if exists "profiles_select" on public.profiles;
create policy "profiles_select" on public.profiles for select
  using (auth.uid() = id or public.get_my_role() in ('pastor','lider'));

drop policy if exists "profiles_update_self" on public.profiles;
create policy "profiles_update_self" on public.profiles for update
  using (auth.uid() = id or public.get_my_role() = 'pastor');

-- CHURCHES
drop policy if exists "churches_read" on public.churches;
create policy "churches_read" on public.churches for select using (auth.role() = 'authenticated');

-- Helper macro: función para simplificar políticas
-- Lectura: cualquier autenticado. Escritura: pastor/lider.
-- Aplicamos a: families, teams, members, member_teams, attendance,
-- discipleship, service_plans, service_tasks, social_posts
do $$
declare
  t text;
  tablas text[] := array['families','teams','members','member_teams',
                         'attendance','discipleship','service_plans',
                         'service_tasks','social_posts','automation_logs'];
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

-- TESORERÍA: solo pastor
drop policy if exists "treasury_select" on public.treasury;
drop policy if exists "treasury_insert" on public.treasury;
drop policy if exists "treasury_update" on public.treasury;
drop policy if exists "treasury_delete" on public.treasury;

create policy "treasury_select" on public.treasury for select
  using (public.get_my_role() in ('pastor','lider'));
create policy "treasury_insert" on public.treasury for insert
  with check (public.get_my_role() = 'pastor');
create policy "treasury_update" on public.treasury for update
  using (public.get_my_role() = 'pastor');
create policy "treasury_delete" on public.treasury for delete
  using (public.get_my_role() = 'pastor');

-- =====================================================================
-- STORAGE BUCKET para fotos de miembros
-- =====================================================================
-- Ejecutar manualmente después en el dashboard de Supabase o via SQL:
insert into storage.buckets (id, name, public)
values ('member-photos', 'member-photos', true)
on conflict (id) do nothing;

-- Permitir a usuarios autenticados subir fotos
drop policy if exists "auth_upload_photos" on storage.objects;
create policy "auth_upload_photos" on storage.objects for insert
  with check (bucket_id = 'member-photos' and auth.role() = 'authenticated');

drop policy if exists "public_read_photos" on storage.objects;
create policy "public_read_photos" on storage.objects for select
  using (bucket_id = 'member-photos');

-- =====================================================================
-- DATOS SEMILLA (opcional — puedes comentar)
-- =====================================================================
insert into public.families (nombre_familia) values
  ('Familia López'),('Familia García'),('Familia Mendoza')
on conflict do nothing;

insert into public.teams (nombre, descripcion) values
  ('Alabanza','Equipo de música y adoración'),
  ('Diaconía','Servicio y hospitalidad'),
  ('Intercesión','Oración y cobertura espiritual'),
  ('Jóvenes','Ministerio juvenil'),
  ('Niños','Escuela dominical')
on conflict do nothing;

-- =====================================================================
-- FIN DEL SCRIPT
-- =====================================================================
