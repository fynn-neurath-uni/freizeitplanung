# Free Hours – shared availability planner

A single-page scheduling tool for GitHub Pages.

- **Participants** open the link, type their name, and paint the hours they're free. They only ever see their own entries.
- **You (the organizer)** log in by email and get a second tab, **Overview**: a heatmap of everyone's free hours overlapping, checkboxes to include/exclude people, a "best times" list, and who is / isn't free in each slot.

Privacy is enforced by the database (Supabase row-level security), not just hidden in the page — a participant can't read other people's data even with browser dev tools.

Open `index.html` without configuring anything to try it in **demo mode** (fake people, data stays in your browser).

## Setup (~10 minutes)

### 1. Database (Supabase, free tier)
1. Create a project at [supabase.com](https://supabase.com).
2. **Authentication → Sign In / Providers**: turn on **Allow anonymous sign-ins** (Email stays on).
3. **SQL Editor**: paste `schema.sql` and run it (your email is already filled in as organizer).
4. **Project Settings → API**: copy the **Project URL** and the **anon / publishable key**.

### 2. Configure the page
At the top of `index.html`, fill in `CONFIG`:
- `SUPABASE_URL`, `SUPABASE_ANON_KEY` – from step 4 (the anon key is meant to be public)
- `OWNER_EMAIL` – the same email as in `schema.sql`
- Optional: `TITLE`, `DAYS` (`"weekly"` or a list of dates like `["2026-11-02","2026-11-03"]`), `START_HOUR`, `END_HOUR`, `SLOT_MINUTES` (60 or 30)

### 3. Publish on GitHub Pages
1. Create a GitHub repository and upload `index.html` (the other files are optional).
2. **Settings → Pages → Build and deployment**: Source = *Deploy from a branch*, Branch = `main` / `root`. Save.
3. Your page is at `https://<username>.github.io/<repo>/`.
4. Back in Supabase, **Authentication → URL Configuration**: set **Site URL** to that address and add it under **Redirect URLs** (needed for your login link).

### 4. Use it
- Share the page link. People type their name and mark their hours.
- Open the page yourself → **Organizer login** → enter your email → click the link in the email. You'll see **My hours** and **Overview**.

## Notes
- Participants are identified per browser (anonymous sign-in). If someone switches device or clears browser data, they start fresh as a new entry — you can just untick the old one.
- Changing `DAYS`/hours later doesn't delete data; slots outside the new grid are simply not shown.
- Supabase limits anonymous sign-ins to 30 per hour per IP by default; you can add a CAPTCHA under Authentication settings if the link ever gets abused.
