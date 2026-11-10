# Supabase: отчёт в Telegram

Каждый день в 9:07 по Москве (задание pg_cron `mutaciya-report`) база собирает статистику «Мутации» за вчера
(`public.mutaciya_report_text(день)`) и отправляет её в личку бота @Survivefridaybot всем из таблицы `dev_admins`
через функцию `tg-notify` (её общий ключ — в закрытой таблице `push_keys`).

Команды в личке бота @Survivefridaybot (только для `dev_admins`). Бот передаёт любую команду `/mut…` в функцию
`public.mutaciya_bot(команда, аргумент)` и отправляет её ответ: `{text}` или `{text, file_name, file_csv}` (файл — документом).
Логика всех команд — в базе, бот менять не нужно. Список — `/mut_help`:

| Команда | Что показывает |
|---|---|
| `/mut` · `/mut_yesterday` · `/mut_week` · `/mut_month` | отчёт за сегодня / вчера / 7 / 30 дней (`mutaciya_report_period`) |
| `/mut_online` | кто сейчас в игре |
| `/mut_new` | новые игроки за сегодня: устройство, экран, язык, партии |
| `/mut_top` | таблица рекордов дня и недели с ID игроков |
| `/mut_find Имя` · `/mut_player ID` | поиск в таблице рекордов · карточка игрока или устройства |
| `/mut_export` | таблица рекордов в CSV |
| `/mut_funnel` · `/mut_retention` | воронка · удержание на 1-й и 7-й день |
| `/mut_modes` · `/mut_deaths` · `/mut_forms` · `/mut_devices` | режимы и испытания · чем кончаются партии · мутанты и скримеры · устройства и настройки |
| `/mut_health` · `/mut_errors` · `/mut_promo` | состояние · ошибки JS у игроков (событие `error`) · пост дня рассылки |
| `/mut_hide ID` | сбросить неприличное имя в таблице рекордов |

Посмотреть код функций: `select pg_get_functiondef('public.mutaciya_bot(text,text)'::regprocedure);`

Отправить отчёт вручную:

```sql
select public.mutaciya_tg_report();               -- за вчера
select public.mutaciya_tg_report(current_date);   -- за сегодня (на текущий момент)
select public.mutaciya_report_text('2026-11-10'); -- только посмотреть текст
select public.mutaciya_report_period('2026-11-04', '2026-11-10'); -- за период
```

Сменить время: `select cron.alter_job((select jobid from cron.job where jobname='mutaciya-report'), schedule := '7 6 * * *');` (время в UTC).
Выключить: `select cron.unschedule('mutaciya-report');`
