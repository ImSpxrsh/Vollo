# VOLL online leaderboard

The game talks to a free [Supabase](https://supabase.com) project. Players make an account in-game with
just a name and a password (no email). Their best single-player distance is posted automatically after
each run, and the LEADERBOARD screen shows the top 50.

## One-time setup (about 5 minutes)

1. Sign up at supabase.com and create a new project (the free plan is fine). Pick any region and database
   password.
2. In the project, open **SQL Editor → New query**, paste everything from [`leaderboard.sql`](leaderboard.sql)
   and press **Run**. It creates two tables and the functions the game calls. Running it again is safe.
3. Open **Project Settings → API Keys** (or **Data API**) and copy:
   - the **Project URL**, for example `https://abcdefgh.supabase.co`
   - the **publishable** key (`sb_publishable_...`), or the legacy **anon** key (`eyJ...`)
4. Paste both into the top of `godot/autoload/Leaderboard.gd`:

   ```gdscript
   const SERVER_URL := "https://abcdefgh.supabase.co"
   const SERVER_KEY := "sb_publishable_..."
   ```

5. Re-export the web build. The leaderboard switches on as soon as the URL is set.

The publishable/anon key is meant to be public, so it's fine in the game files. Never put the
**secret** or **service_role** key in the game.

## How it's protected

- The tables have row-level security on and no policies, so the public key can't read or change them
  directly. Everything goes through the `voll_*` functions.
- Passwords are stored as bcrypt hashes (`pgcrypto`). Logging in gives the game a random session token,
  which is what it saves on the player's computer. The password itself is never saved.
- Names are 3–16 letters, numbers or `_`, unique regardless of upper/lower case.
- Scores above 100,000 m are rejected.

It's a jam leaderboard, not an anti-cheat system: someone determined could still post a fake score with
their own account. To remove one, open **Table Editor → voll_players** in Supabase and edit or delete the row.

## Testing without Supabase

Set `VOLL_LEADERBOARD_URL` (and `VOLL_LEADERBOARD_KEY`) as environment variables when launching Godot to
point the game at any server that speaks the same `POST /rest/v1/rpc/<function>` API.
