-- Staging performance: cover the administrative updater FK without changing balances or feed data.
create index if not exists gift_announcement_settings_updated_by_idx on public.gift_announcement_settings(updated_by) where updated_by is not null;
