# Supabase: отчёт в Telegram

Каждый день в 9:07 по Москве (задание pg_cron `mutaciya-report`) база собирает статистику «Мутации» за вчера
(`public.mutaciya_report_text(день)`) и отправляет её в личку бота @Survivefridaybot всем из таблицы `dev_admins`
через функцию `tg-notify` (её общий ключ — в закрытой таблице `push_keys`).

Отправить отчёт вручную:

```sql
select public.mutaciya_tg_report();               -- за вчера
select public.mutaciya_tg_report(current_date);   -- за сегодня (на текущий момент)
select public.mutaciya_report_text('2026-11-10'); -- только посмотреть текст
```

Сменить время: `select cron.alter_job((select jobid from cron.job where jobname='mutaciya-report'), schedule := '7 6 * * *');` (время в UTC).
Выключить: `select cron.unschedule('mutaciya-report');`
