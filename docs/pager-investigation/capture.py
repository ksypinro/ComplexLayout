"""Capture one settled simulator checkpoint using the skill's compiled probe."""
import json
import pathlib
import subprocess
import sys

root = pathlib.Path(__file__).resolve().parent
pid, name = sys.argv[1:3]
udid = sys.argv[3] if len(sys.argv) > 3 else '16592CE0-AE1E-42E7-BA7D-8A5107A25680'
output = root / name
output.mkdir(exist_ok=False)
subprocess.run(['xcrun', 'simctl', 'io', udid, 'screenshot', str(output / 'screen.png')], check=True, capture_output=True)
commands = [
    'process status', 'thread list',
    'script t = next(t for t in lldb.debugger.GetSelectedTarget().GetProcess() if t.GetQueueName() == "com.apple.main-thread"); lldb.debugger.GetSelectedTarget().GetProcess().SetSelectedThread(t)',
    'frame select 0',
    'command script import /Users/samin/.codex/skills/ios-view-hierarchy-debugger/scripts/lldb_ui.py',
    f'ui_capture {output}/native.json --compiled-probe {root}/probe/PuppetUIProbe.dylib',
    'process detach',
]
args = ['xcrun', 'lldb', '--batch', '-p', pid]
for command in commands:
    args.extend(['-o', command])
result = subprocess.run(args, text=True, capture_output=True, timeout=60)
(output / 'lldb.log').write_text(result.stdout + result.stderr)
if result.returncode:
    raise RuntimeError(result.stdout + result.stderr)
data = json.loads((output / 'native.json').read_text())
print(name, data['target'], 'nodes', len(data['nodes']), 'truncated', data['capture']['truncated'])
print('windows', data['capture']['windows'])
for node in data['nodes']:
    cls = node['class']
    if any(c in cls for c in ('PagingCollectionView', 'UIKitPagingCell')) or cls == 'UICollectionView' or node.get('accessibilityIdentifier') == 'experiment.plain-controller':
        print(cls, node['id'], 'frame', node['geometry']['frame'], 'screen', node['geometry']['screenFrame'], 'safe', node['layout']['safeAreaInsets'], 'hidden', node['visibility'].get('ancestorHidden'), 'scroll', node['properties'].get('scroll'))
