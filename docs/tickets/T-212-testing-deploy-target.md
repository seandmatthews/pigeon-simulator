# T-212 — The testing deploy target: the Ames branch at `/pigeon-simulator/testing`

- **Status:** done (first publish verified same hour) · **Category:** tooling · **Value (1-5):** 3 ·
  **Risk (1-5):** 1
- **Depends on:** T-211 (the box, live hosting), the deploy script
- **Refs:** [[web-hosting]] facts in VERIFICATION.md → Web export · the
  2026-11-13 owner steer: main stays the PROD content; the Ames campaign
  needs its own visible URL before any prod flip

## What

A second deploy target on the same site: the `ames/campaign` build
published to **https://games.matthews.mx/pigeon-simulator/testing/**.
No script changes — `deploy-web.sh` already grew the `DEPLOY_ENV_FILE`
door — just a second untracked env file and the docs:

- `.env.deploy.testing` (untracked): same credentials, `DEPLOY_PATH`
  = `/home/sean/www/games/pigeon-simulator/testing`, `PUBLIC_URL`
  = the testing URL. Deploys from the ames/campaign checkout.
- `.gitignore` + `.git/info/exclude` widen `.env.deploy` →
  `.env.deploy*`.
- No Caddyfile change: the COOP/COEP headers and TLS inherit from the
  `games.matthews.mx` site block; `file_server` serves the
  subdirectory live (no reload).

PROD (`/pigeon-simulator/`) stays main-only. The two builds are
visually self-identifying (Windrow vs the Ames world).

## Why

The owner wants the Ames branch playable from the box before any
prod flip, without polluting the public URL the backlog just landed
on. A subdirectory costs nothing (no DNS, no cert, no reload) and
keeps one deploy script.

## Acceptance criteria

- [ ] `.env.deploy.testing` ignored by BOTH mechanisms
      (`git check-ignore -v`)
- [ ] VERIFICATION.md documents the testing target
- [ ] First testing publish verified (`VERIFY OK` on the testing URL)
- [ ] PROD untouched (its Content-Length differs from testing's —
      different builds live side by side)

## Verification

The deploy script's own verify on the testing URL + curl both URLs.
