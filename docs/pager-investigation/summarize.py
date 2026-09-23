import json
from pathlib import Path

root = Path(__file__).resolve().parent
rows = []
for file in sorted(root.glob('*/native.json')):
    data = json.loads(file.read_text())
    pagers = [n for n in data['nodes'] if 'PagingCollectionView' in n['class']]
    cells = [n for n in data['nodes'] if 'UIKitPagingCell' in n['class']]
    mosaics = [n for n in data['nodes'] if n['class'] == 'UICollectionView']
    row = {'checkpoint': file.parent.name, 'windows': data['capture']['windows'],
           'truncated': data['capture']['truncated'],
           'pager': [{'frame': n['geometry']['screenFrame'], 'scroll': n['properties'].get('scroll')} for n in pagers],
           'cells': [n['geometry']['screenFrame'] for n in cells],
           'mosaics': [{'frame': n['geometry']['screenFrame'], 'scroll': n['properties'].get('scroll')} for n in mosaics]}
    rows.append(row)
    print(row['checkpoint'], 'contentHeight=', [p['scroll']['contentSize']['height'] for p in row['pager']],
          'cellY=', [p['y'] for p in row['cells']],
          'mosaics=', [(m['frame']['x'], m['frame']['y'], m['frame']['width'], m['frame']['height'], m['scroll']['contentOffset']['y']) for m in row['mosaics']])
(root / 'measurements.json').write_text(json.dumps(rows, indent=2))
