# Supabase: отчёт в Telegram

Каждый день в 9:07 по Москве (задание pg_cron `mutaciya-report`) база собирает статистику «Мутации» за вчера
(`public.mutaciya_report_text(день)`) и отправляет её в личку бота @Survivefridaybot всем из таблицы `dev_admins`
через функцию `tg-notify` (её общий ключ — в закрытой таблице `push_keys`).

Команды в личке бота (только для `dev_admins`, их добавляет в `tg-bot` проект «Выжить до пятницы»):
`/mut` — сегодня, `/mut_yesterday` — вчера, `/mut_week` — 7 дней. Текст собирает `public.mutaciya_report_period(с, по)`
(дни по Москве, включительно; доступ только у service_role).

Отправить отчёт вручную:

```sql
select public.mutaciya_tg_report();               -- за вчера
select public.mutaciya_tg_report(current_date);   -- за сегодня (на текущий момент)
select public.mutaciya_report_text('2026-11-10'); -- только посмотреть текст
select public.mutaciya_report_period('2026-11-04', '2026-11-10'); -- за период
```

Сменить время: `select cron.alter_job((select jobid from cron.job where jobname='mutaciya-report'), schedule := '7 6 * * *');` (время в UTC).
Выключить: `select cron.unschedule('mutaciya-report');`
