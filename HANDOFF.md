# HANDOFF — Next session pickup

**Last updated:** 2026-04-22. Author: Claude (Opus 4.7).
**Branch:** `helpcore-strip-wip` (pushed to `origin`).
**Strategic plan:** see `/Users/nicklasbrandrup/.claude/plans/i-have-a-broader-deep-pebble.md`.

## TL;DR

Chatwoot is being converted into a **headless channel gateway** feeding HelpCore-CS-Tool (`~/HelpCore-CS-Tool`). Chatwoot receives messages (webchat / WhatsApp / IG / FB / Telegram / Line / Twilio SMS), webhooks them to HelpCore as tickets, and accepts agent replies back via its REST API.

- **Phase A** ✅ done 2026-04-21 — Chatwoot → HelpCore webhook, smoke-tested green.
- **Phase B** ✅ code done 2026-04-21 — HelpCore → Chatwoot reply client, locally proven. Prod activation blocked on one env var (see below).
- **Phase C.1** ✅ code done 2026-04-21 — HelpCore Settings UI → Chatwoot webhook CRUD.
- **Phase C.2** ✅ code done 2026-04-22 — HelpCore Settings UI → Chatwoot inbox list/create (web widget only) / delete. Also fixed three stale `Channel::Line`/`Channel::Telegram`/`Channel::Sms` references in stripped Chatwoot that were 500-ing `POST /api/v1/accounts/:id/inboxes`.
- **Phase C.3** — Channel-specific configuration (WhatsApp / FB / IG / Email-IMAP). Not started.
- **Phase D** — Delete the Chatwoot Vue dashboard once Phase C covers it. Not started.

Delete this file when Phase D lands.

## How to resume tomorrow

Pick one:

1. **Activate Phase B + C.1 + C.2 in prod.** Expose local Chatwoot to the internet (`cloudflared tunnel --url http://localhost:3000` or ngrok) and set `CHATWOOT_API_URL=https://<tunnel-url>` on the HelpCore Railway service. Same var unlocks the reply client (Phase B) and both Settings → Chatwoot tab subsections (webhooks + inboxes).
2. **Phase C.3 — channel-specific configuration.** Extend the Settings tab with configuration flows for WhatsApp Cloud API, Facebook Page, Instagram Direct, and Email/IMAP. Each needs its own creator helper (Chatwoot's `channel.type` accepts `api` / `email` / `whatsapp` after our strip; `facebook` and `instagram` go through separate OAuth-backed controllers — research before implementing).
3. **Deploy Chatwoot to Railway.** Bigger lift (Rails web + Sidekiq + Postgres + Redis) but needed eventually so prod traffic isn't dev-host-dependent.

Recommend (1) first — fastest validation that the whole loop works — then (2).

## Current state — HelpCore (`~/HelpCore-CS-Tool`, `main`)

Railway auto-deploys. Latest relevant commits:

- `546f567` — Phase C.2: Chatwoot inbox CRUD in Settings UI. Extends `integrations/chatwoot.ts` with `listChatwootInboxes` / `createChatwootWebWidgetInbox` / `deleteChatwootInbox`; new `GET|POST|DELETE /api/chatwoot/inboxes` routes; `api.chatwoot.inboxes.*` in the client; new Inboxes section rendered above Webhooks in the Chatwoot settings tab.
- `c7b6d80` — Phase C.1: Chatwoot webhook CRUD in Settings UI. Extends `server/src/integrations/chatwoot.ts` with `listChatwootWebhooks` / `createChatwootWebhook` / `deleteChatwootWebhook` and a shared `chatwootRequest` helper; new `server/src/routes/chatwoot.ts` (`GET|POST|DELETE /api/chatwoot/webhooks`); `api.chatwoot.webhooks.*` in `client/src/lib/api.ts`; new "Chatwoot" tab in `client/src/app/settings/page.tsx`.
- `33f0357` — Phase B: Chatwoot reply client + orchestrator + route branch. Files: `server/src/engine/chatwoot-reply-sender.ts`, `server/src/routes/tickets.ts` (POST `/:id/messages` branches on `chatwoot_conversation_id`), `scripts/test-chatwoot-reply.ts`.
- `15a3010` — Phase A: schema columns, migration, webhook handler. Files: `shared/schema.ts` (adds `chatwoot_conversation_id` + `chatwoot_account_id` to `helpcore.tickets`, indexed), `migrations/manual_2026-04-20_chatwoot_gateway_correlation.sql` (applied to Railway Postgres), `server/src/webhooks/chatwoot.ts`, `server/src/webhooks/index.ts` (route mounted at `/api/webhooks/chatwoot`).

Railway env on HelpCore-CS-Tool service:

| Var | Status | Value |
|---|---|---|
| `CHATWOOT_WEBHOOK_SECRET` | ✅ set | `384f0738…70158` — also in `/tmp/chatwoot-webhook-secret.txt` |
| `CHATWOOT_DEFAULT_BRAND_SLUG` | ✅ set | `neurogan_cbd` |
| `CHATWOOT_API_ACCESS_TOKEN` | ✅ set | `hDvu6pAK8hYfn36qkdhT8tP9` (user token for `testsub@neurogan.com`) |
| `CHATWOOT_ACCOUNT_ID` | ✅ set | `4` |
| `CHATWOOT_API_URL` | ❌ **unset on purpose** | Set this to activate Phase B — see "How to resume" above |

## Current state — Chatwoot (`~/Documents/GITHUB/chatwoot-app`, `helpcore-strip-wip`)

Last commit `99f052e83` (Phase C.2 enablement): dropped three stale `Channel::Line`/`Channel::Telegram`/`Channel::Sms` references (one in `inboxes_controller.rb`, two in `inboxes_helper.rb`) that were 500-ing every inbox create. The `inbox_name` helper now detects Telegram via `channel_type` string instead of the `Channel::Telegram` constant so the guard is future-safe if the Telegram model ever returns.

Dev-DB state, seeded via rails runner (not tracked in git):

- **Webhook #1** on `Account.first` (id=4, "Test"). URL: `https://helpcore-cs-tool-production.up.railway.app/api/webhooks/chatwoot?token=<CHATWOOT_WEBHOOK_SECRET>`. Subscriptions: `conversation_created`, `message_created`, `conversation_updated`, `conversation_status_changed`.
- **Web widget inbox #1** "HelpCore Web Widget (Phase A smoke test)" with `website_token=pEdt5uTdatwtAVFRenEmHRQg`. Widget URL: `http://localhost:3000/widget?website_token=pEdt5uTdatwtAVFRenEmHRQg`.
- **Conversation #1** on that inbox — the Phase A smoke-test thread. Correlates to HelpCore ticket `aa959a18-bfea-4969-9c48-f83dd3352220`.

If overmind isn't running:

```bash
cd ~/Documents/GITHUB/chatwoot-app
eval "$(rbenv init -)"
OVERMIND_SOCKET=/tmp/overmind-chatwoot.sock OVERMIND_NO_PORT=1 overmind start -f Procfile.dev > /tmp/overmind.log 2>&1 &
```

Admin login: `testsub@neurogan.com` / `Complex123!`.

## Smoke-test evidence

Phase A (Chatwoot → HelpCore) — all four handled events verified against Railway Postgres:

| Event | Result |
|---|---|
| `conversation_created` | Ticket `aa959a18…` on `brand=neurogan_cbd`, `channel_source=chat_widget`, `chatwoot_conversation_id=1`, `status=new` |
| `message_created` (×2) | Both customer messages appended to the same ticket — no duplicate ticket |
| `conversation_status_changed` (resolved) | `status=closed`, `resolved_at` populated |

Phase C.2 (inbox CRUD) — tsx exercised `listChatwootInboxes` / `createChatwootWebWidgetInbox` / `deleteChatwootInbox` against local Chatwoot: listed 1 before, created inbox #3 "Phase C.2 verifier" (got back a `website_token`), listed 2 after create, fired delete (Sidekiq async-destroys in the background). Integration layer works; UI is latent on Railway until `CHATWOOT_API_URL` is set.

Phase C.1 (webhook CRUD) — tsx exercised `listChatwootWebhooks` / `createChatwootWebhook` / `deleteChatwootWebhook` against local Chatwoot: created a dummy webhook, listed 2 total, deleted, listed 1 (the real Webhook #1) remaining. API-layer plumbing works; the UI is latent on Railway until `CHATWOOT_API_URL` is set.

Phase B (HelpCore → Chatwoot) — orchestrator run against local Chatwoot:

```
CHATWOOT_API_URL=http://localhost:3000 \
CHATWOOT_API_ACCESS_TOKEN=hDvu6pAK8hYfn36qkdhT8tP9 \
CHATWOOT_ACCOUNT_ID=4 \
DATABASE_URL="<Railway public proxy>" \
npx tsx scripts/test-chatwoot-reply.ts aa959a18-bfea-4969-9c48-f83dd3352220 "<msg>"
```

Posts Chatwoot Message #7 into Conversation #1 with `type=outgoing`, `sender=User 4`. Proves client + orchestrator; the HTTP→route→dispatch layer is trivial Express and reviewed in code.

## What NOT to do

- Don't delete the Vue dashboard yet. It's the temporary admin UI until Phase C replaces it.
- Don't try to make agents work in Chatwoot's UI. Long-term agents work only in HelpCore.
- Don't touch `config/vite.json` — `autoBuild: false` in test is intentional (fork-bomb fix when `node_modules` absent).
- Don't restore stripped features (teams, SLA, captain, etc.). They live in HelpCore if needed.
- Don't subscribe Chatwoot webhooks to `conversation_resolved` — **it doesn't exist.** `Webhook::ALLOWED_WEBHOOK_EVENTS` only allows: `conversation_status_changed`, `conversation_updated`, `conversation_created`, `contact_created`, `contact_updated`, `message_created`, `message_updated`, `webwidget_triggered`, `inbox_created`, `inbox_updated`, `conversation_typing_on`, `conversation_typing_off`. Our handler covers resolution via `conversation_updated` + `conversation_status_changed` (both map `resolved` → HelpCore `closed`, idempotent).

## Deferred / known issues

- **`chatwoot_account_id` is NULL on existing test ticket.** The webhook handler reads `payload.account_id`, but Chatwoot only exposes account id per-message (`payload.messages[0].account_id`) or via `payload.inbox.account_id`. Not blocking — we only have one Chatwoot account and the env fallback handles it — but worth fixing when the webhook is touched again.
- **Chatwoot OSS doesn't HMAC-sign outbound webhooks.** We use `?token=<secret>` query-param auth. For defense-in-depth, add a custom Rails middleware on `WebhookJob` that appends `X-Chatwoot-Signature`. Not blocking.
- **AI pipeline not wired for Chatwoot tickets.** `processInboundEvent` (AI classification etc.) is only called by email/gmail webhooks. Chatwoot tickets are stored as plain ticket+message rows. Wire it in when intent/routing needs to run on Chatwoot traffic.
- **Single-brand default.** `CHATWOOT_DEFAULT_BRAND_SLUG=neurogan_cbd` attributes every Chatwoot ticket to CBD. When multiple brands operate on Chatwoot, add per-inbox mapping (Chatwoot inbox name → brand slug).
- **iCloud sync duplicates.** `~/Documents/GITHUB/` is inside iCloud Drive. The repo sometimes gets `foo 2.rb` files that confuse Zeitwerk. `.gitignore` now excludes them; dedupe with `find . -path ./node_modules -prune -o \( -name "* [0-9].*" -o -name "* [0-9]" \) -print0 2>/dev/null | xargs -0 rm -rf`.
- **Console noise to ignore**: modal `onClose` deprecation warnings (internal Vue rename), `/enterprise/api/v1/accounts/4/limits` 404 (endpoint removed, page unused), Lit multi-version warnings (ninja-keys library).
- **Devise Google OAuth callback** may 500. Not investigated, not used (no `GOOGLE_OAUTH_CLIENT_ID` configured).

## First-message template for the next session

Paste this into your next Claude session to get started:

> Read `~/Documents/GITHUB/chatwoot-app/HANDOFF.md`. Resume from "How to resume tomorrow" — option 1 (tunnel Chatwoot + set `CHATWOOT_API_URL` to activate Phase B + C.1 + C.2 in prod) or option 2 (Phase C.3 — channel-specific configuration: WhatsApp / FB / IG / Email-IMAP). HelpCore repo is at `~/HelpCore-CS-Tool`.
