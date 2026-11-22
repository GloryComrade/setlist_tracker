# Spotify search

With this set up, the Song of the Show picker searches Spotify and saves each
song's Spotify link. It needs the Backstage Pass project first
([backstage-pass-setup.md](backstage-pass-setup.md)). Allow about 15 minutes.

Until it is set up, or whenever Spotify can't be reached, the picker quietly
searches Apple's catalog instead, so nothing breaks. Each result says where
it came from ("Spotify" or "Apple Music") in small grey text.

**The 30-second clip still works.** Spotify gives apps no preview clips, so
when you pick a Spotify song the app looks the same song up on Apple's
catalog and borrows its preview and Apple Music link. If Apple has no clear
match, the song is saved without a clip (the Open in Spotify button still
works).

## How it fits together

Spotify's API needs a **client secret**, which must never be in the app (the
web app's code is public). So the secret lives in a small Supabase Edge
Function, [`supabase/functions/spotify-search`](../supabase/functions/spotify-search/index.ts),
and the app asks that function to search. The function signs in to Spotify as
the app itself (no Spotify account needed for runners), keeps that token in
memory until shortly before it expires, and returns just the fields the
picker shows.

## 1. Create a Spotify app

1. Sign in at https://developer.spotify.com/dashboard (any Spotify account,
   free is fine) and click **Create app**.
2. Name `Setlist Tracker`, any short description.
3. **Redirect URI:** `http://127.0.0.1:3000` (Spotify requires one, but the
   search never uses it).
4. Under **Which API/SDKs are you planning to use?** tick **Web API**.
5. Accept the terms and save.
6. Open the app's **Settings**: copy the **Client ID**, then click **View
   client secret** and copy the **Client secret**.

The client secret is a real secret: paste it only into Supabase (step 2),
never into the app, GitHub, or a chat.

## 2. Give the secrets to Supabase

Either way works:

- **Dashboard:** your Supabase project → **Edge Functions → Secrets** → add
  `SPOTIFY_CLIENT_ID` and `SPOTIFY_CLIENT_SECRET`.
- **Command line** (after step 3's setup):

  ```
  supabase secrets set SPOTIFY_CLIENT_ID=... SPOTIFY_CLIENT_SECRET=...
  ```

## 3. Deploy the function

### With the Supabase CLI (Mac)

```
brew install supabase/tap/supabase
supabase login
cd setlist_tracker
supabase link --project-ref YOUR-PROJECT-REF   # the xxxx in https://xxxx.supabase.co
supabase functions deploy spotify-search
```

### Or in the dashboard

**Edge Functions → Deploy a new function → Via Editor**, name it
`spotify-search`, and paste the two files from
`supabase/functions/spotify-search/`: `index.ts` and `parse.ts` (add
`parse.ts` as a second file next to `index.ts`). Deploy.

That's it: no app rebuild is needed. The app already calls
`https://YOUR-PROJECT.supabase.co/functions/v1/spotify-search` whenever it
was built with the Supabase URL and key.

## 4. Check it

In a terminal (use your Project URL and publishable key):

```
curl "https://YOUR-PROJECT.supabase.co/functions/v1/spotify-search?q=mr%20brightside" \
  -H "apikey: YOUR_KEY" -H "Authorization: Bearer YOUR_KEY"
```

You should see `{"results":[{"title":"Mr. Brightside",...`. Then open the
app, book a Show, and search for a song: the results say "Spotify".

## If it doesn't work

- **401 "Invalid JWT":** the function keeps Supabase's sign-in check on, which
  accepts a signed-in runner's token and the older **anon** key (a long
  `eyJ...` key under **Project Settings → API Keys → Legacy API keys**). The
  newer `sb_publishable_...` key is not a JWT, so guests calling with it may
  be turned away and quietly get Apple results instead. Fix either by
  building the app with the legacy anon key as `SUPABASE_KEY`, or by
  deploying with `supabase functions deploy spotify-search --no-verify-jwt`
  (anyone could then use the function to search Spotify; it can't reach
  any runner's data).
- **502 "Spotify search is unavailable":** look at **Edge Functions →
  spotify-search → Logs**. "Spotify secrets are not set" means step 2 is
  missing; "token request failed (400/401)" means the ID or secret is wrong.
- **403 from Spotify:** Spotify's development-mode rules can limit new apps.
  Check the app on the Spotify dashboard (status, quota, and any notices) and
  that **Web API** is ticked.
- The app falls back to Apple whenever the function fails, so the picker
  working is not proof Spotify is on: look for "Spotify" on the results.

## Testing the function's parser

`supabase/functions/spotify-search/parse_test.ts` covers turning Spotify's
answer into results. With [Deno](https://deno.com) installed:

```
deno test supabase/functions/spotify-search/
```
