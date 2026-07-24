-- CDD Kongtunmae — core schema
-- Maps the 24-sheet Google Sheets structure described in Kongtunmae/claude.md onto
-- Postgres tables. See the approved migration plan for the full design rationale.

create extension if not exists pgcrypto;

create type user_role as enum (
  'MEMBER', 'COMMITTEE', 'STAFF', 'DISTRICT_HEAD', 'PROVINCE_MGR', 'PROVINCE_HEAD', 'GOVERNOR'
);

create or replace function set_updated_at() returns trigger
language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

-- ---------------------------------------------------------------------------
-- Reference tables (not in the original 24 sheets — needed so RLS/FKs have a
-- real relational target instead of free-text province/district/subdistrict).
-- ---------------------------------------------------------------------------

create table provinces (
  id bigint generated always as identity primary key,
  code text unique not null,
  name_th text not null
);

create table districts (
  id bigint generated always as identity primary key,
  province_id bigint not null references provinces (id),
  code text not null,
  name_th text not null,
  unique (province_id, code)
);

create table subdistricts (
  id bigint generated always as identity primary key,
  district_id bigint not null references districts (id),
  code text not null,
  name_th text not null,
  unique (district_id, code)
);

-- MOM Quest step thresholds are real data given in the spec, not mock.
create table mom_quest_steps (
  step_no smallint primary key check (step_no between 1 and 10),
  name_th text not null,
  pass_threshold_count smallint not null default 1,
  is_cumulative boolean not null default false
);

-- ---------------------------------------------------------------------------
-- Master-data sheets (seeded with placeholder rows in seed.sql — no source
-- xlsx exists yet, every mock row is TODO-marked there).
-- ---------------------------------------------------------------------------

create table village_master (
  id bigint generated always as identity primary key,
  subdistrict_id bigint not null references subdistricts (id),
  village_code text unique not null, -- 11-digit central-format code (จ2+อ2+ต2+หมู่3+suffix2)
  moo_no smallint not null,
  name_th text not null,
  lat numeric(9, 6),
  lng numeric(9, 6),
  founding_year smallint, -- TODO: confirm Buddhist vs Gregorian era once real data arrives
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

create table activities_type (
  id bigint generated always as identity primary key,
  code text unique not null,
  name_th text not null,
  category_th text not null,
  score int not null,
  bonus_point int not null default 0,
  weight numeric(4, 2) not null default 1,
  innovation_point int not null default 0,
  mom_quest_step_no smallint references mom_quest_steps (step_no),
  is_active boolean not null default true
);

-- Structure is a hard business rule (10 automatic + 9 manual = 19 total);
-- enforced by seed-data discipline since only migrations/service_role write here.
create table health_check_indicators (
  id bigint generated always as identity primary key,
  item_no smallint unique not null,
  description_th text not null,
  kind text not null check (kind in ('AUTO', 'MANUAL')),
  is_active boolean not null default true
);

create table partner_agency_options (
  id bigint generated always as identity primary key,
  name_th text not null,
  is_active boolean not null default true
);

-- Key/value, not fixed columns: config values are heterogeneous in type and
-- "National Template Ready" means changing a value must never require a migration.
create table system_config (
  key text primary key,
  value text not null,
  value_type text not null check (value_type in ('int', 'text', 'date_range', 'list')),
  description_th text,
  updated_at timestamptz not null default now()
);

create trigger system_config_set_updated_at
  before update on system_config
  for each row execute function set_updated_at();

create table staff_whitelist (
  id bigint generated always as identity primary key,
  phone text unique not null,
  role user_role not null,
  district_id bigint references districts (id),
  is_used boolean not null default false,
  created_at timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- users — transactional, but referenced by nearly everything below.
-- ---------------------------------------------------------------------------

create table users (
  id uuid primary key default gen_random_uuid(),
  line_user_id text unique not null,
  display_name text,
  phone text,
  role user_role not null default 'MEMBER',
  village_id bigint references village_master (id),
  district_id bigint references districts (id),
  status text not null default 'ACTIVE' check (status in ('ACTIVE', 'SUSPENDED')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  -- MEMBER/COMMITTEE may have village_id = null transiently between LIFF login
  -- and completing the village-selection step on the signup screen; the app
  -- (not the DB) gates write access until that's filled in. STAFF+ roles are
  -- assigned atomically from staff_whitelist, so no such transient state applies.
  constraint users_scope_matches_role check (
    (role in ('MEMBER', 'COMMITTEE'))
    or (role in ('STAFF', 'DISTRICT_HEAD') and district_id is not null)
    or (role in ('PROVINCE_MGR', 'PROVINCE_HEAD', 'GOVERNOR') and village_id is null and district_id is null)
  )
);

create trigger users_set_updated_at
  before update on users
  for each row execute function set_updated_at();

create table sessions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references users (id) on delete cascade,
  refresh_token_hash text not null,
  expires_at timestamptz not null,
  revoked_at timestamptz,
  created_at timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- Remaining master-data sheets that reference users.
-- ---------------------------------------------------------------------------

create table village_awards (
  id bigint generated always as identity primary key,
  village_id bigint not null references village_master (id),
  awarding_agency_th text,
  award_name_th text not null,
  award_level text,
  award_date date,
  description text,
  created_by uuid references users (id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create trigger village_awards_set_updated_at
  before update on village_awards
  for each row execute function set_updated_at();

create table system_issues (
  id bigint generated always as identity primary key,
  reporter_user_id uuid references users (id),
  category text not null,
  description text not null,
  severity text,
  status text not null default 'OPEN' check (status in ('OPEN', 'IN_PROGRESS', 'RESOLVED', 'CLOSED')),
  resolved_by uuid references users (id),
  created_at timestamptz not null default now(),
  resolved_at timestamptz
);

-- ---------------------------------------------------------------------------
-- Transactional sheets (empty structure, no real data yet).
-- ---------------------------------------------------------------------------

create table activities (
  id bigint generated always as identity primary key,
  village_id bigint not null references village_master (id),
  district_id bigint not null references districts (id), -- denormalized ID (not a label) so RLS district-scoping avoids a join
  activity_type_id bigint not null references activities_type (id),
  activity_date date not null,
  recorded_by uuid not null references users (id),
  lat numeric(9, 6),
  lng numeric(9, 6),
  notes text,
  score_frozen int not null,
  innovation_point_frozen int not null,
  bonus_point_frozen int not null,
  weight_frozen numeric(4, 2) not null,
  total_score_frozen numeric(10, 2) generated always as
    ((score_frozen + innovation_point_frozen) * weight_frozen + bonus_point_frozen) stored,
  status text not null default 'SUBMITTED'
    check (status in ('SUBMITTED', 'SPOT_CHECK_FLAGGED', 'VERIFIED', 'REJECTED')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint activities_no_same_type_same_day unique (village_id, activity_type_id, activity_date)
);

create trigger activities_set_updated_at
  before update on activities
  for each row execute function set_updated_at();

-- Auto-fill district_id from the village's subdistrict chain so callers never
-- have to supply it (and can't spoof a district that doesn't match the village).
create or replace function activities_fill_district_id() returns trigger
language plpgsql as $$
begin
  select d.id into new.district_id
  from village_master v
  join subdistricts s on s.id = v.subdistrict_id
  join districts d on d.id = s.district_id
  where v.id = new.village_id;
  return new;
end;
$$;

create trigger activities_before_insert_fill_district
  before insert on activities
  for each row execute function activities_fill_district_id();

create table activity_media (
  id bigint generated always as identity primary key,
  activity_id bigint not null references activities (id) on delete cascade,
  storage_path text not null,
  media_type text not null check (media_type in ('PHOTO', 'VIDEO')),
  file_size_bytes bigint,
  uploaded_at timestamptz not null default now()
);

-- Enforces PhotoMaxPerActivity from system_config (a real limit from the spec,
-- not speculative) — Postgres CHECK can't count sibling rows, so this needs a trigger.
create or replace function activity_media_enforce_photo_cap() returns trigger
language plpgsql as $$
declare
  max_photos int;
  current_count int;
begin
  if new.media_type <> 'PHOTO' then
    return new;
  end if;

  select value::int into max_photos from system_config where key = 'PhotoMaxPerActivity';
  select count(*) into current_count from activity_media
    where activity_id = new.activity_id and media_type = 'PHOTO';

  if max_photos is not null and current_count >= max_photos then
    raise exception 'เกินจำนวนรูปภาพสูงสุดต่อกิจกรรม (% รูป)', max_photos
      using errcode = 'check_violation';
  end if;

  return new;
end;
$$;

create trigger activity_media_before_insert_cap
  before insert on activity_media
  for each row execute function activity_media_enforce_photo_cap();

create table activity_network_partners (
  id bigint generated always as identity primary key,
  activity_id bigint not null references activities (id) on delete cascade,
  partner_agency_id bigint not null references partner_agency_options (id),
  note text
);

create table health_check_form (
  id bigint generated always as identity primary key,
  village_id bigint not null references village_master (id),
  eval_year int not null, -- previous calendar year, per business rule
  indicator_id bigint not null references health_check_indicators (id),
  answer_value text,
  submitted_by uuid references users (id),
  submitted_at timestamptz not null default now(),
  unique (village_id, eval_year, indicator_id)
);

create table health_check_assessment (
  id bigint generated always as identity primary key,
  village_id bigint not null references village_master (id),
  eval_year int not null,
  indicators_passed_count smallint,
  indicators_total smallint not null default 19,
  percentage numeric(5, 2),
  grade text check (grade in ('A', 'B', 'C')), -- A>=80% / B 50-79% / C<50%
  assessed_at timestamptz not null default now(),
  assessed_by uuid references users (id),
  unique (village_id, eval_year)
);

create table health_check_assessment_items (
  id bigint generated always as identity primary key,
  assessment_id bigint not null references health_check_assessment (id) on delete cascade,
  indicator_id bigint not null references health_check_indicators (id),
  is_pass boolean not null,
  value text,
  source text not null check (source in ('AUTO', 'MANUAL')),
  unique (assessment_id, indicator_id)
);

create table health_check_action_plan (
  id bigint generated always as identity primary key,
  village_id bigint not null references village_master (id),
  plan_year int not null,
  seq_no smallint not null check (seq_no between 1 and 10),
  activity_type_id bigint references activities_type (id),
  planned_date date,
  status text not null default 'PLANNED' check (status in ('PLANNED', 'DONE', 'CANCELLED')),
  linked_activity_id bigint references activities (id),
  created_by uuid references users (id),
  created_at timestamptz not null default now(),
  unique (village_id, plan_year, seq_no)
);

create table fund_signatories (
  id bigint generated always as identity primary key,
  village_id bigint not null references village_master (id),
  eval_year int not null,
  signatory_name text not null,
  position_th text,
  signature_order smallint,
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

-- Populated only by a background rollup job (service_role) — never written by app roles.
create table village_score (
  id bigint generated always as identity primary key,
  village_id bigint not null references village_master (id),
  period_year int not null,
  period_month smallint,
  total_score numeric not null default 0,
  activity_count int not null default 0,
  mom_quest_current_step smallint,
  rank_in_district int,
  rank_in_province int,
  computed_at timestamptz not null default now()
);

create table district_summary (
  id bigint generated always as identity primary key,
  district_id bigint not null references districts (id),
  period_year int not null,
  period_month smallint,
  total_activities int not null default 0,
  total_score numeric not null default 0,
  village_count int not null default 0,
  avg_score numeric,
  computed_at timestamptz not null default now()
);

create table monthly_summary (
  id bigint generated always as identity primary key,
  period_year int not null,
  period_month smallint not null,
  total_activities int not null default 0,
  total_score numeric not null default 0,
  active_village_count int not null default 0,
  computed_at timestamptz not null default now(),
  unique (period_year, period_month)
);

-- Ghost Mode — must never contain any identifying column (no reporter_user_id,
-- line_user_id, auth_uid, or IP). This is a schema-level guarantee.
create table anonymousreports (
  id bigint generated always as identity primary key,
  village_id bigint references village_master (id),
  category text not null,
  description text not null,
  incident_lat numeric(9, 6),
  incident_lng numeric(9, 6),
  media_storage_paths text[],
  status text not null default 'NEW' check (status in ('NEW', 'REVIEWING', 'CONFIRMED', 'DISMISSED')),
  reviewed_by uuid references users (id),
  reviewed_at timestamptz,
  created_at timestamptz not null default now()
);

create table notification_log (
  id bigint generated always as identity primary key,
  recipient_user_id uuid not null references users (id),
  channel text not null check (channel in ('LINE_PUSH', 'IN_APP', 'SYSTEM')),
  title text not null,
  body text,
  related_entity_type text,
  related_entity_id bigint,
  is_read boolean not null default false,
  sent_at timestamptz not null default now(),
  read_at timestamptz
);

create table certificates_issued (
  id bigint generated always as identity primary key,
  village_id bigint not null references village_master (id),
  certificate_type text not null,
  title_th text not null,
  issued_date date not null,
  issued_by uuid references users (id),
  pdf_storage_path text,
  related_award_id bigint references village_awards (id),
  created_at timestamptz not null default now()
);

-- Optional sheet per spec — nullable-heavy on purpose, never required to use the main system.
create table household_members (
  id bigint generated always as identity primary key,
  village_id bigint not null references village_master (id),
  household_no text,
  member_name text,
  role_in_household text,
  phone text,
  is_fund_member boolean,
  joined_at date,
  notes text,
  created_by uuid references users (id),
  created_at timestamptz not null default now()
);

create table fund_expenditure (
  id bigint generated always as identity primary key,
  village_id bigint not null references village_master (id),
  eval_year int not null,
  expenditure_date date not null,
  category text not null,
  amount numeric(12, 2) not null,
  description text,
  approved_by uuid references users (id),
  receipt_storage_path text,
  created_by uuid not null references users (id),
  created_at timestamptz not null default now()
);

-- Inferred 24th sheet (TODO: confirm real name once the source xlsx is available).
-- Two-actor flow: DISTRICT_HEAD nominates, PROVINCE_HEAD confirms — distinct states.
create table model_village_candidates (
  id bigint generated always as identity primary key,
  village_id bigint not null references village_master (id),
  cycle_year int not null,
  nominated_by uuid not null references users (id),
  nominated_at timestamptz not null default now(),
  status text not null default 'NOMINATED' check (status in ('NOMINATED', 'CONFIRMED', 'REJECTED')),
  confirmed_by uuid references users (id),
  confirmed_at timestamptz,
  rejection_reason text,
  unique (village_id, cycle_year)
);
