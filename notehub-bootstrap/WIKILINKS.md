# Wikilinks in notehub

Obsidian-style `[[wikilink]]` resolution, with click-to-create for missing targets.

## Syntax supported (v1)

- `[[Target]]` — link by note basename
- `[[Target|display alias]]` — same, with display text
- `[[Target#Heading]]` — parsed, link resolves to file; heading anchor stored but jump behavior is future work

Files store wikilinks as plain `[[...]]` text. **Never rewrite `.md` files to "fix" links.** Resolve at render time.

## Resolution

Single mechanism: basename index lookup.

```
normalize(s) =
    strip .md suffix
    collapse runs of whitespace / hyphens / underscores → single space
    trim, lowercase
```

The vault is indexed at startup into `{normalize(basename) → [paths]}`. Lookup is O(1).

`[[Magic as Realitys Operating System]]`, `Magic-as-Realitys-Operating-System.md`, and `magic_as_realitys_operating_system.md` all collapse to the same key.

No fuzzy search, no heading-as-target fallback, no path-relative resolution. If the bracket text doesn't normalize-match a file, the link is **unresolved**.

### On collision

Two files normalizing to the same key:
- Pick deterministically at resolve time: shortest path first, then alphabetical.
- Log all collisions at startup; surface in `/audit` so the user can rename one.

## Unresolved links (would-create)

Render styled differently (dim / italic / dotted underline). On click:

1. Compute target path: **same folder as the source note**, filename = original bracket text + `.md`.
2. If that path collides with an existing file (shouldn't happen if normalization is consistent, but possible via race or external creation), append `_2`, `_3`, etc.
3. Initial file content: `# {original bracket text}\n\n` — preserve the user's casing and spaces, not the normalized form.
4. Add to the basename index immediately so subsequent renders resolve.

## Files created outside the system

External tools (Finder, Obsidian, rsync from another machine) can create duplicates that normalize the same. Detect at index build:
- Log dupes to `.notehub/audit.jsonl` as `{ts, kind: "basename_collision", key, paths}`.
- Surface via `/audit?kind=basename_collision`.
- Resolution still works (deterministic pick); user is responsible for renaming.

## API

- `POST /resolve-links` — body: `{source_path, targets: [bracket_text, ...]}` → `[{target_text, path?, anchor?, alias?, status: "resolved"|"unresolved"}]`. Batched, called once per rendered note.
- `POST /files/create-from-wikilink` — body: `{source_path, target_text}` → `{path}`. Creates the file with the right content and updates the index.

The renderer (client-side) parses `[[...]]`, calls `/resolve-links` once with all the bracket texts on the page, then rewrites them into `<a>` elements. Resolved → normal styling. Unresolved → "would-create" styling with a click handler that calls `/files/create-from-wikilink`.

## Why this is enough

- No cascade, no heuristics — every link either matches via normalization or it doesn't.
- Click-to-create matches Obsidian's intuitive default.
- In-system creation goes through the same normalization, so duplicates are effectively impossible via the API.
- Outside-system dupes get logged but don't corrupt anything.

## Reference implementation

See `link_resolver.py` in this folder — drop into `app/links.py` or fold into `app/vault.py`. Standalone, no dependencies beyond stdlib.

## Out of scope for v1

- `[[Note#Heading]]` jump-to-anchor in the rendered view (parse it, ignore the anchor on click for now)
- `[[Note#^block-id]]` block references
- `[[#Heading]]` same-document heading links
- Auto-rewrite of wikilinks when a target file is renamed (Obsidian does this; we don't)
- Free-text fuzzy fallback (explicitly rejected — silent wrong matches are worse than no match)
