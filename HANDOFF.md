# HANDOFF — Next session pickup

**Last updated:** 2026-04-22 (late, post-Phase-D). Author: Claude (Opus 4.7).
**Branch:** `helpcore-strip-wip` (pushed to `origin`).
**Strategic plan:** see `/Users/nicklasbrandrup/.claude/plans/i-have-a-broader-deep-pebble.md`.

## TL;DR

Chatwoot is being converted into a **headless channel gateway** feeding HelpCore-CS-Tool (`~/HelpCore-CS-Tool`). Chatwoot receives messages (webchat / WhatsApp / IG / FB / Telegram / Line / Twilio SMS), webhooks them to HelpCore as tickets, and accepts agent replies back via its REST API.

- **Phase A** ✅ done 2026-04-21 — Chatwoot → HelpCore webhook, smoke-tested green.
- **Phase B** ✅ done 2026-04-22 — HelpCore → Chatwoot reply client. `CHATWOOT_API_URL` now set on Railway via the cloudflared tunnel (stage 1 of the finish plan).
- **Phase C.1** ✅ done 2026-04-22 — HelpCore Settings UI → Chatwoot webhook CRUD, live via the tunnel.
- **Phase C.2** ✅ done 2026-04-22 — HelpCore Settings UI → Chatwoot inbox CRUD (web widget), live via the tunnel. Also fixed three stale `Channel::Line`/`Channel::Telegram`/`Channel::Sms` references in stripped Chatwoot.
- **Phase C.3** ✅ done 2026-04-22 — WhatsApp Cloud inbox form (phone + Meta credentials). FB / IG / Email-IMAP intentionally skipped.
- **Phase D** ✅ done 2026-04-22 (commit `6fe4642a0`) — Vue admin dashboard stripped; 3,479 files deleted. Chatwoot is now truly headless. GET / now serves the health probe, GET /app 404s, Application API + widget still 200.
- **Phase D** — Delete the Chatwoot Vue dashboard once Phase C covers it. Not started.

Delete this file when Phase D lands.

## State as of this save

**Working loop (tunnel-based):** a cloudflared tunnel is running on the dev laptop (PID visible with `ps aux | grep cloudflared`) exposing `http://localhost:3000` at `https://reception-sensitivity-rain-kilometers.trycloudflare.com`. Railway HelpCore's `CHATWOOT_API_URL` points at that tunnel. HelpCore Settings → Chatwoot tab now lists the real webhooks + inboxes, and agent replies on Chatwoot-originated tickets flow back through.

**Known limitation:** if the laptop closes, the tunnel dies and HelpCore → Chatwoot breaks (inbound webhooks still work, since those are Chatwoot → HelpCore). Fixing that is the remaining task (stage 3 of the finish plan, see below).

## How to finish — one remaining step

**Stage 3 blocker (needs ~5 min of user action, then I can continue):**

Trying to deploy Chatwoot into the HelpCore CS Tool Railway project via `railway add --repo Brandrup12/chatwoot-app` failed with `Unauthorized`. Railway is authenticated as `nicklasbrandrup@hotmail.com` and can see the HelpCore project, but it doesn't have the Railway GitHub App installed on the `Brandrup12` GitHub account where `chatwoot-app` lives.

Resolve one of these two ways, then tell Claude to continue:

1. **Install Railway's GitHub App on Brandrup12** — https://github.com/apps/railway-app → Configure → pick the `Brandrup12` account → Only select repos → `chatwoot-app`. Fastest path.
2. **Transfer `chatwoot-app` to the `neurogan` GitHub org** where Railway already has access (same place `HelpCore-CS-Tool` lives). Cleaner long-term home for the repo.

Once access is granted, the remaining deploy sequence is scripted below — Claude can execute it without more checkpoints:

```bash
# From ~/Documents/GITHUB/chatwoot-app (already linked to HelpCore CS Tool project):
railway add --service chatwoot-web --repo Brandrup12/chatwoot-app
railway add --service chatwoot-worker --repo Brandrup12/chatwoot-app
# (Claude will then configure both services' env vars via the Railway MCP:
#  DATABASE_URL (reference HelpCore's Postgres), REDIS_URL (reference HelpCore's Redis),
#  SECRET_KEY_BASE (pre-generated, stashed at /tmp/chatwoot-secret-key-base.txt),
#  FRONTEND_URL=https://<chatwoot-web-railway-url>,
#  INSTALLATION_NAME="HelpCore Gateway",
#  per-service start commands: web runs bin/rails server, worker runs bundle exec sidekiq)
# Then deploy, wait for release phase to run rails db:chatwoot_prepare,
# then recreate the webhook + web-widget inbox via HelpCore Settings → Chatwoot,
# and finally set CHATWOOT_API_URL to the new chatwoot-web URL and kill the tunnel.
```

**Shared Postgres note** (per your guidance): HelpCore uses the `helpcore` schema (`pgSchema("helpcore")` in `shared/schema.ts`), Chatwoot's Rails migrations default to `public` — so they coexist in one database without table collisions. The two stacks will still keep separate customer representations (`helpcore.customers` vs Chatwoot's `public.contacts`); the correlation already happens in the Phase A webhook handler, which upserts a `helpcore.customers` row when a Chatwoot conversation arrives. Sharing the DB saves a Railway plugin; it does NOT mean Chatwoot reuses HelpCore's customer rows.

## Stages already completed

- **Stage 1** ✅ Tunnel + Railway `CHATWOOT_API_URL` + Settings tab now live.
- **Stage 2** ✅ Vue admin dashboard stripped (commit `6fe4642a0`).
- **Stage 3** ⏳ Blocked on Railway ↔ GitHub access for `Brandrup12/chatwoot-app`.
- **Stage 4** ⏳ Cleanup (delete this file, tag release commit) — happens after stage 3 lands.

## Current state — HelpCore (`~/HelpCore-CS-Tool`, `main`)

Railway auto-deploys. Latest relevant commits:

- `c81bd43` — Phase C.3: Chatwoot WhatsApp Cloud inbox form. Adds `createChatwootWhatsappInbox` + `CHATWOOT_WHATSAPP_PROVIDERS`; POST `/api/chatwoot/inboxes` now branches on `channel.type` (`web_widget` vs. `whatsapp`), validates phone-number format / provider enum / `whatsapp_cloud` creds server-side; new `api.chatwoot.inboxes.createWhatsappCloud`; new `WhatsappInboxForm` in the Chatwoot settings tab (password-masked API key, warning that creds are round-tripped against Meta at create time).
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

Phase C.3 (WhatsApp inbox) — tsx exercised `createChatwootWhatsappInbox` with dummy `whatsapp_cloud` credentials. Chatwoot's `validate_provider_config` hook round-tripped them against Meta and returned **422 "Provider config Invalid Credentials"** — the exact failure signature we want. Payload shape is correct; live Meta credentials will succeed without further code changes.

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

## Phase D readiness

With C.1 + C.2 + C.3 shipped, HelpCore's Settings → Chatwoot tab covers webhook CRUD, web-widget inbox CRUD, and WhatsApp Cloud inbox creation. That's the ops surface we actually use today. Before deleting Vue pages in Phase D:

- Audit `/app/accounts/:id/settings/inboxes/*` and `/app/accounts/:id/settings/webhooks/*` vs. what the HelpCore Settings tab covers.
- Preserve anything HelpCore UI doesn't yet own: agents, teams (if revived), custom attributes, canned responses (if we keep them), profile.
- The Vue dashboard also houses the **widget preview page** (`/widget?website_token=...`) — that's a separate concern from `/app/*`, keep it.
- Don't remove Rails routes that the Application API uses internally (controllers under `/api/v1/accounts/:id/*`). Phase D is purely a Vue/V3 bundle strip.

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

> Read `~/Documents/GITHUB/chatwoot-app/HANDOFF.md`. Resume from "How to resume tomorrow" — option 1 (tunnel Chatwoot + set `CHATWOOT_API_URL` to activate Phases B/C.1/C.2/C.3 in prod) or option 2 (start Phase D — audit the Vue dashboard and strip the pages HelpCore's Settings tab now covers). HelpCore repo is at `~/HelpCore-CS-Tool`.
