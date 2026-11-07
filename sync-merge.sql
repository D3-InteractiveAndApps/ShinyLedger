-- Shiny Ledger: merge counts from several devices instead of overwriting them.
-- Run once in Supabase → SQL Editor → New query → Run. Safe to run again.
-- Updated Nov 2026: also returns updated_at, the time the server saved the change,
-- so the app can ignore realtime broadcasts that are older than its own save.
--
-- Each device sends how many encounters (and chain links) it ADDED since it last
-- synced. The server adds them on top of what's stored, so counting on a phone and a
-- computer at the same time, even offline, never loses encounters.
-- "Set count" and "chain broke" are sent as absolute values and replace the number.
-- Other fields (notes, status, method, …) keep whichever edit is newest.

create or replace function public.sync_hunt(
  p_id            text,
  p_data          jsonb,
  p_count_delta   integer default 0,
  p_chain_delta   integer default 0,
  p_set_count     boolean default false,
  p_set_chain     boolean default false,
  p_deleted       boolean default false
)
returns jsonb
language plpgsql
security invoker            -- runs as the signed-in player, so row security still applies
set search_path = ''
as $$
declare
  cur     public.hunts%rowtype;
  base    jsonb;
  new_cnt integer;
  new_chn integer;
  out     jsonb;
  ts      timestamptz := now();
begin
  if auth.uid() is null then
    raise exception 'Not signed in';
  end if;

  select * into cur from public.hunts where id = p_id for update;

  -- First time this hunt reaches the server.
  if not found then
    insert into public.hunts (id, user_id, data, deleted, updated_at)
    values (p_id, auth.uid(), case when p_deleted then '{}'::jsonb else coalesce(p_data, '{}'::jsonb) end, p_deleted, ts);
    return jsonb_build_object('data', case when p_deleted then '{}'::jsonb else p_data end, 'deleted', p_deleted, 'updated_at', ts);
  end if;

  -- Deleting wins over any later edits from another device.
  if p_deleted or cur.deleted then
    update public.hunts set deleted = true, data = '{}'::jsonb, updated_at = ts where id = p_id;
    return jsonb_build_object('data', '{}'::jsonb, 'deleted', true, 'updated_at', ts);
  end if;

  -- Newest edit wins for everything except the counters.
  if coalesce((p_data->>'updated')::numeric, 0) >= coalesce((cur.data->>'updated')::numeric, 0) then
    base := p_data;
  else
    base := cur.data;
  end if;

  new_cnt := case when p_set_count then coalesce((p_data->>'count')::integer, 0)
                  else greatest(0, coalesce((cur.data->>'count')::integer, 0) + coalesce(p_count_delta, 0)) end;
  new_chn := case when p_set_chain then coalesce((p_data->>'chain')::integer, 0)
                  else greatest(0, coalesce((cur.data->>'chain')::integer, 0) + coalesce(p_chain_delta, 0)) end;

  out := jsonb_set(jsonb_set(base, '{count}', to_jsonb(new_cnt)), '{chain}', to_jsonb(new_chn));

  update public.hunts set data = out, deleted = false, updated_at = ts where id = p_id;
  return jsonb_build_object('data', out, 'deleted', false, 'updated_at', ts);
end;
$$;

revoke all on function public.sync_hunt(text, jsonb, integer, integer, boolean, boolean, boolean) from public, anon;
grant execute on function public.sync_hunt(text, jsonb, integer, integer, boolean, boolean, boolean) to authenticated;
