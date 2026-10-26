"""Write portable SHA-256 checksums for every delivery file except this list."""
from pathlib import Path
import hashlib
import re

OUT = Path(__file__).resolve().parent.parent
rows = []
for path in sorted(OUT.rglob('*')):
    if not path.is_file() or path.name == 'checksums.sha256':
        continue
    if '__pycache__' in path.parts or re.search(r'\.blend[1-9]$', path.name):
        continue
    rows.append(hashlib.sha256(path.read_bytes()).hexdigest()+'  '+path.relative_to(OUT).as_posix())
(OUT/'checksums.sha256').write_text('\n'.join(rows)+'\n')
print(f'Wrote {len(rows)} file checksums.')
