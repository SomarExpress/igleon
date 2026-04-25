-- =====================================================================
-- ADULAM · PARCHE v1.2
-- Ejecutar en Supabase SQL Editor DESPUÉS de schema.sql y schema-patch-v1.1.sql
--
-- Incluye:
--   1. Rediseño completo de discipulado (cursos, promociones, lecciones)
--   2. Tipos de reunión personalizables (vigilia, ayuno, etc.)
--   3. Relación N:N entre asistencia y servicios (un miembro en varios)
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. TIPOS DE REUNIÓN (personalizables)
-- ---------------------------------------------------------------------
create table if not exists public.meeting_types (
  id          uuid primary key default uuid_generate_v4(),
  codigo      text unique not null, -- 'domingo','vigilia','ayuno', etc.
  nombre      text not null,        -- 'Culto Dominical','Vigilia','Ayuno'
  icono       text default '⛪',
  activo      boolean default true,
  orden       int default 0,
  iglesia_id  uuid references public.churches(id) default '00000000-0000-0000-0000-000000000001',
  created_at  timestamptz not null default now()
);

-- Datos semilla con los tipos que ya existían + algunos comunes
insert into public.meeting_types (codigo, nombre, icono, orden) values
  ('domingo',    'Culto Dominical',  '⛪', 1),
  ('lunes',      'Reunión Lunes',    '📖', 2),
  ('miercoles',  'Reunión Miércoles','🙏', 3),
  ('viernes',    'Reunión Viernes',  '✨', 4),
  ('vigilia',    'Vigilia',          '🌙', 5),
  ('ayuno',      'Ayuno',            '🕊️', 6),
  ('especial',   'Evento Especial',  '🎉', 7)
on conflict (codigo) do nothing;

-- ---------------------------------------------------------------------
-- 2. Migrar attendance y service_plans a usar meeting_types
-- ---------------------------------------------------------------------
-- Agregamos columna nueva que referencia meeting_types.
-- Mantenemos la columna `tipo_reunion` antigua para no romper nada,
-- pero poblamos meeting_type_id donde coincide el código.

-- ATTENDANCE: agregar columna meeting_type_id
alter table public.attendance
  add column if not exists meeting_type_id uuid references public.meeting_types(id) on delete set null;

-- Eliminar el check constraint antiguo para permitir tipos personalizados
alter table public.attendance
  drop constraint if exists attendance_tipo_reunion_check;

-- Popular meeting_type_id basado en el código existente
update public.attendance a
set meeting_type_id = mt.id
from public.meeting_types mt
where a.meeting_type_id is null and a.tipo_reunion = mt.codigo;

-- SERVICE_PLANS: igual
alter table public.service_plans
  add column if not exists meeting_type_id uuid references public.meeting_types(id) on delete set null;

alter table public.service_plans
  drop constraint if exists service_plans_tipo_reunion_check;

update public.service_plans sp
set meeting_type_id = mt.id
from public.meeting_types mt
where sp.meeting_type_id is null and sp.tipo_reunion = mt.codigo;

-- RLS para meeting_types
alter table public.meeting_types enable row level security;

drop policy if exists "meeting_types_select" on public.meeting_types;
drop policy if exists "meeting_types_insert" on public.meeting_types;
drop policy if exists "meeting_types_update" on public.meeting_types;
drop policy if exists "meeting_types_delete" on public.meeting_types;

create policy "meeting_types_select" on public.meeting_types for select using (auth.role() = 'authenticated');
create policy "meeting_types_insert" on public.meeting_types for insert with check (public.get_my_role() in ('pastor','lider'));
create policy "meeting_types_update" on public.meeting_types for update using (public.get_my_role() in ('pastor','lider'));
create policy "meeting_types_delete" on public.meeting_types for delete using (public.get_my_role() = 'pastor');

-- =====================================================================
-- 3. REDISEÑO DE DISCIPULADO
-- =====================================================================
-- La tabla vieja "discipleship" tenía progreso libre; ahora la reemplazamos
-- por un modelo completo: cursos → promociones → lecciones → asistencia.

-- Conservamos la tabla vieja renombrada por si tienes datos
alter table if exists public.discipleship rename to discipleship_legacy;

-- ---------------------------------------------------------------------
-- 3.1 CURSOS (plantillas de discipulado)
-- Ejemplo: "Fiesta de Asnas", "Conociendo el León", "Galaad"
-- ---------------------------------------------------------------------
create table if not exists public.discipleship_courses (
  id             uuid primary key default uuid_generate_v4(),
  nombre         text not null,
  descripcion    text,
  orden          int default 0,        -- para ordenar la ruta de crecimiento
  nivel          int default 1,        -- 1, 2, 3...
  color          text default 'indigo', -- indigo, emerald, amber, violet
  icono          text default '📖',
  min_asistencia int default 80,       -- % mínimo para aprobar
  nota_minima    numeric(4,2) default 70, -- nota mínima para aprobar
  activo         boolean default true,
  iglesia_id     uuid references public.churches(id) default '00000000-0000-0000-0000-000000000001',
  created_at     timestamptz not null default now()
);

-- ---------------------------------------------------------------------
-- 3.2 LECCIONES del curso
-- ---------------------------------------------------------------------
create table if not exists public.discipleship_lessons (
  id               uuid primary key default uuid_generate_v4(),
  course_id        uuid not null references public.discipleship_courses(id) on delete cascade,
  numero           int not null,          -- 1, 2, 3...
  titulo           text not null,
  descripcion      text,
  contenido        text,                  -- notas/guion
  pdf_url          text,                  -- enlace a PDF (Drive, Dropbox, o subido)
  video_url        text,                  -- YouTube, Vimeo, etc.
  material_extra   text,                  -- links adicionales
  created_at       timestamptz not null default now(),
  unique (course_id, numero)
);

-- ---------------------------------------------------------------------
-- 3.3 PROMOCIONES (aperturas del curso en una temporada)
-- Ejemplo: "Fiesta de Asnas - Enero 2026", "Galaad - Abril 2026"
-- ---------------------------------------------------------------------
create table if not exists public.discipleship_cohorts (
  id            uuid primary key default uuid_generate_v4(),
  course_id     uuid not null references public.discipleship_courses(id) on delete cascade,
  nombre        text not null,  -- 'Enero 2026', 'Primera promoción'
  fecha_inicio  date,
  fecha_fin     date,
  maestro_id    uuid references public.members(id) on delete set null,
  estado        text default 'activo' check (estado in ('activo','finalizado','cancelado')),
  notas         text,
  iglesia_id    uuid references public.churches(id) default '00000000-0000-0000-0000-000000000001',
  created_at    timestamptz not null default now()
);

-- ---------------------------------------------------------------------
-- 3.4 PARTICIPANTES de una promoción
-- ---------------------------------------------------------------------
create table if not exists public.discipleship_participants (
  id          uuid primary key default uuid_generate_v4(),
  cohort_id   uuid not null references public.discipleship_cohorts(id) on delete cascade,
  member_id   uuid not null references public.members(id) on delete cascade,
  nota_final  numeric(4,2),  -- calificación final manual
  aprobado    boolean,       -- se calcula automáticamente o manual
  diploma_generado boolean default false,
  observaciones text,
  created_at  timestamptz not null default now(),
  unique (cohort_id, member_id)
);

-- ---------------------------------------------------------------------
-- 3.5 ASISTENCIA a lecciones (por promoción)
-- ---------------------------------------------------------------------
create table if not exists public.discipleship_attendance (
  id           uuid primary key default uuid_generate_v4(),
  cohort_id    uuid not null references public.discipleship_cohorts(id) on delete cascade,
  lesson_id    uuid not null references public.discipleship_lessons(id) on delete cascade,
  member_id    uuid not null references public.members(id) on delete cascade,
  asistio      boolean not null default false,
  fecha        date,
  nota_leccion numeric(4,2), -- nota opcional por lección
  created_at   timestamptz not null default now(),
  unique (cohort_id, lesson_id, member_id)
);

create index if not exists idx_disc_att_cohort on public.discipleship_attendance(cohort_id);
create index if not exists idx_disc_att_member on public.discipleship_attendance(member_id);

-- ---------------------------------------------------------------------
-- 3.6 Vista de progreso por participante (calcula % asistencia)
-- ---------------------------------------------------------------------
create or replace view public.v_discipleship_progress as
select
  p.id                 as participant_id,
  p.cohort_id,
  p.member_id,
  m.nombre             as miembro_nombre,
  c.id                 as course_id,
  c.nombre             as curso_nombre,
  c.min_asistencia     as curso_min_asistencia,
  c.nota_minima        as curso_nota_minima,
  co.nombre            as cohort_nombre,
  co.estado            as cohort_estado,
  (select count(*) from public.discipleship_lessons l where l.course_id = c.id) as total_lecciones,
  (select count(*) from public.discipleship_attendance da
     where da.cohort_id = p.cohort_id and da.member_id = p.member_id and da.asistio = true) as asistencias,
  case
    when (select count(*) from public.discipleship_lessons l where l.course_id = c.id) = 0 then 0
    else round(
      (select count(*) from public.discipleship_attendance da
         where da.cohort_id = p.cohort_id and da.member_id = p.member_id and da.asistio = true)::numeric * 100
      /
      (select count(*) from public.discipleship_lessons l where l.course_id = c.id), 1)
  end as porcentaje_asistencia,
  p.nota_final,
  p.aprobado,
  p.diploma_generado
from public.discipleship_participants p
join public.members m on m.id = p.member_id
join public.discipleship_cohorts co on co.id = p.cohort_id
join public.discipleship_courses c on c.id = co.course_id;

-- ---------------------------------------------------------------------
-- 3.7 RLS discipulado
-- ---------------------------------------------------------------------
do $$
declare
  t text;
  tablas text[] := array[
    'discipleship_courses','discipleship_lessons','discipleship_cohorts',
    'discipleship_participants','discipleship_attendance'
  ];
begin
  foreach t in array tablas loop
    execute format('alter table public.%I enable row level security', t);
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
      using (public.get_my_role() in ('pastor','lider','servidor'))
    $p$, t);
    execute format($p$
      create policy "%1$s_delete" on public.%1$s for delete
      using (public.get_my_role() in ('pastor','lider'))
    $p$, t);
  end loop;
end $$;

-- ---------------------------------------------------------------------
-- 3.8 Datos semilla de cursos según ADULAM
-- ---------------------------------------------------------------------
insert into public.discipleship_courses (nombre, descripcion, orden, nivel, color, icono, min_asistencia, nota_minima) values
  ('Fiesta de Asnas',     'Charla intensiva de un día para proceder al bautismo.', 1, 1, 'amber',   '🫏', 100, 70),
  ('Conociendo el León',  'Etapa de fundamentos de la fe después del bautismo.',   2, 2, 'indigo',  '🦁', 80,  70),
  ('Subiendo a Galaad',   'Formación para el servicio y liderazgo.',               3, 3, 'emerald', '⛰️',  80,  75)
on conflict do nothing;

-- ---------------------------------------------------------------------
-- 3.9 Actualizar vista v_dashboard para usar el nuevo modelo
-- ---------------------------------------------------------------------
create or replace view public.v_dashboard as
select
  (select count(*) from public.members where estado_espiritual <> 'inactivo') as total_miembros,
  (select count(*) from public.members where estado_espiritual = 'nuevo'
     and created_at > now() - interval '30 days')                              as nuevos_miembros,
  (select count(distinct member_id) from public.discipleship_participants p
     join public.discipleship_cohorts co on co.id = p.cohort_id
     where co.estado = 'activo')                                               as en_discipulado,
  (select count(*) from public.members where estado_espiritual = 'inactivo')   as inactivos,
  (select count(distinct member_id) from public.attendance
     where asistio = true and fecha > now() - interval '7 days')               as asistencia_semanal,
  (select coalesce(sum(case when tipo='ingreso' then monto else -monto end),0)
     from public.treasury
     where fecha >= date_trunc('month', current_date))                         as balance_mes;

-- =====================================================================
-- FIN DEL PARCHE v1.2
-- =====================================================================
