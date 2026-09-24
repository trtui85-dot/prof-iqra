-- ============================================================
-- ترحيل 004: إغلاق تلقائي للحصص المنتهية عند عدم مسح انصراف
-- ------------------------------------------------------------
-- قاعدة: إذا مضى موعد نهاية حصة ولم يُسجَّل انصراف، ولم تكن للأستاذ
-- حصة تالية تبدأ بعد هذه الحصة، يُغلق السجل تلقائياً عند وقت نهاية
-- الحصة (مع إشعار الأستاذ «لقد انتهت حصتك»).
-- شغّل الملف في SQL Editor مباشرةً (بيّن أنه لمشروع prof-iqra).
-- ============================================================

create or replace function public.auto_close_sessions()
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  r record;
begin
  for r in
    select l.id as log_id, l.teacher_id, s.class_name, s.end_time
    from public.attendance_logs l
    join public.schedule s on s.id = l.schedule_id
    where l.check_out_time is null
      and l.entry_date = to_char(now(), 'YYYY-MM-DD')
      and s.day_of_week = extract(isodow from now())
      and now() >= (current_date + s.end_time::time)
      and not exists (
        select 1 from public.schedule s2
        where s2.teacher_id = l.teacher_id
          and s2.day_of_week = s.day_of_week
          and s2.id <> s.id
          and (current_date + s2.start_time::time) >= (current_date + s.end_time::time)
      )
  loop
    update public.attendance_logs
      set check_out_time = (current_date + r.end_time::time)::timestamptz
    where id = r.log_id;

    insert into public.notifications (user_id, message, is_read)
    values (r.teacher_id,
            'لقد انتهت حصتك «' || r.class_name || '» وسُجّل حضورك.',
            false);
  end loop;
end $$;

-- إعادة تشغيل المنظيف كل دقيقة (ولعبات الغياب التلقائي كل 15 دقيقة)
select cron.unschedule('auto-close-sessions')
where exists (select 1 from cron.job where jobname = 'auto-close-sessions');
select cron.schedule('auto-close-sessions', '* * * * *',
       'select public.auto_close_sessions();');

-- إلغاء لاحقاً:
-- select cron.unschedule('auto-close-sessions');