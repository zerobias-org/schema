---
name: prerequisites
description: >-
  Pre-flight for the schema repo — verifies every hard requirement (tools,
  MCPs, credentials) before any content flow runs. USE THIS as step 0 of
  /create-schema, when the user asks "check prerequisites" / "am I set up",
  or when an orchestrated cross-repo flow (e.g. connector creation) includes
  this repo. Missing items get installed or waited for — never worked around.
---

# prerequisites — schema repo pre-flight

Run EVERY check below and print a single report: `READY`, or the list of
missing items with their exact fix. Do not start any other work while
something is missing.

**The rule (universal, non-negotiable):** a missing prerequisite allows
exactly **two** actions — (1) install/configure it, asking the user first
where consent or credentials are needed, or (2) stop and wait. No
workarounds, no substitute tooling, no alternative approaches, no partial
continuation. A missing prerequisite PAUSES the flow; it never reroutes it.

**Checklist or nothing (hard):** the report is the FULL checklist — every
check row printed with its live status (✅/❌) — never a bare "READY".
`READY` exists only when every row is ✅ at the same moment. A single ❌ —
even in a component the next step doesn't touch (e.g. an MCP showing
disconnected/red in the UI) — means NOTHING moves: no "it'll recover on
its own", no continuing on the tools that still work, no deferring the
check "until we need it".

**Mutations invalidate the report:** any action that changes a
prerequisite component mid-flow (updating a CLI or MCP package, changing
slot env, switching profile) VOIDS the current checklist — re-run the
affected checks, re-print the full checklist, and resume only from
all-✅. Specifically: updating the npm package behind a LIVE stdio MCP
kills the running server (it goes red) — never hot-swap it mid-flow;
ask the user first, prefer deferring the update to the next launch, or
update + reconnect (`/mcp`) and verify with a live call (`meta.status`)
before anything else runs.

**Skill-vs-reality conflicts:** when a check's observed result contradicts
this skill's text, verify against the primary source (repo build files,
tool source, workflow YAML), act on the source, and fix this skill in the
same session — stale instructions are a prerequisite failure of their own.

## Checks

Two paths through this table:
- **Platform path** (default — you have a ZeroBias org): ALL rows are hard.
- **External contributor** (no ZeroBias account): rows 1–6 AND the GitHub-token row are hard; rows
  7–11 don't apply — follow the no-org fallback in `CONTRIBUTING.md` (gate → PR
  against `main`; maintainers run the org verification). This is the ONE
  sanctioned scope reduction; everything else still follows
  install-or-wait.

| # | Requirement | Check | If missing |
|---|---|---|---|
| 1 | `git` + push access to this repo | `git push --dry-run origin HEAD` (a non-fast-forward rejection still proves auth) | fix remote/auth with the user |
| 2 | `gh` CLI authenticated | `gh auth status` | user runs `gh auth login` (interactive — theirs to do) |
| 3 | Java JDK 17+ (gradle gate; zbb pins the toolchain to 21 itself) | `java -version` | install a JDK (e.g. `brew install temurin`) |
| 4 | Node + `npm` | `npm --version` | install Node LTS |
| 5 | `yq` | `yq --version` | install via package manager (e.g. `brew install yq`) |
| 6 | `zbb` CLI | `command -v zbb && zbb --version` | `npm install -g @zerobias-org/zbb@latest` |
| 7 | **`zb` MCP connected** (`.mcp.json` + profile) | `mcp__zb__zerobias_*` tools in session | credentials setup below |
| 8 | **`zb-knowledge` MCP connected** (`.mcp.json` + launch env vars) | `mcp__zb-knowledge__*` tools in session; `health_check` succeeds. Diagnose from the REPO cwd (`claude mcp get zb-knowledge`) — a user-scope entry can mask the project one when checked from `~` | export `ZB_ORG_ID`/`ZB_API_KEY` **and `KNOWLEDGE_MCP_URL`** — the `.mcp.json` URL defaults to the PROD endpoint, and keys are per-env, so a non-prod key with `KNOWLEDGE_MCP_URL` unset 401s at every launch (hit 2026-08-19); relaunch claude (`--launch` exports all of them, derived from the slot) |
| 9 | `ZB_API_KEY` (**ORG key** — org OWNER, never member; legacy fallback `ZB_TOKEN` works on PROD targets ONLY — non-prod target + unset `ZB_API_KEY` = hard ❌, see ⚠ in Credentials) + `ZB_TOKEN` (**REGISTRY key**, prod-issued) + platform URLs in the slot env | `cd <repo> && [ -n "$(zbb --slot <slot> env get ZB_TOKEN 2>/dev/null \| tail -n1)" ] && echo present` — MUST run from inside the repo (any added-stack path): outside one, `env get` exits 1 with EMPTY output, indistinguishable from "unset" (false all-MISSING, hit 2026-08-18). Exit code alone is a FALSE POSITIVE the other way, and zbb may prefix a vault banner (value = last line) | credentials setup below |
| 10 | Target org UUID known | from user / org config | ask the user |
| 11 | Active `zb` profile org == target org, connection healthy | `zerobias_execute("meta.status")` → `healthy: true` + org matches target (CLI fallback: `zb status`) | `zb profile use <name>` / `zb setup`; org IDs are PER-ENVIRONMENT — a "No such Org" with working auth means wrong-env UUID, list memberships, never assume absence |
| 12 | Key is org OWNER (= Organization Admin) | `zerobias_execute("dana.Me.whoAmI", {})` → `isAdmin: true` | get an owner key — members cannot load artifacts |
| — | **GitHub token for gradle plugin reads** (applies to EVERYONE on a clean machine; dev machines with locally-published `zb/*` in `~/.m2` are silently exempt) | `READ_TOKEN` / `NPM_TOKEN` / `GITHUB_TOKEN` env var present, `read:packages` scope — GitHub Packages Maven requires auth even for public reads (verified 2026-08-17) | EITHER export a PAT that has `read:packages` as `GITHUB_TOKEN`, OR use the gh keyring: `gh auth refresh -s read:packages && export GITHUB_TOKEN=$(gh auth token)`. ⚠ an INVALID `GITHUB_TOKEN` env var silently shadows a valid keyring login — `gh auth status` exposes it |
| — | **build-tools plugin ≥ 1.0.137** (hard floor for org loads) | `./gradlew buildEnvironment \| grep build-tools` → ≥ 1.0.137 | usually a stale locally-published build-tools in `~/.m2` shadowing the release — remove `~/.m2/repository/com/zerobias/build-tools`; otherwise fix the GitHub-token row above |
| — | Gate's remote dataloader step (`testDataloader`) | runs **iff `ZB_TOKEN` is present** (row 9 covers it; older `NEON_API_KEY` mentions are stale). ⚠ Absent `ZB_TOKEN` = the step is SKIPPED, not failed, and the stamp records `"testDataloader": "skipped"` — **skipped is not passed**; org loads and PRs need a stamp that says `passed` | — |
| — | `@zerobias-com/platform-dataloader` global *(optional — local scratch-DB validation per CONTRIBUTING.md)* | `command -v dataloader` (zbb.yaml requires ≥ 1.0.87 when used) | `npm i -g @zerobias-com/platform-dataloader@latest` |

**Tooling freshness (hard).** The ZeroBias CLIs move fast and version skew
fails in confusing ways. For every UNPINNED @zerobias tool —
`@zerobias-org/zbb`, `@zerobias-com/zerobias-mcp` (`zb`), and
`@zerobias-com/platform-dataloader` when installed — the installed version
MUST equal the registry's latest: compare `npm view <pkg> version` against
the installed one. Behind → update with consent (`npm i -g <pkg>@latest`)
or stop and wait — never continue on stale tooling. Documented pins beat
freshness: never bump a pinned version to satisfy this rule.
⚠ Run the `@zerobias-com/*` view/install commands from `$HOME`, not the
repo cwd — this repo's project `.npmrc` reroutes that scope to GitHub
Packages (SAML 403); the user-level `~/.npmrc` mapping to pkg.zerobias.org
(`ZB_TOKEN`) is the working route, and project `.npmrc` beats user config
even for `-g` installs.

**Slot naming (consistent, derived — never invent).** One slot per target
org/env, canonically named `<env>-<org first 8>` (env = platform-host
first label, `app` → `prod`; e.g. `ci-74fc0422`). Deterministic, so every
session derives the same name and REUSES the slot. Before creating one,
adopt any existing slot that already holds the same `ZB_PLATFORM_URL` +
`ZB_ORG_ID`. Never default to ad-hoc names like `local` — the
setup-org-credentials script implements this resolution automatically.

All builds/gates/publishes run **via `zbb`** (`zbb --slot <slot> gate` /
`publishOrg`) — never bare `./gradlew`; only zbb injects the slot env (and
pins the JDK — a bare `./gradlew` on JDK 25 dies with an opaque `25.0.2`).
Schema packages are nested projects: the gradle path mirrors the directory
(`:<vendor>:<code>` or `:<vendor>:<group>:<code>`) — but with zbb you just
run from the package directory.

## Credentials — TWO keys, THREE homes (all hard-required)

Two keys with distinct jobs, plus **org ID** and **platform URL**:

- **`ZB_API_KEY` — the ORG key**: org-owner API key of the TARGET env.
  Consumers: the MCP logins (zb profile, zb-knowledge headers), the
  `/dana/me` owner check, and publishOrg's platform calls (build-tools
  falls back to `ZB_TOKEN` when unset — single-key setups keep working).
- **`ZB_TOKEN` — the REGISTRY key**: auths `pkg.zerobias.org` (npm reads,
  publishes, `.npmrc` interpolation) and the gate's remote dataloader
  step. While the registry accepts only PROD keys, this must be a
  prod-issued key. Rule: don't touch it if it works — the setup script
  verifies registry access and prompts only on failure.

> ⚠ **Any target env other than `app.zerobias.com` REQUIRES `ZB_API_KEY`.**
> `ZB_TOKEN` must be prod-issued (registry requirement) and keys are
> per-environment, so when `ZB_PLATFORM_URL` is not
> `https://app.zerobias.com/api`, the single-key fallback 401s on the
> target env's `/dana/me` — always, not sometimes. Pre-flight rule:
> target ≠ prod AND `ZB_API_KEY` unset in the slot = hard ❌ on row 9;
> set the target-env org-owner key BEFORE starting, don't discover it at
> `verifyOrgPublish`. On prod targets the fallback works — and setting
> `ZB_API_KEY` to the same value as `ZB_TOKEN` is harmless there — so the
> simple habit is: always set both keys explicitly.

These must be installed in three places, because each consumer reads a
different store. The values come from the user, generated in the **TARGET
environment's** app UI (Settings → API Keys — app.zerobias.com for prod,
ci.zerobias.com for ci, …). **Keys are per-environment: a key from one env
returns 401 on another.** Ask; never invent them.

⚠️ **The ORG key (`ZB_API_KEY`, legacy fallback `ZB_TOKEN`) MUST be an org OWNER key — never a plain member key.** A
member key authenticates fine but cannot load artifacts into the org, so
every flow dies at the org-load step with a confusing late failure.
"Owner" in platform terms = **Organization Admin** (the org's admin
group). Verify up front with check #12: `dana.Me.whoAmI` → `isAdmin` must
be `true` — this is the exact `isOrgAdmin` gate the dataloader's
`queueJob` runs, and the same check `publishOrg`'s own
`VerifyOrgPublishTask` enforces at build time. (If `isAdmin` is absent
from the response, the deployed dana predates the field — fall back to
`dana.Org.getRequestOrgMember` and assert `admin: true`.)

**Preferred path — enter once, fan out:** have the user run
[`./scripts/setup-org-credentials.sh`](../../../scripts/setup-org-credentials.sh)
from the repo root in their own terminal (every content repo carries an
identical copy in its `scripts/`). It is **check-first**: already configured → prints the active slot /
platform / org and exits (re-run with `--reconfigure` to switch org, env,
or key); otherwise it prompts for each missing value once (API key
hidden, with a masked `abc…xyz` echo-back; env vars skip prompts; the org
can be given by NAME — it resolves to the UUID via /dana/me/orgs; re-runs
default to the last-used target, Enter to keep) and fixes only what's
missing — keeping the key out of the Claude session entirely. The
per-home reference:

1. **Repo-shipped `.mcp.json` + launch-time env vars** — declares BOTH
   MCPs with `${ZB_ORG_ID}` / `${ZB_API_KEY}` placeholders (no secrets
   committed; project-scoped by nature). The user **exports the vars in
   the shell that launches claude** (`--launch` does this automatically) — temporary, they die with the shell.
   Unset vars → the server shows a missing-var warning and stays
   unconnected (check #8 catches it). Headless `claude -p` loads
   `.mcp.json` without prompting; interactive first use shows a one-time
   trust prompt.
2. **`zb` MCP profile** (`~/.config/mcp-zb/credentials.json`, user-global —
   project-scoped zb creds is a pending platform ask) — consumer: platform
   ops. Install: ensure `~/.npmrc` has the `pkg.zerobias.org` scopes, then
   `npm install -g @zerobias-com/zerobias-mcp`, then `zb setup`
   (interactive prompts: URL, org ID, API key — in that order). Verify: `zb status` and
   that its org matches the target org.
3. **zbb slot env** (slot-scoped by construction) — consumer: the gradle
   gate + `publishOrg`. The six shared vars (`ZB_TOKEN`, `ZB_API_KEY`,
   `ZB_ORG_ID`, `ZB_PLATFORM_URL`, `KNOWLEDGE_MCP_URL`,
   `NPM_CONFIG_TAG=dev`) live ONCE per slot on the shared `dev` stack
   (`@zerobias-org/dev-stack`) — this repo's stack imports them (see
   `zbb.yaml` depends/imports). The setup script seeds the dev stack;
   **never `env set` those six on the schema stack** — a per-stack
   override shadows the import and credential rotation stops propagating.
   **Do NOT set `DATALOADER_SERVICE_URL`** — the gate's remote dataloader
   step deliberately runs against its prod default
   (`https://app.zerobias.com/api/dataloader`) authed by the prod-issued
   `ZB_TOKEN`, even when the org target is another env; a per-env override
   makes the prod key 401 there. The org load never reads this var (it
   uses `ZB_PLATFORM_URL` + `ZB_API_KEY`).
   ⚠ **Slot-env mutation gate:** once a flow is running, any `env set`
   that redirects traffic or identity (URLs, `ZB_ORG_ID`, keys) requires
   showing the user the evidence and the exact command, and getting
   confirmation BEFORE running it — even when source code proves the
   change correct. Never silently repoint an environment.

Never register these MCPs with `claude mcp add -s project` — that would
write literal credentials into a committed file. The placeholder
`.mcp.json` is the committed form.

**Secrets hygiene.** The user may set all three homes themselves in a
separate terminal so the API key never enters the session — offer this
option. Either way: verification must never print secret values into the
session — use presence checks (`[ -n "$(… \| tail -n1)" ]` — never bare exit codes), `zb status`
(prints user/org, not the key), and MCP tool availability. Never read
`~/.claude.json` or `~/.config/mcp-zb/credentials.json` contents.
Secret VALUES never enter the session at all — no `vault kv get` of
secrets, no env dumps, not even "just to compare": hand the user a
ready-made command for their OWN terminal (compare hashes there if
needed) and consume only its pass/fail or hash output.

⚠️ MCP changes are picked up at launch: after the profile setup, or after
exporting `ZB_ORG_ID`/`ZB_TOKEN`, relaunch Claude Code from that shell
before re-running this pre-flight. Easiest: skip the manual exports and
re-run the script with `--launch` — it execs `claude` from the repo root
with all three values exported (read back from the slot). Anything after
`--launch` is passed to claude, so `--launch -p "add schema interface x"`
starts a headless run the same way. Full reference:
<https://github.com/zerobias-org/zerobias-org/blob/main/docs/MCPs.md>

Repo-shipped `.claude/settings.json` pre-authorizes the flow's `zbb`
commands (gate / env get / publishOrg). If the harness still prompts or a
classifier denies one, have the user add the rule via `/permissions` —
`env set` (key installs) stays approval-gated on purpose.

## MCP not connected — diagnose & recover

Applies to any MCP row above (zb, zb-knowledge). The connection is owned by
the Claude Code CLIENT: no tool on any MCP server can reconnect it, and
config edits take effect only when a HUMAN runs `/mcp` (reconnect) or
relaunches claude. **This is a technical limitation of the harness — be
transparent about it**: tell the user plainly that the agent cannot
reconnect MCPs itself and that one manual `/mcp` reconnect (or relaunch)
is needed from them. Ask for that manual step ONLY after you have verified
the fix will work (step 4) — never send the user to click reconnect on a
config you haven't proven, and never present the limitation as their fault.

1. **Diagnose from the repo cwd** — `claude mcp get <name>` (NOT from `~`:
   a user-scope entry with the same name can health-check green and mask
   the project-scope failure the session actually uses). Output shows
   scope, resolved URL, and the connect error.
2. **zb-knowledge 401 = env mismatch, not a bad key** (hit 2026-08-19).
   `.mcp.json`'s URL is `${KNOWLEDGE_MCP_URL:-https://api.app.zerobias.com/…}`
   — the fallback is PROD. Keys are per-environment, so a non-prod
   `ZB_API_KEY` with `KNOWLEDGE_MCP_URL` unset 401s at every launch.
3. **Prove the diagnosis with status codes only** (never print keys):
   `curl -s -o /dev/null -w '%{http_code}' -X POST -H "Authorization: ApiKey $ZB_API_KEY" -H "dana-org-id: $ZB_ORG_ID" https://api.<env>.zerobias.com/knowledge-mcp/mcp`
   → 200 on the key's own env, 401 elsewhere.
4. **Fix, then verify BEFORE asking for the reconnect.**
   Durable: relaunch via `./scripts/setup-org-credentials.sh --launch` —
   it exports `KNOWLEDGE_MCP_URL` derived from the slot's platform URL
   (fix landed 2026-08-20).
   Mid-session (keeps the conversation): add a local-scope override with
   PLACEHOLDER headers (never literal keys — local/user config is
   plaintext on disk):
   `claude mcp add -s local -t http <name> 'https://api.<env>.zerobias.com/knowledge-mcp/mcp' -H 'dana-org-id: ${ZB_ORG_ID}' -H 'Authorization: ApiKey ${ZB_API_KEY}'`
   then confirm `claude mcp get <name>` reports **✔ Connected** — that is
   the "sure it works" gate.
5. **Hand the user the one manual step**: run `/mcp` → reconnect `<name>`,
   framed as above (technical limitation, verified fix, single click).
   After they confirm, verify with a live call (`health_check`) and
   re-print the full prerequisites checklist before resuming.
6. **Hygiene**: mask `claude mcp get` output case-insensitively
   (`APIKey` vs `ApiKey` leaked a key once). Stale user-scope entries
   with literal keys → remove (`claude mcp remove <name> -s user`) and
   rotate the exposed key.

## Output

Always print the FULL checklist — one row per check above with its live
status — in BOTH outcomes; a bare verdict without the table is invalid:

- All ✅ → the checklist, then `READY — all schema-repo prerequisites
  satisfied.`
- Anything ❌ → the checklist, plus for each ❌: requirement · why it's
  needed · exact fix. Then only the two permitted actions until green;
  no other work starts (or resumes) before a re-printed all-✅ checklist.

## Consistency note

Every zerobias-org content repo carries this same skill under the same name,
tailored to its own requirements — deliberate duplication, kept in sync.
Cross-repo orchestrated flows (e.g. connector creation from the meta-repo)
MUST invoke every involved repo's `prerequisites` skill up front, so every
gap is caught before any work starts.
