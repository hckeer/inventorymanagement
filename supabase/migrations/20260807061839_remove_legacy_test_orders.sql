-- Approved cleanup for the personal test project: orders reference the legacy
-- products table and must not survive its replacement.
drop table if exists public.orders cascade;
