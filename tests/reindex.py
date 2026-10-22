import hashlib,sys
from pathlib import Path
root=Path(sys.argv[1])
files=sorted(p for p in root.rglob('*') if p.is_file() and p.name not in ('runtime.sha256','module.prop') and not p.name.endswith('.saved'))
(root/'runtime.sha256').write_text(''.join(hashlib.sha256(p.read_bytes()).hexdigest()+'  '+p.relative_to(root).as_posix()+'\n' for p in files),encoding='ascii',newline='\n')
