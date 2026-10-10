-- T04/T45: forward-only foreign-key lookup indexes from read-only Supabase linter.
-- The production advisor reported five missing FK indexes on 2026-10-10.
-- Apply on verified staging after independent backup/restore; NEVER auto-deploy to production.
create index if not exists admin_access_assigned_by_fk_idx
 on phase3.admin_access(assigned_by);
create index if not exists cp_pair_type_conflicts_type_b_fk_idx
 on phase3.cp_pair_type_conflicts(type_b);
create index if not exists cp_type_conflicts_type_b_fk_idx
 on phase3.cp_type_conflicts(type_b);
create index if not exists session_audits_user_id_fk_idx
 on phase3.session_audits(user_id);
create index if not exists recharge_reward_claims_tier_id_fk_idx
 on public.recharge_reward_claims(tier_id);
