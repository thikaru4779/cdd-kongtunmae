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
--
-- This script is a full reset: it truncates every seeded table (CASCADE, so any
-- dependent transactional rows go too) before re-inserting, so re-running it after
-- editing is always safe. Do NOT re-run this against a database with real
-- signups/activities in it — CASCADE would wipe those along with the seed tables.

truncate table
  provinces, districts, subdistricts, mom_quest_steps, system_config,
  village_master, activities_type, health_check_indicators,
  partner_agency_options, staff_whitelist
restart identity cascade;

insert into provinces (code, name_th) values ('86', 'ชุมพร');

insert into districts (province_id, code, name_th)
select p.id, d.code, d.name_th from provinces p, (values
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

-- TODO(mock): 2 placeholder subdistricts per district (16 total) — replace once
-- the real Village_Master sheet / central-format village list is available.
insert into subdistricts (district_id, code, name_th)
select d.id, sub.code, 'ตำบลตัวอย่าง ' || sub.code || ' ' || d.name_th
from districts d
cross join (values ('01'), ('02')) as sub(code);

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

-- TODO(mock): 48 placeholder villages (real sheet has 336) — 3 villages per
-- subdistrict, covering all 8 districts now instead of just 3. Fake GPS within
-- Chumphon's rough bounding box, fake founding years. Replace once the real
-- Village_Master data is available.
insert into village_master (subdistrict_id, village_code, moo_no, name_th, lat, lng, founding_year)
select
  s.id,
  '86' || d.code || s.code || lpad(v.moo_no::text, 3, '0') || '01',
  v.moo_no,
  'หมู่บ้านตัวอย่าง ' || v.moo_no || ' ' || s.name_th,
  10.49 + (random() * 0.6),
  99.18 + (random() * 0.4),
  2540 + (v.moo_no % 20)
from subdistricts s
join districts d on d.id = s.district_id
cross join generate_series(1, 3) as v(moo_no);

-- TODO(mock): 30 placeholder activity types (real sheet has 80 active types with
-- real score/bonus/weight/innovation formulas) — 3 variants per MOM Quest step
-- instead of 1, so each step has some realistic variety.
insert into activities_type (code, name_th, category_th, score, bonus_point, weight, innovation_point, mom_quest_step_no) values
  ('ACT-01', 'ปฐมนิเทศระดับหมู่บ้าน (ตัวอย่าง)', 'ปฐมนิเทศ', 10, 0, 1.0, 0, 1),
  ('ACT-02', 'ปฐมนิเทศระดับตำบล (ตัวอย่าง)', 'ปฐมนิเทศ', 12, 0, 1.0, 0, 1),
  ('ACT-03', 'อบรมทำความเข้าใจโครงการเชิงลึก (ตัวอย่าง)', 'ปฐมนิเทศ', 15, 0, 1.1, 0, 1),
  ('ACT-04', 'จัดตั้งคณะกรรมการชุดใหม่ (ตัวอย่าง)', 'โครงสร้าง', 15, 0, 1.0, 0, 2),
  ('ACT-05', 'ปรับปรุงโครงสร้างคณะกรรมการ (ตัวอย่าง)', 'โครงสร้าง', 10, 0, 1.0, 0, 2),
  ('ACT-06', 'ประชุมคณะกรรมการประจำเดือน (ตัวอย่าง)', 'โครงสร้าง', 8, 0, 1.0, 0, 2),
  ('ACT-07', 'รับสมัครสมาชิกใหม่ (ตัวอย่าง)', 'สมาชิก', 10, 0, 1.0, 0, 3),
  ('ACT-08', 'กิจกรรมรณรงค์รับสมัครสมาชิก (ตัวอย่าง)', 'สมาชิก', 12, 0, 1.0, 0, 3),
  ('ACT-09', 'ทบทวนทะเบียนสมาชิก (ตัวอย่าง)', 'สมาชิก', 8, 0, 1.0, 0, 3),
  ('ACT-10', 'จัดทำกฎระเบียบกองทุน (ตัวอย่าง)', 'กฎระเบียบ', 12, 0, 1.0, 0, 4),
  ('ACT-11', 'ทบทวนกฎระเบียบประจำปี (ตัวอย่าง)', 'กฎระเบียบ', 10, 0, 1.0, 0, 4),
  ('ACT-12', 'เวทีประชาคมรับรองกฎระเบียบ (ตัวอย่าง)', 'กฎระเบียบ', 15, 0, 1.1, 0, 4),
  ('ACT-13', 'เวทีสร้างความเข้าใจระดับหมู่บ้าน (ตัวอย่าง)', 'เวทีชุมชน', 10, 0, 1.0, 0, 5),
  ('ACT-14', 'เวทีสร้างความเข้าใจร่วมหน่วยงานภาคี (ตัวอย่าง)', 'เวทีชุมชน', 15, 0, 1.1, 0, 5),
  ('ACT-15', 'เวทีสัญจรสร้างความเข้าใจ (ตัวอย่าง)', 'เวทีชุมชน', 12, 0, 1.0, 0, 5),
  ('ACT-16', 'ทอดผ้าป่าสมทบกองทุน (ตัวอย่าง)', 'การเงิน', 20, 5, 1.2, 0, 6),
  ('ACT-17', 'ระดมทุนศรัทธา (ตัวอย่าง)', 'การเงิน', 18, 5, 1.2, 0, 6),
  ('ACT-18', 'ประชุมบริหารจัดการเงินกองทุน (ตัวอย่าง)', 'การเงิน', 10, 0, 1.0, 0, 6),
  ('ACT-19', 'เวทีประชาคมคัดแยกผู้เสพ/ผู้ค้า (ตัวอย่าง)', 'ประชาคม', 15, 0, 1.0, 0, 7),
  ('ACT-20', 'อบรมแนวทางสันติวิธี (ตัวอย่าง)', 'ประชาคม', 12, 0, 1.0, 0, 7),
  ('ACT-21', 'ติดตามผลการคัดแยก (ตัวอย่าง)', 'ประชาคม', 10, 0, 1.0, 0, 7),
  ('ACT-22', 'ลาดตระเวนเฝ้าระวังยาเสพติด (ตัวอย่าง)', 'เฝ้าระวัง', 15, 0, 1.1, 0, 8),
  ('ACT-23', 'กิจกรรมบำบัดฟื้นฟูผู้ผ่านการบำบัด (ตัวอย่าง)', 'เฝ้าระวัง', 18, 0, 1.1, 0, 8),
  ('ACT-24', 'อบรมแกนนำเฝ้าระวังหมู่บ้าน (ตัวอย่าง)', 'เฝ้าระวัง', 12, 0, 1.0, 0, 8),
  ('ACT-25', 'วันกองทุนแม่ของแผ่นดิน (ตัวอย่าง)', 'พิธีการ', 20, 10, 1.0, 5, 9),
  ('ACT-26', 'พิธีรับรองผลการดำเนินงาน (ตัวอย่าง)', 'พิธีการ', 15, 5, 1.0, 0, 9),
  ('ACT-27', 'มอบเกียรติบัตรกองทุนแม่ (ตัวอย่าง)', 'พิธีการ', 12, 5, 1.0, 0, 9),
  ('ACT-28', 'ติดตามประเมินผลประจำปี (ตัวอย่าง)', 'ติดตามผล', 10, 0, 1.0, 0, 10),
  ('ACT-29', 'ถอดบทเรียนสู่หมู่บ้านต้นแบบ (ตัวอย่าง)', 'ติดตามผล', 15, 0, 1.1, 5, 10),
  ('ACT-30', 'ศึกษาดูงานหมู่บ้านต้นแบบ (ตัวอย่าง)', 'ติดตามผล', 12, 0, 1.0, 0, 10);

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
