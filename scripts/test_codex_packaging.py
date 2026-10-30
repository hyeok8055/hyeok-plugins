"""Temporary-repository regression tests; run with stdlib unittest discovery."""

import contextlib
import importlib.util
import io
import json
from pathlib import Path
import shutil
import tempfile
import unittest


SPEC = importlib.util.spec_from_file_location(
    "codex_packaging", Path(__file__).with_name("check-codex-packaging.py"))
PACKAGING = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(PACKAGING)


class PackagingTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.repo = Path(self.temporary.name) / "repo"
        self.plugin = self.repo / "plugins/hyeok-governance"
        self.skill = self.plugin / "skills/hyeok-governance"
        self.marketplace = self.repo / ".agents/plugins/marketplace.json"
        self.manifest = self.plugin / ".codex-plugin/plugin.json"
        self.write_json(self.marketplace, {"plugins": [{
            "name": "hyeok-governance", "source": {
                "source": "local", "path": "./plugins/hyeok-governance"}}]})
        self.write_json(self.manifest, {"name": "hyeok-governance", "skills": "./skills/"})
        self.write(self.skill / "SKILL.md", "---\nname: hyeok-governance\ndescription: >\n  Routing.\n---\n")

    @staticmethod
    def write(path, text):
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(text, encoding="utf-8")

    def write_json(self, path, value):
        self.write(path, json.dumps(value))

    def result(self):
        return PACKAGING.PackagingCheck(self.repo).run()

    def assert_error(self, text):
        self.assertTrue(any(text in error for error in self.result().errors), text)

    def test_collection_and_direct_array_discovery_without_user_mcp(self):
        self.assertEqual([], self.result().errors)
        self.write_json(self.manifest, {"skills": ["skills/hyeok-governance"]})
        result = self.result()
        self.assertEqual([], result.errors)
        self.assertEqual(1, len(result.skills))

    def test_additional_active_plugin_is_checked_without_discovering_external_legacy(self):
        extra = self.repo / "plugins/extra-plugin"
        self.write_json(extra / ".codex-plugin/plugin.json", {"skills": "skills/extra"})
        self.write(extra / "skills/extra/SKILL.md", "---\nname: extra\ndescription: Extra.\n---\n")
        self.write(self.repo.parent / "tmp/legacy-humanize-korean-20990101/.codex-plugin/plugin.json",
                   "{unfinished legacy manifest}")
        result = self.result()
        self.assertEqual([], result.errors)
        self.assertEqual(2, len(result.manifests))
        self.assertEqual(2, len(result.skills))

    def test_missing_skill_directory_and_empty_collection(self):
        self.write_json(self.manifest, {"skills": "skills/missing"})
        self.assert_error("skill path is not a directory")
        (self.skill / "SKILL.md").unlink()
        self.write_json(self.manifest, {"skills": "skills"})
        self.assert_error("no SKILL.md discovered")

    def test_every_array_entry_is_validated(self):
        self.write_json(self.manifest, {"skills": ["skills/hyeok-governance", "skills/missing"]})
        result = self.result()
        self.assertEqual(1, len(result.skills))
        self.assertTrue(any("skill path is not a directory" in error for error in result.errors))

    def test_missing_skills_declaration(self):
        self.write_json(self.manifest, {"name": "hyeok-governance"})
        self.assert_error("skills must be")

    def test_local_marketplace_paths_cannot_escape_repo(self):
        for path in ("../outside", "/absolute", "C:\\outside", "https://example.com/plugin"):
            with self.subTest(path=path):
                self.write_json(self.marketplace, {"plugins": [{"source": {"source": "local", "path": path}}]})
                self.assertTrue(self.result().errors)

    def test_missing_local_plugin_manifest(self):
        self.manifest.unlink()
        self.assert_error("local plugin lacks .codex-plugin/plugin.json")

    def test_skill_paths_cannot_escape_plugin(self):
        self.write_json(self.manifest, {"skills": "../../some-other-skill"})
        self.assert_error("path escapes its package")

    def test_optional_hook_and_mcp_file_declarations(self):
        for field in ("hooks", "mcpServers", "mcp"):
            with self.subTest(field=field):
                self.write_json(self.manifest, {"skills": "skills", field: ["config.json"]})
                self.assert_error(f"{field} declaration is not a file")
                self.write_json(self.plugin / "config.json", {})
                self.assertEqual([], self.result().errors)
                (self.plugin / "config.json").unlink()

    def test_minimum_frontmatter_supports_folded_and_literal_descriptions(self):
        for description in ("Routing.", '"Routing # with a quote"', "|\n  Routing.", ">-\n  Routing."):
            with self.subTest(description=description):
                self.write(self.skill / "SKILL.md", f"---\nname: governance\ndescription: {description}\n---\n")
                self.assertEqual([], self.result().errors)
        for description in ("", "''", '"  "', "# a comment", "null", ">\n  "):
            with self.subTest(description=description):
                self.write(self.skill / "SKILL.md", f"---\nname: governance\ndescription: {description}\n---\n")
                self.assert_error("frontmatter description must be nonempty")
        self.write(self.skill / "SKILL.md", "---\nname: ''\ndescription: Routing.\n---\n")
        self.assert_error("frontmatter name must be nonempty")

    def test_missing_local_reference_is_detected(self):
        with (self.skill / "SKILL.md").open("a", encoding="utf-8") as stream:
            stream.write("Read [flow](references/missing.md#stage).\n")
        self.assert_error("missing standalone governance reference: references/missing.md")

    def test_inline_reference_and_encoded_markdown_destination(self):
        with (self.skill / "SKILL.md").open("a", encoding="utf-8") as stream:
            stream.write("Read `references/codex-flow.md#start` and [space](references/with%20space.md).\n")
        self.assert_error("references/codex-flow.md")
        self.write(self.skill / "references/codex-flow.md", "Read [models](model-routing.md).\n")
        self.write(self.skill / "references/with space.md", "Available.\n")
        self.assert_error("model-routing.md")
        self.write(self.skill / "references/model-routing.md", "Available.\n")
        self.assertEqual([], self.result().errors)

    def test_malformed_json_and_missing_frontmatter_are_errors(self):
        self.write(self.skill / "SKILL.md", "No frontmatter.\n")
        self.assert_error("missing YAML frontmatter")
        self.write(self.manifest, "{broken JSON}")
        self.assert_error("cannot read JSON")

    def test_all_present_governance_references_are_checked(self):
        for filename in ("codex-flow.md", "skill-and-mcp-setup.md", "organizer-rules.md",
                         "source-catalog.md", "requirements-trace.md", "future-reference.md"):
            with self.subTest(filename=filename):
                path = self.skill / "references" / filename
                self.write(path, "Read [details][flow].\n\n[flow]: missing.md\n")
                self.assert_error("missing standalone governance reference: missing.md")
                path.unlink()

    def test_new_reference_can_link_to_siblings_and_report_missing_documents(self):
        self.write(self.skill / "references/skill-and-mcp-setup.md",
                   "Read [sources](source-catalog.md).\n")
        self.write(self.skill / "references/source-catalog.md",
                   "Read [rules](organizer-rules.md) and the project's `AGENTS.md`.\n")
        self.assert_error("missing standalone governance reference: organizer-rules.md")
        self.write(self.skill / "references/organizer-rules.md", "[Entry](../SKILL.md)\n")
        self.assertEqual([], self.result().errors)

    def test_skill_only_copy_preserves_contained_links(self):
        with (self.skill / "SKILL.md").open("a", encoding="utf-8") as stream:
            stream.write("Read `references/codex-flow.md` and `GOVERNANCE.md`.\n")
        self.write(self.skill / "GOVERNANCE.md", "Standalone rules.\n")
        self.write(self.skill / "references/codex-flow.md", "[Routing](model-routing.md#models)\n")
        self.write(self.skill / "references/model-routing.md", "Independent words about available models.\n")
        destination = Path(self.temporary.name) / "isolated/governance"
        shutil.copytree(self.skill, destination)
        check = PACKAGING.PackagingCheck(self.repo)
        check.check_governance(destination)
        self.assertEqual([], check.errors)
        (destination / "GOVERNANCE.md").unlink()
        check.check_governance(destination)
        self.assertTrue(any("GOVERNANCE.md" in error for error in check.errors))

    def test_parent_reference_fails_even_when_repository_target_exists(self):
        self.write(self.plugin / "GOVERNANCE.md", "Rules outside skill.\n")
        with (self.skill / "SKILL.md").open("a", encoding="utf-8") as stream:
            stream.write("Read [rules](../../GOVERNANCE.md).\n")
        self.assert_error("path escapes its package")

    def test_upstream_docs_urls_fenced_examples_and_user_configs_are_not_scanned(self):
        with (self.skill / "SKILL.md").open("a", encoding="utf-8") as stream:
            stream.write("[Web](https://example.com/missing.md) [anchor](#local)\n"
                         "Use `~/.codex/config.toml` and the project's `README.md`.\n"
                         "```md\n[Example](references/missing.md)\n```\n")
        self.write(self.skill / "references/vendor/upstream.md", "[Missing](missing.md)\n")
        self.write(self.skill / "references/viz-catalog.md",
                   "Vendor skill paths: `type-process.md`, `catalog.md`, `references/import-drawio.md`.\n")
        upstream = self.plugin / "skills/vendor/SKILL.md"
        self.write(upstream, "---\nname: vendor\ndescription: Vendor.\n---\n[Missing](missing.md)\n")
        self.write(upstream.parent / "references/upstream.md", "[Missing](missing.md)\n")
        self.assertEqual([], self.result().errors)

    def test_cli_exit_status_and_summary(self):
        output = io.StringIO()
        with contextlib.redirect_stdout(output):
            self.assertEqual(0, PACKAGING.main(["--repo", str(self.repo)]))
        self.assertIn("PASS: 1 plugin manifests, 1 skills, 0 errors", output.getvalue())
        (self.skill / "SKILL.md").unlink()
        with contextlib.redirect_stdout(output):
            self.assertEqual(1, PACKAGING.main(["--repo", str(self.repo)]))


if __name__ == "__main__":
    unittest.main()
