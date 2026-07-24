-- CDD Kongtunmae — seed data
--
-- Real data (kept as-is, from Kongtunmae/claude.md): province name, the 8 Chumphon
-- districts (public administrative divisions), the 13 System_Config keys, and the
-- 10 MOM Quest step definitions.
--
-- Everything else (subdistricts, villages, activity types, health check indicator
-- wording, partner agencies, staff whitelist phone numbers) is MOCK PLACEHOLDER
-- DATA — no source xlsx exists yet (see plan doc). Every mock row is TODO-marked
-- below per the project's own convention: never let mock data pass as real.

insert into provinces (code, name_th) values ('86', 'ชุมพร');

insert into districts (province_id, code, name_th)
select p.id, code, name_th from provinces p, (values
  ('01', 'เมืองชุมพร'),
  ('02', 'ท่าแซะ'),
  ('03', 'ปะทิว'),
  ('04', 'สวี'),
  ('05', 'ทุ่งตะโก'),
  ('06', 'หลังสวน'),
  ('07', 'ละแม'),
  ('08', 'พะโต๊ะ')
) as d(code, name_th)
where p.code = '86';

-- TODO(mock): subdistrict names are placeholders (1 per district) — replace once
-- the real Village_Master sheet / central-format village list is available.
insert into subdistricts (district_id, code, name_th)
select d.id, '01', 'ตำบลตัวอย่าง ' || d.name_th from districts d;

-- Real data — verbatim from Kongtunmae/claude.md §MOM Quest.
insert into mom_quest_steps (step_no, name_th, pass_threshold_count, is_cumulative) values
  (1, 'ปฐมนิเทศทำความเข้าใจโครงการ', 1, false),
  (2, 'จัดตั้งคณะกรรมการกองทุนแม่', 1, false),
  (3, 'รับสมัครครัวเรือนสมาชิก', 1, false),
  (4, 'จัดทำกฎชุมชนเข้มแข็ง', 1, false),
  (5, 'เวทีสร้างความเข้าใจ', 1, false),
  (6, 'บริหารเงินกองทุน (ทุนศรัทธา/ผ้าป่า)', 3, true),
  (7, 'ประชาคมคัดแยกโดยสันติวิธี', 1, false),
  (8, 'ป้องกัน เฝ้าระวัง และบำบัดฟื้นฟู', 5, true),
  (9, 'รับรองผลและวันกองทุนแม่', 1, false),
  (10, 'ติดตามประเมินผลสู่ต้นแบบ', 3, true);

-- Real data — verbatim from Kongtunmae/claude.md §System_Config (13 keys).
insert into system_config (key, value, value_type, description_th) values
  ('StagnationThresholdDays', '30', 'int', 'จำนวนวันก่อนถือว่าหมู่บ้านหยุดนิ่ง'),
  ('PhotoMaxPerActivity', '10', 'int', 'จำนวนรูปสูงสุดต่อกิจกรรม'),
  ('VideoMaxSizeMB', '100', 'int', 'ขนาดวิดีโอสูงสุด (MB)'),
  ('AppVersion', '1.0.0', 'text', 'เวอร์ชันแอปพลิเคชัน'),
  ('HealthCheckAssessmentWindow', '01-01 to 03-31', 'date_range', 'ช่วงเวลาตรวจสุขภาพกองทุน'),
  ('HealthCheckEvalYearBasis', 'ปีปฏิทินก่อนหน้า (1 ม.ค. - 31 ธ.ค.)', 'text', 'ฐานปีที่ใช้ประเมิน'),
  ('HouseholdMembersSheetStatus', 'ไม่บังคับ (Optional)', 'text', 'สถานะการบังคับกรอกครัวเรือน'),
  ('DataRetentionPolicy', 'เก็บ 2 ปีล่าสุดในไฟล์หลัก', 'text', 'นโยบายเก็บข้อมูล'),
  ('ArchiveTiming', 'ช่วงเดียวกับตรวจสุขภาพ (ม.ค.-31 มี.ค.)', 'date_range', 'ช่วงเวลา archive'),
  ('ArchiveSheets', 'Activities, Activity_Media, Activity_Network_Partners, Notification_Log, Fund_Expenditure', 'list', 'ตารางที่ archive'),
  ('NonArchiveSheets', 'Village_Master, Activities_Type, Users, Village_Score, District_Summary, Health_Check_Assessment, Certificates_Issued', 'list', 'ตารางที่ไม่ archive'),
  ('ArchiveFileNaming', 'Click_Chumphon_360_Archive_[ปี].xlsx', 'text', 'รูปแบบชื่อไฟล์ archive (TODO: ปรับชื่อให้ตรงระบบใหม่)');

-- TODO(mock): 12 placeholder villages (real sheet has 336) — 4 villages each in
-- the first 3 districts' (mock) subdistricts, fake GPS within Chumphon's rough
-- bounding box, fake founding years. Replace once the real Village_Master data
-- is available.
insert into village_master (subdistrict_id, village_code, moo_no, name_th, lat, lng, founding_year)
select
  s.id,
  '86' || d.code || '01' || lpad(v.moo_no::text, 3, '0') || '01',
  v.moo_no,
  'หมู่บ้านตัวอย่าง ' || v.moo_no || ' ต.' || s.name_th,
  10.49 + (random() * 0.6),
  99.18 + (random() * 0.4),
  2540 + (v.moo_no % 20)
from subdistricts s
join districts d on d.id = s.district_id
cross join generate_series(1, 4) as v(moo_no)
where d.code in ('01', '02', '03');

-- TODO(mock): 10 placeholder activity types (real sheet has 80 active types with
-- real score/bonus/weight/innovation formulas) — mapped across all 10 MOM Quest steps.
insert into activities_type (code, name_th, category_th, score, bonus_point, weight, innovation_point, mom_quest_step_no) values
  ('ACT-01', 'กิจกรรมปฐมนิเทศโครงการ (ตัวอย่าง)', 'ปฐมนิเทศ', 10, 0, 1.0, 0, 1),
  ('ACT-02', 'กิจกรรมจัดตั้งคณะกรรมการ (ตัวอย่าง)', 'โครงสร้าง', 15, 0, 1.0, 0, 2),
  ('ACT-03', 'กิจกรรมรับสมัครสมาชิก (ตัวอย่าง)', 'สมาชิก', 10, 0, 1.0, 0, 3),
  ('ACT-04', 'กิจกรรมจัดทำกฎชุมชน (ตัวอย่าง)', 'กฎระเบียบ', 12, 0, 1.0, 0, 4),
  ('ACT-05', 'กิจกรรมเวทีสร้างความเข้าใจ (ตัวอย่าง)', 'เวทีชุมชน', 10, 0, 1.0, 0, 5),
  ('ACT-06', 'กิจกรรมทอดผ้าป่าสมทบกองทุน (ตัวอย่าง)', 'การเงิน', 20, 5, 1.2, 0, 6),
  ('ACT-07', 'กิจกรรมประชาคมคัดแยก (ตัวอย่าง)', 'ประชาคม', 15, 0, 1.0, 0, 7),
  ('ACT-08', 'กิจกรรมเฝ้าระวังยาเสพติด (ตัวอย่าง)', 'เฝ้าระวัง', 15, 0, 1.1, 0, 8),
  ('ACT-09', 'กิจกรรมวันกองทุนแม่ (ตัวอย่าง)', 'พิธีการ', 20, 10, 1.0, 5, 9),
  ('ACT-10', 'กิจกรรมติดตามประเมินผล (ตัวอย่าง)', 'ติดตามผล', 10, 0, 1.0, 0, 10);

-- TODO(mock): 19 placeholder health check indicators (10 automatic + 9 manual per
-- the spec's hard rule) — real wording lives in the source xlsx, not available yet.
insert into health_check_indicators (item_no, description_th, kind)
select n, 'ตัวชี้วัดอัตโนมัติที่ ' || n || ' (ตัวอย่าง)', 'AUTO' from generate_series(1, 10) as n;

insert into health_check_indicators (item_no, description_th, kind)
select n, 'ตัวชี้วัดกรอกมือที่ ' || (n - 10) || ' (ตัวอย่าง)', 'MANUAL' from generate_series(11, 19) as n;

-- TODO(mock): 10 placeholder partner agencies — real list is Partner_Agency_Options.
insert into partner_agency_options (name_th) values
  ('หน่วยงานภาคี ตัวอย่าง 1'),
  ('หน่วยงานภาคี ตัวอย่าง 2'),
  ('หน่วยงานภาคี ตัวอย่าง 3'),
  ('หน่วยงานภาคี ตัวอย่าง 4'),
  ('หน่วยงานภาคี ตัวอย่าง 5'),
  ('หน่วยงานภาคี ตัวอย่าง 6'),
  ('หน่วยงานภาคี ตัวอย่าง 7'),
  ('หน่วยงานภาคี ตัวอย่าง 8'),
  ('หน่วยงานภาคี ตัวอย่าง 9'),
  ('หน่วยงานภาคี ตัวอย่าง 10');

-- TODO(mock): 5 fake phone numbers, matching the project's existing demo
-- convention ("demo ด้วยเบอร์ปลอม 5 เบอร์"). Real provisioning still unresolved.
insert into staff_whitelist (phone, role, district_id)
select phone, role::user_role, d.id from (values
  ('0810000001', 'STAFF', '01'),
  ('0810000002', 'DISTRICT_HEAD', '01'),
  ('0810000003', 'STAFF', '02'),
  ('0810000004', 'PROVINCE_MGR', null),
  ('0810000005', 'PROVINCE_HEAD', null)
) as w(phone, role, district_code)
left join districts d on d.code = w.district_code;
