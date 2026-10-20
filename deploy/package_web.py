from pathlib import Path
import hashlib,tarfile,sys
root=Path(__file__).resolve().parents[1]
build=Path(sys.argv[1]).resolve() if len(sys.argv)>1 else root/'build'
out=build/'sacrifice-web-release.tar.gz'
with tarfile.open(out,'w:gz') as tar:
    for p in sorted((build/'web').iterdir()):
        if p.is_file() and not p.name.endswith(('.import','.tmp','.log')): tar.add(p,arcname=p.name)
print(hashlib.sha256(out.read_bytes()).hexdigest())
print(f'{out} ({out.stat().st_size} bytes)')
