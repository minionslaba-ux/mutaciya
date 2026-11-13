-- «Мутация»: кто сейчас в игре (сайт и Пикабу), реклама «показано из попыток», сводка по Пикабу в 20:00 МСК.

-- 1) онлайн: игра раз в минуту зовёт mutaciya_ping (пока вкладка видна)
create table if not exists public.mutaciya_online (
  device uuid primary key,
  pk boolean not null default false,
  ver text not null default '',
  mode text not null default '',
  state text not null default '',
  score int not null default 0,
  top text not null default '',
  w int,
  started_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
alter table public.mutaciya_online enable row level security;
create index if not exists mutaciya_online_upd_idx on public.mutaciya_online (updated_at);

create or replace function public.mutaciya_ping(p_device uuid, p_pk boolean default false, p_ver text default '', p_mode text default '',
  p_state text default '', p_score int default 0, p_top text default '', p_w int default null)
returns void language plpgsql security definer set search_path = '' as $$
begin
  if p_device is null then return; end if;
  insert into public.mutaciya_online as o (device, pk, ver, mode, state, score, top, w)
  values (p_device, coalesce(p_pk, false), left(coalesce(p_ver, ''), 20), left(coalesce(p_mode, ''), 20), left(coalesce(p_state, ''), 10),
          greatest(0, least(coalesce(p_score, 0), 100000000)), left(coalesce(p_top, ''), 20), least(greatest(p_w, 0), 10000))
  on conflict (device) do update set pk = excluded.pk, ver = excluded.ver, mode = excluded.mode, state = excluded.state,
    score = excluded.score, top = excluded.top, w = excluded.w, updated_at = now(),
    started_at = case when o.updated_at < now() - interval '10 minutes' then now() else o.started_at end;
  if random() < 0.02 then delete from public.mutaciya_online where updated_at < now() - interval '2 days'; end if;
end $$;
revoke all on function public.mutaciya_ping(uuid, boolean, text, text, text, int, text, int) from public;
grant execute on function public.mutaciya_ping(uuid, boolean, text, text, text, int, text, int) to anon, authenticated, service_role;

create or replace function public.mutaciya_online_text(p_pk boolean default true)
returns text language plpgsql security definer set search_path = '' as $$
declare x text; n int; v_site int; v_pk int;
begin
  select count(*) filter (where pk), count(*) filter (where not pk) into v_pk, v_site
    from public.mutaciya_online where updated_at > now() - interval '2 minutes';
  select count(*), string_agg(format('• %s · %s · %s · %s · %s мин · очки %s · старший: %s',
           upper(left(device::text, 6)), case when w < 820 then 'телефон' else 'компьютер' end,
           case state when 'play' then 'играет' when 'menu' then 'в меню' when 'over' then 'конец смены' when 'pause' then 'пауза' else state end,
           public.mutaciya_mode_name(mode), greatest(1, round(extract(epoch from now() - started_at) / 60)), score, coalesce(public.mutaciya_form_name(nullif(top, '')), top)), e'\n' order by started_at)
    into n, x from public.mutaciya_online where updated_at > now() - interval '2 minutes' and mutaciya_online.pk = p_pk;
  return concat_ws(e'\n',
    case when p_pk then '🟣 Пикабу Игры — сейчас в игре: ' else '🌐 Сайт — сейчас в игре: ' end || n,
    case when n > 0 then e'\n' || x else null end,
    '',
    format('Для сравнения: Пикабу %s · сайт %s (активность за 2 минуты)', v_pk, v_site));
end $$;
revoke all on function public.mutaciya_online_text(boolean) from public, anon, authenticated;

-- 2) сводка по Пикабу: реклама «показано из попыток» (события ad = попытка, ad_res = результат)
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
               where (ev = 'session_start' and data->>'pk' = 'true') or ver like '%-pk'),
       a as (select coalesce(data->>'type', '?') k, ev, data from public.mutaciya_events join pk using (device)
              where ev in ('ad', 'ad_res') and at >= t1 and at < t2)
  select string_agg(format('%s: показано %s из %s%s', case k when 'rewarded' then 'за награду' when 'fullscreen' then 'между партиями' else k end,
                           shown, tries, case when why is not null then ' (не показано: ' || why || ')' else '' end), ' · ')
    into ads
    from (select k, count(*) filter (where ev = 'ad') tries,
                 count(*) filter (where ev = 'ad_res' and data->>'ok' = 'true') shown,
                 (select string_agg(w || ' ×' || n, ', ') from (select coalesce(nullif(a2.data->>'why', ''), '?') w, count(*) n from a a2
                    where a2.k = a1.k and a2.ev = 'ad_res' and a2.data->>'ok' = 'false' group by 1 order by 2 desc limit 3) q2) why
            from a a1 group by k) q;

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
    format('📺 Реклама: %s', coalesce(ads, 'попыток не было')),
    format('🎞 FPS: %s', coalesce(fps, 'замеров пока нет')),
    format('💰 Покупки: %s', coalesce(buys, 'нет')),
    '',
    case when d1 <> d2 then '📅 По дням:' || e'\n' || coalesce(days, '—') || e'\n' else null end,
    format('Всего на Пикабу: игроков %s · покупок %s на %s ₽ (до комиссии Пикабу)', all_pl, all_buy, all_rub),
    'Просмотры страницы, оценки и доход с рекламы — только в Студии Пикабу.');
end $$;

revoke all on function public.mutaciya_pikabu_text(date, date, boolean) from public, anon, authenticated;

-- 3) бот: /mut_online_pikabu и /mut_online_site + строки в /mut_help
create or replace function public.mutaciya_bot(p_cmd text, p_arg text default '')
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
  if c = 'mut_online_pikabu' then return jsonb_build_object('text', public.mutaciya_online_text(true)); end if;
  if c = 'mut_online_site' then return jsonb_build_object('text', public.mutaciya_online_text(false)); end if;
  r := public.mutaciya_bot_core(p_cmd, p_arg);
  if c = 'mut_help' and r ? 'text' then
    r := jsonb_set(r, '{text}', to_jsonb((r->>'text') || e'\n\n🟣 Пикабу Игры\n/mut_pikabu — сегодня · /mut_pikabu 7 — за 7 дней: игроки, партии, время, удержание, реклама, FPS, покупки\n/mut_online_pikabu — кто сейчас играет на Пикабу · /mut_online_site — на сайте\nСводка по Пикабу за день приходит сама в 20:00 МСК.'));
  end if;
  return r;
end $$;

-- 4) сводка по Пикабу за сегодня — в 20:00 МСК админам (через tg-notify, как утренний отчёт)
create or replace function public.mutaciya_tg_pikabu()
returns bigint language plpgsql security definer set search_path = '' as $$
declare k text; d date := (now() at time zone 'Europe/Moscow')::date;
begin
  select cron_key into k from public.push_keys where id = 1;
  return net.http_post(
    url := 'https://auequuxfcwdshblqrwbd.supabase.co/functions/v1/tg-notify',
    headers := '{"Content-Type": "application/json"}'::jsonb,
    body := jsonb_build_object('key', k, 'text', public.mutaciya_pikabu_text(d, d)));
end $$;
revoke all on function public.mutaciya_tg_pikabu() from public, anon, authenticated;

select cron.unschedule('mutaciya-pikabu-daily') where exists (select 1 from cron.job where jobname = 'mutaciya-pikabu-daily');
select cron.schedule('mutaciya-pikabu-daily', '0 17 * * *', 'select public.mutaciya_tg_pikabu()');
