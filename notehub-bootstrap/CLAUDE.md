# notehub — session resume primer

You're picking up a project that was designed in a previous Claude session. Read this first, then `README.md` for the full design.

## What notehub is

A small markdown hub. Plain `.md` files on disk, a minimal web editor, and an API that lets Claude agents read, write, query, and run scheduled tasks against a vault. The editor is intentionally boring. **The value is the API and the hub** — not the editor.

The user has ADHD and explicitly does not want fancy editor UX (no drag-drop, no rename UI, no multi-pane). File management is fine via ssh/ftp or by asking Claude. The goal is: stop scattering todos/automations across email drafts and ad-hoc scripts, get one place to capture and interrogate.

## Repos and locations

- **App code**: `github.com/omiq/notehub` (public, open source). Local: `/Users/chrisg/github/notehub/` on the user's Mac.
- **Personal vault**: `github.com/omiq/vault` (private). Local: `/Users/chrisg/github/vault/` on the user's Mac.
- The app reads vault path from env var `NOTEHUB_VAULT` (per-machine, gitignored `.env`). So the same code runs on Mac and on the user's always-on Linux server.

## Key decisions already made

1. **Stack**: Python + FastAPI backend, CodeMirror 6 frontend (vanilla JS, no framework for v1), flat `.md` files, optional SQLite FTS5 later, APScheduler in-process for scheduled tasks, single bearer token auth behind Tailscale.
2. **Conventions** (see README for full list):
   - YAML frontmatter with `status` / `project` / `due` / `tags`
   - Standard markdown links `[text](path.md)` — defer `[[wikilinks]]` until we feel pain
   - Daily notes at `daily/YYYY-MM-DD.md`
   - Agent-written files quarantined under `claude/` until promoted
   - Audit log at `.notehub/audit.jsonl` (append-only; **commit it** in the vault repo — it's the agent history)
3. **Vault commit/push policy**:
   - Agent writes via API → immediate local commit with structured message (`agent: task=... files=... prompt="..."`)
   - Human editor saves → debounced commit per file (60s after last edit)
   - Push → separate worker on 1–5 min timer; API never blocks on git/network
   - For v0/week-1, a simple cron (`git add -A && git commit -m auto && git push` every 5 min) is acceptable to ship fast; upgrade to API-managed commits once audit/blame matters.
   - On push conflict: `git pull --rebase`; on actual merge conflict, halt push, write `.notehub/sync-conflict.md`, surface via `/audit`.
4. **Vault repo gitignore**: include `.notehub/audit.jsonl`, exclude `.notehub/index.sqlite` and `.notehub/trash/`.

## API surface (v1)

Full table is in `README.md`. The headline endpoints:

- `GET /files`, `PUT /files`, `POST /files/move`, `DELETE /files`
- `GET /search`, `GET /quickopen`
- `GET /todos` (aggregated across vault), `PATCH /todos`
- `POST /journal`, `GET /journal/<date>` — capture endpoint, phone shortcut hits this
- `POST /ask` — the interrogate endpoint: search → stuff into Claude prompt → return answer + citations
- `GET /links`, `GET /graph`
- `GET /tasks`, `POST /tasks/{id}/run`, `GET /tasks/{id}/runs` — scheduled coworks defined in `.notehub/tasks.yaml`
- `GET /audit`

All endpoints require `Authorization: Bearer <token>`.

## Suggested next steps

Pick one based on what the user wants in this session:

1. **Scaffold the FastAPI app**. Minimal: bearer-token middleware, `/files` CRUD, `GitWorker` stub that enqueues commit intents (no actual git calls yet — just log them). Deps: `fastapi`, `uvicorn`, `python-frontmatter`, `pydantic`, `pyyaml`. Layout:
   ```
   app/
     main.py          FastAPI app + middleware
     config.py        loads NOTEHUB_VAULT, NOTEHUB_TOKEN from env
     routers/
       files.py
       search.py
       todos.py
       journal.py
       ask.py
       tasks.py
       audit.py
     git_worker.py    asyncio.Queue + debounced commit + push tick
     vault.py         path helpers, frontmatter parsing, safety (no `..` escapes)
   ```
2. **Build the minimal web editor** — single page, CodeMirror 6, flat sidebar list, `Cmd+P` quick-open, `Cmd+K` "ask the vault". Static files served by FastAPI.
3. **Wire `/ask`** — needs `anthropic` SDK, search results → prompt template → response with citations.
4. **Migrate one scattered automation** into `.notehub/tasks.yaml` (user said they'd collect their priority list).

## Things to ask the user before assuming

- The "Current scattered automations to migrate" section in `README.md` is empty — they were going to fill it in. If empty when you start, ask for the priority list.
- Whether `/ask` should stream responses (we leaned yes but didn't decide).
- Whether preview rendering is client-side (lean) or server-side.

## What NOT to do

- Don't build rename/drag-and-drop file UX — explicitly out of scope for v1.
- Don't introduce a database for primary storage — files are the source of truth. SQLite is only an optional FTS index.
- Don't have the API block on `git push`. Ever.
- Don't write directly into the user's main notes from agents in v1 — write to `claude/` and let the user promote.
- Don't add wikilinks unless the user asks; standard `[text](path.md)` links keep parsing trivial.

## Out-of-scope for v1

Multi-user, real-time collab, mobile-native app (mobile = web UI over Tailscale), drag-and-drop file management, wikilinks, server-side preview rendering, plugin system.
