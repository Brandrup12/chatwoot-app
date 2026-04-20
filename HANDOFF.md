# HANDOFF — Next session pickup

**Last session:** 2026-04-19. Author: Claude (Opus 4.7).
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

## What's done (committed, pushed to origin)

Latest 5 commits on `helpcore-strip-wip`:

- `d75d239c3` — DB strip: dropped 37 stripped-feature tables + related orphan Ruby models (SLA, teams, portals, captain, campaigns, macros, etc.). Specs green at **3273 ex / 0 fail / 64 pending**.
- `1ed490e5b` — `.gitignore` rule for iCloud sync-duplicate files (`* N.*`) + deleted existing dups.
- `981137a37` — Restored dashboard SPA entry from upstream + cleaned ~240 stripped-feature Vue files. **Note**: the Vue UI restore is now viewed as misaligned work (see plan). It's not blocking and we're leaving it in place as a temporary admin UI until HelpCore grows its own Settings screens (Phase C below).
- `149bcebfe` — Patched runtime refs (jbuilders, Instagram/OAuth callback URL helpers, SuperAdmin STI removal, cache_keys, orphan dashboard_apps controller).
- `e3a106b04` — Phase 12: green controller + enterprise spec suites after the strip.

Current state of the app locally (if overmind is still running):

- Rails `http://localhost:3000` — `/app/login` loads the Vue dashboard, you can log in and click around. Admin user: `testsub@neurogan.com` / `Complex123!`.
- Vite dev server `http://localhost:3036`.
- Sidekiq running.
- Postgres + Redis via `brew services`.

If overmind is not running:

```bash
cd ~/Documents/GITHUB/chatwoot-app
eval "$(rbenv init -)"
OVERMIND_SOCKET=/tmp/overmind-chatwoot.sock OVERMIND_NO_PORT=1 overmind start -f Procfile.dev > /tmp/overmind.log 2>&1 &
```

## What's next — Phase A

**Goal:** A customer messaging via the webchat widget → a ticket appears in HelpCore.

This is cross-repo work. No Rails code needs to change — Chatwoot already supports outbound webhooks natively.

### Step 1: Add correlation column to HelpCore

File: `~/HelpCore-CS-Tool/shared/schema.ts` (near `tickets` table, line ~125).

Add:

```ts
chatwootConversationId: integer("chatwoot_conversation_id"),
chatwootAccountId: integer("chatwoot_account_id"),
```

Generate + apply the migration:

```bash
cd ~/HelpCore-CS-Tool
npm run db:generate
npm run db:migrate
```

### Step 2: Build the Chatwoot webhook handler in HelpCore

File to create: `~/HelpCore-CS-Tool/server/src/webhooks/chatwoot.ts`.

Follow the existing pattern in `webhooks/gmail.ts` and `webhooks/email.ts`. The handler should:

- Accept a POST at `/webhooks/chatwoot`.
- Verify a shared-secret header (e.g. `X-Chatwoot-Signature`) via HMAC against the raw body. Store the secret in env as `CHATWOOT_WEBHOOK_SECRET`.
- Switch on `event` field in the payload:
  - `conversation_created` — create a `tickets` row. Store `chatwootConversationId` + `chatwootAccountId`. Set `channel` to map Chatwoot's `inbox.channel_type` (`Channel::WebWidget` → `webchat`, `Channel::Whatsapp` → `whatsapp`, `Channel::Email` → `email`, etc.).
  - `message_created` — look up the ticket by `chatwootConversationId`, insert a row into `messages`. Direction: `incoming` if `message_type === 'incoming'`, `outgoing` otherwise.
  - `conversation_updated` — update `status` / `assignee` on the ticket.
  - `conversation_resolved` — set ticket `status = 'closed'`.
- Wire into `server/src/webhooks/index.ts` the same way `gmail` / `shopify` are wired.

Chatwoot's webhook payload shape is documented at https://developers.chatwoot.com/platform/features/webhooks — but the canonical source is the `WebhookJob` in this repo (`app/jobs/webhooks/webhook_job.rb`) and the serializer in `app/builders/conversations/event_data_presenter.rb`. Read those when in doubt.

### Step 3: Point Chatwoot at HelpCore's webhook endpoint

In Chatwoot Settings (via the Vue UI we kept) → Integrations → Webhooks, add:

- URL: `http://localhost:3001/webhooks/chatwoot` (dev) or the Railway HelpCore URL (prod)
- Subscribe to: `conversation_created`, `message_created`, `conversation_updated`, `conversation_resolved`
- Store the shared secret somewhere HelpCore can read it.

Alternatively, seed this via Rails: `Webhook.create!(account: Account.first, url: '...', subscriptions: [...])`.

### Step 4: End-to-end smoke test

1. Start both apps: overmind in chatwoot-app, `npm run dev` in HelpCore.
2. In Chatwoot, create a web widget inbox.
3. Open the widget embed in a browser (`http://localhost:3000/widget?website_token=<token>`), send a test message as a "customer".
4. Check Sidekiq logs — webhook should fire.
5. In HelpCore DB, verify a ticket + message row exist.

If all that works, Phase A is done. Commit in both repos.

## What NOT to do

- Don't delete the Vue dashboard yet. It's our temporary admin UI. Remove it in Phase D, after HelpCore's Settings UI (Phase C) covers the same ground.
- Don't try to make agents work in Chatwoot's UI. Long-term they work in HelpCore. Chatwoot is headless.
- Don't touch `config/vite.json` — `autoBuild: false` in test is intentional (fork-bomb fix when `node_modules` absent).
- Don't restore stripped features (teams, SLA, captain, etc.) — they live in HelpCore if needed.
- Don't worry about the backend strip tables we kept in DB (e.g., `dashboard_apps`). They're harmless and their model files still work.

## Deferred / known issues

- **iCloud sync duplicates**: `~/Documents/GITHUB/` is inside iCloud Drive. The repo occasionally gets `foo 2.rb` files that confuse Zeitwerk. `.gitignore` now excludes them, and the delete-pattern is:
  ```bash
  find . -path ./node_modules -prune -o \( -name "* [0-9].*" -o -name "* [0-9]" \) -print0 2>/dev/null | xargs -0 rm -rf
  ```
- **Modal onClose deprecation warnings** in browser console: cosmetic, from an internal Vue component rename. Ignore.
- **`/enterprise/api/v1/accounts/4/limits` 404** on UpgradePage preload: the endpoint is gone, the UI doesn't render that page for real users. Ignore.
- **Lit dev-mode / multiple versions** warnings in console: @chatwoot/ninja-keys library noise. Ignore.
- **Devise OAuth callback** may 500 on Google SSO — not investigated, not needed since SSO isn't being used. Revisit if you configure `GOOGLE_OAUTH_CLIENT_ID`.

## Full phase roadmap (for context)

- **Phase A** (this session): Chatwoot → HelpCore webhook. 2–4 hrs.
- **Phase B**: HelpCore → Chatwoot reply API client. ~1 day. Creates `server/src/integrations/chatwoot.ts` in HelpCore with a client that calls `POST /api/v1/accounts/:id/conversations/:id/messages`.
- **Phase C**: HelpCore Settings UI (create inbox, configure WhatsApp/IG channels, manage webhook subs). 2–4 days. Built with Next.js + Shadcn + calls Chatwoot's REST API.
- **Phase D**: Delete Chatwoot's Vue dashboard, v3 bundle, `/app` routes. Chatwoot fully headless. Few hours.

When Phase D lands, delete this handoff file.

---

## First-message template for the next session

Paste this into your next Claude session to get started:

> Read `~/Documents/GITHUB/chatwoot-app/HANDOFF.md`. Start on Phase A as described. Chatwoot app should already be running via overmind; if not, boot it. HelpCore repo is at `~/HelpCore-CS-Tool`.
