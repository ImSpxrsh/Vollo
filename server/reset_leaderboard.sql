-- Resets the VOLL online leaderboard: every player's best goes back to 0 and
-- the board starts empty. Accounts, passwords, synced progress (coins,
-- upgrades) and community maps are NOT touched.
-- This cannot be undone. Run it in Supabase: SQL Editor -> New query -> Run.

update public.voll_players set best = 0, best_at = null;
