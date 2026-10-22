import hashlib,sys
from pathlib import Path
try:print(hashlib.sha256(Path(sys.argv[1]).read_bytes()).hexdigest())
except OSError:sys.exit(1)
