# DK Bananza recomp: installs the tools and builds dkb.exe from your own dump, with no other steps.
# Run again to resume or update: finished steps go by quickly. Messages stay ASCII so "irm | iex" cannot garble them.
# Tests can set DK_PASTA (install folder), DK_DUMP (dump folder) and DK_SEM_ATALHO=1 to skip the dialogs and the shortcut.
$ErrorActionPreference = 'Continue'
Add-Type -AssemblyName System.Windows.Forms

$log = Join-Path $env:TEMP 'dkb-instalar.log'

function Parar($msg) {
    Write-Host "`nERRO: $msg" -ForegroundColor Red
    Write-Host "Registro completo: $log"
    Read-Host 'Aperte Enter para sair'
    throw 'instalacao interrompida'
}
function Titulo($t) { Write-Host "`n=== $t ===" -ForegroundColor Cyan }
# Runs a program and stops the install when it fails. Output goes to the screen and the log.
function Rodar($exe) {
    & $exe @args 2>&1 | ForEach-Object { "$_" } | Tee-Object -FilePath $log -Append
    if ($LASTEXITCODE -ne 0) { Parar "falhou: $exe $args" }
}
function AtualizarPath() {
    $m = [Environment]::GetEnvironmentVariable('Path', 'Machine'); $u = [Environment]::GetEnvironmentVariable('Path', 'User')
    $env:PATH = "$env:PATH;$m;$u"
}
function Instalar($id, $override) {
    Write-Host "Instalando $id (o Windows pode pedir permissao)..."
    $a = @('install', '--id', $id, '-e', '--accept-source-agreements', '--accept-package-agreements')
    if ($override) { $a += @('--override', $override) }
    & winget @a 2>&1 | ForEach-Object { "$_" } | Tee-Object -FilePath $log -Append
    AtualizarPath
}

Titulo 'DK Bananza para Windows - instalador'
Write-Host 'Experimental: pode travar e alguns efeitos ficam faltando. Voce precisa do seu proprio dump da versao 1.0.0.'
Write-Host 'Nao compartilhe o dkb.exe, o cache de shaders, os saves nem o dump.'

Titulo '1/7 Verificando o PC'
if ($env:PROCESSOR_ARCHITECTURE -ne 'AMD64') { Parar 'precisa de Windows x64.' }
# Windows reports less than what is installed (a 16 GB PC can show 14 GB), so the requirement goes by the modules. Some VMs list none.
$visivel = [math]::Round((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory / 1GB)
$ram = [math]::Max([math]::Round((Get-CimInstance Win32_PhysicalMemory | Measure-Object Capacity -Sum).Sum / 1GB), $visivel)
if ($ram -lt 16) { Parar "precisa de 16 GB de RAM; este PC tem $ram GB." }
if ($visivel -lt 15) { Write-Host "AVISO: o Windows so pode usar $visivel GB dos $ram GB, e o jogo usa cerca de 13 GB. Feche os outros programas antes de jogar; pode travar." -ForegroundColor Yellow }
$pasta = $env:DK_PASTA
if (-not $pasta) {
    Write-Host 'Escolha onde instalar (a janela pode abrir atras desta). Para atualizar, escolha a mesma pasta.'
    $d = New-Object System.Windows.Forms.FolderBrowserDialog
    $d.Description = 'Escolha onde instalar (precisa de 60 GB livres). Sera criada a pasta dkb-pc-recomp aqui dentro.'
    $d.SelectedPath = $env:USERPROFILE
    if ($d.ShowDialog() -ne 'OK') { Parar 'nenhuma pasta escolhida.' }
    # Picking an existing install resumes it instead of nesting a second one inside it
    $pasta = if (Test-Path (Join-Path $d.SelectedPath '.git')) { $d.SelectedPath } else { Join-Path $d.SelectedPath 'dkb-pc-recomp' }
}
if ($pasta -notmatch '^[A-Za-z]:\\') { Parar "escolha uma pasta em uma unidade com letra, nao: $pasta" }
$unidade = (Split-Path $pasta -Qualifier).TrimEnd(':')
$livre = [math]::Floor((Get-PSDrive $unidade).Free / 1GB)
$feito = Test-Path (Join-Path $pasta 'build\extracted\dkb100\romfs')
if ($livre -lt 60 -and -not $feito) { Parar "precisa de 60 GB livres em ${unidade}:; ha $livre GB." }
Write-Host "RAM $ram GB, $livre GB livres em ${unidade}:"

$dump = $env:DK_DUMP
if (-not $dump) {
    $d = New-Object System.Windows.Forms.FolderBrowserDialog
    $d.Description = 'Escolha a pasta do seu dump'
    if ($d.ShowDialog() -ne 'OK') { Parar 'nenhuma pasta escolhida.' }
    $dump = $d.SelectedPath
}
# Accepts the dump folder, its base folder, or a dump with exefs and romfs directly inside
$base = if (Test-Path (Join-Path $dump 'base\exefs\main')) { Join-Path $dump 'base' } else { $dump }
foreach ($f in 'main', 'sdk', 'rtld', 'main.npdm') {
    if (-not (Test-Path (Join-Path $base "exefs\$f"))) { Parar "nao achei exefs\$f em $base. Escolha a pasta do jogo, a que contem base ou exefs e romfs." }
}
if (-not (Test-Path (Join-Path $base 'romfs'))) { Parar "nao achei a pasta romfs em $base." }

Titulo '2/7 Ferramentas'
AtualizarPath
if (-not (Get-Command winget -ErrorAction SilentlyContinue)) { Parar 'winget nao encontrado: instale o "Instalador de Aplicativo" pela Microsoft Store.' }
if (-not (Get-Command git -ErrorAction SilentlyContinue)) { Instalar 'Git.Git' }
& py -3.12 --version *> $null
if ($LASTEXITCODE -ne 0) { Instalar 'Python.Python.3.12' }
if (-not (Test-Path 'C:\msys64\usr\bin\bash.exe')) { Instalar 'MSYS2.MSYS2' }
$vs = 'C:\Program Files (x86)\Microsoft Visual Studio\Installer'
# The shader translator links with MSVC: what it needs is the C++ tools and the Windows SDK, not just any Visual Studio
function TemCpp() {
    $vc = (Test-Path "$vs\vswhere.exe") -and (& "$vs\vswhere.exe" -latest -prerelease -products '*' -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath)
    $sdk = Test-Path "${env:ProgramFiles(x86)}\Windows Kits\10\Lib\*\um\x64\kernel32.lib"
    return ($vc -and $sdk)
}
if (-not (TemCpp)) {
    $existente = if (Test-Path "$vs\vswhere.exe") { & "$vs\vswhere.exe" -latest -prerelease -products '*' -property installationPath }
    if ($existente) {
        # winget says "already installed" and adds nothing to an install without C++, so ask the Visual Studio Installer
        Write-Host "Adicionando as ferramentas de C++ ao Visual Studio em $existente (o Windows pode pedir permissao; leva alguns minutos)..."
        $a = "modify --installPath `"$existente`" --add Microsoft.VisualStudio.Component.VC.Tools.x86.x64 --add Microsoft.VisualStudio.Component.Windows11SDK.26100 --quiet --norestart --force"
        Start-Process "$vs\setup.exe" -ArgumentList $a -Verb RunAs -Wait
    } else {
        Instalar 'Microsoft.VisualStudio.BuildTools' '--quiet --wait --norestart --add Microsoft.VisualStudio.Workload.VCTools --includeRecommended'
    }
    if (-not (TemCpp)) { Parar 'faltam as ferramentas de C++ do Visual Studio. Abra o Visual Studio Installer, clique em Modificar, marque "Desenvolvimento para desktop com C++" e rode este comando de novo.' }
}
$sdks = (Get-Command dotnet -ErrorAction SilentlyContinue) -and (& dotnet --list-sdks | Select-String '^10\.')
if (-not $sdks) { Instalar 'Microsoft.DotNet.SDK.10' }
foreach ($c in 'git', 'py', 'dotnet') { if (-not (Get-Command $c -ErrorAction SilentlyContinue)) { Parar "$c nao foi instalado. Feche esta janela e rode de novo." } }
if (-not (Test-Path 'C:\msys64\usr\bin\bash.exe')) { Parar 'o MSYS2 nao foi instalado.' }

Titulo '3/7 Compilador (MSYS2)'
$env:MSYSTEM = 'UCRT64'; $env:CHERE_INVOKING = '1'
$bash = 'C:\msys64\usr\bin\bash.exe'
if (-not (Test-Path 'C:\msys64\ucrt64\bin\clang.exe')) {
    # The first update may close MSYS2 midway: hence twice, and no stop on its exit code
    & $bash -lc 'pacman -Syuu --noconfirm' 2>&1 | ForEach-Object { "$_" } | Tee-Object -FilePath $log -Append
    & $bash -lc 'pacman -Syuu --noconfirm' 2>&1 | ForEach-Object { "$_" } | Tee-Object -FilePath $log -Append
}
Rodar $bash -lc 'pacman -S --needed --noconfirm mingw-w64-ucrt-x86_64-{clang,lld,ninja,gcc,make,pkgconf,sdl3,opus,libvpx,zstd,vulkan-devel,vulkan-memory-allocator,vulkan-validation-layers,shaderc,spirv-tools} base-devel git unzip'
$env:PATH = "C:\msys64\ucrt64\bin;$vs;$env:PATH"
$env:PYTHONUTF8 = '1'

Titulo '4/7 Codigo'
if (Test-Path (Join-Path $pasta '.git')) {
    Rodar git -C $pasta pull --ff-only
} else {
    Rodar git clone -b local-prs 'https://github.com/sostenesfreitas/dkb-pc-recomp' $pasta
}
Set-Location $pasta
if (-not (Test-Path '.venv\Scripts\python.exe')) { Rodar py -3.12 -m venv .venv }
Rodar .venv\Scripts\python.exe -m pip install -q --disable-pip-version-check -r tools\requirements.txt
$python = (Resolve-Path '.venv\Scripts\python.exe').Path

$esperado = (Get-Content 'tools\data\expected-dkb100.json' -Raw | ConvertFrom-Json).exefs_sha256.main
if ($esperado -ne (Get-FileHash (Join-Path $base 'exefs\main')).Hash) { Parar 'este dump nao e a versao base 1.0.0. A atualizacao 458752 e o DLC nao tem suporte.' }
Write-Host 'Dump confere: versao 1.0.0.'

Titulo '5/7 Tradutor de shaders e codigo do jogo'
Rodar $python tools\build_xlate.py
Rodar $python recomp\gen.py --exefs (Join-Path $base 'exefs') --out generated\dkb100 --modules 'main,sdk' --patches recomp\patches-dkb100.txt

Titulo '6/7 Arquivos do jogo e executavel (pode levar uns 15 minutos)'
if (-not (Test-Path 'build\extracted\dkb100\romfs\romfs.bin')) {
    Rodar $python tools\dkb_pack_romfs.py --dir (Join-Path $base 'romfs') --out build\extracted\dkb100\romfs
}
Rodar $python tools\build_game.py --version dkb100 --expected tools\data\expected-dkb100.json --exefs (Join-Path $base 'exefs') --romfs build\extracted\dkb100\romfs

Titulo '7/7 Verificando'
Rodar build\dkb100\dkb.exe --selftest
if (-not (Test-Path 'build\dkb100\totk.ini')) { Copy-Item amigos\totk.ini build\dkb100\totk.ini }
if (-not $env:DK_SEM_ATALHO) {
    $atalho = (New-Object -ComObject WScript.Shell).CreateShortcut((Join-Path ([Environment]::GetFolderPath('Desktop')) 'Donkey Kong Bananza.lnk'))
    $atalho.TargetPath = 'powershell.exe'
    $atalho.Arguments = "-ExecutionPolicy Bypass -File `"$pasta\amigos\jogar-dk.ps1`""
    $atalho.WorkingDirectory = $pasta
    $atalho.IconLocation = "$pasta\build\dkb100\dkb.exe"
    $atalho.Save()
}
Write-Host "`nPronto! Conecte um controle e abra o atalho 'Donkey Kong Bananza' na Area de Trabalho." -ForegroundColor Green
if (-not $env:DK_SEM_ATALHO) { Read-Host 'Aperte Enter para sair' }
