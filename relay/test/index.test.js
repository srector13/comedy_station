// Run with `npm test` in relay/ (Node 20+).
import assert from "node:assert/strict";
import { test, beforeEach } from "node:test";
import relay, { upstreamURL } from "../src/index.js";

let upstreamCalls;
let stored;

beforeEach(() => {
  upstreamCalls = [];
  stored = new Map();
  globalThis.caches = {
    default: {
      match: async (request) => stored.get(request.url)?.clone(),
      put: async (request, response) => { stored.set(request.url, response); },
    },
  };
  globalThis.fetch = async (url, init) => {
    upstreamCalls.push({ url: String(url), headers: init.headers });
    return new Response(JSON.stringify({ results: [] }), { status: 200, headers: { "Content-Type": "application/json;charset=utf-8" } });
  };
});

async function get(path, env = { TMDB_KEY: "abc123" }) {
  const waits = [];
  const response = await relay.fetch(new Request(`https://relay.example${path}`), env, { waitUntil: (p) => waits.push(p) });
  await Promise.all(waits);
  return response;
}

test("only the app's requests and parameters pass", () => {
  const discover = upstreamURL("https://relay.example/3/discover/movie?with_keywords=9716&page=2&api_key=stolen&evil=1");
  assert.equal(discover.url.toString(), "https://api.themoviedb.org/3/discover/movie?page=2&with_keywords=9716");
  assert.ok(upstreamURL("https://relay.example/3/movie/123/credits"));
  assert.equal(upstreamURL("https://relay.example/3/account"), null);
  assert.equal(upstreamURL("https://relay.example/3/movie/123/videos"), null);
  assert.equal(upstreamURL("https://relay.example/discover/movie"), null);
});

test("a v3 key goes in the query, and an answer is cached", async () => {
  const first = await get("/3/search/keyword?query=stand-up%20comedy");
  assert.equal(first.status, 200);
  assert.match(first.headers.get("Cache-Control"), /max-age=604800/);
  assert.equal(upstreamCalls.length, 1);
  assert.equal(upstreamCalls[0].url, "https://api.themoviedb.org/3/search/keyword?query=stand-up+comedy&api_key=abc123");
  // The cache is keyed without the key.
  assert.deepEqual([...stored.keys()], ["https://api.themoviedb.org/3/search/keyword?query=stand-up+comedy"]);

  const second = await get("/3/search/keyword?query=stand-up%20comedy");
  assert.equal(second.status, 200);
  assert.equal(upstreamCalls.length, 1, "a cached answer went to TMDB again");
});

test("a v4 token goes in a header", async () => {
  await get("/3/watch/providers/movie?watch_region=US", { TMDB_KEY: "eyJ.e30.sig" });
  assert.equal(upstreamCalls[0].url, "https://api.themoviedb.org/3/watch/providers/movie?watch_region=US");
  assert.equal(upstreamCalls[0].headers.Authorization, "Bearer eyJ.e30.sig");
});

test("anything else is refused", async () => {
  assert.equal((await get("/3/account")).status, 404);
  assert.equal((await get("/3/discover/movie", {})).status, 503);
  const post = await relay.fetch(new Request("https://relay.example/3/discover/movie", { method: "POST" }), {}, { waitUntil() {} });
  assert.equal(post.status, 405);
  assert.equal(upstreamCalls.length, 0);
});

test("errors aren't cached", async () => {
  globalThis.fetch = async () => new Response("{}", { status: 401 });
  const response = await get("/3/discover/movie?page=1");
  assert.equal(response.status, 401);
  assert.equal(response.headers.get("Cache-Control"), "no-store");
  assert.equal(stored.size, 0);
});
