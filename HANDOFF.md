# HANDOFF — Next session pickup

**Last updated:** 2026-04-20. Author: Claude (Opus 4.7).
**Branch:** `helpcore-strip-wip` (pushed to `origin`).
**Strategic plan:** see `/Users/nicklasbrandrup/.claude/plans/i-have-a-broader-deep-pebble.md`.

Read this file first when a new session opens on this repo.

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
- `server/src/webhooks/chatwoot.ts` — webhook handler covering `conversation_created`, `message_created`, `conversation_updated`, `conversation_status_changed` (see note below). Auth via optional `?token=` query param or `X-Chatwoot-Signature` HMAC. Brand resolves from `CHATWOOT_DEFAULT_BRAND_SLUG` (falls back to first brand).
- `server/src/webhooks/index.ts` — wired `/webhooks/chatwoot`.

### Correction vs. the previous handoff

The previous HANDOFF listed `conversation_resolved` as an event. **Chatwoot has no such event.** `Webhook::ALLOWED_WEBHOOK_EVENTS` only allows: `conversation_status_changed`, `conversation_updated`, `conversation_created`, `contact_created`, `contact_updated`, `message_created`, `message_updated`, `webwidget_triggered`, `inbox_created`, `inbox_updated`, `conversation_typing_on`, `conversation_typing_off`. The handler now listens to `conversation_updated` + `conversation_status_changed` (both map `resolved` → HelpCore `closed`, idempotent).

## What's done on Chatwoot's DB (local only)

Seeded via `bundle exec rails runner` (not committed — Chatwoot dev DB state):

- `Webhook #1` on `Account.first` (account_id=4, "Test"), subscribed to `conversation_created`, `message_created`, `conversation_updated`, `conversation_status_changed`.
- URL: `https://helpcore-cs-tool-production.up.railway.app/webhooks/chatwoot?token=<secret>`.
- Shared secret stashed at `/tmp/chatwoot-webhook-secret.txt` on the dev machine. **Move it to 1Password / Railway before the secret rotates off `/tmp`.**

## What's left to finish Phase A

These are **prod-side operations** you need to run (I did not run them — prod-affecting).

### 1. Apply the migration against Railway HelpCore

```bash
cd ~/HelpCore-CS-Tool
# Pull DATABASE_URL from Railway (either via dashboard or `railway variables`)
DATABASE_URL="postgresql://..." psql "$DATABASE_URL" \
  -f migrations/manual_2026-04-20_chatwoot_gateway_correlation.sql
```

The file is idempotent (uses `ADD COLUMN IF NOT EXISTS` + `CREATE INDEX IF NOT EXISTS`), so re-running is safe.

### 2. Set env vars on Railway HelpCore

In the Railway dashboard (or via `railway variables set`):

- `CHATWOOT_WEBHOOK_SECRET` — copy from `/tmp/chatwoot-webhook-secret.txt` (value: `384f0738e22a81654beb2700a85fc72d380267f7c6070158`).
- `CHATWOOT_DEFAULT_BRAND_SLUG` — pick one of the existing brand slugs (e.g. `neurogan_cbd`). Tickets created from Chatwoot will be attributed to that brand until we add per-inbox mapping.

Redeploy once set (Railway may auto-redeploy on env change depending on config).

### 3. Create a web widget inbox in Chatwoot and capture the token

Via the Vue UI at `http://localhost:3000/app` — log in as `testsub@neurogan.com` / `Complex123!`, go to **Settings → Inboxes → Add Inbox → Website**. Set a name + website domain. After creation, note the `websiteToken` from the inbox settings or:

```bash
eval "$(rbenv init -)" && cd ~/Documents/GITHUB/chatwoot-app
bundle exec rails runner 'puts Channel::WebWidget.last.website_token'
```

### 4. Smoke test

Open the widget preview:

```
http://localhost:3000/widget?website_token=<token>
```

Send a test message as a "customer". Then in a separate shell watch the Sidekiq log to confirm the `WebhookJob` fires:

```bash
tail -f /tmp/overmind.log | grep -i webhook
```

And in the HelpCore Railway DB:

```sql
SELECT id, brand_id, channel_source, status, chatwoot_conversation_id, chatwoot_account_id, created_at
FROM helpcore.tickets
WHERE chatwoot_conversation_id IS NOT NULL
ORDER BY created_at DESC LIMIT 5;

SELECT ticketId, sender_type, body_text, created_at
FROM helpcore.messages
WHERE ticket_id = '<the ticket id above>'
ORDER BY created_at;
```

If there's a ticket row + at least one customer message row, Phase A is done. Commit in both repos (Chatwoot side only needs this HANDOFF update — the dev-DB webhook record isn't tracked in source).

### If the smoke test fails

- **WebhookJob never fires** — check `Webhook.all.pluck(:id, :url, :subscriptions)` in Chatwoot rails console; verify URL matches `helpcore-cs-tool-production.up.railway.app` and subscriptions include `conversation_created` + `message_created`.
- **401 from HelpCore** — confirm `CHATWOOT_WEBHOOK_SECRET` in Railway matches `/tmp/chatwoot-webhook-secret.txt` exactly.
- **404 from HelpCore** — the Railway deploy may not have completed. Watch `railway logs` until you see the new build.
- **500 from HelpCore** — tail Railway logs, look for `[Chatwoot Webhook]` entries.
- **Ticket created but no message** — Chatwoot may fire `message_created` before `conversation_created` if timing is weird; the handler logs "unknown conv" and bails. Next message on the same conv will land correctly. (Rare.)

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

- **Phase A** ✅ code shipped / ⏳ prod migration + smoke test pending: Chatwoot → HelpCore webhook. 2–4 hrs.
- **Phase B**: HelpCore → Chatwoot reply API client. ~1 day. Creates `server/src/integrations/chatwoot.ts` in HelpCore with a client that calls `POST /api/v1/accounts/:id/conversations/:id/messages`.
- **Phase C**: HelpCore Settings UI (create inbox, configure WhatsApp/IG channels, manage webhook subs). 2–4 days. Built with Next.js + Shadcn + calls Chatwoot's REST API.
- **Phase D**: Delete Chatwoot's Vue dashboard, v3 bundle, `/app` routes. Chatwoot fully headless. Few hours.

When Phase D lands, delete this handoff file.

---

## First-message template for the next session

Paste this into your next Claude session to get started:

> Read `~/Documents/GITHUB/chatwoot-app/HANDOFF.md`. Phase A code is shipped; apply the migration + set the Railway env vars listed under "What's left to finish Phase A", then run the smoke test. HelpCore repo is at `~/HelpCore-CS-Tool`.
