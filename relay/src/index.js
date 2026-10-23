// Standup's TMDB relay, a Cloudflare Worker. It holds the TMDB key as a
// Worker secret (TMDB_KEY), so the key never ships in the app or this public
// repository. It answers only the few requests the app makes, with only
// the query parameters each one uses, and keeps the answers in Cloudflare's
// edge cache, so the lists everyone's Home shows are fetched from TMDB once
// an hour rather than once a person.

const TMDB = "https://api.themoviedb.org/3/";

const HOUR = 60 * 60;
const DAY = 24 * HOUR;

// The requests Standup makes (`TMDBClient`), the parameters each may carry,
// and how long an answer is kept.
export const ROUTES = [
  { path: /^search\/keyword$/, params: ["query", "page"], ttl: 7 * DAY },
  {
    path: /^discover\/movie$/,
    params: [
      "include_adult", "include_video", "language", "page",
      "primary_release_date.gte", "primary_release_date.lte", "sort_by",
      "vote_count.gte", "watch_region", "with_keywords",
      "with_watch_monetization_types", "with_watch_providers",
    ],
    ttl: HOUR,
  },
  { path: /^watch\/providers\/movie$/, params: ["language", "watch_region"], ttl: DAY },
  { path: /^movie\/\d+\/credits$/, params: ["language"], ttl: 7 * DAY },
];

// TMDB's URL for a request to the relay, keeping only the parameters its
// route allows, sorted, so equal requests share one cache entry. Null for
// anything the app doesn't ask for.
export function upstreamURL(requestURL) {
  const url = new URL(requestURL);
  if (!url.pathname.startsWith("/3/")) return null;
  const path = url.pathname.slice("/3/".length);
  const route = ROUTES.find((candidate) => candidate.path.test(path));
  if (!route) return null;
  const upstream = new URL(path, TMDB);
  for (const name of [...route.params].sort()) {
    const value = url.searchParams.get(name);
    if (value !== null) upstream.searchParams.set(name, value);
  }
  return { url: upstream, ttl: route.ttl };
}

function failure(status, message) {
  return new Response(JSON.stringify({ status_message: message }), {
    status,
    headers: { "Content-Type": "application/json", "Cache-Control": "no-store" },
  });
}

export default {
  async fetch(request, env, ctx) {
    if (request.method !== "GET") {
      return new Response(null, { status: 405, headers: { Allow: "GET" } });
    }
    const target = upstreamURL(request.url);
    if (!target) return failure(404, "Standup's relay doesn't answer that.");
    const key = env.TMDB_KEY;
    if (!key) return failure(503, "The relay has no TMDB key yet.");

    // The cache is keyed by TMDB's URL without the key.
    const cacheKey = new Request(target.url.toString());
    const cache = caches.default;
    const hit = await cache.match(cacheKey);
    if (hit) return hit;

    // A v4 read access token (a JWT, with dots) goes in a header; a v3
    // key goes in the query.
    const authorized = new URL(target.url);
    const headers = { Accept: "application/json" };
    if (key.includes(".")) {
      headers.Authorization = `Bearer ${key}`;
    } else {
      authorized.searchParams.set("api_key", key);
    }
    const answer = await fetch(authorized, { headers });
    const response = new Response(answer.body, {
      status: answer.status,
      headers: {
        "Content-Type": answer.headers.get("Content-Type") ?? "application/json",
        "Cache-Control": answer.ok ? `public, max-age=${target.ttl}` : "no-store",
      },
    });
    if (answer.ok) {
      ctx.waitUntil(cache.put(cacheKey, response.clone()));
    }
    return response;
  },
};
