-- Phase 2 performance hardening. Cover foreign keys without changing data.
-- All indexes are on the independent TotiChatpro database.
create index if not exists phase2_invite_creator_fk_idx
  on public.phase2_room_invites(created_by);
create index if not exists phase2_invite_redeemer_fk_idx
  on public.phase2_room_invites(redeemed_by)
  where redeemed_by is not null;
create index if not exists phase2_messages_sender_fk_idx
  on public.room_messages(sender_id);
