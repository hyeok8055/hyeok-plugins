#!/usr/bin/env node
// hyeok-governance — fail-open context injector for Claude Code.
//
// SessionStart  -> arg "full"    -> injects the whole GOVERNANCE.md once.
// UserPromptSubmit -> arg "oneline" -> injects a hard-capped one-line standing-order
//                                       reminder every turn (cheap; keeps rules in context).
//
// Contract: emits {hookSpecificOutput:{hookEventName, additionalContext}} on stdout.
// ALWAYS exits 0 and never throws — on ANY error it emits nothing so a broken hook can
// never block a turn (the user's zero-side-effects requirement).

const fs = require("fs");
const path = require("path");

const ONELINER =
  "[hyeok-governance] Standing orders: caveman ULTRA skins your conversation only " +
  "(terse). ponytail = minimal-but-not-negligent on executable/shippable code. " +
  "typst-korean = Typst docs on EXPLICIT request only (not default for generic PDF/장표/보고서). " +
  "insane-search = default tool for ANY web/data/research search, do not ask; cross-host " +
  "(auto on Claude/Grok, launcher+instruction on Codex) when present, else say so & use host search. " +
  "Substance > style. NEVER compress code blocks, files-on-disk, commit/PR text, security " +
  "analysis, document content, or mandated clarifying questions. No hard gates — comply by intent.";

function readEventName() {
  // Hook input arrives as JSON on stdin; pull hook_event_name if present.
  try {
    const raw = fs.readFileSync(0, "utf8");
    if (!raw) return null;
    const obj = JSON.parse(raw);
    return obj && obj.hook_event_name ? String(obj.hook_event_name) : null;
  } catch (e) {
    return null;
  }
}

function findGovernance() {
  const candidates = [
    process.env.CLAUDE_PLUGIN_ROOT
      ? path.join(process.env.CLAUDE_PLUGIN_ROOT, "GOVERNANCE.md")
      : null,
    path.join(__dirname, "..", "GOVERNANCE.md"),
  ].filter(Boolean);
  for (const p of candidates) {
    try {
      if (fs.statSync(p).isFile()) return fs.readFileSync(p, "utf8");
    } catch (e) {
      /* try next */
    }
  }
  return null;
}

function main() {
  const mode = process.argv[2] === "oneline" ? "oneline" : "full";
  const eventName =
    readEventName() ||
    (mode === "oneline" ? "UserPromptSubmit" : "SessionStart");

  let context = "";
  if (mode === "oneline") {
    context = ONELINER;
  } else {
    const doc = findGovernance();
    context = doc ? doc : ONELINER; // fall back to the one-liner if the file is missing
  }

  if (!context) return; // emit nothing rather than empty noise

  process.stdout.write(
    JSON.stringify({
      hookSpecificOutput: {
        hookEventName: eventName,
        additionalContext: context,
      },
    })
  );
}

try {
  main();
} catch (e) {
  // swallow — fail open
}
process.exit(0);
