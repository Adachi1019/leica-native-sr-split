"""Minimal host fixture tools for the Windows MinGit shell; never shipped as module code."""
from pathlib import Path
import shutil,sys
op,*args=sys.argv[1:]
if op=='cat':
    for name in args:sys.stdout.buffer.write(Path(name).read_bytes())
elif op=='cp':
    assert len(args)==2
    shutil.copyfile(args[0],args[1])
elif op=='sed':
    assert args[:2]==['-n','s/^versionCode=//p'] and len(args)==3
    for line in Path(args[2]).read_text().splitlines():
        if line.startswith('versionCode='):print(line.split('=',1)[1])
else:raise SystemExit('Unsupported fixture tool: '+op)
