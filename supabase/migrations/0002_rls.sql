-- CDD Kongtunmae — Row Level Security
-- Identity comes from a custom-minted JWT (see lib/auth), not Supabase Auth's
-- auth.uid() — claims live under app_metadata: app_role, village_id, district_id.
-- service_role bypasses RLS entirely (used for signup role-elevation and rollup jobs).

create or replace function auth_role() returns user_role
language sql stable as $$
  select nullif(auth.jwt() -> 'app_metadata' ->> 'app_role', '')::user_role
$$;

create or replace function auth_village_id() returns bigint
language sql stable as $$
  select nullif(auth.jwt() -> 'app_metadata' ->> 'village_id', '')::bigint
$$;

create or replace function auth_district_id() returns bigint
language sql stable as $$
  select nullif(auth.jwt() -> 'app_metadata' ->> 'district_id', '')::bigint
$$;

create or replace function auth_app_user_id() returns uuid
language sql stable as $$
  select nullif(auth.jwt() ->> 'sub', '')::uuid
$$;

-- Looks up a village's district without callers needing to know the
-- subdistrict/district join chain — used by tables that only store village_id.
create or replace function village_district_id(v_id bigint) returns bigint
language sql stable as $$
  select d.id from village_master v
  join subdistricts s on s.id = v.subdistrict_id
  join districts d on d.id = s.district_id
  where v.id = v_id
$$;

-- ---------------------------------------------------------------------------
-- Enable RLS everywhere. Tables with no policy below are default-deny for the
-- `authenticated` role and reachable only via the service_role admin client.
-- ---------------------------------------------------------------------------

alter table provinces enable row level security;
alter table districts enable row level security;
alter table subdistricts enable row level security;
alter table mom_quest_steps enable row level security;
alter table village_master enable row level security;
alter table activities_type enable row level security;
alter table health_check_indicators enable row level security;
alter table partner_agency_options enable row level security;
alter table system_config enable row level security;
alter table staff_whitelist enable row level security;
alter table users enable row level security;
alter table sessions enable row level security;
alter table village_awards enable row level security;
alter table system_issues enable row level security;
alter table activities enable row level security;
alter table activity_media enable row level security;
alter table activity_network_partners enable row level security;
alter table health_check_form enable row level security;
alter table health_check_assessment enable row level security;
alter table health_check_assessment_items enable row level security;
alter table health_check_action_plan enable row level security;
alter table fund_signatories enable row level security;
alter table fund_expenditure enable row level security;
alter table household_members enable row level security;
alter table village_score enable row level security;
alter table district_summary enable row level security;
alter table monthly_summary enable row level security;
alter table anonymousreports enable row level security;
alter table notification_log enable row level security;
alter table certificates_issued enable row level security;
alter table model_village_candidates enable row level security;

-- ---------------------------------------------------------------------------
-- Shape B — province-wide reference/master data: readable by every
-- authenticated role (needed for dropdowns even by MEMBER); no app-role writes.
-- ---------------------------------------------------------------------------

create policy shape_b_select on provinces for select using (auth_role() is not null);
create policy shape_b_select on districts for select using (auth_role() is not null);
create policy shape_b_select on subdistricts for select using (auth_role() is not null);
create policy shape_b_select on mom_quest_steps for select using (auth_role() is not null);
create policy shape_b_select on village_master for select using (auth_role() is not null);
create policy shape_b_select on activities_type for select using (auth_role() is not null);
create policy shape_b_select on health_check_indicators for select using (auth_role() is not null);
create policy shape_b_select on partner_agency_options for select using (auth_role() is not null);
create policy shape_b_select on system_config for select using (auth_role() is not null);

-- staff_whitelist: no policies at all — service_role only (contains phone -> role mapping).

-- ---------------------------------------------------------------------------
-- users — self-service is limited to reading; role/village/district assignment
-- and profile edits go through SECURITY DEFINER RPCs, never direct table grants.
-- ---------------------------------------------------------------------------

create policy users_select_self on users for select using (id = auth_app_user_id());

create policy users_select_district on users for select using (
  auth_role() in ('STAFF', 'DISTRICT_HEAD') and district_id = auth_district_id()
);

create policy users_select_province on users for select using (
  auth_role() in ('PROVINCE_MGR', 'PROVINCE_HEAD', 'GOVERNOR')
);

create or replace function update_own_display_name(new_display_name text) returns void
security definer set search_path = public
language plpgsql as $$
begin
  update users set display_name = new_display_name, updated_at = now()
  where id = auth_app_user_id();
end;
$$;

-- sessions: no policies — service_role only (session issuance/revocation is server-side).

-- ---------------------------------------------------------------------------
-- Shape C — village_awards: publicly readable recognition, writes restricted
-- to exactly one role.
-- ---------------------------------------------------------------------------

create policy awards_select on village_awards for select using (auth_role() is not null);

create policy awards_write on village_awards for all
  using (auth_role() = 'PROVINCE_MGR')
  with check (auth_role() = 'PROVINCE_MGR');

-- ---------------------------------------------------------------------------
-- Shape D — system_issues: self-report / triage.
-- ---------------------------------------------------------------------------

create policy issues_insert_own on system_issues for insert
  with check (reporter_user_id = auth_app_user_id());

create policy issues_select_own on system_issues for select
  using (reporter_user_id = auth_app_user_id());

create policy issues_select_staff on system_issues for select
  using (auth_role() in ('STAFF', 'DISTRICT_HEAD', 'PROVINCE_MGR', 'PROVINCE_HEAD', 'GOVERNOR'));

-- ---------------------------------------------------------------------------
-- Shape A — village/district-scoped operational data. GOVERNOR never appears
-- in a write policy anywhere in this file (strict read-only, per spec).
-- ---------------------------------------------------------------------------

create policy activities_select on activities for select using (
  auth_role() in ('PROVINCE_MGR', 'PROVINCE_HEAD', 'GOVERNOR')
  or (auth_role() in ('STAFF', 'DISTRICT_HEAD') and district_id = auth_district_id())
  or (auth_role() in ('MEMBER', 'COMMITTEE') and village_id = auth_village_id())
);

create policy activities_insert on activities for insert
  with check (auth_role() = 'COMMITTEE' and village_id = auth_village_id());

create policy activity_media_select on activity_media for select using (
  exists (
    select 1 from activities a where a.id = activity_media.activity_id
    and (
      auth_role() in ('PROVINCE_MGR', 'PROVINCE_HEAD', 'GOVERNOR')
      or (auth_role() in ('STAFF', 'DISTRICT_HEAD') and a.district_id = auth_district_id())
      or (auth_role() in ('MEMBER', 'COMMITTEE') and a.village_id = auth_village_id())
    )
  )
);

create policy activity_media_insert on activity_media for insert
  with check (
    auth_role() = 'COMMITTEE'
    and exists (
      select 1 from activities a
      where a.id = activity_media.activity_id and a.village_id = auth_village_id()
    )
  );

create policy activity_network_partners_select on activity_network_partners for select using (
  exists (
    select 1 from activities a where a.id = activity_network_partners.activity_id
    and (
      auth_role() in ('PROVINCE_MGR', 'PROVINCE_HEAD', 'GOVERNOR')
      or (auth_role() in ('STAFF', 'DISTRICT_HEAD') and a.district_id = auth_district_id())
      or (auth_role() in ('MEMBER', 'COMMITTEE') and a.village_id = auth_village_id())
    )
  )
);

create policy activity_network_partners_insert on activity_network_partners for insert
  with check (
    auth_role() = 'COMMITTEE'
    and exists (
      select 1 from activities a
      where a.id = activity_network_partners.activity_id and a.village_id = auth_village_id()
    )
  );

create policy health_check_form_select on health_check_form for select using (
  auth_role() in ('PROVINCE_MGR', 'PROVINCE_HEAD', 'GOVERNOR')
  or (auth_role() in ('STAFF', 'DISTRICT_HEAD') and village_district_id(village_id) = auth_district_id())
  or (auth_role() in ('MEMBER', 'COMMITTEE') and village_id = auth_village_id())
);

create policy health_check_form_insert on health_check_form for insert
  with check (auth_role() = 'COMMITTEE' and village_id = auth_village_id());

create policy health_check_assessment_select on health_check_assessment for select using (
  auth_role() in ('PROVINCE_MGR', 'PROVINCE_HEAD', 'GOVERNOR')
  or (auth_role() in ('STAFF', 'DISTRICT_HEAD') and village_district_id(village_id) = auth_district_id())
  or (auth_role() in ('MEMBER', 'COMMITTEE') and village_id = auth_village_id())
);
-- No insert/update policy: assessments are computed by a service-role job, not entered directly.

create policy health_check_assessment_items_select on health_check_assessment_items for select using (
  exists (
    select 1 from health_check_assessment hca where hca.id = health_check_assessment_items.assessment_id
    and (
      auth_role() in ('PROVINCE_MGR', 'PROVINCE_HEAD', 'GOVERNOR')
      or (auth_role() in ('STAFF', 'DISTRICT_HEAD') and village_district_id(hca.village_id) = auth_district_id())
      or (auth_role() in ('MEMBER', 'COMMITTEE') and hca.village_id = auth_village_id())
    )
  )
);

create policy action_plan_select on health_check_action_plan for select using (
  auth_role() in ('PROVINCE_MGR', 'PROVINCE_HEAD', 'GOVERNOR')
  or (auth_role() in ('STAFF', 'DISTRICT_HEAD') and village_district_id(village_id) = auth_district_id())
  or (auth_role() in ('MEMBER', 'COMMITTEE') and village_id = auth_village_id())
);

create policy action_plan_write on health_check_action_plan for all
  using (auth_role() = 'COMMITTEE' and village_id = auth_village_id())
  with check (auth_role() = 'COMMITTEE' and village_id = auth_village_id());

create policy fund_signatories_select on fund_signatories for select using (
  auth_role() in ('PROVINCE_MGR', 'PROVINCE_HEAD', 'GOVERNOR')
  or (auth_role() in ('STAFF', 'DISTRICT_HEAD') and village_district_id(village_id) = auth_district_id())
  or (auth_role() in ('MEMBER', 'COMMITTEE') and village_id = auth_village_id())
);

create policy fund_signatories_write on fund_signatories for all
  using (auth_role() = 'COMMITTEE' and village_id = auth_village_id())
  with check (auth_role() = 'COMMITTEE' and village_id = auth_village_id());

create policy fund_expenditure_select on fund_expenditure for select using (
  auth_role() in ('PROVINCE_MGR', 'PROVINCE_HEAD', 'GOVERNOR')
  or (auth_role() in ('STAFF', 'DISTRICT_HEAD') and village_district_id(village_id) = auth_district_id())
  or (auth_role() in ('MEMBER', 'COMMITTEE') and village_id = auth_village_id())
);

create policy fund_expenditure_write on fund_expenditure for all
  using (auth_role() = 'COMMITTEE' and village_id = auth_village_id())
  with check (auth_role() = 'COMMITTEE' and village_id = auth_village_id());

create policy household_members_select on household_members for select using (
  auth_role() in ('PROVINCE_MGR', 'PROVINCE_HEAD', 'GOVERNOR')
  or (auth_role() in ('STAFF', 'DISTRICT_HEAD') and village_district_id(village_id) = auth_district_id())
  or (auth_role() in ('MEMBER', 'COMMITTEE') and village_id = auth_village_id())
);

create policy household_members_write on household_members for all
  using (auth_role() = 'COMMITTEE' and village_id = auth_village_id())
  with check (auth_role() = 'COMMITTEE' and village_id = auth_village_id());

create policy certificates_issued_select on certificates_issued for select using (
  auth_role() in ('PROVINCE_MGR', 'PROVINCE_HEAD', 'GOVERNOR')
  or (auth_role() in ('STAFF', 'DISTRICT_HEAD') and village_district_id(village_id) = auth_district_id())
  or (auth_role() in ('MEMBER', 'COMMITTEE') and village_id = auth_village_id())
);
-- No insert policy yet: issuance flow not built (roadmap phase 6) — service_role only for now.

-- village_score / district_summary / monthly_summary: read-only, populated by a
-- service-role rollup job (not part of this first slice).

create policy village_score_select on village_score for select using (
  auth_role() in ('PROVINCE_MGR', 'PROVINCE_HEAD', 'GOVERNOR')
  or (auth_role() in ('STAFF', 'DISTRICT_HEAD') and village_district_id(village_id) = auth_district_id())
  or (auth_role() in ('MEMBER', 'COMMITTEE') and village_id = auth_village_id())
);

create policy district_summary_select on district_summary for select using (
  auth_role() in ('PROVINCE_MGR', 'PROVINCE_HEAD', 'GOVERNOR')
  or (auth_role() in ('STAFF', 'DISTRICT_HEAD') and district_id = auth_district_id())
);

create policy monthly_summary_select on monthly_summary for select using (
  auth_role() in ('STAFF', 'DISTRICT_HEAD', 'PROVINCE_MGR', 'PROVINCE_HEAD', 'GOVERNOR')
);

-- ---------------------------------------------------------------------------
-- Shape E — Ghost Mode. Insert is unconditional (the identity guarantee is
-- schema-level: no identifying column exists on this table at all).
-- ---------------------------------------------------------------------------

create policy anonymousreports_insert on anonymousreports for insert with check (true);

create policy anonymousreports_select on anonymousreports for select using (
  auth_role() in ('PROVINCE_MGR', 'PROVINCE_HEAD', 'GOVERNOR')
  or (
    auth_role() in ('STAFF', 'DISTRICT_HEAD')
    and (village_id is null or village_district_id(village_id) = auth_district_id())
  )
);

create policy anonymousreports_update on anonymousreports for update
  using (
    auth_role() in ('PROVINCE_MGR', 'PROVINCE_HEAD')
    or (
      auth_role() in ('STAFF', 'DISTRICT_HEAD')
      and (village_id is null or village_district_id(village_id) = auth_district_id())
    )
  )
  with check (true);
-- No policy for MEMBER/COMMITTEE at all on this table beyond the insert above — default-deny.

-- ---------------------------------------------------------------------------
-- notification_log — recipients read their own notifications; writes are
-- system-generated (service_role only).
-- ---------------------------------------------------------------------------

create policy notification_log_select_own on notification_log for select
  using (recipient_user_id = auth_app_user_id());

-- ---------------------------------------------------------------------------
-- Shape F — model_village_candidates: two-actor state machine encoded directly
-- in USING (evaluates the OLD row) vs WITH CHECK (evaluates the NEW row).
-- ---------------------------------------------------------------------------

create policy model_village_select on model_village_candidates for select using (
  auth_role() in ('PROVINCE_MGR', 'PROVINCE_HEAD', 'GOVERNOR', 'STAFF', 'DISTRICT_HEAD')
  or (auth_role() in ('MEMBER', 'COMMITTEE') and village_id = auth_village_id())
);

create policy district_head_nominate on model_village_candidates for insert
  with check (
    auth_role() = 'DISTRICT_HEAD'
    and status = 'NOMINATED'
    and village_district_id(village_id) = auth_district_id()
  );

create policy province_head_confirm on model_village_candidates for update
  using (auth_role() = 'PROVINCE_HEAD' and status = 'NOMINATED')
  with check (status in ('CONFIRMED', 'REJECTED'));
