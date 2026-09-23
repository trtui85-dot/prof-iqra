-- ============================================================
-- أساتذة اقرأ — تنظيف البيانات المكررة (إصدار 2)
-- نفّذ هذا الكود في: Supabase Dashboard > SQL Editor > Run
-- يعالج سبب خطأ 406: "multiple (or no) rows returned"
-- ============================================================

-- 1) حسابات مكررة بنفس رقم الهاتف: عطّل الأحدث (ليس حذفاً) حتى
--    يبقى حساب واحد فعّال لكل هاتف ويعود تسجيل الدخول سليماً.
update users u
set is_active = false
from users u2
where u.role = 'teacher'
  and u.phone = u2.phone
  and u.created_at > u2.created_at
  and u2.role = 'teacher';

-- 2) سجلات حضور مطابقة تماماً (نفس اليوم والحصة والدخول والخروج والحالة)
--    والناتجة عن محاولات متكررة: احذف المكرّر وابقِ الأحدث فقط.
delete from attendance_logs a
using attendance_logs a2
where a.teacher_id    = a2.teacher_id
  and a.schedule_id   is not distinct from a2.schedule_id
  and a.entry_date    = a2.entry_date
  and a.status        = a2.status
  and a.check_in_time is not distinct from a2.check_in_time
  and a.check_out_time is not distinct from a2.check_out_time
  and a.late_minutes  is not distinct from a2.late_minutes
  and a.created_at < a2.created_at;