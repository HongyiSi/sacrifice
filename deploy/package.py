from pathlib import Path
import tarfile,hashlib,sys
root=Path(__file__).resolve().parents[1]
build=Path(sys.argv[1]).resolve() if len(sys.argv)>1 else root/'build'
out=build/'sacrifice-release.tar.gz'
with tarfile.open(out,'w:gz',compresslevel=6) as tar:
    for folder in ['web','server']:
        tar.add(build/folder,arcname=folder,filter=lambda info: None if info.name.endswith(('.import','.tmp','.log')) else info)
    for name in ['sacrifice.service','nginx-sacrifice.conf','nginx-sacrifice-game.locations','nginx-sacrifice-diagnostics.conf','sacrifice-diagnostics.logrotate']:
        tar.add(root/'deploy'/name,arcname='deploy/'+name)
print(hashlib.sha256(out.read_bytes()).hexdigest())
print(f'{out} ({out.stat().st_size} bytes)')
