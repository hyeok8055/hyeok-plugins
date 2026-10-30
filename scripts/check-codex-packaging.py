#!/usr/bin/env python3
"""Offline, stdlib-only checks for this repository's Codex skill marketplace.

Run: python scripts/check-codex-packaging.py [--repo PATH]
Only packaged declarations are checked; no user MCP configuration is required,
read, or executed. Markdown link checks cover governance's entry point and
references/*.md, not vendored upstream documentation. Archived plugins are not
auto-discovered; active plugins and declared marketplace sources are checked.
"""

import argparse
import json
from pathlib import Path, PureWindowsPath
import re
from urllib.parse import unquote, urlsplit


PROJECT_DOCUMENTS = {"README.MD", "AGENTS.MD", "SKILL.MD", "PLANS.MD", "GOALS.MD", "PROMPTS.MD"}


def inside(path, root):
    try:
        path.relative_to(root)
        return True
    except ValueError:
        return False


def nonempty_scalar(value):
    value = value.strip()
    if value.startswith(("'", '"')):
        quote = value[0]
        end = value.rfind(quote)
        return end > 0 and bool(value[1:end].strip())
    value = re.split(r"\s+#", value, maxsplit=1)[0].strip()
    return bool(value) and not value.startswith("#") and value.lower() not in {
        "null", "~", "[]", "{}", "true", "false",
    }


def has_frontmatter_field(lines, key):
    """Check the required scalar subset without pretending to parse all YAML."""
    for index, line in enumerate(lines):
        match = re.match(r"^" + key + r":[ \t]*(.*)$", line)
        if not match:
            continue
        value = match.group(1)
        if re.fullmatch(r"[>|][+\-1-9]*(?:\s+#.*)?", value.strip()):
            block = []
            for following in lines[index + 1:]:
                if following and not following[0].isspace():
                    break
                block.append(following.strip())
            return any(text and not text.startswith("#") for text in block)
        return nonempty_scalar(value)
    return False


def local_links(text, include_inline=True):
    """Yield actual Markdown destinations and explicit inline doc references.

    Bare README.md/AGENTS.md examples and config paths can describe the target
    project or user home. Inline code checks explicit relative .md paths and
    bare document filenames other than these conventional project entrypoints.
    Only the skill entrypoint uses inline path discovery: reference documents
    can discuss filenames relative to a different, separately installed skill.
    Fenced examples and external URLs are not packaging dependencies.
    """
    text = re.sub(r"(?ms)^[ \t]*(`{3,}|~{3,})[^\n]*\n.*?^[ \t]*\1[^\n]*$", "", text)
    targets = []
    for pattern in (
        r'!?\[[^\]\n]*\]\(\s*(?:<([^>\n]+)>|([^\s)]+))(?:\s+[\'\"][^\n]*?[\'\"])?\s*\)',
        r"(?m)^[ \t]{0,3}\[[^\]\n]+\]:[ \t]*(?:<([^>\n]+)>|(\S+))",
    ):
        targets.extend(a or b for a, b in re.findall(pattern, text))
    if include_inline:
        for code in re.findall(r"(?<!`)`([^`\n]+)`(?!`)", text):
            if (re.fullmatch(r"(?:\.{1,2}/|references/)[^\s`*<>]+\.md(?:#[^\s]+)?", code)
                    or (re.fullmatch(r"[^/\\\s`*<>]+\.md(?:#[^\s]+)?", code)
                        and code.split("#", 1)[0].upper() not in PROJECT_DOCUMENTS)):
                targets.append(code)
    for target in dict.fromkeys(targets):
        if target.startswith(("#", "//")):
            continue
        # A Windows drive or file: URL is a non-portable local path, not a web URL.
        if PureWindowsPath(target).drive or target.lower().startswith("file:"):
            yield target
            continue
        parsed = urlsplit(target)
        if not parsed.scheme and parsed.path:
            yield unquote(parsed.path)


class PackagingCheck:
    def __init__(self, repo):
        self.repo = Path(repo).resolve()
        self.errors = []
        self.manifests = set()
        self.skills = set()

    def error(self, path, message):
        label = path.relative_to(self.repo) if inside(path, self.repo) else path
        self.errors.append(f"{label.as_posix()}: {message}")

    def read_json(self, path):
        try:
            data = json.loads(path.read_text(encoding="utf-8-sig"))
            if not isinstance(data, dict):
                raise ValueError("expected a JSON object")
            return data
        except (OSError, ValueError) as exc:
            self.error(path, f"cannot read JSON: {exc}")
            return None

    def local_path(self, base, value, boundary, declared_in):
        if not isinstance(value, str) or not value.strip():
            self.error(declared_in, "local path must be a nonempty string")
            return None
        value = value.replace("\\", "/")
        if (Path(value).is_absolute() or PureWindowsPath(value).drive
                or value.startswith(("~", "$")) or urlsplit(value).scheme):
            self.error(declared_in, f"path must be relative to its package: {value}")
            return None
        try:
            target = (base / value).resolve()
        except (OSError, RuntimeError) as exc:
            self.error(declared_in, f"cannot resolve {value}: {exc}")
            return None
        if not inside(target, boundary):
            self.error(declared_in, f"path escapes its package: {value}")
            return None
        return target

    def declared_paths(self, value, declared_in, field):
        values = [value] if isinstance(value, str) else value
        if not isinstance(values, list) or not values or any(
                not isinstance(item, str) or not item.strip() for item in values):
            self.error(declared_in, f"{field} must be a path string or nonempty array of path strings")
            return []
        return values

    def check_skill(self, path, plugin_root):
        resolved = path.resolve()
        if not inside(resolved, plugin_root):
            self.error(path, "SKILL.md escapes its plugin package")
            return
        if resolved in self.skills:
            return
        self.skills.add(resolved)
        try:
            lines = path.read_text(encoding="utf-8-sig").splitlines()
        except (OSError, UnicodeError) as exc:
            self.error(path, f"cannot read skill: {exc}")
            return
        if not lines or lines[0].strip() != "---" or "---" not in lines[1:]:
            self.error(path, "missing YAML frontmatter delimiters")
            return
        frontmatter = lines[1:lines.index("---", 1)]
        for field in ("name", "description"):
            if not has_frontmatter_field(frontmatter, field):
                self.error(path, f"frontmatter {field} must be nonempty")
        if path.parent.name == "hyeok-governance":
            self.check_governance(path.parent.resolve())

    def check_governance(self, skill_root):
        # Containment also rejects symlinks that would break a skill-only copy.
        documents = [skill_root / "SKILL.md"]
        documents.extend(sorted((skill_root / "references").glob("*.md")))
        for document in documents:
            if not inside(document.resolve(), skill_root):
                self.error(document, "governance document escapes its standalone skill")
                continue
            try:
                text = document.read_text(encoding="utf-8-sig")
            except (OSError, UnicodeError) as exc:
                self.error(document, f"cannot read governance document: {exc}")
                continue
            for link in local_links(text, include_inline=document == skill_root / "SKILL.md"):
                target = self.local_path(document.parent, link, skill_root, document)
                if target is not None and not target.exists():
                    self.error(document, f"missing standalone governance reference: {link}")

    def check_manifest(self, manifest):
        plugin_root = manifest.parent.parent.resolve()
        if not inside(manifest.resolve(), self.repo):
            self.error(manifest, "manifest escapes repository")
            return
        self.manifests.add(manifest)
        data = self.read_json(manifest)
        if data is None:
            return
        for value in self.declared_paths(data.get("skills"), manifest, "skills"):
            directory = self.local_path(plugin_root, value, plugin_root, manifest)
            if directory is None:
                continue
            if not directory.is_dir():
                self.error(manifest, f"skill path is not a directory: {value}")
                continue
            # A declaration can name one skill or a directory of skill folders.
            skills = ([directory / "SKILL.md"] if (directory / "SKILL.md").is_file()
                      else sorted(directory.glob("*/SKILL.md")))
            if not skills:
                self.error(manifest, f"no SKILL.md discovered under: {value}")
            for skill in skills:
                self.check_skill(skill, plugin_root)
        for field in ("hooks", "mcpServers", "mcp"):
            if field not in data:
                continue
            for value in self.declared_paths(data[field], manifest, field):
                target = self.local_path(plugin_root, value, plugin_root, manifest)
                if target is not None and not target.is_file():
                    self.error(manifest, f"{field} declaration is not a file: {value}")

    def run(self):
        marketplace = self.repo / ".agents/plugins/marketplace.json"
        data = self.read_json(marketplace)
        # Keep archives out of auto-discovery; marketplace entries can declare
        # other local plugin roots explicitly.
        manifests = set((self.repo / "plugins").rglob(".codex-plugin/plugin.json"))
        if data is not None:
            entries = data.get("plugins")
            if not isinstance(entries, list):
                self.error(marketplace, "plugins must be an array")
                entries = []
            for entry in entries:
                if not isinstance(entry, dict) or not isinstance(entry.get("source"), dict):
                    self.error(marketplace, "plugin entry must declare a source object")
                    continue
                source = entry["source"]
                if source.get("source") != "local":
                    continue  # Offline check: never fetch remote plugin sources.
                directory = self.local_path(self.repo, source.get("path"), self.repo, marketplace)
                if directory is None:
                    continue
                manifest = directory / ".codex-plugin/plugin.json"
                if not directory.is_dir() or not manifest.is_file():
                    self.error(marketplace, f"local plugin lacks .codex-plugin/plugin.json: {source.get('path')}")
                else:
                    manifests.add(manifest)
        for manifest in sorted(manifests):
            self.check_manifest(manifest)
        return self


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo", type=Path, default=Path(__file__).resolve().parent.parent,
                        help="repository root (defaults to this script's repository)")
    check = PackagingCheck(parser.parse_args(argv).repo).run()
    for error in check.errors:
        print(f"ERROR {error}")
    print(f"{'FAIL' if check.errors else 'PASS'}: {len(check.manifests)} plugin manifests, "
          f"{len(check.skills)} skills, {len(check.errors)} errors")
    return int(bool(check.errors))


if __name__ == "__main__":
    raise SystemExit(main())
