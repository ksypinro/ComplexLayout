"""Host side of the isolated XCTest/native-capture handshake."""
import json
import pathlib
import shutil
import subprocess
import sys
import time

root = pathlib.Path(__file__).resolve().parent
sync = pathlib.Path('/tmp/complex-layout-uitest-sync')
sync.mkdir(exist_ok=True)
udid = sys.argv[1] if len(sys.argv) > 1 else '16592CE0-AE1E-42E7-BA7D-8A5107A25680'
seen = set()
deadline = time.monotonic() + 1800
while time.monotonic() < deadline:
    try:
        checkpoint = json.loads((sync / 'current.json').read_text())
    except (FileNotFoundError, json.JSONDecodeError):
        time.sleep(0.25)
        continue
    name = checkpoint['name']
    if name in seen or (sync / f'{name}.continue').exists():
        time.sleep(0.25)
        continue
    seen.add(name)
    processes = subprocess.check_output(['ps', '-axo', 'pid=,args='], text=True)
    candidates = [line.split(None, 1)[0] for line in processes.splitlines()
                  if udid in line and line.rstrip().endswith('/ComplexLayout.app/ComplexLayout')]
    if len(candidates) != 1:
        # launch arguments appear after the executable in some process listings.
        candidates = [line.split(None, 1)[0] for line in processes.splitlines()
                      if udid in line and '/ComplexLayout.app/ComplexLayout ' in line]
    if len(candidates) != 1:
        raise RuntimeError(f'Ambiguous app PID: {candidates}')
    result = subprocess.run([sys.executable, str(root / 'capture.py'), candidates[0], name, udid],
                            text=True, capture_output=True, timeout=80)
    print(result.stdout, flush=True)
    if result.returncode:
        raise RuntimeError(result.stderr)
    (root / name / 'context.json').write_text(json.dumps(checkpoint, indent=2))
    for suffix in ['-ax.txt', '.png']:
        shutil.copy(sync / f'{name}{suffix}', root / name / f'xcuitest{suffix}')
    (sync / f'{name}.continue').touch()
    print('ACK', name, flush=True)
