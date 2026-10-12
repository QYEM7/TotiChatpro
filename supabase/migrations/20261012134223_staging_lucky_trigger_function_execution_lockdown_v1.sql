-- Security hardening: internal Lucky trigger functions cannot be invoked directly
-- by anonymous/public clients or standard authenticated sessions. Only DB triggers execute them.
revoke all on function phase3.draw_verified_lucky_award() from public,anon,authenticated;
revoke all on function phase3.reject_unapproved_lucky_gift() from public,anon,authenticated;