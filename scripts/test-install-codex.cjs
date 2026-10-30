/* No dependencies. All installer executions target temporary homes and mocked
 * host CLIs. Usage: node scripts/test-install-codex.cjs [--powershell PATH]
 * [--sh PATH]. Defaults: powershell.exe on Windows, sh elsewhere. */
'use strict';
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const cp = require('node:child_process');
const repo = path.resolve(__dirname, '..');
const win = process.platform === 'win32';
const switches = process.argv.slice(2);
function option(name) { const i = switches.indexOf(name); return i < 0 ? null : switches[i + 1]; }
const engines = [];
if ((!option('--only') || option('--only') === 'ps') && (win || option('--powershell'))) engines.push({ kind: 'ps', exe: option('--powershell') || 'powershell.exe' });
if ((!option('--only') || option('--only') === 'sh') && (!win || option('--sh'))) engines.push({ kind: 'sh', exe: option('--sh') || 'sh' });
assert(engines.length, 'No test engine selected');
const scratch = fs.mkdtempSync(path.join(os.tmpdir(), 'hyeok-install-tests-'));
function shellPath(p) { return win ? p.replaceAll('\\', '/').replace(/^([A-Za-z]):/, (_, drive) => '/' + drive.toLowerCase()) : p; }
function write(file, data) { fs.mkdirSync(path.dirname(file), { recursive: true }); fs.writeFileSync(file, data); }
function read(file) { return fs.readFileSync(file, 'utf8'); }
function canonical(file) { const resolved = path.resolve(file); return win ? resolved.toLowerCase() : resolved; }
function files(root) {
  if (!fs.existsSync(root)) return [];
  return fs.readdirSync(root, { withFileTypes: true }).flatMap(item => {
    const p = path.join(root, item.name);
    return item.isDirectory() ? files(p) : [p];
  }).sort();
}
const defaults = ['hyeok-governance', 'typst-korean', 'diagram-design', 'archify', 'lieflat-charts', 'juhyeoknizer'];
const begin = '<!-- BEGIN hyeok-gov -->', end = '<!-- END hyeok-gov -->';
const config = 'model = "keep-my-model"\nmodel_provider = "keep-provider"\napproval_policy = "on-request"\n[mcp_servers.mine]\nurl = "https://example.invalid/mcp"\n';
let runs = 0;
try {
  for (const engine of engines) {
    const base = path.join(scratch, engine.kind);
    const fixture = path.join(base, 'repo');
    fs.mkdirSync(fixture, { recursive: true });
    for (const file of ['install.ps1', 'install.sh', 'uninstall.ps1', 'uninstall.sh']) {
      fs.copyFileSync(path.join(repo, file), path.join(fixture, file));
    }
    for (const name of defaults) {
      const source = path.join(fixture, 'plugins', name, 'skills', name);
      if (name === 'hyeok-governance') {
        fs.cpSync(path.join(repo, 'plugins', name, 'skills', name), source, { recursive: true });
      } else {
        write(path.join(source, 'SKILL.md'), `---\nname: ${name}\ndescription: Installer fixture.\n---\nRead references/probe.md.\n`);
      }
      write(path.join(source, 'references', 'probe.md'), `resource for ${name}\n`);
      write(path.join(source, '.hidden-resource'), 'hidden\n');
      fs.mkdirSync(path.join(source, 'empty'), { recursive: true });
    }
    write(path.join(fixture, 'plugins', 'hyeok-governance', 'GOVERNANCE.md'), 'DO NOT SYNTHESIZE THE INSTALLED SKILL FROM THIS FILE\n');
    const bin = path.join(base, 'bin');
    const log = path.join(base, 'cli.jsonl');
    const stub = path.join(bin, 'stub.cjs');
    write(stub, `const fs=require('fs'),p=require('path');
const args=process.argv.slice(2), raw=process.env.CODEX_HOME;
const home=process.platform==='win32'?raw.replace(/^\\/([a-z])\\//i,(_,d)=>d+':/'):raw;
fs.appendFileSync(process.env.HYEOK_CLI_LOG,JSON.stringify({args,home})+'\\n');
if(args.includes('--help'))process.exit(process.env.HYEOK_UNSUPPORTED==='1'?2:0);
if(args[0]!=='plugin'||!['add','remove','marketplace'].includes(args[1]))process.exit(9);
fs.mkdirSync(home,{recursive:true});fs.appendFileSync(p.join(home,'config.toml'),'# mock plugin change\\n');
process.stdout.write('{}\\n');\n`);
    if (win) write(path.join(bin, 'codex.cmd'), `@"${process.execPath}" "${stub}" %*\r\n`);
    const quote = value => "'" + value.replaceAll("'", "'\\''") + "'";
    write(path.join(bin, 'codex'), `#!/bin/sh\nexec ${quote(shellPath(process.execPath))} ${quote(shellPath(stub))} "$@"\n`);
    fs.chmodSync(path.join(bin, 'codex'), 0o755);
    for (const host of ['claude', 'grok']) {
      write(path.join(bin, host), '#!/bin/sh\nexit 77\n');
      fs.chmodSync(path.join(bin, host), 0o755);
      if (win) write(path.join(bin, host + '.cmd'), '@exit /b 77\r\n');
    }
    function fresh(label) {
      const home = path.join(base, label + ' home [safe]');
      fs.mkdirSync(home, { recursive: true });
      return home;
    }
    function run(home, { uninstall = false, mode, flags = [], fail = false, noTarget = false, unsupported = false } = {}) {
      const script = path.join(fixture, (uninstall ? 'uninstall' : 'install') + (engine.kind === 'ps' ? '.ps1' : '.sh'));
      const extras = mode ? [engine.kind === 'ps' ? '-Mode' : '--mode', mode] : [];
      const isolation = noTarget ? [] : [engine.kind === 'ps' ? '-TargetHome' : '--target-home', engine.kind === 'ps' ? home : shellPath(home)];
      const args = engine.kind === 'ps'
        ? ['-NoProfile', '-NonInteractive', '-ExecutionPolicy', 'Bypass', '-File', script, ...isolation, ...extras, ...flags]
        : [shellPath(script), ...isolation, ...extras, ...flags];
      const profile = noTarget ? path.join(home, 'custom-profile') : path.join(base, 'do-not-touch-profile');
      const env = { ...process.env, USERPROFILE: home, HOME: engine.kind === 'sh' ? shellPath(home) : home,
        CODEX_HOME: engine.kind === 'sh' ? shellPath(profile) : profile,
        XDG_CONFIG_HOME: path.join(home, '.config'), APPDATA: path.join(home, 'AppData'),
        HYEOK_CLI_LOG: log, HYEOK_UNSUPPORTED: unsupported ? '1' : '0',
        PATH: engine.kind === 'sh'
          ? [shellPath(bin), shellPath(path.dirname(engine.exe)), '/usr/bin', '/bin', ...process.env.PATH.split(path.delimiter).map(shellPath)].join(':')
          : bin + path.delimiter + process.env.PATH };
      const result = cp.spawnSync(engine.exe, args, { cwd: fixture, env, encoding: 'utf8', timeout: 120000, windowsHide: true });
      runs++;
      assert.ifError(result.error);
      const output = result.stdout + result.stderr;
      if (fail) assert.notEqual(result.status, 0, 'Expected refusal: ' + output);
      else assert.equal(result.status, 0, output);
      assert(!fs.existsSync(path.join(base, 'do-not-touch-profile')), 'Explicit target leaked into external CODEX_HOME');
      return output;
    }
    function calls() { return fs.existsSync(log) ? read(log).trim().split('\n').filter(Boolean).map(JSON.parse) : []; }
    const home = fresh('standalone');
    const gov = path.join(home, '.agents', 'skills', 'hyeok-governance');
    const foreignEntry = '---\nname: foreign-governance\ndescription: Original user skill.\n---\nKeep me.\n';
    write(path.join(gov, 'SKILL.md'), foreignEntry);
    write(path.join(gov, 'keep.txt'), 'user addition\n');
    const originalAgents = `foreign before\r\n${begin}\r\nlarge legacy governance\r\n${end}\r\nforeign after\r\n`;
    const agents = path.join(home, '.codex', 'AGENTS.override.md');
    write(agents, originalAgents);
    write(path.join(home, '.codex', 'AGENTS.md'), 'inactive instructions\n');
    write(path.join(home, '.codex', 'config.toml'), config);
    write(path.join(home, '.claude', 'settings.json'), '{"foreign":true}\n');
    write(path.join(home, '.grok', 'config.toml'), 'foreign = true\n');
    const personalMarketplace = path.join(home, '.agents', 'plugins', 'marketplace.json');
    write(personalMarketplace, Buffer.from('\ufeff{"foreign":true}\n'));
    run(home);
    assert.equal(calls().length, 0, 'Standalone mode called a CLI');
    assert.equal(read(path.join(home, '.codex', 'config.toml')), config);
    assert.equal(read(path.join(home, '.codex', 'AGENTS.md')), 'inactive instructions\n');
    assert.equal(read(path.join(home, '.claude', 'settings.json')), '{"foreign":true}\n');
    assert.equal(read(path.join(home, '.grok', 'config.toml')), 'foreign = true\n');
    assert.equal(read(personalMarketplace), '\ufeff{"foreign":true}\n');
    assert.equal(read(path.join(gov, 'keep.txt')), 'user addition\n');
    assert(!fs.existsSync(path.join(home, '.codex', 'skills')));
    for (const name of ['humanize-korean', 'humanize', 'humanize-redo']) assert(!fs.existsSync(path.join(home, '.agents', 'skills', name)));
    for (const name of defaults) {
      const source = path.join(fixture, 'plugins', name, 'skills', name);
      for (const file of files(source)) assert.deepEqual(fs.readFileSync(path.join(home, '.agents', 'skills', name, path.relative(source, file))), fs.readFileSync(file));
      assert(fs.statSync(path.join(home, '.agents', 'skills', name, 'empty')).isDirectory());
    }
    assert.equal((read(agents).match(/<!-- BEGIN hyeok-gov -->/g) || []).length, 1);
    assert(read(agents).includes('foreign before\r\n') && read(agents).endsWith('foreign after\r\n'));
    assert(read(agents).includes('hyeok-governance/SKILL.md') && read(agents).length < 1500);
    assert(!read(agents).includes('large legacy governance'));
    const backups = path.join(home, '.hyeok', 'backups');
    assert(files(backups).some(file => read(file) === originalAgents));
    assert(files(backups).some(file => read(file) === foreignEntry));
    assert(!fs.readdirSync(path.join(home, '.agents', 'skills')).some(name => name.endsWith('.bak')));
    const before = files(home).map(file => [file, fs.readFileSync(file), fs.statSync(file).mtimeMs]);
    run(home, { flags: engine.kind === 'ps' ? ['-SkipCliPlugins', '-SkipFonts', '-PonytailMode', 'full'] : ['--skip-cli-plugins', '--skip-fonts', '--ponytail-mode', 'full'] });
    for (const [file, content, mtime] of before) { assert.deepEqual(fs.readFileSync(file), content); assert.equal(fs.statSync(file).mtimeMs, mtime, 'Not idempotent: ' + file); }
    assert.equal(files(home).length, before.length);
    run(home, { mode: 'plugins', fail: true });
    assert.equal(calls().length, 0);
    const legacy = fresh('legacy-optional');
    run(legacy, { flags: [engine.kind === 'ps' ? '-IncludeLegacyHumanize' : '--include-legacy-humanize'], fail: true });
    assert(!fs.existsSync(path.join(legacy, '.agents')));
    const oldWriting = path.join(legacy, '.agents', 'skills', 'humanize-korean', 'SKILL.md');
    write(oldWriting, 'preserve legacy writing skill');
    run(legacy, { fail: true });
    run(legacy, { mode: 'plugins', fail: true });
    assert.equal(read(oldWriting), 'preserve legacy writing skill');
    assert(!fs.existsSync(path.join(legacy, '.agents', 'skills', 'juhyeoknizer')));
    const duplicate = fresh('duplicate');
    write(path.join(duplicate, '.codex', 'skills', 'archify', 'SKILL.md'), 'keep duplicate');
    run(duplicate, { fail: true });
    assert(!fs.existsSync(path.join(duplicate, '.agents')));
    const malformed = fresh('malformed');
    write(path.join(malformed, '.codex', 'AGENTS.md'), 'keep\n' + begin + '\nunterminated');
    run(malformed, { fail: true });
    assert(!fs.existsSync(path.join(malformed, '.agents')));
    const custom = fresh('custom-profile');
    run(custom, { noTarget: true });
    assert(fs.existsSync(path.join(custom, 'custom-profile', 'AGENTS.md')));
    assert(!fs.existsSync(path.join(custom, '.codex')));
    const pluginHome = fresh('plugins');
    write(path.join(pluginHome, '.codex', 'config.toml'), config);
    run(pluginHome, { mode: 'plugins' });
    assert(!fs.existsSync(path.join(pluginHome, '.agents', 'skills')));
    assert(!fs.existsSync(path.join(pluginHome, '.codex', 'AGENTS.md')));
    const adds = calls().filter(call => call.args[0] === 'plugin' && call.args[1] === 'add' && !call.args.includes('--help'));
    assert.deepEqual(adds.map(call => call.args[2]), defaults.map(name => name + '@hyeok-plugins'));
    assert(calls().every(call => canonical(call.home) === canonical(path.join(pluginHome, '.codex'))), JSON.stringify(calls()));
    assert(read(path.join(pluginHome, '.codex', 'config.toml')).startsWith(config));
    assert(files(path.join(pluginHome, '.hyeok', 'backups')).some(file => read(file) === config));
    run(pluginHome, { fail: true });
    assert(!fs.existsSync(path.join(pluginHome, '.agents', 'skills')));
    run(pluginHome, { uninstall: true, mode: 'plugins' });
    const removals = calls().filter(call => call.args[1] === 'remove');
    assert.deepEqual(removals.map(call => call.args[2]), defaults.map(name => name + '@hyeok-plugins'));
    assert(!fs.existsSync(path.join(pluginHome, '.hyeok', 'codex-plugins-installed')));
    const unsupported = fresh('unsupported');
    run(unsupported, { mode: 'plugins', unsupported: true, fail: true });
    assert(!fs.existsSync(path.join(unsupported, '.hyeok')));
    assert(!fs.existsSync(path.join(unsupported, '.codex')));
    const diagram = path.join(home, '.agents', 'skills', 'diagram-design', 'SKILL.md');
    write(diagram, 'user modified skill\n');
    const archify = path.join(home, '.agents', 'skills', 'archify');
    fs.unlinkSync(path.join(archify, '.hyeok-installed'));
    run(home, { uninstall: true });
    assert.equal(read(path.join(gov, 'SKILL.md')), foreignEntry);
    assert.equal(read(path.join(gov, 'keep.txt')), 'user addition\n');
    assert.equal(read(diagram), 'user modified skill\n');
    assert(fs.existsSync(path.join(archify, 'SKILL.md')));
    assert(!fs.existsSync(path.join(home, '.agents', 'skills', 'typst-korean', 'SKILL.md')));
    assert(fs.existsSync(path.join(home, '.agents', 'skills', 'typst-korean', 'references', 'probe.md')));
    assert(!read(agents).includes(begin));
    assert(read(agents).includes('foreign before') && read(agents).includes('foreign after'));
    assert.equal(read(path.join(home, '.codex', 'config.toml')), config);
    console.log(`${engine.kind}: full resource copy, single writing skill, idempotence, backups, duplicate guard, custom profile, mocked plugins and protected uninstall passed`);
  }
  console.log(`PASS: ${runs} isolated installer/uninstaller executions; no real user home or real host CLI used.`);
} finally {
  // Only delete the exact mkdtemp directory we created. Never follow a user path.
  assert.equal(path.dirname(scratch), path.resolve(os.tmpdir()));
  assert(path.basename(scratch).startsWith('hyeok-install-tests-'));
  try { fs.rmSync(scratch, { recursive: true, force: true, maxRetries: 5, retryDelay: 200 }); }
  catch (error) { console.error('Temporary test files retained for inspection:', scratch, error.code); }
}
