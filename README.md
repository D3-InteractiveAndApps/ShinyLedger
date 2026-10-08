# Shiny Ledger

Shiny hunt tracker for every main-series Pokémon game: live odds, chain-aware counters, an RNG lab, 40 themes, and a home screen app that syncs between phone and computer.

Static site (GitHub Pages) + Supabase (sign-in and storage). No build step.

## Files

| Path | What it is |
|---|---|
| `index.html` | The whole app |
| `config.js` | Your Supabase URL and anon key |
| `sw.js` | Service worker: offline use and fast loading |
| `manifest.webmanifest`, `icons/` | Home screen app name and icons |
| `vendor/supabase.js` | Supabase client, bundled so the app works offline |
| `supabase/schema.sql` | Database tables and privacy rules |

## Setup

### 1. Supabase
1. Create a project at supabase.com.
2. **SQL Editor → New query**: paste `supabase/schema.sql`, run it.
3. **Authentication → Email Templates → Magic Link**: make sure the body includes the code, for example:
   `Your Shiny Ledger code is {{ .Token }}`
   (The app signs in with a typed code, not a link. Links open in Safari instead of the installed iPhone app, which has separate storage.)
4. **Authentication → URL Configuration**: set **Site URL** to your GitHub Pages address.
5. **Project Settings → API**: copy the **Project URL** and the **anon public** key into `config.js`.

### 2. GitHub Pages
1. Push this folder to a GitHub repository (files at the repo root).
2. **Settings → Pages**: deploy from the `main` branch, `/ (root)`.
3. Open `https://<user>.github.io/<repo>/`.

### 3. Home screen
- **iPhone**: open the site in Safari → Share → Add to Home Screen.
- **Android**: Chrome shows an install prompt, or use ⋮ → Install app.
- Also available from the sync button (top right) → Account & app.

## How sync works
- Every change is saved on the device first, so counting works with no signal.
- When signed in and online, changes upload within a second and appear live on your other devices.
- Hunts made before signing in upload to your account the first time you sign in.
- If two devices edit the same hunt while offline, the most recent edit wins.

## Deploying updates
Change the `VERSION` string at the top of `sw.js` on every deploy so installed apps fetch the new files.
