alter table public.wallet_ledger drop constraint wallet_ledger_kind_check;
alter table public.wallet_ledger add constraint wallet_ledger_kind_check check(kind in('owner_grant','agent_topup','gift_sent','gift_received','store_purchase','diamond_conversion','monthly_settlement','moderation_adjustment','refund','transfer_sent','transfer_received'));
create function phase3.transfer_coins(p_recipient_id uuid,p_amount bigint,p_request_id uuid) returns jsonb language plpgsql security definer set search_path='' as $$
declare u uuid:=phase3.actor(); prior public.financial_operations%rowtype; body jsonb; op uuid; debit bigint; credit bigint; answer jsonb;
begin
 if p_recipient_id is null or p_recipient_id=u or p_amount is null or p_amount<=0 or p_amount>9007199254740991 or p_request_id is null then raise exception 'Invalid transfer';end if;
 body:=jsonb_build_object('recipient',p_recipient_id,'amount',p_amount);
 select * into prior from public.financial_operations where actor_id=u and request_id=p_request_id;
 if found then if prior.operation<>'transfer' or prior.payload<>body then raise exception 'Idempotency key conflict';end if;return prior.result;end if;
 if (select count(*) from public.financial_operations where actor_id=u and created_at>now()-interval '1 minute')>=30 then raise exception 'Rate limit exceeded';end if;
 if not exists(select 1 from auth.users where id=p_recipient_id and email_confirmed_at is not null and not coalesce(is_anonymous,false) and (banned_until is null or banned_until<now())) then raise exception 'Recipient unavailable';end if;
 perform user_id from public.wallets where user_id in(u,p_recipient_id) order by user_id for update;
 update public.wallets set coins=coins-p_amount,updated_at=now() where user_id=u and coins>=p_amount returning coins into debit;
 if not found then raise exception 'Insufficient coins';end if;
 update public.wallets set coins=coins+p_amount,updated_at=now() where user_id=p_recipient_id and coins<=9007199254740991-p_amount returning coins into credit;
 if not found then raise exception 'Recipient wallet unavailable';end if;
 insert into public.financial_operations(actor_id,request_id,operation,payload) values(u,p_request_id,'transfer',body) returning id into op;
 insert into public.wallet_ledger(user_id,currency,amount_change,balance_after,operation_id,transaction_id,kind) values(u,'coins',-p_amount,debit,gen_random_uuid(),op,'transfer_sent'),(p_recipient_id,'coins',p_amount,credit,gen_random_uuid(),op,'transfer_received');
 insert into public.security_audit(actor_id,operation_id,action,details) values(u,op,'coin_transfer',body);
 answer:=jsonb_build_object('id',op,'status','completed','amount',p_amount,'balance',debit);
 update public.financial_operations set result=answer where id=op;return answer;
end $$;
revoke all on function phase3.transfer_coins(uuid,bigint,uuid) from public,anon;
grant execute on function phase3.transfer_coins(uuid,bigint,uuid) to authenticated;
create function public.phase3_transfer_coins(p_recipient_id uuid,p_amount bigint,p_request_id uuid) returns jsonb language sql security invoker set search_path='' as $$select phase3.transfer_coins(p_recipient_id,p_amount,p_request_id)$$;
revoke all on function public.phase3_transfer_coins(uuid,bigint,uuid) from public,anon;
grant execute on function public.phase3_transfer_coins(uuid,bigint,uuid) to authenticated;
