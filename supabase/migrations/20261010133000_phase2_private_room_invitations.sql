-- Phase 2: ephemeral one-use invitations to private rooms.
-- No old data or tables modified. The invite secret is never stored in plaintext.
create table public.phase2_room_invites (
  room_id uuid primary key references public.rooms(id) on delete cascade,
  token_hash text not null,
  created_by uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  expires_at timestamptz not null,
  redeemed_at timestamptz,
  redeemed_by uuid references auth.users(id),
  constraint phase2_invite_hash_length check (char_length(token_hash)=64)
);
create index phase2_invite_expiry on public.phase2_room_invites(expires_at);
alter table public.phase2_room_invites enable row level security;
-- All access to invitation rows must go through caller-checked RPCs.
revoke all on public.phase2_room_invites from public, anon, authenticated;

create function public.phase2_room_invite_create(p_room_id uuid)
returns text
language plpgsql security definer set search_path=''
as $$
declare caller uuid; secret text;
begin
  caller:=auth.uid();
  if caller is null then raise exception 'not authenticated'; end if;
  -- Serialize against room deletion and competing code generation.
  perform 1 from public.rooms r
  where r.id=p_room_id and r.owner_id=caller and r.is_private
  for update;
  if not found then raise exception 'not owner of a private room'; end if;
  secret:=pg_catalog.encode(extensions.gen_random_bytes(24),'hex');
  insert into public.phase2_room_invites(room_id,token_hash,created_by,expires_at)
  values(p_room_id,pg_catalog.encode(extensions.digest(secret,'sha256'),'hex'),
    caller,now()+interval '30 minutes')
  on conflict(room_id) do update
    set token_hash=excluded.token_hash,
        created_by=excluded.created_by,
        created_at=now(),
        expires_at=excluded.expires_at,
        redeemed_at=null,
        redeemed_by=null;
  return p_room_id::text||':'||secret;
end;
$$;

create function public.phase2_room_invite_join(p_room_id uuid,p_token text)
returns boolean
language plpgsql security definer set search_path=''
as $$
declare caller uuid; candidate_hash text; inv public.phase2_room_invites%rowtype;
begin
  caller:=auth.uid();
  if caller is null then raise exception 'not authenticated'; end if;
  if p_room_id is null or p_token is null
     or p_token !~ '^[0-9a-f]{48}$' then
     raise exception 'invalid invite'; end if;

  -- A one-use token is consumed in the same transaction as membership creation.
  select * into inv from public.phase2_room_invites
    where room_id=p_room_id for update;
  if not found or inv.expires_at<=now() or inv.redeemed_at is not null then
     raise exception 'invite expired or used'; end if;
  candidate_hash:=pg_catalog.encode(extensions.digest(p_token,'sha256'),'hex');
  if candidate_hash<>inv.token_hash then raise exception 'invalid invite'; end if;

  perform 1 from public.rooms r
   where r.id=p_room_id and r.is_private for share;
  if not found then raise exception 'room is unavailable'; end if;
  if exists(select 1 from public.room_members
    where user_id=caller) then
    raise exception 'leave your current room first'; end if;
  insert into public.room_members(room_id,user_id) values(p_room_id,caller);
  update public.phase2_room_invites
    set redeemed_at=now(),redeemed_by=caller
    where room_id=p_room_id;
  return true;
end;
$$;

revoke all on function
  public.phase2_room_invite_create(uuid),
  public.phase2_room_invite_join(uuid,text)
from public,anon;
grant execute on function
  public.phase2_room_invite_create(uuid),
  public.phase2_room_invite_join(uuid,text)
to authenticated;

comment on table public.phase2_room_invites is
 'Private room codes: 24 random bytes, hashed, single use, 30-minute expiry; not client readable.';
