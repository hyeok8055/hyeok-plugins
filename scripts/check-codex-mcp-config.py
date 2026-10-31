#!/usr/bin/env python3
"""Check documented MCP configuration against the installed Codex CLI.

Requires Python 3.11+ and Codex on PATH. All writes use a temporary Codex profile
and project. Only configuration commands run: no model call, server launch,
authentication, or live MCP connection. This is an optional maintainer check,
not part of installation or a command to run in a managed examination session.
"""
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
import tomllib


def main():
    repo = Path(__file__).resolve().parent.parent
    codex = shutil.which('codex')
    if not codex:
        raise SystemExit('Codex CLI is required for this optional check; no installation attempted.')
    real_profile = Path(os.environ.get('CODEX_HOME', str(Path.home() / '.codex')))
    real_config = real_profile / 'config.toml'
    before = real_config.read_bytes() if real_config.exists() else None
    with tempfile.TemporaryDirectory(prefix='hyeok-mcp-scope-') as temporary:
        root = Path(temporary)
        profile = root / 'profile'
        project = root / 'project'
        profile.mkdir()
        project.mkdir()
        environment = os.environ.copy()
        environment['CODEX_HOME'] = str(profile)
        environment.pop('CONTEXT7_API_KEY', None)

        def cli(*arguments):
            result = subprocess.run([codex, 'mcp', *arguments], cwd=project, env=environment,
                                    capture_output=True, text=True, encoding='utf-8', timeout=25)
            if result.returncode:
                raise RuntimeError(result.stderr)
            return result.stdout

        original = 'model = "provided-model"\n[mcp_servers.provided]\ncommand = "must-not-run"\n'
        config = profile / 'config.toml'
        config.write_text(original, encoding='utf-8')
        cli('add', 'scope_probe', '--', 'hyeok-command-that-must-not-run')
        data = tomllib.loads(config.read_text(encoding='utf-8'))
        assert data['model'] == 'provided-model'
        assert data['mcp_servers']['provided']['command'] == 'must-not-run'
        assert data['mcp_servers']['scope_probe']['command'] == 'hyeok-command-that-must-not-run'
        assert not (project / '.codex').exists()
        print('PASS mcp add writes only isolated user configuration and preserves existing settings')

        guide = repo / 'plugins/hyeok-governance/skills/hyeok-governance/references/skill-and-mcp-setup.md'
        blocks = re.findall(r'```toml\n(.*?)\n```', guide.read_text(encoding='utf-8'), flags=re.S)
        assert blocks, 'No TOML examples to check'
        for block in blocks:
            expected = tomllib.loads(block)['mcp_servers']
            config.write_text(original + '\n' + block + '\n', encoding='utf-8')
            for name, server in expected.items():
                actual = json.loads(cli('get', name, '--json'))
                transport = actual.get('transport', actual)
                assert transport['url'] == server['url']
                assert transport.get('bearer_token_env_var') == server.get('bearer_token_env_var')
                assert not actual.get('required', False)
            print('PASS CLI parses HTTP configuration: ' + ', '.join(expected))

        (project / '.git').mkdir()
        (project / '.codex').mkdir()
        (project / '.codex/config.toml').write_text(blocks[0], encoding='utf-8')
        expected_names = set(tomllib.loads(blocks[0])['mcp_servers'])
        trust_key = json.dumps(str(project))
        for trust, expected_present in [('untrusted', False), ('trusted', True)]:
            config.write_text(original + f'\n[projects.{trust_key}]\ntrust_level = "{trust}"\n', encoding='utf-8')
            servers = json.loads(cli('list', '--json'))
            names = {item['name'] for item in servers}
            assert (expected_names <= names) == expected_present, (trust, names)
            print(f'PASS project MCP configuration loaded={expected_present} for trust={trust}')
    assert (real_config.read_bytes() if real_config.exists() else None) == before
    print('PASS real user config unchanged; no MCP connection or model call attempted')


if __name__ == '__main__':
    main()
