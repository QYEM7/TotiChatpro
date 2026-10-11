-- Staging only: cover audited phase4 foreign keys without modifying records.
create index if not exists admin_access_assigned_by_idx on phase3.admin_access(assigned_by);
create index if not exists cp_pair_type_conflicts_type_b_idx on phase3.cp_pair_type_conflicts(type_b);
create index if not exists cp_type_conflicts_type_b_idx on phase3.cp_type_conflicts(type_b);
create index if not exists session_audits_user_id_idx on phase3.session_audits(user_id);
create index if not exists recharge_reward_claims_tier_id_idx on public.recharge_reward_claims(tier_id);
