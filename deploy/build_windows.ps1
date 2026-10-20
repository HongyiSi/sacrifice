param([string]$GodotExe = '', [string]$OutputDirectory = '')
$ErrorActionPreference='Stop'
$root=Split-Path -Parent $PSScriptRoot
if (!$GodotExe) { $GodotExe=Join-Path (Split-Path -Parent $root) 'work/sacrifice-godot/Godot.exe' }
if (!$OutputDirectory) { $OutputDirectory=Join-Path $root 'build' }
$OutputDirectory=[IO.Path]::GetFullPath($OutputDirectory)
$desktop=Join-Path $OutputDirectory 'windows'
New-Item -ItemType Directory -Force $desktop | Out-Null
$log=Join-Path $OutputDirectory 'windows-export.log'
$argsList=@('--headless','--path',('"'+$root+'"'),'--log-file',('"'+$log+'"'),'--export-release','"Windows Desktop"',('"'+(Join-Path $desktop 'Sacrifice.exe')+'"'))
$p=Start-Process -FilePath $GodotExe -ArgumentList $argsList -WindowStyle Hidden -PassThru
if (!$p.WaitForExit(180000)) { Stop-Process -Id $p.Id; throw 'Windows export timeout' }
if ($p.ExitCode -ne 0) { Get-Content $log -Tail 20; throw 'Windows export failed' }
# Keep attribution with the portable distribution when the web build is available.
foreach($name in @('CREDITS.txt','OFL.txt','Nunito-OFL.txt')) {
 $source=Join-Path $OutputDirectory ('web/'+$name)
 if (Test-Path -LiteralPath $source) { Copy-Item -LiteralPath $source -Destination (Join-Path $desktop $name) -Force }
}
Write-Output 'SACRIFICE_WINDOWS_EXPORT_OK'
