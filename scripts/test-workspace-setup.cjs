/* node scripts/test-workspace-setup.cjs --sh /path/to/sh
 * No dependencies. All setup runs use disposable projects and fake HOME/CLI. */
'use strict';
const fs = require('node:fs');
const path = require('node:path');
const os = require('node:os');
const cp = require('node:child_process');
const assert = require('node:assert/strict');
const repo = path.resolve(__dirname, '..');
const arg = process.argv.indexOf('--sh');
const sh = arg < 0 ? 'sh' : process.argv[arg + 1];
const win = process.platform === 'win32';
const posix = p => win ? p.replaceAll('\\', '/').replace(/^([a-z]):/i, (_, d) => '/' + d.toLowerCase()) : p;
const temp = fs.mkdtempSync(path.join(os.tmpdir(), 'hyeok-workspace-test-'));
const fixture = path.join(temp, 'public clone');
const home = path.join(temp, 'fake home');
const workspace = path.join(temp, 'task project');
const bin = path.join(temp, 'bin');
const names = ['hyeok-governance', 'typst-korean', 'diagram-design', 'archify', 'lieflat-charts', 'juhyeoknizer'];
const write = (p, content) => { fs.mkdirSync(path.dirname(p), { recursive: true }); fs.writeFileSync(p, content); };
const read = p => fs.readFileSync(p, 'utf8');
const files = dir => !fs.existsSync(dir) ? [] : fs.readdirSync(dir, { withFileTypes: true }).flatMap(e => e.isDirectory() ? files(path.join(dir, e.name)) : [path.join(dir, e.name)]).sort();
const snapshot = dir => files(dir).map(f => [path.relative(dir, f), fs.readFileSync(f).toString('base64'), fs.statSync(f).mtimeMs]);
let runs = 0;
try {
  fs.mkdirSync(workspace, { recursive: true });
  write(path.join(fixture, 'scripts/setup-codex-workspace.sh'), fs.readFileSync(path.join(repo, 'scripts/setup-codex-workspace.sh')));
  for (const name of names) {
    const root = path.join(fixture, 'plugins', name, 'skills', name);
    write(path.join(root, 'SKILL.md'), `---\nname: ${name}\ndescription: fixture\n---\n`);
    write(path.join(root, 'references/deep/resource.md'), 'Resource content\n');
    write(path.join(root, '.hidden'), 'hidden\n');
    fs.mkdirSync(path.join(root, 'empty'), { recursive: true });
  }
  write(path.join(home, '.codex/config.toml'), 'model = "organizer"\n[mcp_servers.provided]\ncommand = "keep"\n');
  write(path.join(home, '.codex/auth.json'), '{"keep":true}\n');
  write(path.join(home, '.agents/skills/juhyeoknizer/SKILL.md'), 'global copy preserved\n');
  write(path.join(bin, 'codex'), '#!/bin/sh\n[ "$#" = 1 ] && [ "$1" = --version ] || exit 99\nprintf "codex organizer-version\\n"\n');
  fs.chmodSync(path.join(bin, 'codex'), 0o755);
  // Deliberately no Python, Node, package managers, or actual Codex in PATH.
  const env = { ...process.env, HOME: posix(home), USERPROFILE: home, CODEX_HOME: posix(path.join(home, '.codex')),
    PATH: [posix(bin), ...(win ? [posix(path.dirname(sh)), '/usr/bin', '/bin'] : ['/usr/bin', '/bin'])].join(':') };
  const script = posix(path.join(fixture, 'scripts/setup-codex-workspace.sh'));
  function run(args = [], cwd = workspace, ok = true, selectedScript = script) {
    runs++;
    // Git Bash starts native utilities much more slowly than a Linux shell.
    const timeout = win && selectedScript !== script ? 300000 : 90000;
    const r = cp.spawnSync(sh, [selectedScript, ...args], { cwd, env, encoding: 'utf8', timeout });
    assert(!r.error, String(r.error));
    if (ok) assert.equal(r.status, 0, r.stdout + r.stderr); else assert.notEqual(r.status, 0, r.stdout + r.stderr);
    return r.stdout + r.stderr;
  }
  const duplicateHome = snapshot(home);
  assert.match(run(['--check'], workspace, false), /Global duplicate/);
  assert.deepEqual(snapshot(home), duplicateHome);
  assert.deepEqual(fs.readdirSync(workspace), []);
  fs.unlinkSync(path.join(home, '.agents/skills/juhyeoknizer/SKILL.md'));
  const homeBefore = snapshot(home);
  assert.match(run(['--check']), /no files written/);
  assert.deepEqual(fs.readdirSync(workspace), []);
  const agents = path.join(workspace, 'AGENTS.md');
  const original = '# Organizer rules\r\nKeep these instructions.\r\n';
  write(agents, original);
  const skillEntry = path.join(workspace, '.agents/skills/archify/SKILL.md');
  write(skillEntry, 'foreign original\n');
  write(path.join(workspace, '.agents/skills/archify/personal.txt'), 'keep me\n');
  run();
  assert(read(agents).startsWith(original));
  assert.equal(read(agents).split('<!-- BEGIN hyeok-gov -->').length, 2);
  for (const name of names) {
    const source = path.join(fixture, 'plugins', name, 'skills', name);
    for (const f of files(source)) assert.deepEqual(fs.readFileSync(path.join(workspace, '.agents/skills', name, path.relative(source, f))), fs.readFileSync(f));
    assert(fs.statSync(path.join(workspace, '.agents/skills', name, 'empty')).isDirectory());
  }
  const backups = files(path.join(workspace, '.hyeok/backups'));
  assert(backups.some(f => read(f) === original));
  assert(backups.some(f => read(f) === 'foreign original\n'));
  assert.equal(read(path.join(workspace, '.hyeok/workspace-setup/owner')), 'hyeok-workspace-v1\n');
  const installed = snapshot(workspace);
  run(['--workspace', posix(workspace)], fixture);
  assert.deepEqual(snapshot(workspace), installed, 'second run must leave content and timestamps unchanged');
  run(['--check']);
  assert.deepEqual(snapshot(workspace), installed, 'check must not write state');
  const override = path.join(workspace, 'AGENTS.override.md');
  write(override, '# Override\n<!-- BEGIN hyeok-gov -->\nold text\n<!-- END hyeok-gov -->\nTail\n');
  const agentsBefore = read(agents);
  assert.match(run(), /takes precedence/);
  assert.equal(read(agents), agentsBefore);
  assert(read(override).startsWith('# Override\n'));
  assert(read(override).endsWith('Tail\n'));
  write(override, '<!-- BEGIN hyeok-gov -->\n');
  const malformed = snapshot(workspace);
  assert.match(run([], workspace, false), /Malformed/);
  assert.deepEqual(snapshot(workspace), malformed);
  fs.unlinkSync(override);
  assert.match(run(['--workspace', 'relative'], workspace, false), /Absolute/);
  assert.match(run(['--workspace', posix(home)], workspace, false), /global skill root|HOME/);
  assert.match(run(['--workspace', posix(path.join(fixture, 'plugins/archify/skills/archify'))], workspace, false), /overlap/);
  const linked = path.join(temp, 'workspace alias');
  fs.symlinkSync(workspace, linked, win ? 'junction' : 'dir');
  assert.match(run(['--workspace', posix(linked)], workspace, false), /Symlink/);
  const alias = path.join(temp, 'source alias');
  fs.symlinkSync(fixture, alias, win ? 'junction' : 'dir');
  assert.match(run([], workspace, false, posix(path.join(alias, 'scripts/setup-codex-workspace.sh'))), /Symlink/);
  const nested = path.join(fixture, 'plugins/archify/skills/archify/linked');
  fs.symlinkSync(path.join(fixture, 'plugins/typst-korean/skills/typst-korean'), nested, win ? 'junction' : 'dir');
  assert.match(run(['--check'], workspace, false), /Symlink/);
  fs.unlinkSync(nested);
  fs.renameSync(path.join(bin, 'codex'), path.join(bin, 'codex.disabled'));
  assert.match(run(['--check']), /absent from PATH/);
  assert.deepEqual(snapshot(home), homeBefore, 'home config/auth/skills must remain byte and timestamp identical');
  // Full production source copy, still isolated with a fake home and CLI.
  const realTarget = path.join(temp, 'actual resources');
  fs.mkdirSync(realTarget);
  run(['--workspace', posix(realTarget)], fixture, true, posix(path.join(repo, 'scripts/setup-codex-workspace.sh')));
  let count = 0;
  for (const name of names) {
    const source = path.join(repo, 'plugins', name, 'skills', name);
    for (const f of files(source)) {
      assert.deepEqual(fs.readFileSync(path.join(realTarget, '.agents/skills', name, path.relative(source, f))), fs.readFileSync(f));
      count++;
    }
  }
  console.log(`PASS: ${runs} isolated runs; ${count} real resource files; read-only check, default cwd, explicit workspace, override precedence, backups, idempotence, duplicate stop, symlink/overlap guards; no real HOME/CLI changes.`);
} catch (error) {
  // Report the actual assertion before cleanup, which may itself fail on Windows.
  console.error(error);
  process.exitCode = 1;
} finally {
  // Only the exact directory created by mkdtemp is eligible for cleanup.
  assert.equal(path.dirname(temp), os.tmpdir());
  assert(path.basename(temp).startsWith('hyeok-workspace-test-'));
  try {
    fs.rmSync(temp, { recursive: true, force: true, maxRetries: 5, retryDelay: 100 });
  } catch (error) {
    console.error(`Cleanup failed for test-owned directory ${temp}: ${error.message}`);
    process.exitCode = 1;
  }
}
