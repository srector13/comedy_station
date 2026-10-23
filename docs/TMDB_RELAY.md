# TMDB relay

Home's New, Popular and Essential Specials, Trending Comedians, and Browse's streaming-service and decade lists come from TMDB. TMDB needs a key, and this repository and its release IPAs are public, so the key can't be built into the app: anyone could pull it out and use it up.

Instead, Standup asks a small relay: a Cloudflare Worker (`relay/`) that holds the key as a secret.

- It answers only the four requests the app makes (`search/keyword`, `discover/movie`, `watch/providers/movie`, `movie/<id>/credits`), passes on only the query parameters each one uses, and accepts nothing but GET. Anything else gets a 404.
- It keeps TMDB's answers in Cloudflare's cache: lists for an hour, streaming services for a day, the stand-up keyword and credits for a week. Everyone's Home is fetched from TMDB once an hour rather than once a person, which keeps well inside TMDB's rate limits and the Worker's free plan (100,000 requests a day).
- It sees no one's searches, library or account: only which public lists are asked for.

## Set it up (once)

1. **TMDB key.** At [themoviedb.org](https://www.themoviedb.org) → Settings → API, request a key (Developer). Copy the **API Key** or the **API Read Access Token**; either works.
2. **Cloudflare.** Make a free account at [dash.cloudflare.com](https://dash.cloudflare.com). Note the **Account ID** (on the right of Workers & Pages, or of any domain's overview). Then My Profile → API Tokens → **Create Token** → the **Edit Cloudflare Workers** template → Create, and copy the token.
3. **GitHub.** In this repository: Settings → Secrets and variables → Actions → **New repository secret**, three times:
   - `TMDB_KEY`: the TMDB key or token
   - `CLOUDFLARE_API_TOKEN`: the Cloudflare token
   - `CLOUDFLARE_ACCOUNT_ID`: the account ID
4. **Deploy.** Actions → **Deploy TMDB relay** → Run workflow. When it finishes, its summary shows the relay's address, like `https://standup-tmdb-relay.<your-subdomain>.workers.dev`.
5. **Point the app at it.** Set the app target's `STANDUP_TMDB_RELAY` build setting to that host (without `https://`), in `Standup.xcodeproj`. The address isn't secret; it's in every build that uses it. The next **Build unsigned IPA** logs `TMDB relay: <host>`, and Settings no longer shows a TMDB section.

The relay redeploys by itself when `relay/` changes on `main`. To change the key, update the `TMDB_KEY` secret and run **Deploy TMDB relay** again.

## Test it

`cd relay && npm test` runs its tests with Node (20 or later). After deploying:

```sh
curl "https://standup-tmdb-relay.<your-subdomain>.workers.dev/3/search/keyword?query=stand-up%20comedy"
```

answers with TMDB's keywords, and anything outside the four requests, like `/3/account`, answers 404.

## TMDB's terms

TMDB's free API is for non-commercial use, with its logo, notice and JustWatch credit shown (Settings → About). A paid app, ads or in-app purchases would need TMDB's commercial license first.
