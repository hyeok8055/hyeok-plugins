#!/usr/bin/env python3
"""Linux/POSIX stdlib regression tests; no Node, live Codex, or real home writes.

Run: python3 -B scripts/test_workspace_setup.py
"""
import os
from pathlib import Path
import subprocess
import tempfile
import unittest


REPO = Path(__file__).resolve().parent.parent
NAMES = (
    "hyeok-governance", "typst-korean", "diagram-design", "archify",
    "lieflat-charts", "juhyeoknizer",
)
BEGIN = b"<!-- BEGIN hyeok-gov -->"


def write(path, content):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(content)


def snapshot(root):
    return {
        str(p.relative_to(root)): (
            "link", os.readlink(p)
        ) if p.is_symlink() else (
            "dir",
        ) if p.is_dir() else (
            "file", p.read_bytes(), p.stat().st_mtime_ns
        )
        for p in root.rglob("*")
    }


@unittest.skipUnless(os.name == "posix", "Run with Linux/WSL python3 and sh")
class WorkspaceSetupTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="hyeok-workspace-python-")
        self.root = Path(self.temp.name)
        self.addCleanup(self.temp.cleanup)
        self.fixture = self.root / "public clone"
        self.script = self.fixture / "scripts/setup-codex-workspace.sh"
        write(self.script, (REPO / "scripts/setup-codex-workspace.sh").read_bytes())
        for name in NAMES:
            skill = self.fixture / "plugins" / name / "skills" / name
            write(skill / "SKILL.md", f"---\nname: {name}\ndescription: fixture\n---\n".encode())
            write(skill / "references/deep/resource.md", b"nested resource\n")
            write(skill / ".hidden", b"hidden resource\n")
            (skill / "empty").mkdir()
        self.home = self.root / "fake home"
        self.profile = self.home / ".codex"
        write(self.profile / "config.toml", b'model = "provided"\n[mcp_servers.keep]\ncommand = "keep"\n')
        write(self.profile / "auth.json", b'{"test_secret":"never-print-this"}\n')
        self.home_before = snapshot(self.home)
        self.workspace = self.root / "task project"
        self.workspace.mkdir()
        self.env = dict(os.environ, HOME=str(self.home), CODEX_HOME=str(self.profile),
                        PATH="/usr/bin:/bin")

    def run_setup(self, *args, success=True, script=None):
        before = snapshot(self.home)
        result = subprocess.run(
            ["sh", str(script or self.script), *args], cwd=self.workspace,
            env=self.env, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
            timeout=60,
        )
        self.assertEqual(snapshot(self.home), before, "setup changed fake home")
        self.assertNotIn("never-print-this", result.stdout)
        if success:
            self.assertEqual(result.returncode, 0, result.stdout)
        else:
            self.assertNotEqual(result.returncode, 0, result.stdout)
        return result.stdout

    def test_empty_and_whitespace_override_do_not_shadow_agents(self):
        original = b"# Organizer rules\r\nKeep all task instructions.\r\n"
        agents = self.workspace / "AGENTS.md"
        override = self.workspace / "AGENTS.override.md"
        for empty in (b"", b" \t\r\n\n"):
            with self.subTest(empty=empty):
                write(agents, original)
                write(override, empty)
                self.run_setup()
                self.assertEqual(override.read_bytes(), empty)
                self.assertTrue(agents.read_bytes().startswith(original))
                self.assertEqual(agents.read_bytes().count(BEGIN), 1)

    def test_nonempty_override_preserves_base_agents(self):
        agents = self.workspace / "AGENTS.md"
        override = self.workspace / "AGENTS.override.md"
        write(agents, b"# Base instructions\n")
        write(override, b"# Active organizer override\n")
        self.run_setup()
        self.assertEqual(agents.read_bytes(), b"# Base instructions\n")
        self.assertTrue(override.read_bytes().startswith(b"# Active organizer override\n"))
        self.assertIn(BEGIN, override.read_bytes())

    def test_custom_fallback_stops_before_creating_agents(self):
        write(self.profile / "config.toml", b'project_doc_fallback_filenames = [\n "TEAM_RULES.md",\n]\n')
        write(self.workspace / "TEAM_RULES.md", b"# Organizer fallback rules\n")
        before = snapshot(self.workspace)
        self.assertIn("--fallback-file", self.run_setup(success=False))
        self.assertEqual(snapshot(self.workspace), before)
        self.assertIn("--fallback-file", self.run_setup("--check", success=False))
        self.assertEqual(snapshot(self.workspace), before)

    def test_project_fallback_config_is_also_guarded(self):
        write(self.workspace / ".codex/config.toml", b'"project_doc_fallback_filenames" = ["TEAM_RULES.md"]\n')
        write(self.workspace / "TEAM_RULES.md", b"# Provided instructions\n")
        before = snapshot(self.workspace)
        self.assertIn("--fallback-file", self.run_setup(success=False))
        self.assertEqual(snapshot(self.workspace), before)

    def test_unselected_profiles_do_not_block_setup(self):
        write(self.profile / "unused.config.toml", b'project_doc_fallback_filenames = ["TEAM_RULES.md"]\n')
        write(self.workspace / "TEAM_RULES.md", b"# Not active in the current profile\n")
        self.run_setup()
        self.assertIn(BEGIN, (self.workspace / "AGENTS.md").read_bytes())
        self.assertEqual((self.workspace / "TEAM_RULES.md").read_bytes(), b"# Not active in the current profile\n")

    def test_custom_codex_home_ignores_default_user_config(self):
        write(self.profile / "config.toml", b'project_doc_fallback_filenames = ["TEAM_RULES.md"]\n')
        active_profile = self.home / "active profile"
        write(active_profile / "config.toml", b'model = "provided"\n')
        self.env["CODEX_HOME"] = str(active_profile)
        self.run_setup()
        self.assertIn(BEGIN, (self.workspace / "AGENTS.md").read_bytes())

    def test_empty_fallback_declaration_is_a_conservative_stop(self):
        write(self.profile / "config.toml", b'project_doc_fallback_filenames = []\n')
        before = snapshot(self.workspace)
        output = self.run_setup(success=False)
        self.assertIn("may affect", output)
        self.assertIn("Verify effective settings", output)
        self.assertEqual(snapshot(self.workspace), before)

    def test_existing_active_agents_does_not_need_fallback_selection(self):
        write(self.profile / "config.toml", b'project_doc_fallback_filenames = ["TEAM_RULES.md"]\n')
        write(self.workspace / "AGENTS.md", b"# Already active\n")
        write(self.workspace / "TEAM_RULES.md", b"# Inactive fallback\n")
        self.run_setup()
        self.assertIn(BEGIN, (self.workspace / "AGENTS.md").read_bytes())
        self.assertEqual((self.workspace / "TEAM_RULES.md").read_bytes(), b"# Inactive fallback\n")

    def test_selected_fallback_remains_active_and_setup_is_idempotent(self):
        write(self.profile / "config.toml", b'project_doc_fallback_filenames = ["TEAM_RULES.md"]\n')
        fallback = self.workspace / "TEAM_RULES.md"
        original = b"# Organizer fallback\nKeep required tests.\n"
        write(fallback, original)
        write(self.workspace / "AGENTS.override.md", b"")
        self.run_setup("--fallback-file", "TEAM_RULES.md")
        self.assertFalse((self.workspace / "AGENTS.md").exists())
        self.assertEqual((self.workspace / "AGENTS.override.md").read_bytes(), b"")
        self.assertTrue(fallback.read_bytes().startswith(original))
        self.assertEqual(fallback.read_bytes().count(BEGIN), 1)
        self.assertTrue(any(p.read_bytes() == original for p in (self.workspace / ".hyeok/backups").rglob("TEAM_RULES.md")))
        installed = snapshot(self.workspace)
        self.run_setup("--fallback-file", "TEAM_RULES.md")
        self.assertEqual(snapshot(self.workspace), installed)

    def test_invalid_or_shadowed_fallback_is_rejected_without_writes(self):
        write(self.workspace / "TEAM_RULES.md", b"# Fallback\n")
        for filename in ("../outside.md", "missing.md", "AGENTS.md"):
            with self.subTest(filename=filename):
                before = snapshot(self.workspace)
                self.run_setup("--fallback-file", filename, success=False)
                self.assertEqual(snapshot(self.workspace), before)
        write(self.workspace / "AGENTS.md", b"# Active standard instructions\n")
        before = snapshot(self.workspace)
        self.run_setup("--fallback-file", "TEAM_RULES.md", success=False)
        self.assertEqual(snapshot(self.workspace), before)

    def test_parent_repo_duplicate_stops_before_writes(self):
        (self.workspace / ".git").mkdir()
        write(self.workspace / ".agents/skills/archify/SKILL.md", b"parent copy\n")
        nested = self.workspace / "services/api"
        nested.mkdir(parents=True)
        self.workspace = nested
        before = snapshot(self.root / "task project")
        self.assertIn("parent", self.run_setup(success=False).lower())
        self.assertEqual(snapshot(self.root / "task project"), before)

    def test_duplicate_outside_repo_boundary_is_ignored(self):
        write(self.root / ".agents/skills/archify/SKILL.md", b"outside repository\n")
        write(self.workspace / ".git", b"gitdir: /fixture/worktree\n")
        self.run_setup()
        self.assertIn(BEGIN, (self.workspace / "AGENTS.md").read_bytes())

    def test_parent_project_fallback_config_is_guarded(self):
        (self.workspace / ".git").mkdir()
        write(self.workspace / ".codex/config.toml", b"'project_doc_fallback_filenames' = ['TEAM_RULES.md']\n")
        nested = self.workspace / "services/api"
        nested.mkdir(parents=True)
        write(nested / "TEAM_RULES.md", b"# Task instructions\n")
        self.workspace = nested
        before = snapshot(self.root / "task project")
        self.assertIn("--fallback-file", self.run_setup(success=False))
        self.assertEqual(snapshot(self.root / "task project"), before)

    def test_large_instructions_warn_without_changing_settings(self):
        original = b"# Organizer rules\n" + b"A" * 32768 + b"\n"
        write(self.workspace / "AGENTS.md", original)
        output = self.run_setup()
        self.assertIn("32 KiB", output)
        self.assertTrue((self.workspace / "AGENTS.md").read_bytes().startswith(original))
        self.assertEqual(snapshot(self.home), self.home_before)

    def test_check_copy_backups_and_idempotence(self):
        before = snapshot(self.workspace)
        self.run_setup("--check")
        self.assertEqual(snapshot(self.workspace), before)
        original = b"# Provided instructions\r\nKeep these.\r\n"
        write(self.workspace / "AGENTS.md", original)
        write(self.workspace / ".agents/skills/archify/SKILL.md", b"old copy\n")
        write(self.workspace / ".agents/skills/archify/personal.txt", b"preserve\n")
        self.run_setup()
        for name in NAMES:
            source = self.fixture / "plugins" / name / "skills" / name
            target = self.workspace / ".agents/skills" / name
            for p in source.rglob("*"):
                installed = target / p.relative_to(source)
                self.assertTrue(installed.exists())
                if p.is_file():
                    self.assertEqual(installed.read_bytes(), p.read_bytes())
        self.assertEqual((self.workspace / ".agents/skills/archify/personal.txt").read_bytes(), b"preserve\n")
        backups = [p.read_bytes() for p in (self.workspace / ".hyeok/backups").rglob("*") if p.is_file()]
        self.assertIn(original, backups)
        self.assertIn(b"old copy\n", backups)
        installed = snapshot(self.workspace)
        self.run_setup()
        self.run_setup("--check")
        self.assertEqual(snapshot(self.workspace), installed)

    def test_global_duplicate_malformed_and_symlink_guards(self):
        write(self.home / ".agents/skills/archify/SKILL.md", b"global copy\n")
        before = snapshot(self.workspace)
        self.assertIn("Global duplicate", self.run_setup(success=False))
        self.assertEqual(snapshot(self.workspace), before)
        (self.home / ".agents/skills/archify/SKILL.md").unlink()
        write(self.workspace / "AGENTS.md", BEGIN + b"\n")
        before = snapshot(self.workspace)
        self.assertIn("Malformed", self.run_setup(success=False))
        self.assertEqual(snapshot(self.workspace), before)
        (self.workspace / "AGENTS.md").unlink()
        (self.workspace / "AGENTS.override.md").symlink_to(self.profile / "config.toml")
        before = snapshot(self.workspace)
        self.assertIn("Symlink", self.run_setup(success=False))
        self.assertEqual(snapshot(self.workspace), before)

    def test_real_payload_matches_source(self):
        # Only the target is temporary. This also checks all production assets.
        output = self.run_setup(script=REPO / "scripts/setup-codex-workspace.sh")
        self.assertIn("Installed 6 complete skills", output)
        count = 0
        for name in NAMES:
            source = REPO / "plugins" / name / "skills" / name
            for p in source.rglob("*"):
                target = self.workspace / ".agents/skills" / name / p.relative_to(source)
                self.assertTrue(target.exists())
                if p.is_file():
                    self.assertEqual(target.read_bytes(), p.read_bytes())
                    count += 1
        self.assertGreater(count, 300)
        print(f"Verified {count} production resource files in Linux workspace.")


if __name__ == "__main__":
    unittest.main(verbosity=2)
