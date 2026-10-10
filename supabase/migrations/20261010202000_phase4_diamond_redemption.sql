create table phase3.economy_settings (
 singleton boolean primary key default true check(singleton),
 redemption_numerator integer not null check(redemption_numerator>0),
 redemption_denominator integer not null check(redemption_denominator>=redemption_numerator)
);
insert into phase3.economy_settings(redemption_numerator,redemption_denominator) values(3,10);
alter table phase3.economy_settings enable row level security;
revoke all on phase3.economy_settings from public,anon,authenticated;
create table public.diamond_lots (
 id uuid primary key default gen_random_uuid(),user_id uuid not null references auth.users(id),
 gift_event_id uuid not null unique references public.gift_events(id),
 source_type text not null check(source_type in('FIXED_GIFT','LUCKY_GIFT')),
 amount bigint not null check(amount>0),remaining bigint not null check(remaining>=0 and remaining<=amount),
 created_at timestamptz not null default now()
);
create table public.diamond_redemptions (
 id uuid primary key references public.financial_operations(id),user_id uuid not null references auth.users(id),
 diamonds_amount bigint not null check(diamonds_amount>0),fixed_diamonds bigint not null check(fixed_diamonds>=0),
 lucky_diamonds bigint not null check(lucky_diamonds>=0),coins_amount bigint not null check(coins_amount>0),
 created_at timestamptz not null default now(),check(fixed_diamonds+lucky_diamonds=diamonds_amount)
);
create table public.diamond_redemption_allocations (
 redemption_id uuid not null references public.diamond_redemptions(id),
 lot_id uuid not null references public.diamond_lots(id),amount bigint not null check(amount>0),
 primary key(redemption_id,lot_id)
);
create index diamond_lots_user_created_idx on public.diamond_lots(user_id,created_at,id);
create index diamond_redemptions_user_idx on public.diamond_redemptions(user_id,created_at desc);
create index diamond_allocations_lot_idx on public.diamond_redemption_allocations(lot_id);
alter table public.diamond_lots enable row level security;
alter table public.diamond_redemptions enable row level security;
alter table public.diamond_redemption_allocations enable row level security;
revoke all on public.diamond_lots,public.diamond_redemptions,public.diamond_redemption_allocations from public,anon,authenticated;
grant select on public.diamond_lots,public.diamond_redemptions,public.diamond_redemption_allocations to authenticated;
create policy lot_self on public.diamond_lots for select to authenticated using(user_id=(select auth.uid()));
create policy redemption_self on public.diamond_redemptions for select to authenticated using(user_id=(select auth.uid()));
create policy allocation_self on public.diamond_redemption_allocations for select to authenticated using(exists(select 1 from public.diamond_redemptions r where r.id=redemption_id and r.user_id=(select auth.uid())));
create function phase3.issue_gift_diamond_lot() returns trigger language plpgsql security definer set search_path='' as $$
begin
 if auth.uid() is distinct from new.sender_id then raise exception 'Gift issuer mismatch' using errcode='42501';end if;
 insert into public.diamond_lots(user_id,gift_event_id,source_type,amount,remaining) values(new.recipient_id,new.id,new.diamond_source_type,new.amount,new.amount);
 return new;
end $$;
revoke all on function phase3.issue_gift_diamond_lot() from public,anon,authenticated;
create trigger phase4_gift_diamond_source after insert on public.gift_events for each row execute function phase3.issue_gift_diamond_lot();
-- Backfill only actual already-issued gifts; no invented balances or legacy accounts.
insert into public.diamond_lots(user_id,gift_event_id,source_type,amount,remaining,created_at)
select recipient_id,id,diamond_source_type,amount,amount,created_at from public.gift_events;
create function phase3.diamond_state() returns jsonb language plpgsql security definer set search_path='' as $$
declare u uuid:=phase3.actor();f bigint;l bigint;balance bigint;
begin
 select diamonds into balance from public.wallets where user_id=u;
 if balance is null then raise exception 'Wallet unavailable';end if;
 select coalesce(sum(remaining) filter(where source_type='FIXED_GIFT'),0),coalesce(sum(remaining) filter(where source_type='LUCKY_GIFT'),0) into f,l from public.diamond_lots where user_id=u;
 return jsonb_build_object('diamonds',balance,'fixed',f,'lucky',l,'untracked',greatest(0,balance-f-l));
end $$;
create function phase3.preview_redemption(p_diamonds bigint) returns jsonb language plpgsql security definer set search_path='' as $$
declare u uuid:=phase3.actor();state jsonb;f bigint;l bigint;coins bigint;rate phase3.economy_settings%rowtype;
begin
 if p_diamonds is null or p_diamonds<=0 or p_diamonds>9007199254740991 then raise exception 'Invalid diamond amount';end if;
 perform user_id from public.wallets where user_id=u for share;
 state:=phase3.diamond_state();
 if (state->>'diamonds')::bigint<p_diamonds then raise exception 'Insufficient diamonds';end if;
 f:=least(p_diamonds,(state->>'fixed')::bigint);l:=p_diamonds-f;
 if l>(state->>'lucky')::bigint then raise exception 'Insufficient tracked diamonds';end if;
 select * into rate from phase3.economy_settings where singleton for share;
 coins:=floor(f::numeric*rate.redemption_numerator/rate.redemption_denominator)+floor(l::numeric*rate.redemption_numerator/rate.redemption_denominator);
 if coins<=0 then raise exception 'Amount too small to redeem';end if;
 return jsonb_build_object('diamonds',p_diamonds,'fixed',f,'lucky',l,'coins',coins,'numerator',rate.redemption_numerator,'denominator',rate.redemption_denominator);
end $$;
create function phase3.redeem_diamonds(p_diamonds bigint,p_expected_coins bigint,p_request_id uuid) returns jsonb language plpgsql security definer set search_path='' as $$
declare u uuid:=phase3.actor();prior public.financial_operations%rowtype;body jsonb;quote jsonb;op uuid;
 lot public.diamond_lots%rowtype;left_to_use bigint;take bigint;coin_balance bigint;diamond_balance bigint;answer jsonb;
begin
 if p_request_id is null or p_diamonds is null or p_diamonds<=0 or p_diamonds>9007199254740991 then raise exception 'Invalid redemption';end if;
 body:=jsonb_build_object('diamonds',p_diamonds);
 select * into prior from public.financial_operations where actor_id=u and request_id=p_request_id;
 if found then if prior.operation<>'diamond_redemption' or prior.payload<>body then raise exception 'Idempotency key conflict';end if;return prior.result;end if;
 if (select count(*) from public.financial_operations where actor_id=u and created_at>now()-interval '1 minute')>=30 then raise exception 'Rate limit exceeded';end if;
 perform user_id from public.wallets where user_id=u for update;
 quote:=phase3.preview_redemption(p_diamonds);
 if p_expected_coins is null or p_expected_coins<>(quote->>'coins')::bigint then raise exception 'Redemption quote changed; confirm again';end if;
 insert into public.financial_operations(actor_id,request_id,operation,payload) values(u,p_request_id,'diamond_redemption',body) returning id into op;
 insert into public.diamond_redemptions(id,user_id,diamonds_amount,fixed_diamonds,lucky_diamonds,coins_amount) values(op,u,p_diamonds,(quote->>'fixed')::bigint,(quote->>'lucky')::bigint,p_expected_coins);
 left_to_use:=p_diamonds;
 for lot in select * from public.diamond_lots where user_id=u and remaining>0 order by source_type,created_at,id for update loop
  exit when left_to_use=0;take:=least(left_to_use,lot.remaining);
  update public.diamond_lots set remaining=remaining-take where id=lot.id;
  insert into public.diamond_redemption_allocations(redemption_id,lot_id,amount) values(op,lot.id,take);
  left_to_use:=left_to_use-take;
 end loop;
 if left_to_use<>0 then raise exception 'Insufficient tracked diamonds';end if;
 update public.wallets set diamonds=diamonds-p_diamonds,coins=coins+p_expected_coins,updated_at=now() where user_id=u and diamonds>=p_diamonds and coins<=9007199254740991-p_expected_coins returning coins,diamonds into coin_balance,diamond_balance;
 if not found then raise exception 'Wallet amount out of range';end if;
 insert into public.wallet_ledger(user_id,currency,amount_change,balance_after,operation_id,transaction_id,kind) values(u,'diamonds',-p_diamonds,diamond_balance,gen_random_uuid(),op,'diamond_conversion'),(u,'coins',p_expected_coins,coin_balance,gen_random_uuid(),op,'diamond_conversion');
 insert into public.security_audit(actor_id,operation_id,action,details) values(u,op,'diamond_redemption',quote);
 answer:=quote||jsonb_build_object('id',op,'status','completed','coin_balance',coin_balance,'diamond_balance',diamond_balance);
 update public.financial_operations set result=answer where id=op;return answer;
end $$;
revoke all on function phase3.diamond_state(),phase3.preview_redemption(bigint),phase3.redeem_diamonds(bigint,bigint,uuid) from public,anon;
grant execute on function phase3.diamond_state(),phase3.preview_redemption(bigint),phase3.redeem_diamonds(bigint,bigint,uuid) to authenticated;
create function public.phase4_diamond_state() returns jsonb language sql security invoker set search_path='' as $$select phase3.diamond_state()$$;
create function public.phase4_preview_redemption(p_diamonds bigint) returns jsonb language sql security invoker set search_path='' as $$select phase3.preview_redemption(p_diamonds)$$;
create function public.phase4_redeem_diamonds(p_diamonds bigint,p_expected_coins bigint,p_request_id uuid) returns jsonb language sql security invoker set search_path='' as $$select phase3.redeem_diamonds(p_diamonds,p_expected_coins,p_request_id)$$;
revoke all on function public.phase4_diamond_state(),public.phase4_preview_redemption(bigint),public.phase4_redeem_diamonds(bigint,bigint,uuid) from public,anon;
grant execute on function public.phase4_diamond_state(),public.phase4_preview_redemption(bigint),public.phase4_redeem_diamonds(bigint,bigint,uuid) to authenticated;
