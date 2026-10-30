"""Focused stdlib tests for juhyeoknizer's read-only linter and fixtures.

Run: python -B -m unittest discover -s scripts -p test_juhyeoknizer.py
These test observable diagnostics and preservation, not AI detection or taste.
"""

import importlib.util
import json
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest


REPO = Path(__file__).resolve().parent.parent
SKILL = REPO / "plugins/juhyeoknizer/skills/juhyeoknizer"
SCRIPT = SKILL / "scripts/check_prose.py"
SPEC = importlib.util.spec_from_file_location("juhyeoknizer_check_prose", SCRIPT)
checker = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = checker
SPEC.loader.exec_module(checker)


def codes(findings, severity=None):
    return {item.code for item in findings if severity is None or item.severity == severity}


class ProseTests(unittest.TestCase):
    def test_each_prohibited_dot_and_lookalike(self):
        for char in sorted(checker.DOTS):
            with self.subTest(codepoint=f"U+{ord(char):04X}"):
                findings = checker.check_text("기획" + char + "개발")
                self.assertEqual(codes(findings, "error"), {"middle-dot"})

    def test_user_allowed_report_symbols(self):
        text = "Ⅰ. 배경\n□ 현황 확인\n◦ 자료 정리 필요\n- 처리 기준을 정의한다.\n  * 내부 자료 기준\n  ㄴ 담당 범위 확인\n[데이터 처리]"
        self.assertEqual(checker.check_text(text, "plain"), [])

    def test_precise_unicode_location_with_crlf(self):
        finding = checker.check_text("첫 줄\r\n둘째\u00b7문장")[0]
        self.assertEqual((finding.line, finding.column), (2, 3))

    def test_url_punctuation_is_preserved_and_explained(self):
        text = "참고 https://example.org/a\u00b7b?q=30%25"
        findings = checker.check_text(text)
        self.assertEqual(codes(findings), {"preserved-punctuation"})
        self.assertEqual(checker.exit_code(findings, strict=True), 0)

    def test_link_label_is_authored_but_destination_is_protected(self):
        findings = checker.check_text("[설계\u00b7개발](https://example.org/a\u00b7b)")
        self.assertEqual(sum(item.code == "middle-dot" for item in findings), 1)
        self.assertEqual(sum(item.code == "preserved-punctuation" for item in findings), 1)

    def test_local_link_destination_is_also_preserved(self):
        findings = checker.check_text("[원본](./자료\u00b7코드.txt)")
        self.assertEqual(codes(findings), {"preserved-punctuation"})

    def test_fences_and_variable_length_inline_code(self):
        text = "````python\nexpr = 'a\u22c5b'\n```\n````\n문장 ``value`a\u00b7b`` 보존"
        findings = checker.check_text(text)
        self.assertEqual(codes(findings), {"preserved-punctuation"})
        self.assertEqual(len(findings), 2)

    def test_tilde_fences_are_protected(self):
        findings = checker.check_text("~~~text\n원문\u00b7코드\n~~~")
        self.assertEqual(codes(findings), {"preserved-punctuation"})

    def test_quote_without_matching_source_is_not_a_bypass(self):
        findings = checker.check_text("“기획\u00b7개발”을 담당했다.")
        self.assertEqual(codes(findings, "error"), {"middle-dot"})

    def test_exact_source_quote_is_preserved(self):
        source = "직접 인용: “기획\u00b7개발”"
        findings = checker.check_text("인용문 “기획\u00b7개발”", source=source)
        self.assertEqual(codes(findings), {"preserved-punctuation"})

    def test_changed_quote_is_flagged_for_review(self):
        findings = checker.check_text("“운영\u00b7개발”", source="“기획\u00b7개발”")
        self.assertIn("middle-dot", codes(findings, "error"))
        self.assertIn("protected-literal-changed", codes(findings, "warning"))

    def test_block_quote_preserves_original(self):
        findings = checker.check_text("> 원문 기획\u00b7개발\n새 문장은 간단히 쓴다.")
        self.assertEqual(codes(findings), {"preserved-punctuation"})

    def test_explicit_identifier_is_protected_but_nearby_prose_is_checked(self):
        findings = checker.check_text("공식명 A\u00b7B / 기획\u00b7개발", protected_literals=["A\u00b7B"])
        self.assertEqual(codes(findings), {"preserved-punctuation", "middle-dot"})

    def test_missing_explicit_identifier_is_warning(self):
        findings = checker.check_text("문서", protected_literals=["load_events_v2"])
        self.assertEqual(codes(findings, "warning"), {"protected-literal-missing"})

    def test_plain_target_detects_markdown_residue(self):
        cases = ("**주문 API**", "_요약_", "~~초안~~", "`load_events_v2`", "# 경력",
                 "[자료](https://example.org)", "|항목|값|", "```text\n문장\n```", "__업무__")
        for text in cases:
            with self.subTest(text=text):
                self.assertIn("markdown-residue", codes(checker.check_text(text, "plain"), "error"))

    def test_markdown_target_accepts_intentional_formatting(self):
        self.assertEqual(checker.check_text("## 배경\n**자료 정리**\n[처리 과정]"), [])

    def test_plain_target_detects_orphaned_markup(self):
        for text in ("성과 **", "**작업 내용", "호출 `load_events_v2", "~~초안", "__요약"):
            with self.subTest(text=text):
                self.assertIn("markdown-residue", codes(checker.check_text(text, "plain"), "error"))

    def test_plain_double_underscore_identifier_is_not_emphasis(self):
        self.assertEqual(checker.check_text("load__events 호출", "plain"), [])

    def test_plain_target_retains_report_support_and_process_labels(self):
        self.assertEqual(checker.check_text("[데이터 처리]\n  * 내부 집계\n  ㄴ 검증 전 가정\nload_events_v2 호출", "plain"), [])

    def test_vague_claims_are_advisory_not_ai_detection(self):
        findings = checker.check_text("성능을 크게 개선하며 유기적으로 협업했다.")
        self.assertEqual(codes(findings, "error"), set())
        self.assertEqual(codes(findings, "warning"), {"vague-claim"})
        self.assertEqual(checker.exit_code(findings), 0)
        self.assertEqual(checker.exit_code(findings, strict=True), 1)

    def test_unresolved_placeholders_warn_without_fabricating_evidence(self):
        findings = checker.check_text("[확인 필요] 성과 XX% / [기관명] [수치] TBD")
        self.assertEqual(codes(findings), {"unresolved-placeholder"})
        self.assertGreaterEqual(len(findings), 4)

    def test_concrete_action_without_number_is_valid(self):
        self.assertEqual(checker.check_text("중복 요청을 확인하는 테스트를 작성했다. 배포는 맡지 않았다."), [])

    def test_new_numeric_achievement_is_review_warning(self):
        findings = checker.check_text("처리 시간 50% 단축", source="처리 시간 개선 작업")
        self.assertIn("number-added", codes(findings, "warning"))
        self.assertEqual(codes(findings, "error"), set())

    def test_changed_measurement_unit_is_review_warning(self):
        findings = checker.check_text("자료 20건 확인", source="자료 20% 확인")
        self.assertEqual(codes(findings, "warning"), {"number-added", "number-removed"})

    def test_equivalent_year_and_thousands_separator_with_new_list_number(self):
        findings = checker.check_text("1. ’26 자료 1200건\n[2] 전처리", source="2026년 자료 1,200건")
        self.assertEqual(findings, [])

    def test_code_and_url_numbers_do_not_create_achievement_drift(self):
        source = "`load_events_v2` / https://example.org/v3?a=15 / 자료 10건"
        output = "자료 10건: `load_events_v2` / https://example.org/v3?a=15"
        self.assertEqual(checker.check_text(output, source=source), [])

    def test_changed_url_and_code_are_flagged_without_auto_repair(self):
        source = "`load_events_v2` / https://example.org/v3?a=15"
        output = "`load_events_v3` / https://example.org/v3?a=16"
        findings = checker.check_text(output, source=source)
        self.assertEqual(codes(findings, "warning"), {"protected-literal-changed"})
        self.assertEqual(len(findings), 2)
        self.assertIn("load_events_v3", output)

    def test_three_synthetic_fixtures_preserve_evidence(self):
        data = json.loads((SKILL / "references/examples.json").read_text(encoding="utf-8"))
        self.assertIn("가상", data["notice"])
        self.assertEqual(len(data["examples"]), 3)
        for case in data["examples"]:
            with self.subTest(example=case["id"]):
                self.assertTrue(case["annotation"])
                self.assertIn("가상 예시", case["output"])
                for literal in case["preserve"]:
                    self.assertIn(literal, case["output"])
                findings = checker.check_text(case["output"], case["target"], case["input"])
                self.assertEqual([item for item in findings if item.severity != "info"], [])
                self.assertEqual(codes(findings, "info"), set(case["expected_info_codes"]))


class CliTests(unittest.TestCase):
    def run_cli(self, *args, script=SCRIPT, stdin=None, cwd=None):
        return subprocess.run([sys.executable, "-B", "-X", "utf8", str(script), *map(str, args)],
                              input=stdin, text=True, encoding="utf-8", capture_output=True, cwd=cwd)

    def test_stdin_json_reports_error_and_location(self):
        result = self.run_cli("-", "--format", "json", stdin="기획\u00b7개발")
        self.assertEqual(result.returncode, 1, result.stderr)
        report = json.loads(result.stdout)
        self.assertEqual(report["summary"]["error"], 1)
        self.assertEqual(report["findings"][0]["column"], 3)

    def test_cli_never_rewrites_input_or_source_files(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            original = root / "original.txt"
            revised = root / "revised.txt"
            original.write_text("원본 20건 / `load_events_v2`", encoding="utf-8")
            revised.write_text("기획\u00b7개발 50% / `load_events_v3`", encoding="utf-8")
            before = {p.name: p.read_bytes() for p in root.iterdir()}
            result = self.run_cli(revised, "--source", original, "--format", "json", cwd=root)
            self.assertEqual(result.returncode, 1, result.stderr)
            self.assertIn("protected-literal-changed", {f["code"] for f in json.loads(result.stdout)["findings"]})
            self.assertEqual(before, {p.name: p.read_bytes() for p in root.iterdir()})

    def test_warning_exit_code_can_be_strict(self):
        normal = self.run_cli("-", stdin="유기적으로 협업")
        strict = self.run_cli("-", "--strict", stdin="유기적으로 협업")
        self.assertEqual(normal.returncode, 0, normal.stderr)
        self.assertEqual(strict.returncode, 1, strict.stderr)

    def test_missing_file_has_exit_two(self):
        with tempfile.TemporaryDirectory() as directory:
            result = self.run_cli(Path(directory) / "missing.txt")
            self.assertEqual(result.returncode, 2)
            self.assertIn("Cannot read", result.stderr)

    def test_isolated_skill_copy_has_no_repository_runtime_dependency(self):
        with tempfile.TemporaryDirectory() as directory:
            copied = Path(directory) / "juhyeoknizer"
            shutil.copytree(SKILL, copied)
            result = self.run_cli("-", "--target", "plain", script=copied / "scripts/check_prose.py",
                                  stdin="담당한 작업과 검증 결과를 기록한다.", cwd=directory)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertIn("error=0", result.stdout)


if __name__ == "__main__":
    unittest.main()
