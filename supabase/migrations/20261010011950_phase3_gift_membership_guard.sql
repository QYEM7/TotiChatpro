-- A recipient may leave between preliminary validation and acquiring row locks.
create or replace function phase3.send_gift(p_room_id uuid,p_recipient_id uuid,p_gift_id text,p_quantity integer,p_request_id uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
declare u uuid:=phase3.actor(); prior public.financial_operations%rowtype;
 g public.gift_catalog%rowtype; total bigint; debit bigint; credit bigint; op uuid; body jsonb; answer jsonb; member_count integer;
begin
 if p_request_id is null or p_room_id is null or p_recipient_id is null or p_gift_id is null or p_quantity is null or p_quantity not in(1,7,17,77,777) or p_recipient_id=u then raise exception 'Invalid gift request';end if;
 body:=jsonb_build_object('room',p_room_id,'recipient',p_recipient_id,'gift',p_gift_id,'quantity',p_quantity);
 perform pg_advisory_xact_lock(hashtextextended(u::text||p_request_id::text,0));
 select * into prior from public.financial_operations where actor_id=u and request_id=p_request_id;
 if found then
  if prior.operation<>'gift' or prior.payload<>body then raise exception 'Idempotency key conflict';end if;return prior.result;
 end if;
 if (select count(*) from public.financial_operations where actor_id=u and created_at>now()-interval '1 minute')>=30 then raise exception 'Rate limit exceeded';end if;
 if not exists(select 1 from public.room_members where room_id=p_room_id and user_id=u) or not exists(select 1 from public.room_members where room_id=p_room_id and user_id=p_recipient_id) then raise exception 'Room membership required' using errcode='42501';end if;
 -- Hold both memberships throughout the transaction, including concurrent room exit.
 perform user_id from public.room_members where room_id=p_room_id and user_id in(u,p_recipient_id) order by user_id for share;
 get diagnostics member_count=row_count;
 if member_count<>2 then raise exception 'Room membership expired' using errcode='42501';end if;
 select * into g from public.gift_catalog where id=p_gift_id and is_active for share;
 if not found then raise exception 'Gift unavailable';end if;
 -- CP requires the relationship subsystem; never bypass its pairing rules.
 if g.relationship_type_id is not null then raise exception 'A confirmed CP relationship is required';end if;
 if not exists(select 1 from public.gift_categories where id=g.category_id and enabled) then raise exception 'Category unavailable';end if;
 total:=g.price*p_quantity;
 if total>9007199254740991 then raise exception 'Amount out of range';end if;
 perform user_id from public.wallets where user_id in(u,p_recipient_id) order by user_id for update;
 update public.wallets set coins=coins-total,updated_at=now() where user_id=u and coins>=total returning coins into debit;
 if not found then raise exception 'Insufficient coins';end if;
 update public.wallets set diamonds=diamonds+total,updated_at=now() where user_id=p_recipient_id and diamonds<=9007199254740991-total returning diamonds into credit;
 if not found then raise exception 'Recipient wallet unavailable';end if;
 insert into public.financial_operations(actor_id,request_id,operation,payload) values(u,p_request_id,'gift',body) returning id into op;
 insert into public.gift_events(id,sender_id,recipient_id,room_id,gift_id,quantity,amount,diamond_source_type) values(op,u,p_recipient_id,p_room_id,g.id,p_quantity,total,g.diamond_source_type);
 insert into public.wallet_ledger(user_id,currency,amount_change,balance_after,operation_id,kind,transaction_id) values
 (u,'coins',-total,debit,gen_random_uuid(),'gift_sent',op),(p_recipient_id,'diamonds',total,credit,gen_random_uuid(),'gift_received',op);
 insert into public.security_audit(actor_id,operation_id,action,details) values(u,op,'gift_sent',body||jsonb_build_object('amount',total));
 answer:=jsonb_build_object('id',op,'status','completed','amount',total,'balance',debit,'gift_id',g.id,'quantity',p_quantity);
 update public.financial_operations set result=answer where id=op;
 return answer;
end $$;
