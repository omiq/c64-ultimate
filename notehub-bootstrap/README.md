# notehub

A small markdown hub: plain `.md` files on disk, a minimal web editor, and an API that lets Claude agents read, write, query, and run scheduled tasks against the vault.

The editor is intentionally boring. The value is the API and the hub.

## Goals

- One place for notes, todos, journal, specs, and scheduled coworks.
- Plain markdown on disk — no DB, no lock-in. Git/rsync/Obsidian all still work as fallbacks.
- Interrogate the vault instead of letting it pile up.
- Move scattered automations (email drafts, ad-hoc scripts in random repos) into one place with a config and a log.

## Non-goals (for v1)

- Fancy editor UX (rename, drag-and-drop, multi-pane). Use ssh/ftp or ask Claude.
- Real-time collaboration.
- Mobile-native app. Mobile = the web UI over Tailscale.

## Conventions

- Files are `.md` with optional YAML frontmatter.
- Standard frontmatter keys: `status` (`open|done|archived`), `project` (slug), `due` (`YYYY-MM-DD`), `tags` (list).
- Todos are GitHub-style `- [ ]` / `- [x]` lines. Inline `due:2026-05-20` / `project:c64` tags allowed.
- Daily notes live at `daily/YYYY-MM-DD.md`.
- Agent-written files go under `claude/` until promoted by a human edit.
- Links: both `[[wikilinks]]` (Obsidian-compatible, primary) and standard `[text](path.md)` are supported. See `WIKILINKS.md` for the resolution + click-to-create spec; reference implementation in `link_resolver.py`.

## Directory layout

```
vault/
  daily/                  YYYY-MM-DD.md per day
  projects/<slug>/        per-project notes, specs, progress
  inbox/                  quick capture, unsorted
  reference/              evergreen notes
  claude/                 agent-written, pending review
  .notehub/
    audit.jsonl           append-only log of agent writes
    tasks.yaml            scheduled cowork definitions
    index.sqlite          optional FTS index (built from files)
```

## API surface (v1)

All endpoints require `Authorization: Bearer <token>`. JSON in/out unless noted.

### Files

| Method | Path | Purpose |
|---|---|---|
| `GET`  | `/files?path=<rel>`         | List dir entries or return file body (`{path, content, frontmatter, mtime}`). |
| `PUT`  | `/files?path=<rel>`         | Create/overwrite. Body: `{content, expected_mtime?}` for optimistic concurrency. |
| `POST` | `/files/move`               | `{from, to}` — rename/move. |
| `DELETE` | `/files?path=<rel>`       | Soft delete (move to `.notehub/trash/`). |

### Search

| Method | Path | Purpose |
|---|---|---|
| `GET` | `/search?q=&tag=&status=&project=&since=&limit=` | Full-text + frontmatter filter. Returns `[{path, score, snippet, frontmatter}]`. |
| `GET` | `/quickopen?q=`             | Fuzzy filename match for `Cmd+P`-style picker. |

### Todos

| Method | Path | Purpose |
|---|---|---|
| `GET`  | `/todos?status=&project=&due_before=&due_after=` | Aggregated from every `.md`. Returns `[{path, line, text, parent_heading, done, due, project, tags}]`. |
| `PATCH` | `/todos`                   | `{path, line, done}` — toggle a single todo. |

### Journal

| Method | Path | Purpose |
|---|---|---|
| `POST` | `/journal`                  | Body: `{text, heading?, date?}`. Appends to `daily/<date>.md` (defaults today). Creates file if missing. |
| `GET`  | `/journal/<date>`           | Read a daily note (or 404). |

### Ask (interrogate)

| Method | Path | Purpose |
|---|---|---|
| `POST` | `/ask`                      | Body: `{question, scope?, max_sources?}`. Server runs a search, stuffs top hits into a Claude prompt, returns `{answer, sources:[{path, snippet}]}`. |

### Links / graph

| Method | Path | Purpose |
|---|---|---|
| `GET`  | `/links?path=<rel>`                 | `{outgoing:[...], backlinks:[...]}`. |
| `GET`  | `/graph?root=<rel>&depth=2`         | Subgraph for the given root note. |
| `POST` | `/resolve-links`                    | Batch wikilink resolution for renderer. Body: `{source_path, targets:[...]}` → `[{target, path?, anchor?, alias?, status}]`. See `WIKILINKS.md`. |
| `POST` | `/files/create-from-wikilink`       | `{source_path, target_text}` → `{path}`. Creates a new note for an unresolved wikilink in the same folder as the source. |

### Scheduled coworks (the real automation hub)

`.notehub/tasks.yaml`:
```yaml
- id: weekly-review
  cron: "0 9 * * MON"
  prompt: |
    Summarize last week's daily notes into a weekly review.
    Group by project. Surface unfinished todos.
  scope: "daily/"
  output: "reviews/{{year}}-W{{week}}.md"
```

| Method | Path | Purpose |
|---|---|---|
| `GET`  | `/tasks`                    | List configured tasks + last run status. |
| `POST` | `/tasks/{id}/run`           | Manual trigger. Returns run id. |
| `GET`  | `/tasks/{id}/runs`          | Run history with output paths + token usage. |

### Audit

| Method | Path | Purpose |
|---|---|---|
| `GET` | `/audit?since=&path=`        | Tail of `audit.jsonl`. Every agent write is `{ts, endpoint, prompt, files_touched, diff}`. |

## Stack (proposed)

- **Backend**: Python + FastAPI. Reasons: typed endpoints, auto OpenAPI (which Claude can consume as a tool spec), Anthropic SDK first-class, good markdown/frontmatter libs.
- **Editor**: CodeMirror 6, vanilla JS. No framework for v1.
- **Storage**: flat files. SQLite FTS5 added only when ripgrep gets slow.
- **Scheduler**: APScheduler in-process for v1; promote to systemd timers later if needed.
- **Auth**: single bearer token in env var. Behind Tailscale.

## Current scattered automations to migrate

_(Filled in by user — these become the first `tasks.yaml` entries.)_

- [ ] TODO: list current scheduled tasks running across email drafts / repos
- [ ] TODO: list current todo locations to consolidate

## Open questions

- Whether to render preview server-side or client-side (lean client-side, marked.js + post-process for wikilinks).
- Whether `/ask` should stream responses — probably yes once it works at all.
- Auto-rewrite wikilinks when a target file is renamed? Obsidian does this; we currently do not (and the resolver doesn't need it because resolution is by basename, not path).
