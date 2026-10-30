#!/usr/bin/env python3
"""Read-only Korean prose checks. Python 3.9+, standard library only.

This is a style linter, not an AI detector or a factual/semantic verifier.
Use --source with the same passage before revision, not an entire evidence dump.
"""

import argparse
from dataclasses import asdict, dataclass
import json
from pathlib import Path
import re
import sys


DOTS = frozenset("\u00b7\u0387\u2022\u2027\u2219\u22c5\u30fb\u318d\uff65")
QUOTE_RE = re.compile(r'"[^"\n]+"|“[^”\n]+”|「[^」\n]+」|『[^』\n]+』')
INLINE_CODE_RE = re.compile(r"(?<!`)(`+)(?!`)([^\n]*?)(?<!`)\1(?!`)")
URL_RE = re.compile(r"https?://[^\s<>\"`]+", re.IGNORECASE)
LINK_DEST_RE = re.compile(r"\]\([ \t]*(<[^>\n]+>|[^\s)]+)")
FENCE_RE = re.compile(r"^[ \t]{0,3}(`{3,}|~{3,})([^\r\n]*)")
BLOCK_QUOTE_RE = re.compile(r"(?m)^[ \t]{0,3}>[ \t]?(.*)$")
VAGUE_RE = re.compile(
    r"(?:크게|획기적으로|대폭|비약적으로|상당히)\s*(?:개선|향상|단축|절감|증가|높|줄|증대)"
    r"|(?:성능|효율|생산성|사용자\s*만족도|고객\s*경험)(?:을|를|이|가)?\s*"
    r"(?:크게\s*)?(?:개선|향상|제고|최적화)"
    r"|시너지(?:를)?\s*창출|유기적으로\s*협업|성공적으로\s*수행"
)
PLACEHOLDER_RE = re.compile(
    r"\b(?:TODO|TBD|FIXME)\b"
    r"|\[(?:확인\s*필요|미확인|수치\s*미확인|기관명|조사명|연도|수치|출처|성과|목표|0{2,})\]"
    r"|(?<![A-Za-z])(?:XX|OO|N)\s*(?:%|건|명|회|배)(?![A-Za-z])"
    r"|<\s*(?:수치|기관명|연도|출처|성과)\s*>", re.IGNORECASE
)
YEAR_RE = re.compile(r"(?<![A-Za-z_0-9])(?:(?P<full>(?:19|20)\d{2})\s*년|[’'](?P<short>\d{2})(?:\s*년)?)(?!\d)")
NUMBER_RE = re.compile(
    r"(?<![A-Za-z_0-9.])[+-]?\d+(?:,\d{3})*(?:\.\d+)?"
    r"(?:[ \t]*(?:퍼센트포인트|%p|%|개월|시간|만원|억원|건|명|회|개|배|초|분|일|주|년|원|ms|MB|GB))?",
    re.IGNORECASE,
)
LIST_NUMBER_RE = re.compile(r"(?m)^[ \t]*(?:(?:#{1,6}|[□◦ㅁ-])[ \t]*)?(?:\[\d+\]|\d+[.)])(?=\s)")


@dataclass(frozen=True)
class Span:
    start: int
    end: int
    kind: str
    literal: str


@dataclass(frozen=True)
class Finding:
    code: str
    severity: str
    line: int
    column: int
    message: str


def masked(text, spans):
    """Keep offsets/newlines stable; never modify the caller's string or file."""
    chars = list(text)
    for span in spans:
        for index in range(span.start, span.end):
            if chars[index] not in "\r\n":
                chars[index] = " "
    return "".join(chars)


def position(text, offset):
    return text.count("\n", 0, offset) + 1, offset - text.rfind("\n", 0, offset)


def finding(text, offset, code, severity, message):
    line, column = position(text, offset)
    return Finding(code, severity, line, column, message)


def fence_spans(text):
    spans = []
    opened = None
    offset = 0
    for line in text.splitlines(keepends=True):
        match = FENCE_RE.match(line)
        if match:
            marker = match[1]
            if opened is None:
                opened = (offset, offset + len(line), marker)
            elif (marker[0] == opened[2][0] and len(marker) >= len(opened[2])
                  and not match[2].strip()):
                content = text[opened[1]:offset].rstrip("\r\n")
                spans.append(Span(opened[0], offset + len(line), "fenced-code", content))
                opened = None
        offset += len(line)
    if opened is not None:
        spans.append(Span(opened[0], len(text), "fenced-code", text[opened[1]:].rstrip("\r\n")))
    return spans


def trim_url(raw):
    # Sentence punctuation and Markdown's closing delimiters are not the URL.
    value = raw.rstrip(".,;!?:")
    for opening, closing in (("(", ")"), ("[", "]")):
        while value.endswith(closing) and value.count(closing) > value.count(opening):
            value = value[:-1]
    return value


def protected_spans(text, source=None, protected_literals=()):
    spans = fence_spans(text)
    for match in BLOCK_QUOTE_RE.finditer(masked(text, spans)):
        spans.append(Span(match.start(), match.end(), "block-quote", text[match.start(1):match.end(1)]))
    for match in INLINE_CODE_RE.finditer(masked(text, spans)):
        spans.append(Span(match.start(), match.end(), "inline-code", text[match.start(2):match.end(2)]))
    for match in URL_RE.finditer(masked(text, spans)):
        literal = trim_url(text[match.start():match.end()])
        spans.append(Span(match.start(), match.start() + len(literal), "url", literal))
    # Protect a local Markdown destination without hiding its authored label.
    for match in LINK_DEST_RE.finditer(masked(text, spans)):
        spans.append(Span(match.start(1), match.end(1), "link-destination", text[match.start(1):match.end(1)].strip("<>")))
    if source is not None:
        for match in QUOTE_RE.finditer(masked(text, spans)):
            literal = text[match.start():match.end()]
            if literal in source:
                spans.append(Span(match.start(), match.end(), "source-quote", literal))
    for literal in protected_literals:
        if not literal:
            continue
        start = 0
        while True:
            start = text.find(literal, start)
            if start < 0:
                break
            spans.append(Span(start, start + len(literal), "explicit-literal", literal))
            start += len(literal)
    return sorted(spans, key=lambda span: (span.start, span.end, span.kind))


def numeric_tokens(text, spans):
    prose = masked(text, spans)
    prefixes = [Span(m.start(), m.end(), "list-prefix", "") for m in LIST_NUMBER_RE.finditer(prose)]
    prose = masked(prose, prefixes)
    numbers = {}
    years = []
    for match in YEAR_RE.finditer(prose):
        year = match["full"] or "20" + match["short"]
        numbers.setdefault("year:" + year, match.start())
        years.append(Span(match.start(), match.end(), "year", ""))
    for match in NUMBER_RE.finditer(masked(prose, years)):
        token = re.sub(r"[ \t,]", "", match[0]).lower()
        numbers.setdefault(token, match.start())
    return numbers


def plain_markdown_findings(text, spans):
    # Keep code markup visible to the format check while preserving its content
    # from the separate punctuation/style checks.
    format_spans = [span for span in spans if span.kind not in {"fenced-code", "inline-code"}]
    surface = masked(text, format_spans)
    matches = []
    for span in spans:
        if span.kind in {"fenced-code", "inline-code"}:
            matches.append((span.start, span.end))
    patterns = (
        r"(?m)^[ \t]{0,3}#{1,6}[ \t]+\S[^\n]*",
        r"\*\*\S[^\n]*?\*\*|__\S[^\n]*?__|~~\S[^\n]*?~~",
        r"(?<![\w*])\*[^*\s][^*\n]*\*(?![\w*])|(?<![\w_])_[^_\s][^_\n]*_(?![\w_])",
        r"!?\[[^\]\n]*\]\([^\n]*?\)",
        r"(?m)^[ \t]*\|[^\n]+\|[ \t]*$",
        r"(?<!\\)(?:\*{2,}|~{2,}|`+)|(?<![\w\\])_{2,}|_{2,}(?!\w)",
    )
    for pattern in patterns:
        for match in re.finditer(pattern, surface):
            if not any(start <= match.start() < end for start, end in matches):
                matches.append((match.start(), match.end()))
    return [finding(text, start, "markdown-residue", "error",
                    "일반 텍스트 대상에 Markdown 문법이 남아 있음. 렌더링할 표현을 직접 확인할 것.")
            for start, _ in sorted(set(matches))]


def check_text(text, target="markdown", source=None, protected_literals=()):
    """Return stable diagnostics; leave all input bytes and facts untouched."""
    if target not in {"plain", "markdown"}:
        raise ValueError("target must be plain or markdown")
    spans = protected_spans(text, source, protected_literals)
    prose = masked(text, spans)
    findings = []
    for offset, char in enumerate(text):
        if char not in DOTS:
            continue
        codepoint = f"U+{ord(char):04X}"
        if prose[offset] == char:
            findings.append(finding(text, offset, "middle-dot", "error",
                                    f"{codepoint}: 새로 쓴 문장의 점 기호. 쉼표/슬래시/문장 분리를 검토할 것."))
        else:
            kind = next(span.kind for span in spans if span.start <= offset < span.end)
            findings.append(finding(text, offset, "preserved-punctuation", "info",
                                    f"{codepoint}: {kind} 원문 보존 예외. 보존 이유를 설명할 것."))
    if target == "plain":
        findings.extend(plain_markdown_findings(text, spans))
    for match in VAGUE_RE.finditer(prose):
        findings.append(finding(text, match.start(), "vague-claim", "warning",
                                "추상적인 성과/협업 표현. 실제 행동과 근거가 드러나는지 확인할 것. 수치를 만들지 말 것."))
    for match in PLACEHOLDER_RE.finditer(prose):
        findings.append(finding(text, match.start(), "unresolved-placeholder", "warning",
                                "미확인 자리표시자가 남아 있음. 제출본의 근거/완료 여부를 확인할 것."))
    if source is not None:
        source_spans = protected_spans(source, source, protected_literals)
        before = numeric_tokens(source, source_spans)
        after = numeric_tokens(text, spans)
        for token in sorted(after.keys() - before.keys()):
            findings.append(finding(text, after[token], "number-added", "warning",
                                    f"원문에 없는 수치/단위 {token!r}. 별도 근거 또는 표기 변환인지 확인할 것."))
        for token in sorted(before.keys() - after.keys()):
            findings.append(finding(text, 0, "number-removed", "warning",
                                    f"원문 수치/단위 {token!r}가 결과에 보이지 않음. 요약 범위를 확인할 것."))
        seen = set()
        for span in source_spans:
            if span.literal and span.literal not in seen and span.literal not in text:
                seen.add(span.literal)
                line, column = position(source, span.start)
                findings.append(finding(text, 0, "protected-literal-changed", "warning",
                                        f"원문 {line}:{column}의 {span.kind} 누락/변경. 원문을 대조할 것."))
    for literal in protected_literals:
        if literal and literal not in text:
            findings.append(finding(text, 0, "protected-literal-missing", "warning",
                                    "명시한 보호 문자열이 결과에 없음. 식별자/명칭의 보존 여부를 확인할 것."))
    return sorted(findings, key=lambda item: (item.line, item.column, item.code, item.message))


def exit_code(findings, strict=False):
    return int(any(item.severity == "error" or strict and item.severity == "warning" for item in findings))


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("input", help="UTF-8 text file, or - for stdin")
    parser.add_argument("--target", choices=("markdown", "plain"), default="markdown")
    parser.add_argument("--source", type=Path, help="original passage for optional review warnings")
    parser.add_argument("--protect-literal", action="append", default=[], help="exact literal to preserve (repeatable)")
    parser.add_argument("--format", choices=("text", "json"), default="text")
    parser.add_argument("--strict", action="store_true", help="treat warnings as exit 1 as well")
    args = parser.parse_args(argv)
    if any(not literal for literal in args.protect_literal):
        parser.error("--protect-literal must be nonempty")
    try:
        text = sys.stdin.read() if args.input == "-" else Path(args.input).read_text(encoding="utf-8-sig")
        source = args.source.read_text(encoding="utf-8-sig") if args.source is not None else None
    except (OSError, UnicodeError) as exc:
        print(f"Cannot read UTF-8 input: {exc}", file=sys.stderr)
        return 2
    findings = check_text(text, args.target, source, args.protect_literal)
    summary = {severity: sum(item.severity == severity for item in findings)
               for severity in ("error", "warning", "info")}
    if args.format == "json":
        print(json.dumps({"path": args.input, "target": args.target,
                          "findings": [asdict(item) for item in findings], "summary": summary},
                         ensure_ascii=False, indent=2))
    else:
        for item in findings:
            print(f"{args.input}:{item.line}:{item.column}: {item.severity} {item.code}: {item.message}")
        print(" ".join(f"{key}={value}" for key, value in summary.items()))
    return exit_code(findings, args.strict)


if __name__ == "__main__":
    for stream in (sys.stdin, sys.stdout, sys.stderr):
        if hasattr(stream, "reconfigure"):
            stream.reconfigure(encoding="utf-8")
    raise SystemExit(main())
