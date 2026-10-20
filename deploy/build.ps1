param([string]$GodotExe = "", [string]$WebRuntime = "D:\Godot projects\daifugo\build\web", [string]$OutputDirectory = "")
$ErrorActionPreference='Stop'
$root=Split-Path -Parent $PSScriptRoot
if (!$GodotExe) { $GodotExe=Join-Path (Split-Path -Parent $root) 'work/sacrifice-godot/Godot.exe' }
if (!$OutputDirectory) { $OutputDirectory=Join-Path $root 'build' }
$OutputDirectory=[IO.Path]::GetFullPath($OutputDirectory)
foreach($dir in @('web','server','logs')) { New-Item -ItemType Directory -Force (Join-Path $OutputDirectory $dir) | Out-Null }
foreach($target in @(@('Web','web/index.pck'),@('Web Mobile','web/index-mobile.pck'),@('Linux Dedicated Server','server/sacrifice-server.pck'))) {
 $log=Join-Path $OutputDirectory ('logs/'+$target[0].Replace(' ','-')+'.log')
 $argsList=@('--headless','--path',('"'+$root+'"'),'--log-file',('"'+$log+'"'),'--export-pack',('"'+$target[0]+'"'),('"'+(Join-Path $OutputDirectory $target[1])+'"'))
 $p=Start-Process -FilePath $GodotExe -ArgumentList $argsList -WindowStyle Hidden -PassThru
 if (!$p.WaitForExit(180000)) { Stop-Process -Id $p.Id; throw 'export timeout' }
 if ($p.ExitCode -ne 0) { Get-Content $log -Tail 20; throw 'export failed' }
}
foreach($name in @('index.js','index.wasm','index.audio.worklet.js','index.audio.position.worklet.js')) { Copy-Item -LiteralPath (Join-Path $WebRuntime $name) -Destination (Join-Path $OutputDirectory ('web/'+$name)) -Force }
# Optional music is fetched only after entry, and only for the current scene.
# Serve the original recordings to the browser media pipeline; no re-encoding.
foreach($track in @(@('old_tower_inn_loop.wav','music-lobby.wav'),@('woodland_fantasy.mp3','music-battle.mp3'))) {
 Copy-Item -LiteralPath (Join-Path $root ('assets/music/'+$track[0])) -Destination (Join-Path $OutputDirectory ('web/'+$track[1])) -Force
}
Copy-Item -LiteralPath 'D:/Godot projects/heart/build/runtime/Godot_v4.7.1-stable_linux.x86_64' -Destination (Join-Path $OutputDirectory 'server/godot-server.x86_64') -Force
Copy-Item -LiteralPath (Join-Path $root 'assets/icon.svg') -Destination (Join-Path $OutputDirectory 'web/icon.svg') -Force
Copy-Item -LiteralPath (Join-Path $root 'assets/fonts/OFL.txt') -Destination (Join-Path $OutputDirectory 'web/OFL.txt') -Force
Copy-Item -LiteralPath (Join-Path $root 'assets/fonts/Nunito-OFL.txt') -Destination (Join-Path $OutputDirectory 'web/Nunito-OFL.txt') -Force
$credits="Sacrifice: Noto Sans CJK SC subset (Google / Adobe), SIL OFL 1.1. See OFL.txt.`nWoodland Fantasy (c) Matthew Pablo, https://www.matthewpablo.com , CC BY 3.0 https://creativecommons.org/licenses/by/3.0/ . Original unmodified recording: https://opengameart.org/content/woodland-fantasy .`nThe Old Tower Inn by RandomMind, CC0 https://creativecommons.org/publicdomain/zero/1.0/ . Original loop: https://opengameart.org/content/medieval-the-old-tower-inn .`n"
$credits += "Attack SFX: Mixkit Heavy sword hit (2794), Short fire whoosh (1345), Wizard fire woosh (1326), Fire swoosh burning (1328), Fireball spell (1347). https://mixkit.co/free-sound-effects/sword/ ; https://mixkit.co/free-sound-effects/fire/ ; https://mixkit.co/license/modal/sfxFree/ . Additional Foley: Tinysized SFX by Jan Schupke / Vehicle, CC0, https://opengameart.org/content/fantasy-sound-effects-tinysized-sfx .`n"
$credits += "Healing SFX: Mixkit Light spell (873), approved candidate E. https://mixkit.co/free-sound-effects/magic/ ; https://mixkit.co/license/modal/sfxFree/ . Defense and flying emblems: Tinysized SFX by Jan Schupke / Vehicle, CC0. Edited and synchronized to the game.`n"
$credits += "Nunito by Vernon Adams, Cyreal and Jacques Le Bailly, SIL OFL 1.1. See Nunito-OFL.txt.`n"
foreach($source in (Get-ChildItem -LiteralPath (Join-Path $root 'assets/sfx') -Recurse -File | Where-Object {$_.Name -in @('SOURCES.txt','sources.json','CREDITS.md')} | Sort-Object FullName)) {
 $credits += "`n--- " + $source.FullName.Substring($root.Length+1).Replace('\','/') + " ---`n" + (Get-Content -LiteralPath $source.FullName -Raw -Encoding UTF8) + "`n"
}
[IO.File]::WriteAllText((Join-Path $OutputDirectory 'web/CREDITS.txt'),$credits,[Text.UTF8Encoding]::new($false))
& (Join-Path $PSScriptRoot 'prepare_web.ps1') -WebDirectory (Join-Path $OutputDirectory 'web')
# Rebuilding a directory invalidates any old precompressed responses.
foreach($name in @('index.pck.gz','index-mobile.pck.gz','index.js.gz','index.wasm.gz')) {
 $file=Join-Path $OutputDirectory ('web/'+$name)
 if(Test-Path -LiteralPath $file){Remove-Item -LiteralPath $file}
}
Write-Output 'SACRIFICE_BUILD_OK'
Get-Item (Join-Path $OutputDirectory 'web/index.pck'),(Join-Path $OutputDirectory 'web/index-mobile.pck'),(Join-Path $OutputDirectory 'server/sacrifice-server.pck') | Select-Object Name,Length
