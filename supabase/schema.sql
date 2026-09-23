-- ============================================================
-- أساتذة اقرأ (prof-iqra) — مخطط قاعدة البيانات
-- نفّذ هذا الكود في: Supabase Dashboard > SQL Editor > New query
-- ============================================================

create extension if not exists "pgcrypto";

-- ------------------------------------------------------------
-- users : مفتاح الهوية نفسه للأدمن والأستاذ (تسجيل الأستاذ يتم من لوحة الإدارة)
-- role = 'admin' | 'teacher'
-- pin_hash = sha256('iqra$#:' + PIN) — تُحسب داخل التطبيق
-- ------------------------------------------------------------
create table if not exists users (
  id          uuid primary key default gen_random_uuid(),
  role        text not null check (role in ('admin','teacher')),
  name        text not null,
  phone       text not null unique,
  pin_hash    text not null,
  subject     text,
  section     text,
  is_active   boolean not null default true,
  created_at  timestamptz not null default now()
);

-- ------------------------------------------------------------
-- schedule : الجدول الأسبوعي لكل أستاذ (يتكرر تلقائياً كل أسبوع)
-- day_of_week = 1..7 (1 = الاثنين .. 7 = الأحد) مطابقة لـ DateTime.weekday
-- ------------------------------------------------------------
create table if not exists schedule (
  id           uuid primary key default gen_random_uuid(),
  teacher_id   uuid not null references users(id) on delete cascade,
  day_of_week  smallint not null check (day_of_week between 1 and 7),
  start_time   time not null,
  end_time     time not null,
  class_name   text not null,
  created_at   timestamptz not null default now()
);

create index if not exists idx_schedule_teacher_day
  on schedule (teacher_id, day_of_week);

-- ------------------------------------------------------------
-- attendance_logs : سجل الحضور لكل حصة
-- status = 'present' | 'late' | 'absent'
-- ------------------------------------------------------------
create table if not exists attendance_logs (
  id              uuid primary key default gen_random_uuid(),
  teacher_id      uuid not null references users(id) on delete cascade,
  schedule_id     uuid references schedule(id) on delete set null,
  class_name      text,
  entry_date      date not null default current_date,
  check_in_time   timestamptz,
  check_out_time  timestamptz,
  status          text not null check (status in ('present','late','absent')),
  late_minutes    int,                   -- عدد دقائق التأخير (عند الحضور المتأخر)
  created_at      timestamptz not null default now()
);

create index if not exists idx_att_teacher_date
  on attendance_logs (teacher_id, entry_date);

-- ------------------------------------------------------------
-- notifications : إشعارات داخل التطبيق (للمستخدم أو للإدارة)
-- ------------------------------------------------------------
create table if not exists notifications (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references users(id) on delete cascade,
  message     text not null,
  is_read     boolean not null default false,
  created_at  timestamptz not null default now()
);

-- ------------------------------------------------------------
-- app_settings : إعدادات عامة — هنا السر الحالي لرمز QR
-- ------------------------------------------------------------
create table if not exists app_settings (
  key         text primary key,
  value       text not null,
  updated_at  timestamptz not null default now()
);

insert into app_settings (key, value)
values ('qr_secret', gen_random_uuid()::text)
on conflict (key) do nothing;

-- ------------------------------------------------------------
-- Realtime (البث الفوري للحضور والإشعارات)
-- ------------------------------------------------------------
alter publication supabase_realtime add table attendance_logs;
alter publication supabase_realtime add table notifications;

-- ------------------------------------------------------------
-- ملاحظة أمان: التطبيق يؤمّن الدخول عبر رقم الهاتف + كود PIN
-- (مصادقة على مستوى التطبيق وليس Supabase Auth).
-- لذلك تم تعطيل RLS مؤقتاً ويُستعمل المفتاح anon كبديل مباشر.
-- في نسخة الإنتاج لاحقاً يُفضَّل تفعيل RLS.
-- ------------------------------------------------------------
alter table users            enable row level security;
alter table schedule         enable row level security;
alter table attendance_logs  enable row level security;
alter table notifications    enable row level security;
alter table app_settings     enable row level security;

create policy "allow all users" on users            for all using (true) with check (true);
create policy "allow all schedule" on schedule       for all using (true) with check (true);
create policy "allow all attendance" on attendance_logs for all using (true) with check (true);
create policy "allow all notifications" on notifications for all using (true) with check (true);
create policy "allow all settings" on app_settings   for all using (true) with check (true);

-- ------------------------------------------------------------
-- حساب أدمن افتراضي
-- الهاتف: 0660000000   |   PIN: 1234
-- hash = sha256('iqra$#:1234') = d565658261b98a925d11dcdfe7fc39adf08e8ea258fe16250d2172a4c31ba85c
-- غير الكود ثم أعدّل الحساب من لوحة الإدارة
-- ------------------------------------------------------------
insert into users (role, name, phone, pin_hash, is_active)
values (
  'admin',
  'المدير',
  '0660000000',
  'd565658261b98a925d11dcdfe7fc39adf08e8ea258fe16250d2172a4c31ba85c',
  true
)
on conflict (phone) do nothing;