-- ============================================================
--  حساب العرض التجريبي لـ Google Play Review (IQRA)
-- ------------------------------------------------------------
-- الغرض: منح مراجع Google accès direct à l'application avec
--        des données réalistes (المطلوب في قسم App access).
-- ------------------------------------------------------------
-- 1) انسخ هذا الملف والصقه في Supabase → SQL Editor ثم Run.
-- 2) بيانات الدخول التي تعطيها للمراجع:
--      الأستاذ التجريبي : 22123456  /  PIN : 1234
--      الإدارة          : 0660000000  /  PIN : 1234
--      (يقبل التطبيق إدخال الرقم مع رمز الدولة أو بدونه:
--       22123456 أو +22222123456 أو 0022222123456)
-- 3) بعد انتهاء المراجعة يمكنك حذف الحساب التجريبي من داخل التطبيق
--    أو بالأمر في آخر الملف.
-- 4) آمن للتشغيل أكثر من مرة (idempotent).
-- ============================================================

-- 1) حساب الأستاذ التجريبي
insert into public.users (role, name, phone, pin_hash, subject, section, is_active)
values ('teacher', 'أستاذ تجريبي', '22123456',
        'd565658261b98a925d11dcdfe7fc39adf08e8ea258fe16250d2172a4c31ba85c',
        'اللغة العربية', 'القسم أ', true)
on conflict (phone) do update
  set is_active = true,
      subject   = excluded.subject,
      section   = excluded.section;

-- 2) جدول حصصه الأسبوعي (الاثنين=1 … الأحد=7)
insert into public.schedule (teacher_id, day_of_week, start_time, end_time, class_name)
select u.id, v.day, v.start::time, v.finish::time, v.class_name
from public.users u
join (values
        (1, '08:00', '09:00', 'القسم أ — حصة 1'),
        (1, '10:00', '11:30', 'القسم ب — حصة 2'),
        (2, '08:00', '09:00', 'القسم ج — حصة 1'),
        (3, '09:00', '10:30', 'القسم أ — حصة 2'),
        (4, '08:00', '09:00', 'القسم ب — حصة 1'),
        (5, '10:00', '11:30', 'القسم ج — حصة 2')
     ) as v(day, start, finish, class_name) on true
where u.phone = '22123456'
  and not exists (
    select 1 from public.schedule s
    where s.teacher_id = u.id and s.class_name = v.class_name
  );

-- 3) سجلات حضور لآخر 10 أيام (حاضر / متأخر / غائب)
--    حتى تظهر التقارير (يومي / أسبوعي / شهري) ببيانات حقيقية.
with days as (
  select
    d,
    (current_date - (d || ' days')::interval)::date as entry_date,
    extract(isodow from (current_date - (d || ' days')::interval))::int as dow,
    case when d % 5 = 0 then 'late' else 'present' end as status,
    case when d % 5 = 0 then 12 else 0 end as late_min
  from generate_series(1, 10) as d
)
insert into public.attendance_logs
  (teacher_id, schedule_id, class_name, entry_date,
   check_in_time, check_out_time, status, late_minutes)
select
  u.id,
  s.id,
  s.class_name,
  days.entry_date,
  case when days.status = 'absent' then null
       else (s.start_time + (days.late_min || ' minutes')::interval)::time end,
  case when days.status = 'absent' then null else s.end_time end,
  days.status,
  days.late_min
from public.users u
join public.schedule s on s.teacher_id = u.id
join days on days.dow = s.day_of_week
where u.phone = '22123456'
  and not exists (
    select 1 from public.attendance_logs l
    where l.teacher_id = u.id
      and l.schedule_id = s.id
      and l.entry_date = days.entry_date
  );

-- ============================================================
--  (اختياري) حذف حساب العرض بعد انتهاء مراجعة Google Play:
--  delete from public.users where phone = '22123456';
--  (سجلات الحضور والجدول تُحذف تلقائياً بـ on delete cascade)
-- ============================================================