# VOLL — itch.io submission kit

Everything in this folder is ready to paste or upload:

| File | Use on itch.io |
|---|---|
| `cover_630x500.png` | **Cover image** (Edit game → Cover image) |
| `cover_315x250.png` | Small version, if a jam page asks for one |
| `screenshots/*.png` | **Screenshots** (1280×720, in the order shown on the page) |
| `voll_trailer.mp4` | Gameplay video. itch.io embeds videos from YouTube/Vimeo, so upload it there and paste the link into **Gameplay video or trailer** |
| `voll_trailer.gif` | Short loop for the description or social posts |

---

## 1. Build the web version

The project already has a **Web** export preset (`godot/export_presets.cfg`, no threads, so no special server headers).

1. Open the project in Godot 4.7 (`godot/project.godot`).
2. **Editor → Manage Export Templates → Download and Install** (one time, matches 4.7.2).
3. **Project → Export → Web → Export Project**. It writes `build/web/index.html` and friends.
   Or from a terminal, from the repo root:
   ```bash
   /Users/sparsh/Downloads/Godot.app/Contents/MacOS/Godot --headless --path godot --export-release "Web" ../build/web/index.html
   ```
4. Zip the **contents** of `build/web` (index.html must be at the top of the zip):
   ```bash
   cd build/web && zip -r ../voll_web.zip . && cd ../..
   ```

> Fonts: the game uses Mac system fonts (Avenir Next / Copperplate). Browsers don't have them, so the web build
> falls back to Godot's default font. It still works; bundle a .ttf in the theme if you want the exact look online.

## 2. itch.io upload settings

**Create new project** →

- **Kind of project:** HTML
- **Uploads:** `voll_web.zip` → tick **This file will be played in the browser**
- **Embed options:**
  - Viewport dimensions: **1280 × 720**
  - ✅ Fullscreen button
  - ✅ Automatically start on page load: off (needs a click so browsers allow audio)
  - ⬜ Mobile friendly (mouse/keyboard game)
  - ⬜ SharedArrayBuffer support (not needed: threads are off)
  - Frame options: ✅ Click to launch in fullscreen *off*, ✅ Scrollbars *off*
- **Classification:** Games
- **Release status:** Released (or Prototype for a jam build)
- **Pricing:** No payments (or "$0 or donate")
- **Genre:** Action  ·  **Secondary:** Platformer
- **Tags:** `bounce`, `physics`, `endless-runner`, `local-multiplayer`, `split-screen`, `casual`, `2d`, `godot`, `game-jam`, `cute`
- **Input:** Mouse, Keyboard, Xbox controller (player 2 in versus)
- **Accessibility:** Configurable controls is not supported; tick *High-contrast* and *Reduced motion* options exist
- **Average session:** A few minutes
- **Languages:** English
- **Multiplayer:** Local multiplayer, 2 players, split screen

---

## 3. Page text (copy-paste)

**Title:** VOLL

**Short description / tagline** (max ~110 chars):

> A smiley ball never stops rolling. Build trampolines, ramps and floors in real time to keep it alive.

**Description:**

> **There's no road ahead. Build one before Variety gets there.**
>
> Variety is a cheerful little ball that rolls on its own and keeps speeding up. You can't steer it. All you can
> do is drop pieces in front of it: a **trampoline** to bounce over danger, a **ramp** to launch or dive, a
> **floor** to roll on. Every piece crumbles after a few seconds, so you're always building the next stretch.
>
> When things go wrong, you **bounce back**. Fall off the bottom and you're thrown back up for the price of a
> heart. Squash devil balls by landing on them. Bounce right next to a spike for a clutch combo.
>
> **Features**
> - Endless course: three hand-made warm-up levels, then randomly generated levels that get harder every 60 m
> - Checkpoints between levels: continue from the last flag after a crash
> - 3 hearts, shields, slow-mo hourglasses, speed boosters, rest bridges and coins
> - Clutch bounces and enemy stomps build a combo for bonus metres
> - 12 ball "varieties" to unlock through 11 awards. Everyone starts yellow!
> - Coin shop with permanent upgrades (shield start, sturdier pieces, coin magnet, extra heart…)
> - **2-player split-screen versus** on one keyboard (or keyboard + gamepad)
> - **Versus the computer** with Easy, Normal and Hard bots
> - Stats & awards page, high-contrast hazards and reduce-motion options
>
> **Controls**
>
> | | |
> |---|---|
> | Aim | Mouse |
> | Place piece | Left click |
> | Pick piece | 1 Trampoline · 2 Ramp · 3 Floor |
> | Flip ramp | R |
> | Pause | Esc / P |
> | Restart / continue | Space |
>
> **Versus, player 2:** arrows aim · Enter places · `,` `.` `/` pick a piece · `'` flips the ramp
> (gamepad: left stick · A place · X cycle · Y flip)
>
> Made in Godot 4 for the **"Bounce Back"** jam.

**Credits** (same as the in-game Credits screen):

> Game, code and levels: the Voll team · Art: the Voll team; some images found online through Google Images,
> which belong to their original artists · Music: Voll background theme, written and sung by the Voll team ·
> Sound effects synthesised in-engine · Menus: Maaack's Godot Menus Template (MIT) · Engine: Godot (MIT)

---

## 4. Jam submission checklist

- [ ] Web build zipped and uploaded, "played in the browser" ticked, 1280×720
- [ ] Cover image + at least 3 screenshots uploaded
- [ ] Trailer on YouTube, link pasted into the page
- [ ] Page set to **Public** (or *Restricted* until the jam opens submissions)
- [ ] Check the jam's rules on outside art. If it asks for credit, name the artists of the images found on Google
      (a reverse image search finds them); if it only allows original or free-licence art, swap those images out
- [ ] Submitted to the jam page (**Submit your project** on the jam, pick VOLL)
- [ ] Played once in an incognito browser window to check audio starts after the first click
