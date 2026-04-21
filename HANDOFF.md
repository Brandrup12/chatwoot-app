# HANDOFF — Next session pickup

**Last updated:** 2026-04-21. Author: Claude (Opus 4.7).
**Branch:** `helpcore-strip-wip` (pushed to `origin`).
**Strategic plan:** see `/Users/nicklasbrandrup/.claude/plans/i-have-a-broader-deep-pebble.md`.

Read this file first when a new session opens on this repo.

**Phase A is done.** Smoke test proven end-to-end against Railway HelpCore on 2026-04-21 (see "Phase A smoke-test results" below). Next session: Phase B — HelpCore → Chatwoot reply API client.

---

## Where we are

This repo is being converted into a **headless channel gateway** that feeds HelpCore-CS-Tool (`~/HelpCore-CS-Tool`). Chatwoot's role:

- Receive messages from channels HelpCore can't do natively: WhatsApp Cloud API, Instagram, Facebook Messenger, live webchat widget, Twilio, Telegram, Line.
- Forward them to HelpCore as tickets via outbound webhook.
- Accept agent replies from HelpCore via Chatwoot's REST API and deliver to the original channel.

HelpCore is the agent-facing tool. Chatwoot becomes API-only over time. Tech stacks don't merge: Chatwoot stays Rails 7 + Sidekiq; HelpCore is Next.js 15 + Express 5 + Drizzle + BullMQ.

## What's done on Chatwoot (committed, pushed to origin)

Latest 5 commits on `helpcore-strip-wip`:

- `d99ea613b` — HANDOFF.md for the 2026-04-20 session (this file's prior revision).
- `d75d239c3` — DB strip: dropped 37 stripped-feature tables + related orphan Ruby models (SLA, teams, portals, captain, campaigns, macros, etc.). Specs green at **3273 ex / 0 fail / 64 pending**.
- `1ed490e5b` — `.gitignore` rule for iCloud sync-duplicate files (`* N.*`) + deleted existing dups.
- `981137a37` — Restored dashboard SPA entry from upstream + cleaned ~240 stripped-feature Vue files. Vue UI stays as temporary admin UI until HelpCore's Settings UI (Phase C) lands.
- `149bcebfe` — Patched runtime refs (jbuilders, Instagram/OAuth callback URL helpers, SuperAdmin STI removal, cache_keys, orphan dashboard_apps controller).

## What's done on HelpCore (Phase A code shipped)

On HelpCore's `main` branch, commit `15a3010` — Railway auto-deploys:

- `shared/schema.ts` — added `chatwoot_conversation_id` + `chatwoot_account_id` to `helpcore.tickets`, indexed by conversation id.
- `migrations/manual_2026-04-20_chatwoot_gateway_correlation.sql` — idempotent additive migration. **Not yet applied to prod.**
- `server/src/api/webhooks/chatwoot.ts` — webhook handler covering `conversation_created`, `message_created`, `conversation_updated`, `conversation_status_changed` (see note below). Auth via optional `?token=` query param or `X-Chatwoot-Signature` HMAC. Brand resolves from `CHATWOOT_DEFAULT_BRAND_SLUG` (falls back to first brand).
- `server/src/webhooks/index.ts` — wired `/api/webhooks/chatwoot`.

### Correction vs. the previous handoff

The previous HANDOFF listed `conversation_resolved` as an event. **Chatwoot has no such event.** `Webhook::ALLOWED_WEBHOOK_EVENTS` only allows: `conversation_status_changed`, `conversation_updated`, `conversation_created`, `contact_created`, `contact_updated`, `message_created`, `message_updated`, `webwidget_triggered`, `inbox_created`, `inbox_updated`, `conversation_typing_on`, `conversation_typing_off`. The handler now listens to `conversation_updated` + `conversation_status_changed` (both map `resolved` → HelpCore `closed`, idempotent).

## What's done on Chatwoot's DB (local only)

Seeded via `bundle exec rails runner` (not committed — Chatwoot dev DB state):

- `Webhook #1` on `Account.first` (account_id=4, "Test"), subscribed to `conversation_created`, `message_created`, `conversation_updated`, `conversation_status_changed`.
- URL: `https://helpcore-cs-tool-production.up.railway.app/api/webhooks/chatwoot?token=<secret>`.
- Shared secret stashed at `/tmp/chatwoot-webhook-secret.txt` on the dev machine. **Move it to 1Password / Railway before the secret rotates off `/tmp`.**

## Phase A smoke-test results (2026-04-21)

All four handled events verified end-to-end against Railway HelpCore, using the real `Conversation #1` from the `HelpCore Web Widget (Phase A smoke test)` inbox (`website_token=pEdt5uTdatwtAVFRenEmHRQg`):

| Event fired | HelpCore result |
|---|---|
| `conversation_created` | Ticket `aa959a18…` inserted, `channel_source=chat_widget`, `brand_id=neurogan_cbd`, `chatwoot_conversation_id=1`, `status=new` |
| `message_created` ("Hey!") | Customer message row attached to the ticket |
| `message_created` ("Looks good!") | Second customer message appended to the same ticket — no duplicate ticket |
| `conversation_status_changed` (resolved) | Ticket `status=closed`, `resolved_at` populated |

### What shipped to prod this session

- Migration applied against Railway Postgres (cols + `idx_tickets_chatwoot_conversation` confirmed).
- `CHATWOOT_WEBHOOK_SECRET` and `CHATWOOT_DEFAULT_BRAND_SLUG=neurogan_cbd` set on the HelpCore Railway service; the service redeployed picking them up.
- Chatwoot's Webhook #1 updated to the **correct path** (see correction below).

### Correction #2: webhook router mount path

The original HANDOFF said the endpoint was `/api/webhooks/chatwoot` — but `server/src/index.ts` mounts `webhookRouter` at `/api/webhooks`, not `/webhooks`. All URLs in this doc are now `/api/webhooks/chatwoot`, matching the live route. The Chatwoot Webhook record was updated accordingly.

### Known minor issue

`chatwoot_account_id` remains NULL on the test ticket. Chatwoot's conversation-level payload doesn't expose `account_id` at the top level; the webhook handler currently reads it from `payload.account_id` (absent) instead of `payload.messages[0].account_id` or `payload.inbox.account_id`. Not blocking for Phase A (we only have one Chatwoot account), worth fixing when we touch the handler again.

## What NOT to do

- Don't delete the Vue dashboard yet. It's our temporary admin UI. Remove it in Phase D, after HelpCore's Settings UI (Phase C) covers the same ground.
- Don't try to make agents work in Chatwoot's UI. Long-term they work in HelpCore. Chatwoot is headless.
- Don't touch `config/vite.json` — `autoBuild: false` in test is intentional (fork-bomb fix when `node_modules` absent).
- Don't restore stripped features (teams, SLA, captain, etc.) — they live in HelpCore if needed.
- Don't worry about the backend strip tables we kept in DB (e.g., `dashboard_apps`). They're harmless and their model files still work.

## Deferred / known issues

- **Chatwoot OSS doesn't HMAC-sign outbound webhooks.** We're using `?token=<secret>` query-param auth as MVP. If we want defense in depth, we'd add a custom Rails middleware on the `WebhookJob` that appends an `X-Chatwoot-Signature` header. Not blocking.
- **AI pipeline not wired for Chatwoot tickets.** `processInboundEvent` (which runs the AI pipeline) is only called by email/gmail webhooks. Chatwoot creates plain tickets + messages without AI classification. Wire it in Phase B or later, once agent replies flow back the other direction.
- **Single-brand default via env.** `CHATWOOT_DEFAULT_BRAND_SLUG` attributes all Chatwoot tickets to one brand. Multi-brand mapping (e.g., per Chatwoot inbox name) should come when we actually operate more than one brand on Chatwoot.
- **iCloud sync duplicates**: `~/Documents/GITHUB/` is inside iCloud Drive. The repo occasionally gets `foo 2.rb` files that confuse Zeitwerk. `.gitignore` now excludes them, and the delete-pattern is:
  ```bash
  find . -path ./node_modules -prune -o \( -name "* [0-9].*" -o -name "* [0-9]" \) -print0 2>/dev/null | xargs -0 rm -rf
  ```
- **Modal onClose deprecation warnings** in browser console: cosmetic, from an internal Vue component rename. Ignore.
- **`/enterprise/api/v1/accounts/4/limits` 404** on UpgradePage preload: the endpoint is gone, the UI doesn't render that page for real users. Ignore.
- **Lit dev-mode / multiple versions** warnings in console: @chatwoot/ninja-keys library noise. Ignore.
- **Devise OAuth callback** may 500 on Google SSO — not investigated, not needed since SSO isn't being used. Revisit if you configure `GOOGLE_OAUTH_CLIENT_ID`.

## Full phase roadmap (for context)

- **Phase A** ✅ done (2026-04-21): Chatwoot → HelpCore webhook shipped, migration applied, env vars set, smoke test green.
- **Phase B**: HelpCore → Chatwoot reply API client. ~1 day. Creates `server/src/integrations/chatwoot.ts` in HelpCore with a client that calls `POST /api/v1/accounts/:id/conversations/:id/messages`.
- **Phase C**: HelpCore Settings UI (create inbox, configure WhatsApp/IG channels, manage webhook subs). 2–4 days. Built with Next.js + Shadcn + calls Chatwoot's REST API.
- **Phase D**: Delete Chatwoot's Vue dashboard, v3 bundle, `/app` routes. Chatwoot fully headless. Few hours.

When Phase D lands, delete this handoff file.

---

## First-message template for the next session

Paste this into your next Claude session to get started:

> Read `~/Documents/GITHUB/chatwoot-app/HANDOFF.md`. Phase A is done. Start Phase B: build the HelpCore → Chatwoot reply API client (`server/src/integrations/chatwoot.ts` in HelpCore) so that an agent reply in HelpCore posts back into the Chatwoot conversation. HelpCore repo is at `~/HelpCore-CS-Tool`.
