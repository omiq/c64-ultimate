"""Wikilink resolver for notehub. See WIKILINKS.md for the spec.

Standalone reference implementation — drop into app/links.py or fold into
app/vault.py. Stdlib only.
"""

from __future__ import annotations

import re
from dataclasses import dataclass, field
from pathlib import Path
from typing import Iterator


WIKILINK_RE = re.compile(
    r"\[\[(?P<target>[^\]|#]+)(?:#(?P<anchor>[^\]|]+))?(?:\|(?P<alias>[^\]]+))?\]\]"
)

_NORMALIZE_RE = re.compile(r"[\s_\-]+")


def normalize(s: str) -> str:
    if s.endswith(".md"):
        s = s[:-3]
    return _NORMALIZE_RE.sub(" ", s).strip().lower()


@dataclass
class ParsedLink:
    target: str            # original bracket text, e.g. "Magic as Realitys OS"
    anchor: str | None     # text after #, if any
    alias: str | None      # display text after |, if any
    start: int             # character offset in source
    end: int


@dataclass
class ResolvedLink:
    target: str
    anchor: str | None
    alias: str | None
    path: Path | None      # None = unresolved (would-create)
    collisions: list[Path] = field(default_factory=list)

    @property
    def resolved(self) -> bool:
        return self.path is not None


def parse_wikilinks(text: str) -> Iterator[ParsedLink]:
    for m in WIKILINK_RE.finditer(text):
        yield ParsedLink(
            target=m.group("target").strip(),
            anchor=(m.group("anchor") or "").strip() or None,
            alias=(m.group("alias") or "").strip() or None,
            start=m.start(),
            end=m.end(),
        )


class LinkIndex:
    """Vault-wide basename index. Built once at startup, mutated on writes."""

    def __init__(self, vault_root: Path):
        self.root = vault_root.resolve()
        self._by_key: dict[str, list[Path]] = {}

    def build(self) -> list[tuple[str, list[Path]]]:
        """Walk the vault, populate the index. Returns list of collisions."""
        self._by_key.clear()
        for path in self.root.rglob("*.md"):
            if any(part.startswith(".") for part in path.relative_to(self.root).parts):
                continue
            self._add_path(path)
        return self.collisions()

    def collisions(self) -> list[tuple[str, list[Path]]]:
        return [(key, paths) for key, paths in self._by_key.items() if len(paths) > 1]

    def add(self, path: Path) -> None:
        self._add_path(path.resolve())

    def remove(self, path: Path) -> None:
        path = path.resolve()
        key = normalize(path.stem)
        if key in self._by_key:
            self._by_key[key] = [p for p in self._by_key[key] if p != path]
            if not self._by_key[key]:
                del self._by_key[key]

    def rename(self, old: Path, new: Path) -> None:
        self.remove(old)
        self.add(new)

    def resolve(self, target: str) -> tuple[Path | None, list[Path]]:
        """Returns (resolved_path, all_matches). resolved_path is the deterministic pick."""
        key = normalize(target)
        matches = self._by_key.get(key, [])
        if not matches:
            return None, []
        if len(matches) == 1:
            return matches[0], matches
        # Deterministic tiebreak: shortest relative path, then alphabetical.
        chosen = min(matches, key=lambda p: (len(p.parts), str(p)))
        return chosen, matches

    def _add_path(self, path: Path) -> None:
        key = normalize(path.stem)
        bucket = self._by_key.setdefault(key, [])
        if path not in bucket:
            bucket.append(path)
            bucket.sort(key=lambda p: (len(p.parts), str(p)))


def resolve_links(
    text: str, source_path: Path, index: LinkIndex
) -> list[ResolvedLink]:
    out: list[ResolvedLink] = []
    for parsed in parse_wikilinks(text):
        path, all_matches = index.resolve(parsed.target)
        out.append(
            ResolvedLink(
                target=parsed.target,
                anchor=parsed.anchor,
                alias=parsed.alias,
                path=path,
                collisions=all_matches if len(all_matches) > 1 else [],
            )
        )
    return out


def new_file_path_for(target: str, source_path: Path) -> Path:
    """Same folder as source, filename = target + .md. Append _N on collision."""
    folder = source_path.parent
    base = target.strip()
    candidate = folder / f"{base}.md"
    if not candidate.exists():
        return candidate
    n = 2
    while True:
        candidate = folder / f"{base}_{n}.md"
        if not candidate.exists():
            return candidate
        n += 1


def initial_content(target: str) -> str:
    return f"# {target}\n\n"


def create_from_wikilink(
    target: str, source_path: Path, vault_root: Path, index: LinkIndex
) -> Path:
    """Create a new note for an unresolved wikilink. Returns the new path."""
    source = source_path.resolve()
    if vault_root.resolve() not in source.parents and source != vault_root.resolve():
        raise ValueError(f"source_path {source} outside vault {vault_root}")
    new_path = new_file_path_for(target, source)
    new_path.write_text(initial_content(target), encoding="utf-8")
    index.add(new_path)
    return new_path


# --- minimal smoke test (run as `python link_resolver.py /path/to/vault`) ---

if __name__ == "__main__":
    import sys

    if len(sys.argv) != 2:
        print("usage: python link_resolver.py <vault_root>")
        sys.exit(1)

    root = Path(sys.argv[1])
    idx = LinkIndex(root)
    collisions = idx.build()
    print(f"indexed {sum(len(v) for v in idx._by_key.values())} files "
          f"under {len(idx._by_key)} keys")
    if collisions:
        print(f"\n{len(collisions)} collision(s):")
        for key, paths in collisions:
            print(f"  {key!r}")
            for p in paths:
                print(f"    {p.relative_to(root)}")
