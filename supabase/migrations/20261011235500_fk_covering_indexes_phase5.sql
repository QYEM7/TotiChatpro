-- Stage-only PG foreign-key covering indexes reported by Supabase performance advisors.
-- No data updates or deletions. Does not change approved app/production.
create index if not exists tc_fk_host_month_accrual_lines_host_id_ix on phase3.host_month_accrual_lines(host_id);
create index if not exists tc_fk_social_follow_requests_target_id_ix on phase3.social_follow_requests(target_id);
create index if not exists tc_fk_special_id_grant_requests_target_id_ix on phase3.special_id_grant_requests(target_id);
create index if not exists tc_fk_account_special_ids_granted_by_ix on public.account_special_ids(granted_by);
create index if not exists tc_fk_medal_catalog_created_by_ix on public.medal_catalog(created_by);
create index if not exists tc_fk_medal_entitlements_granted_by_ix on public.medal_entitlements(granted_by);
create index if not exists tc_fk_medal_entitlements_medal_key_ix on public.medal_entitlements(medal_key);
create index if not exists tc_fk_medal_entitlements_revoked_by_ix on public.medal_entitlements(revoked_by);
create index if not exists tc_fk_room_bans_banned_by_ix on public.room_bans(banned_by);
create index if not exists tc_fk_room_game_matches_player_o_ix on public.room_game_matches(player_o);
create index if not exists tc_fk_room_game_matches_player_x_ix on public.room_game_matches(player_x);
create index if not exists tc_fk_room_game_matches_winner_id_ix on public.room_game_matches(winner_id);
create index if not exists tc_fk_room_moderators_assigned_by_ix on public.room_moderators(assigned_by);
create index if not exists tc_fk_room_music_queue_added_by_ix on public.room_music_queue(added_by);
create index if not exists tc_fk_room_music_queue_bookmark_id_ix on public.room_music_queue(bookmark_id);
create index if not exists tc_fk_room_mutes_muted_by_ix on public.room_mutes(muted_by);
create index if not exists tc_fk_vip_entitlements_granted_by_ix on public.vip_entitlements(granted_by);
