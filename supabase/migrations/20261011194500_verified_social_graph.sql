-- TotiChat beta social graph, live accounts only. No invented followers.
-- Follow direction is explicit; mutual follow is a friend, not a unilateral grant.
create table public.social_follows(
 follower_id uuid not null references auth.users(id) on delete cascade,
 followed_id uuid not null references auth.users(id) on delete cascade,
 created_at timestamptz not null default now(),
 primary key(follower_id,followed_id),
 constraint tc_social_no_self check(follower_id<>followed_id)
);
create index tc_social_followed_new on public.social_follows(followed_id,created_at desc);
create index tc_social_follower_new on public.social_follows(follower_id,created_at desc);
alter table public.social_follows enable row level security;
revoke all on public.social_follows from public,anon,authenticated;

create table phase3.social_follow_requests(
 actor_id uuid not null references auth.users(id) on delete cascade,
 request_id uuid not null,
 target_id uuid not null references auth.users(id) on delete cascade,
 desired boolean not null,
 created_at timestamptz not null default now(),
 primary key(actor_id,request_id)
);
create index tc_social_rate on phase3.social_follow_requests(actor_id,created_at desc);
alter table phase3.social_follow_requests enable row level security;
revoke all on phase3.social_follow_requests from public,anon,authenticated;

create function phase3.social_follow(p_target uuid,p_follow boolean,p_request_id uuid)
returns jsonb language plpgsql security definer set search_path='' as $fn$
declare me uuid:=phase3.actor(); prior phase3.social_follow_requests%rowtype;target_name text;
begin
 if p_target is null or p_target=me or p_follow is null or p_request_id is null then
  raise exception 'Invalid follow request';
 end if;
 select p.display_name into target_name
 from public.profiles p join auth.users u on u.id=p.id
 where p.id=p_target and u.deleted_at is null and u.email_confirmed_at is not null
 and not coalesce(u.is_anonymous,false) and (u.banned_until is null or u.banned_until<now());
 if not found then raise exception 'Account unavailable' using errcode='42501';end if;
 select * into prior from phase3.social_follow_requests x
 where x.actor_id=me and x.request_id=p_request_id;
 if found then
  if prior.target_id<>p_target or prior.desired<>p_follow then
   raise exception 'Follow idempotency conflict';
  end if;
  return jsonb_build_object('followed',p_follow,'targetId',p_target);
 end if;
 if (select count(*) from phase3.social_follow_requests x
   where x.actor_id=me and x.created_at>now()-interval '1 minute')>=30 then
  raise exception 'Follow rate limit exceeded';
 end if;
 if exists(select 1 from public.dm_blocks b
   where (b.blocker_id=me and b.blocked_id=p_target)
    or (b.blocker_id=p_target and b.blocked_id=me)) then
   raise exception 'Social action is blocked' using errcode='42501';
 end if;
 if p_follow then
  insert into public.social_follows(follower_id,followed_id)
  values(me,p_target) on conflict do nothing;
 else
  delete from public.social_follows where follower_id=me and followed_id=p_target;
 end if;
 insert into phase3.social_follow_requests(actor_id,request_id,target_id,desired)
 values(me,p_request_id,p_target,p_follow);
 return jsonb_build_object('followed',p_follow,'targetId',p_target);
end $fn$;
revoke all on function phase3.social_follow(uuid,boolean,uuid) from public,anon;
grant execute on function phase3.social_follow(uuid,boolean,uuid) to authenticated;

-- Existing DM blocks must also sever an existing follow in BOTH directions.
-- No direct writes to another customer's follow state are otherwise granted.
create function phase3.social_disconnect_on_dm_block()
returns trigger language plpgsql security definer set search_path='' as $fn$
begin
 delete from public.social_follows f where
  (f.follower_id=new.blocker_id and f.followed_id=new.blocked_id)
  or (f.follower_id=new.blocked_id and f.followed_id=new.blocker_id);
 return new;
end $fn$;
revoke all on function phase3.social_disconnect_on_dm_block() from public,anon,authenticated;
create trigger tc_social_disconnect_on_block
 after insert on public.dm_blocks for each row
 execute function phase3.social_disconnect_on_dm_block();

-- Authenticated view of counts, caller follow state and mutual friends.
-- Return 0 for genuine empty relations. Hard cap list to protect resources.
create function phase3.social_overview(p_target uuid)
returns jsonb language plpgsql security definer set search_path='' as $fn$
declare me uuid:=phase3.actor(); followers bigint; following bigint;friends bigint; mine boolean;their boolean;
begin
 if p_target is null or not exists(select 1 from public.profiles p where p.id=p_target) then
  raise exception 'Account unavailable' using errcode='42501';
 end if;
 if p_target<>me and exists(select 1 from public.dm_blocks b
  where (b.blocker_id=me and b.blocked_id=p_target)
   or (b.blocker_id=p_target and b.blocked_id=me)) then
  raise exception 'Social account unavailable' using errcode='42501';
 end if;
 select count(*) into followers from public.social_follows where followed_id=p_target;
 select count(*) into following from public.social_follows where follower_id=p_target;
 select count(*) into friends from public.social_follows f
 where f.follower_id=p_target and exists
 (select 1 from public.social_follows reciprocal
  where reciprocal.follower_id=f.followed_id and reciprocal.followed_id=p_target);
 select exists(select 1 from public.social_follows
  where follower_id=me and followed_id=p_target) into mine;
 select exists(select 1 from public.social_follows
  where follower_id=p_target and followed_id=me) into their;
 return jsonb_build_object('userId',p_target,'followers',followers,
  'following',following,'friends',friends,'isFollowing',mine,
  'followsYou',their,'mutual',mine and their);
end $fn$;
revoke all on function phase3.social_overview(uuid) from public,anon;
grant execute on function phase3.social_overview(uuid) to authenticated;

-- Recipient list: no raw e-mails or private account data; cursor protects
-- results and the other's block relationship is respected.
create function phase3.social_list(p_kind text,p_limit integer default 25,
 p_before timestamptz default null)
returns jsonb language plpgsql security definer set search_path='' as $fn$
declare me uuid:=phase3.actor();nodes jsonb;
begin
 if p_kind not in('followers','following','friends') or p_limit is null
  or p_limit not between 1 and 50 or
  (p_before is not null and p_before>now()+interval '1 minute') then
  raise exception 'Invalid social page';
 end if;
 select coalesce(jsonb_agg(to_jsonb(t) order by t.created_at desc,t.user_id),'[]'::jsonb)
 into nodes from (
  select case when p_kind='followers' then f.follower_id else f.followed_id end user_id,
    p.display_name,p.avatar_url,f.created_at,
    exists(select 1 from public.social_follows mine
      where mine.follower_id=me and mine.followed_id=p.id) as is_following
  from public.social_follows f
  join public.profiles p on p.id=(
    case when p_kind='followers' then f.follower_id else f.followed_id end)
  where (case when p_kind='followers' then f.followed_id else f.follower_id end)=me
   and (p_before is null or f.created_at<p_before)
   and (p_kind<>'friends' or exists(select 1 from public.social_follows reciprocal
     where reciprocal.follower_id=f.followed_id and reciprocal.followed_id=me))
   and not exists(select 1 from public.dm_blocks b
     where (b.blocker_id=me and b.blocked_id=p.id)
        or (b.blocker_id=p.id and b.blocked_id=me))
  order by f.created_at desc,f.follower_id,f.followed_id
  limit p_limit
 ) t;
 return jsonb_build_object('items',nodes);
end $fn$;
revoke all on function phase3.social_list(text,integer,timestamptz) from public,anon;
grant execute on function phase3.social_list(text,integer,timestamptz) to authenticated;

-- Discover by exact name prefix only; no email, phone or unverified accounts.
create function phase3.social_search(p_prefix text,p_limit integer default 15)
returns jsonb language plpgsql security definer set search_path='' as $fn$
declare me uuid:=phase3.actor();results jsonb;prefix text:=btrim(coalesce(p_prefix,''));
begin
 if char_length(prefix) not between 2 and 40 or p_limit is null or p_limit not between 1 and 20 then
  raise exception 'Use 2-40 characters to search';
 end if;
 select coalesce(jsonb_agg(to_jsonb(t) order by t.display_name,t.user_id),'[]'::jsonb)
 into results from (
  select p.id user_id,p.display_name,p.avatar_url,
    exists(select 1 from public.social_follows mine
      where mine.follower_id=me and mine.followed_id=p.id) as is_following
  from public.profiles p join auth.users u on u.id=p.id
  where p.id<>me and p.display_name ilike
     replace(replace(replace(prefix,'\\','\\\\'),'%','\\%'),'_','\\_')||'%'
   and u.deleted_at is null and u.email_confirmed_at is not null
   and not coalesce(u.is_anonymous,false)
   and (u.banned_until is null or u.banned_until<now())
   and not exists(select 1 from public.dm_blocks b where
     (b.blocker_id=me and b.blocked_id=p.id)
      or (b.blocker_id=p.id and b.blocked_id=me))
  order by p.display_name,p.id limit p_limit
 ) t;
 return jsonb_build_object('items',results);
end $fn$;
revoke all on function phase3.social_search(text,integer) from public,anon;
grant execute on function phase3.social_search(text,integer) to authenticated;

create function public.phase5_social_follow(p_target uuid,p_follow boolean,p_request_id uuid)
returns jsonb language plpgsql security invoker set search_path='' as $fn$
begin perform phase3.actor();return phase3.social_follow(p_target,p_follow,p_request_id);end $fn$;
create function public.phase5_social_overview(p_target uuid)
returns jsonb language plpgsql security invoker set search_path='' as $fn$
begin perform phase3.actor();return phase3.social_overview(p_target);end $fn$;
create function public.phase5_social_list(p_kind text,p_limit integer default 25,
 p_before timestamptz default null)
returns jsonb language plpgsql security invoker set search_path='' as $fn$
begin perform phase3.actor();return phase3.social_list(p_kind,p_limit,p_before);end $fn$;
create function public.phase5_social_search(p_prefix text,p_limit integer default 15)
returns jsonb language plpgsql security invoker set search_path='' as $fn$
begin perform phase3.actor();return phase3.social_search(p_prefix,p_limit);end $fn$;
revoke all on function public.phase5_social_follow(uuid,boolean,uuid),
 public.phase5_social_overview(uuid),public.phase5_social_list(text,integer,timestamptz),
 public.phase5_social_search(text,integer) from public,anon;
grant execute on function public.phase5_social_follow(uuid,boolean,uuid),
 public.phase5_social_overview(uuid),public.phase5_social_list(text,integer,timestamptz),
 public.phase5_social_search(text,integer) to authenticated;
comment on table public.social_follows is
 'Verified directed follow edges; mutual edges are friends; rows are private to backend RPC and never seeded or fabricated.';
