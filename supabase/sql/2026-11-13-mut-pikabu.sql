-- «Мутация» на Пикабу Играх: сводка по площадке для бота (/mut_pikabu [дни]) и блок «Пикабу» в отчётах.
-- Игроки Пикабу = устройства, у которых session_start с data.pk=true или версия с суффиксом -pk (с 13.11.2026).
-- Обёртки: mutaciya_bot → mutaciya_bot_core, mutaciya_report_period → mutaciya_report_period_core
-- (старая логика не трогается, права копируются). Всё в одной транзакции: ошибка — ничего не меняется.

create or replace function public.mutaciya_pikabu_text(d1 date, d2 date, short boolean default false)
returns text language plpgsql security definer set search_path = '' as $$
declare
  tz constant text := 'Europe/Moscow';
  t1 timestamptz := (d1::timestamp) at time zone tz;
  t2 timestamptz := ((d2 + 1)::timestamp) at time zone tz;
  today date := (now() at time zone tz)::date;
  pl int; nw int; ses int; gs int; ge int; lv int;
  med_s numeric; med_g numeric; boot numeric;
  ret text; tops text; ads text; fps text; buys text; days text; dev text;
  all_pl int; all_buy int; all_rub int;
begin
  with pk as (select distinct device from public.mutaciya_events
               where (ev = 'session_start' and data->>'pk' = 'true') or ver like '%-pk'),
       e as (select x.* from public.mutaciya_events x join pk using (device) where x.at >= t1 and x.at < t2)
  select count(distinct device), count(distinct session),
         count(*) filter (where ev = 'game_start'), count(*) filter (where ev = 'game_end'),
         count(*) filter (where ev = 'leave')
    into pl, ses, gs, ge, lv from e;

  with pk as (select distinct device from public.mutaciya_events
               where (ev = 'session_start' and data->>'pk' = 'true') or ver like '%-pk'),
       f as (select device, min(at) first from public.mutaciya_events join pk using (device) group by device)
  select count(*) into nw from f where first >= t1 and first < t2;

  with pk as (select distinct device from public.mutaciya_events
               where (ev = 'session_start' and data->>'pk' = 'true') or ver like '%-pk'),
       s as (select session, extract(epoch from max(at) - min(at)) sec from public.mutaciya_events join pk using (device)
              where at >= t1 and at < t2 group by session)
  select percentile_cont(.5) within group (order by sec) into med_s from s;

  with pk as (select distinct device from public.mutaciya_events
               where (ev = 'session_start' and data->>'pk' = 'true') or ver like '%-pk')
  select percentile_cont(.5) within group (order by (data->>'dur')::numeric) into med_g
    from public.mutaciya_events join pk using (device)
   where ev in ('game_end', 'leave') and at >= t1 and at < t2 and data->>'dur' ~ '^\d+$';

  if pl = 0 then
    return '🟣 Пикабу Игры: за период игроков нет.';
  end if;

  if short then
    return format('🟣 Пикабу Игры: игроков %s (новых %s) · заходов %s · партий %s · медиана захода %s · медиана партии %s',
      pl, nw, ses, gs, coalesce(round(med_s / 60, 1) || ' мин', '—'), coalesce(round(med_g) || ' с', '—'));
  end if;

  -- по дням
  with pk as (select distinct device from public.mutaciya_events
               where (ev = 'session_start' and data->>'pk' = 'true') or ver like '%-pk')
  select string_agg(format('%s — игроков %s, партий %s', to_char(d, 'DD.MM'), p, g), e'\n' order by d) into days
    from (select (at at time zone tz)::date d, count(distinct device) p, count(*) filter (where ev = 'game_start') g
            from public.mutaciya_events join pk using (device) where at >= t1 and at < t2 group by 1) q;

  -- устройства и загрузка
  with pk as (select distinct device from public.mutaciya_events
               where (ev = 'session_start' and data->>'pk' = 'true') or ver like '%-pk'),
       s as (select device, (data->>'w')::int w from public.mutaciya_events join pk using (device)
              where ev = 'session_start' and at >= t1 and at < t2 and data->>'w' ~ '^\d+$')
  select format('телефоны %s · компьютеры %s', count(distinct device) filter (where w < 820), count(distinct device) filter (where w >= 820))
    into dev from s;
  with pk as (select distinct device from public.mutaciya_events
               where (ev = 'session_start' and data->>'pk' = 'true') or ver like '%-pk')
  select percentile_cont(.5) within group (order by (data->>'boot')::numeric) into boot
    from public.mutaciya_events join pk using (device)
   where ev = 'session_start' and at >= t1 and at < t2 and data->>'boot' ~ '^\d+$';

  -- до какого уровня (top — номер старшего мутанта в партии)
  with pk as (select distinct device from public.mutaciya_events
               where (ev = 'session_start' and data->>'pk' = 'true') or ver like '%-pk')
  select string_agg(format('№%s — %s', top + 1, n), ' · ' order by top) into tops
    from (select (data->>'top')::int top, count(*) n from public.mutaciya_events join pk using (device)
           where ev = 'game_end' and at >= t1 and at < t2 and data->>'top' ~ '^\d+$' group by 1) q;

  -- удержание: новые игроки периода (кроме сегодняшних), вернувшиеся на следующий день
  with pk as (select distinct device from public.mutaciya_events
               where (ev = 'session_start' and data->>'pk' = 'true') or ver like '%-pk'),
       f as (select device, min((at at time zone tz)::date) fd from public.mutaciya_events join pk using (device) group by device),
       c as (select f.device, f.fd from f where f.fd >= d1 and f.fd <= least(d2, today - 1))
  select case when count(*) = 0 then '—' else format('%s из %s (%s%%)',
           count(*) filter (where exists (select 1 from public.mutaciya_events x where x.device = c.device
                                           and (x.at at time zone tz)::date = c.fd + 1)),
           count(*),
           round(100.0 * count(*) filter (where exists (select 1 from public.mutaciya_events x where x.device = c.device
                                           and (x.at at time zone tz)::date = c.fd + 1)) / count(*))) end
    into ret from c;

  -- реклама
  with pk as (select distinct device from public.mutaciya_events
               where (ev = 'session_start' and data->>'pk' = 'true') or ver like '%-pk')
  select string_agg(format('%s %s', case k when 'rewarded' then 'за награду' when 'fullscreen' then 'между партиями' else k end, n), ' · ')
    into ads
    from (select coalesce(data->>'type', '?') k, count(*) n from public.mutaciya_events join pk using (device)
           where ev = 'ad' and at >= t1 and at < t2 group by 1) q;

  -- FPS (один замер за сессию после 60 с игры)
  with pk as (select distinct device from public.mutaciya_events
               where (ev = 'session_start' and data->>'pk' = 'true') or ver like '%-pk')
  select string_agg(format('%s: медиана %s, худший %s (замеров %s)', k, m, lo, n), ' · ') into fps
    from (select case when data->>'mob' = 'true' then 'телефоны' else 'компьютеры' end k,
                 round(percentile_cont(.5) within group (order by (data->>'fps')::numeric)) m,
                 min((data->>'fps')::int) lo, count(*) n
            from public.mutaciya_events join pk using (device)
           where ev = 'fps' and at >= t1 and at < t2 and data->>'fps' ~ '^\d+$' group by 1) q;

  -- покупки (проверенные подписью Пикабу)
  select string_agg(format('%s ×%s%s', product_id, n, case when t > 0 then format(' (тестовых %s)', t) else '' end), ' · ')
    into buys
    from (select product_id, count(*) n, count(*) filter (where test) t from public.mutaciya_pk_purchases
           where created_at >= t1 and created_at < t2 group by 1) q;

  -- за всё время
  with pk as (select distinct device from public.mutaciya_events
               where (ev = 'session_start' and data->>'pk' = 'true') or ver like '%-pk')
  select count(*) into all_pl from pk;
  select count(*), coalesce(sum(case product_id when 'all' then 349 when 'noads' then 199 when 'relic' then 149
                                      when 'rust' then 99 when 'neon' then 99 else 0 end), 0)
    into all_buy, all_rub from public.mutaciya_pk_purchases where not test;

  return concat_ws(e'\n',
    format('🟣 «Мутация» на Пикабу Играх · %s', case when d1 = d2 then to_char(d1, 'DD.MM') else to_char(d1, 'DD.MM') || '–' || to_char(d2, 'DD.MM') end),
    '',
    format('👥 Игроков %s (новых %s) · заходов %s', pl, nw, ses),
    format('🎮 Партий начато %s, доиграно %s, брошено на середине %s', gs, ge, lv),
    format('⏱ Медиана захода %s · медиана партии %s',
           coalesce(round(med_s / 60, 1) || ' мин', '—'), coalesce(round(med_g) || ' с', '—')),
    format('🔁 Вернулись на следующий день: %s', ret),
    format('📱 %s · загрузка (медиана) %s', coalesce(dev, '—'), coalesce(round(boot / 1000, 1) || ' с', '—')),
    format('🧪 Старший мутант в конце партии: %s', coalesce(tops, '—')),
    format('📺 Реклама показана: %s', coalesce(ads, 'нет')),
    format('🎞 FPS: %s', coalesce(fps, 'замеров пока нет')),
    format('💰 Покупки: %s', coalesce(buys, 'нет')),
    '',
    case when d1 <> d2 then '📅 По дням:' || e'\n' || coalesce(days, '—') || e'\n' else null end,
    format('Всего на Пикабу: игроков %s · покупок %s на %s ₽ (до комиссии Пикабу)', all_pl, all_buy, all_rub),
    'Просмотры страницы, оценки и доход с рекламы — только в Студии Пикабу.');
end $$;

revoke all on function public.mutaciya_pikabu_text(date, date, boolean) from public, anon, authenticated;

-- обёртка бота: /mut_pikabu [дни] + строка в /mut_help, остальное — старой функции
alter function public.mutaciya_bot(text, text) rename to mutaciya_bot_core;

create function public.mutaciya_bot(p_cmd text, p_arg text default '')
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  tz constant text := 'Europe/Moscow';
  today date := (now() at time zone tz)::date;
  c text := lower(regexp_replace(coalesce(p_cmd, ''), '^/', ''));
  n int; r jsonb;
begin
  if c = 'mut_pikabu' then
    n := greatest(1, least(90, coalesce(nullif(regexp_replace(coalesce(p_arg, ''), '\D', '', 'g'), '')::int, 1)));
    return jsonb_build_object('text', public.mutaciya_pikabu_text(today - n + 1, today));
  end if;
  r := public.mutaciya_bot_core(p_cmd, p_arg);
  if c = 'mut_help' and r ? 'text' then
    r := jsonb_set(r, '{text}', to_jsonb((r->>'text') || e'\n\n🟣 Пикабу Игры\n/mut_pikabu — сегодня · /mut_pikabu 7 — за 7 дней: игроки, партии, время, удержание, реклама, FPS, покупки'));
  end if;
  return r;
end $$;

-- обёртка отчёта: к /mut, /mut_week и утреннему отчёту добавляется строка «Пикабу»
alter function public.mutaciya_report_period(date, date) rename to mutaciya_report_period_core;

create function public.mutaciya_report_period(d1 date, d2 date)
returns text language plpgsql security definer set search_path = '' as $$
begin
  return public.mutaciya_report_period_core(d1, d2) || e'\n\n' || public.mutaciya_pikabu_text(d1, d2, true);
end $$;

-- права новых обёрток — как у старых функций
do $$
declare g record;
begin
  revoke all on function public.mutaciya_bot(text, text) from public;
  revoke all on function public.mutaciya_report_period(date, date) from public;
  for g in select distinct grantee from information_schema.routine_privileges
            where routine_schema = 'public' and routine_name = 'mutaciya_bot_core' and privilege_type = 'EXECUTE' loop
    execute format('grant execute on function public.mutaciya_bot(text, text) to %s', case when g.grantee = 'PUBLIC' then 'public' else quote_ident(g.grantee) end);
  end loop;
  for g in select distinct grantee from information_schema.routine_privileges
            where routine_schema = 'public' and routine_name = 'mutaciya_report_period_core' and privilege_type = 'EXECUTE' loop
    execute format('grant execute on function public.mutaciya_report_period(date, date) to %s', case when g.grantee = 'PUBLIC' then 'public' else quote_ident(g.grantee) end);
  end loop;
end $$;
