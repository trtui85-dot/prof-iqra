-- ============================================================
-- الإعداد على الخادم: غياب تلقائي + إشعارات FCM للإدارة
-- ------------------------------------------------------------
-- المتطلبات:
--  1) شغّل migration_003_fcm.sql أولاً (عمود fcm_token)
--  2) انشر الدالة في supabase/edge_functions/fcm-notify
--     supabase functions deploy fcm-notify --no-verify-jwt
--  3) ضع أسرار الدالة في Supabase → Edge Functions → Settings:
--        GOOGLE_APPLICATION_CREDENTIALS = محتوى JSON لحساب خدمة Firebase
--        FIREBASE_PROJECT_ID = معرف مشروع Firebase
--  4) فعّل الامتداد pg_net (Database → Extensions) إذا لم يكن مفعلاً
--  5) انسخ والصق بقية هذا الملف في SQL Editor وشغّله.
-- ============================================================

-- أ) دالة الغياب التلقائي (تطابق قاعدة التطبيق: بداية الحصة + 90 دقيقة)
create or replace function public.auto_mark_absents()
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  r record;
  admins uuid[];
begin
  select array_agg(id) into admins
  from public.users where role = 'admin' and is_active = true;

  for r in
    select t.id as teacher_id, t.name as teacher_name, s.id as schedule_id,
           s.class_name, s.start_time, s.end_time
    from public.users t
    join public.schedule s on s.teacher_id = t.id and s.day_of_week = extract(isodow from now())
    where t.role = 'teacher' and t.is_active = true
      and not exists (
        select 1 from public.attendance_logs l
        where l.teacher_id = t.id and l.schedule_id = s.id
          and l.entry_date = to_char(now(), 'YYYY-MM-DD')
      )
      and (
        now() > (current_date + s.start_time::time) + interval '90 minutes'
        or now() > (current_date + s.end_time::time)
      )
  loop
    insert into public.attendance_logs
      (teacher_id, schedule_id, class_name, entry_date, status)
    values
      (r.teacher_id, r.schedule_id, r.class_name,
       to_char(now(), 'YYYY-MM-DD'), 'absent');

    if admins is not null then
      insert into public.notifications (user_id, message, is_read)
      select a, 'الأستاذ ' || r.teacher_name || ' غاب عن حصة «' || r.class_name || '» (لم يسجّل حضوره).', false
      from unnest(admins) as a;
    end if;
  end loop;
end $$;

-- ب) عند إدراج سجل حضور/تأخر/غياب → نداء الدالة fcm-notify لإخطار الإدارة خارج التطبيق
create or replace function public.notify_fcm_on_attendance()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  teacher_name text;
begin
  select name into teacher_name from public.users where id = new.teacher_id;
  perform net.http_post(
    url := 'https://vyokksvtvdozetrnzziv.supabase.co/functions/v1/fcm-notify',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Accept', 'application/json'
    ),
    body := jsonb_build_object(
      'title', case new.status
                when 'present' then 'تسجيل حضور'
                when 'late' then 'حضور متأخر'
                else 'غياب تلقائي'
              end,
      'body', 'الأستاذ ' || coalesce(teacher_name, '—') || ' — ' ||
              coalesce(new.class_name, '') || '.',
      'role', 'admin'
    )
  );
  return new;
end $$;

drop trigger if exists trg_att_fcm on public.attendance_logs;
create trigger trg_att_fcm
  after insert on public.attendance_logs
  for each row
  when (new.status in ('present', 'late', 'absent'))
  execute function public.notify_fcm_on_attendance();

-- ج) جدولة الغياب التلقائي كل 15 دقيقة
select cron.schedule(
  'auto-absent-check',
  '*/15 * * * *',
  'select public.auto_mark_absents();'
);

-- هـ) إلغاء كل ذلك عند الحاجة:
-- drop trigger if exists trg_att_fcm on public.attendance_logs;
-- select cron.unschedule('auto-absent-check');