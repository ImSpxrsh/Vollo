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
6. For **account progress sync** (coins, upgrades, varieties, awards and stats follow you to any device you
   log in on), also run everything from [`progress.sql`](progress.sql) in the SQL Editor. Until it's run, the
   game keeps working and just keeps progress on each device.

## How progress sync works

When you log in (or open the game while logged in), the game downloads your account's progress and merges it
with this device: counters such as coins earned, coins spent and best distance keep the larger value, and
upgrades, varieties and awards are combined. It then uploads the merged result, and uploads again a few
seconds after anything changes. It never uploads before that first download, so logging in on a fresh
device can't wipe your account. Settings such as volume and keybinds stay per device.

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
