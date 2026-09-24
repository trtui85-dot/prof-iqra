-- ترحيل 003: عمود رمز الجهاز (FCM) جدول users
-- شغّل هذا الملف في Supabase SQL Editor مباشرةً.
alter table public.users add column if not exists fcm_token text;