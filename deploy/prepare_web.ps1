param([Parameter(Mandatory=$true)][string]$WebDirectory)
$ErrorActionPreference='Stop'
$WebDirectory=[IO.Path]::GetFullPath($WebDirectory)
$assets=[ordered]@{}
foreach($name in @('index.pck','index-mobile.pck','index.wasm','music-lobby.wav','music-battle.mp3')) {
 $file=Join-Path $WebDirectory $name
 $assets[$name]=[ordered]@{sha256=(Get-FileHash -LiteralPath $file -Algorithm SHA256).Hash.ToLowerInvariant();bytes=(Get-Item -LiteralPath $file).Length}
}
$project=Get-Content -LiteralPath (Join-Path (Split-Path -Parent $PSScriptRoot) 'project.godot') -Raw -Encoding UTF8
$version=[regex]::Match($project,'config/version="([^"]+)"').Groups[1].Value
$manifest=[ordered]@{schema=1;version=$version;assets=$assets}
# Keep Godot's native touch keyboard enabled, matching the Web export preset.
# Desktop browsers without touch support continue to use the normal keyboard/IME.
$config=@{args=@();canvasResizePolicy=2;ensureCrossOriginIsolationHeaders=$false;executable='index';experimentalVK=$true;fileSizes=@{'index.pck'=$assets['index.pck'].bytes;'index-mobile.pck'=$assets['index-mobile.pck'].bytes;'index.wasm'=$assets['index.wasm'].bytes};focusCanvas=$true;gdextensionLibs=@()}
$html=Get-Content -LiteralPath (Join-Path $PSScriptRoot 'web_shell.html') -Raw -Encoding UTF8
$html=$html.Replace('__CONFIG__',($config|ConvertTo-Json -Depth 6 -Compress))
$html=$html.Replace('__ASSET_MANIFEST__',($manifest|ConvertTo-Json -Depth 6 -Compress))
$html=$html.Replace('__RESOURCE_CACHE__',(Get-Content -LiteralPath (Join-Path $PSScriptRoot 'web_cache.js') -Raw -Encoding UTF8))
$html=$html.Replace('__WEB_MUSIC__',(Get-Content -LiteralPath (Join-Path $PSScriptRoot 'web_music.js') -Raw -Encoding UTF8))
$html=$html.Replace('__MOBILE_SUPPORT__',(Get-Content -LiteralPath (Join-Path $PSScriptRoot 'web_mobile.js') -Raw -Encoding UTF8))
$html=$html.Replace('__PACK_SUPPORT__',(Get-Content -LiteralPath (Join-Path $PSScriptRoot 'web_pack.js') -Raw -Encoding UTF8))
$html=$html.Replace('__CLIENT_DIAGNOSTICS__',(Get-Content -LiteralPath (Join-Path $PSScriptRoot 'web_diagnostics.js') -Raw -Encoding UTF8))
[IO.File]::WriteAllText((Join-Path $WebDirectory 'index.html'),$html,[Text.UTF8Encoding]::new($false))
Write-Output 'SACRIFICE_WEB_SHELL_READY'
