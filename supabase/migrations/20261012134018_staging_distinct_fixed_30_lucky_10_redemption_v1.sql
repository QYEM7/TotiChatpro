-- Stage-only financial correctness: FIXED_GIFT redeem at configured 30%;
-- LUCKY_GIFT redeem at 10%. Nonredeemable Lucky Points never enter diamond lots.
create or replace function phase3.preview_redemption(p_diamonds bigint)
returns jsonb language plpgsql security definer set search_path = ''
as $fn$
declare u uuid:=phase3.actor();state jsonb;f bigint;l bigint;coins bigint;
rate phase3.economy_settings%rowtype;
begin
 if p_diamonds is null or p_diamonds<=0 or p_diamonds>9007199254740991
 then raise exception 'Invalid diamond amount';end if;
 perform user_id from public.wallets where user_id=u for share;
 state:=phase3.diamond_state();
 if (state->>'diamonds')::bigint<p_diamonds then raise exception 'Insufficient diamonds';end if;
 f:=least(p_diamonds,(state->>'fixed')::bigint);l:=p_diamonds-f;
 if l>(state->>'lucky')::bigint then raise exception 'Insufficient tracked diamonds';end if;
 select * into rate from phase3.economy_settings where singleton for share;
 if not found or rate.redemption_denominator<1 or rate.redemption_numerator<0
 then raise exception 'Fixed diamond rate unavailable';end if;
 coins:=floor(f::numeric*rate.redemption_numerator/rate.redemption_denominator)
       +floor(l::numeric/10);
 if coins<=0 then raise exception 'Amount too small to redeem';end if;
 return jsonb_build_object('diamonds',p_diamonds,'fixed',f,'lucky',l,
  'coins',coins,'numerator',rate.redemption_numerator,'denominator',rate.redemption_denominator,
  'fixedConversionRate','30_PERCENT_CONFIGURED','luckyConversionRate','10_PERCENT',
  'luckyPointsRedeemable',false);
end $fn$;