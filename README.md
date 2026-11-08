# DKB Recomp

> [!WARNING]
> **Este é um fork pessoal para testes**, baseado em [Lucas-blip-png/dkb-pc-recomp](https://github.com/Lucas-blip-png/dkb-pc-recomp) `6386b42`. A branch `local-prs` junta os PRs #67, #68 e #72, que o projeto ainda não aceitou, e um diagnóstico local. Problemas desta branch não devem ser relatados ao projeto original como se fossem dele.

## Como compilar o Donkey Kong Bananza (branch `local-prs`)

O resultado é um `dkb.exe` nativo para Windows, sem emulador, gerado no seu PC a partir da sua cópia do jogo. **Ainda é experimental:** pode travar, e alguns efeitos ficam faltando.

Este repositório não tem jogo, keys nem executável, e este guia não explica como obter o jogo. Tudo o que o build gera sai do jogo: **não compartilhe** o `dkb.exe`, `generated\`, `build\`, o cache de shaders, os saves nem o dump.

Usa um assistente de IA? Peça para ele seguir [`amigos/AGENTS.md`](amigos/AGENTS.md).

### Jeito fácil: um comando só

Abra o PowerShell, cole o comando abaixo e, quando pedir, escolha onde instalar (pode ser outra unidade) e a pasta do seu dump:

```powershell
powershell -ExecutionPolicy Bypass -c "irm https://raw.githubusercontent.com/sostenesfreitas/dkb-pc-recomp/local-prs/amigos/instalar-dk.ps1 | iex"
```

Ele confere o PC e o dump, instala o que faltar, compila tudo em `dkb-pc-recomp` dentro da pasta escolhida, roda o autoteste e cria o atalho **Donkey Kong Bananza** na Área de Trabalho. O Windows pode pedir permissão de administrador para instalar as ferramentas. Se algo falhar ou você quiser atualizar, rode o mesmo comando de novo. Antes de colar, você pode ler o script em [`amigos/instalar-dk.ps1`](amigos/instalar-dk.ps1).

Você ainda precisa do próprio dump da versão 1.0.0 e de 16 GB de RAM e 60 GB livres na unidade escolhida. As ferramentas (MSYS2, Visual Studio) sempre vão para `C:`. O instalador só foi testado em um PC que já tinha as ferramentas; em um PC limpo, se ele parar, mande o registro `%TEMP%\dkb-instalar.log`.

As etapas abaixo são o mesmo processo, passo a passo, para quem prefere fazer à mão.

### 1. Confira se você tem o necessário

- Windows 10 ou 11 em um PC x64, com CPU com AVX2.
- Placa de vídeo com Vulkan 1.3 e driver atualizado.
- 16 GB de RAM ou mais (o jogo usa cerca de 13 GB).
- Cerca de 60 GB livres.
- Seu dump da **versão base 1.0.0**, nesta estrutura. A atualização 458752 e o DLC não têm suporte.

```
<dump>\base\exefs\main, sdk, rtld, main.npdm
<dump>\base\romfs\...
```

### 2. Instale as ferramentas

Você também precisa de [Git](https://git-scm.com) e [Python 3.12](https://www.python.org/downloads/). No PowerShell, instale o resto (o Windows pode pedir permissão de administrador):

```powershell
winget install --id MSYS2.MSYS2 -e
winget install --id Microsoft.VisualStudio.BuildTools -e --override "--quiet --wait --norestart --add Microsoft.VisualStudio.Workload.VCTools --includeRecommended"
winget install --id Microsoft.DotNet.SDK.10 -e
```

Abra um PowerShell **novo** e instale o compilador e as bibliotecas. O primeiro comando pode fechar o próprio MSYS2 no meio da atualização; é normal, e por isso ele roda duas vezes:

```powershell
$env:MSYSTEM = "UCRT64"; $env:CHERE_INVOKING = "1"
C:\msys64\usr\bin\bash.exe -lc "pacman -Syuu --noconfirm"
C:\msys64\usr\bin\bash.exe -lc "pacman -Syuu --noconfirm"
C:\msys64\usr\bin\bash.exe -lc "pacman -S --needed --noconfirm mingw-w64-ucrt-x86_64-{clang,lld,ninja,gcc,make,pkgconf,sdl3,opus,libvpx,zstd,vulkan-devel,vulkan-memory-allocator,vulkan-validation-layers,shaderc,spirv-tools} base-devel git unzip"
```

### 3. Baixe o código

```powershell
git clone -b local-prs https://github.com/sostenesfreitas/dkb-pc-recomp
cd dkb-pc-recomp
py -3.12 -m venv .venv
.venv\Scripts\python -m pip install -r tools\requirements.txt
```

O `-b local-prs` é necessário: a branch padrão não tem estas correções.

### 4. Compile

Rode tudo na mesma janela, de dentro de `dkb-pc-recomp`. Na primeira linha, troque o caminho pela pasta do seu dump. Num Ryzen 9 9950X3D, o processo todo levou cerca de 15 minutos.

```powershell
$dump = "C:\caminho\do\seu\dump"
$env:PATH = "C:\msys64\ucrt64\bin;C:\Program Files (x86)\Microsoft Visual Studio\Installer;$env:PATH"
$env:PYTHONUTF8 = "1"

# Confere se o dump é a versão 1.0.0: deve mostrar True
(Get-Content tools\data\expected-dkb100.json | ConvertFrom-Json).exefs_sha256.main -eq (Get-FileHash "$dump\base\exefs\main").Hash

# O tradutor de shaders
.venv\Scripts\python tools\build_xlate.py

# O código do jogo vira C
.venv\Scripts\python recomp\gen.py --exefs "$dump\base\exefs" --out generated\dkb100 --modules 'main,sdk' --patches recomp\patches-dkb100.txt

# Os arquivos do jogo, cerca de 9 GB
.venv\Scripts\python tools\dkb_pack_romfs.py --dir "$dump\base\romfs" --out build\extracted\dkb100\romfs

# O executável
.venv\Scripts\python tools\build_game.py --version dkb100 --expected tools\data\expected-dkb100.json --exefs "$dump\base\exefs" --romfs build\extracted\dkb100\romfs

# A verificação: deve terminar com "selftest: passed (0 failures)"
build\dkb100\dkb.exe --selftest
```

Se pouca memória travar o PC, adicione `--jobs 6` ao comando do `build_game.py`.

### 5. Jogue

Só na primeira vez, copie as configurações. Sem elas, o terreno destrutível fica preto:

```powershell
Copy-Item amigos\totk.ini build\dkb100\totk.ini
```

Para abrir o jogo, da pasta `dkb-pc-recomp`:

```powershell
powershell -ExecutionPolicy Bypass -File amigos\jogar-dk.ps1
```

Conecte um controle antes de abrir. **F11** alterna a tela cheia e **F10** mostra o fps. Se o PC tiver mais de uma placa, defina parte do nome da certa antes de abrir, por exemplo `$env:TOTK_GPU_NAME = "5090"`.

### O que esperar

Testado só em uma RTX 5090 com driver 617.14, a partir de um save no começo do jogo.

| O que acontece | Motivo |
|---|---|
| Engasgos ao ver uma área pela primeira vez | Shaders e pipelines sendo preparados; ficam salvos para as próximas vezes |
| Falta algum efeito ou luz | O projeto e o `amigos\jogar-dk.ps1` pulam shaders que derrubam a GPU na NVIDIA |
| Jogo fecha com `device lost` no log | Problema conhecido na NVIDIA, ainda sem causa definida; pode aparecer em áreas novas |
| Imagem interna em 1620p, mesmo em 4K | O jogo ainda desenha na resolução dele e o FSR amplia |
| Limite de 60 fps | Acima disso não há suporte para este jogo |

Em placas AMD ou Intel, a lista de shaders pulados não foi testada. Comece abrindo o jogo direto, por `build\dkb100\dkb.exe`, depois de definir `$env:TOTK_GPU_NAME`.

Se o jogo fechar, copie `build\dkb100\logs\totk.log` antes de abrir de novo, porque a próxima execução renomeia esse arquivo. Como investigar: [`amigos/AGENTS.md`](amigos/AGENTS.md).

### Atualizar

```powershell
git pull
```

Depois repita, na mesma janela da etapa 4 (com `$dump`, `PATH` e `PYTHONUTF8` definidos), o `build_xlate.py`, o `gen.py` e o `build_game.py`.

---

[![License: GPL-3.0-or-later](https://img.shields.io/badge/license-GPL--3.0--or--later-blue)](LICENSE)
[![Content guard](https://github.com/Lucas-blip-png/dkb-pc-recomp/actions/workflows/content-guard.yml/badge.svg?branch=bananza)](https://github.com/Lucas-blip-png/dkb-pc-recomp/actions/workflows/content-guard.yml)
[![Stars](https://img.shields.io/github/stars/Lucas-blip-png/dkb-pc-recomp?style=flat)](https://github.com/Lucas-blip-png/dkb-pc-recomp/stargazers)
[![Help wanted](https://img.shields.io/github/issues/Lucas-blip-png/dkb-pc-recomp/help%20wanted?label=help%20wanted)](https://github.com/Lucas-blip-png/dkb-pc-recomp/issues?q=is%3Aopen+label%3A%22help+wanted%22)
[![Discussions](https://img.shields.io/github/discussions/Lucas-blip-png/dkb-pc-recomp)](https://github.com/Lucas-blip-png/dkb-pc-recomp/discussions)
[![Ko-fi](https://img.shields.io/badge/Ko--fi-support%20the%20work-ff5e5b?logo=ko-fi&logoColor=white)](https://ko-fi.com/lucasblippng)

**DKB Recomp** is a static recompilation of *Donkey Kong Bananza* (Nintendo Switch 2, 2025) into a native Windows
x86-64 application with a Vulkan renderer. There is no emulator at run time: the game's ARM64 code is translated to C
ahead of time and compiled into one executable, and its graphics calls are answered by a host implementation of
NVN 2. It is built on [TotK Recomp](https://github.com/valentderah/totk-pc-recomp), which does the same for *Tears of
the Kingdom* on the original Switch.

As far as we know, no other static recompilation of a Switch 2 game is public.

> [!IMPORTANT]
> **No game files are included, and none ever will be.** You need your own copy of *Donkey Kong Bananza*, dumped
> from your own console. Instructions for obtaining those files will not be provided. There are no downloadable
> builds: everyone builds from their own dump.

## Status

**Not playable yet.** The game boots, goes through the title screen into the tutorial cave, renders the 3D scene and
answers the controller: you can walk and punch through the mining tunnel, with the guide movies playing, and one
hand-played run reached the Ingot Isle Cave-In section. It still
can crash (on NVIDIA two light quads are skipped to avoid a GPU fault,
[#9](https://github.com/Lucas-blip-png/dkb-pc-recomp/issues/9)), and
many effects are missing.
There is no release. An installer builds the game from your own dump: [docs/installer.md](docs/installer.md).
Progress, day by day: [docs/devlog.md](docs/devlog.md).

| Phase | | State |
| --- | --- | --- |
| F0 CPU | ✅ | `main` and `sdk` (180,061 functions) lift with no unsupported instruction (ARMv8.3 pointer authentication and `LDAPR` added). Differential tests against Unicorn pass. |
| F1 OS | ✅ | Boots on TotK Recomp's Horizon host with the Switch 2 differences: RomFS, save, audio, controller. |
| F2 NVN 2 | ✅ | 700 NVN 2 entry points answered; the game loop runs. 51 new command buffer calls (mesh shaders, VRS, DLSS, push constants…) are accepted but not recorded yet. |
| F3 Shaders | ✅ | All 4,820 Ampere shader stages of the first 3D scene go through Eglantine's Ampere-to-Maxwell lowering and TotK Recomp's translator to SPIR-V. |
| F4 Vulkan | ✅ | The title screen and the tutorial's 3D scene render. |
| F5 Playable | 🚧 | Controller, guide movies (VP9) and push constants work. Open: a GPU fault some minutes in on NVIDIA, the black destructible terrain (its geometry stage, [#45](https://github.com/Lucas-blip-png/dkb-pc-recomp/issues/45)), some textures, performance outside the tutorial. |

The plan, phase by phase: [docs/bananza-plan.md](docs/bananza-plan.md). What is open right now:
[Roadmap to playable](https://github.com/Lucas-blip-png/dkb-pc-recomp/issues/10).

## How it works

```mermaid
flowchart LR
    subgraph offline["At build time, on your PC"]
        exefs["Your dump: main + sdk<br/>(ARM64)"] --> lifter["Lifter<br/>recomp/"] --> c["C code"] --> clang["Clang"] --> exe["dkb.exe"]
    end
    subgraph runtime["At run time"]
        exe --> host["Horizon host<br/>threads, files, audio, input"]
        exe --> nvn["NVN 2 front end<br/>runtime/nvn_*"] --> vk["Vulkan back end"]
        sass["Ampere shaders"] --> lower["Eglantine lowering<br/>Ampere → Maxwell"] --> xlate["Translator<br/>tools/xlate"] --> spirv["SPIR-V"] --> vk
    end
```

The longer version is in [docs/architecture.md](docs/architecture.md) (shared with TotK Recomp) and
[docs/bananza-shaders.md](docs/bananza-shaders.md) (the NVN 2 shader work).

## How to help

Each open problem is a separate, well-bounded job with its own issue. Pick one, say in the issue that you are on it,
and keep each pull request to one topic. Issues labelled
[`in progress`](https://github.com/Lucas-blip-png/dkb-pc-recomp/issues?q=is%3Aopen+label%3A%22in+progress%22) are
already taken, and the top of the [roadmap](https://github.com/Lucas-blip-png/dkb-pc-recomp/issues/10) says what is
being worked on right now.

**No code needed**, only your PC and your own copy of the game:

- [#3](https://github.com/Lucas-blip-png/dkb-pc-recomp/issues/3) **Test on your GPU.** Everything so far was checked
  on one NVIDIA card. Runs on AMD, Intel and other NVIDIA cards, with logs, show what breaks there.
- [#7](https://github.com/Lucas-blip-png/dkb-pc-recomp/issues/7) **Play past the tutorial** and report where it stops.
- [#9](https://github.com/Lucas-blip-png/dkb-pc-recomp/issues/9) **The GPU fault after the first guide movie**: seen
  on three NVIDIA drivers (617.14, 617.42, 621.01); runs on AMD and Intel would show whether it is NVIDIA's.

**Code** ([help wanted](https://github.com/Lucas-blip-png/dkb-pc-recomp/issues?q=is%3Aopen+label%3A%22help+wanted%22)):

- [#5](https://github.com/Lucas-blip-png/dkb-pc-recomp/issues/5) **Checkerboard textures** on some rock surfaces. The Switch 2 GOB layout (f4f7b17) fixes the gold rock in the tutorial cave; the other surfaces still need a check.
- [#6](https://github.com/Lucas-blip-png/dkb-pc-recomp/issues/6) **NVN 2 calls not recorded yet**: mesh shaders, VRS,
  DLSS and others.
- **Symbols.** Function names help debugging. They come from
  [GRAnimated/DKBananza](https://github.com/GRAnimated/DKBananza), which welcomes contributions too.

Your first contribution, step by step:

1. Build from your own dump ([Building from source](#building-from-source)).
2. Run it as in [docs/dkb-testing.md](docs/dkb-testing.md) and note how far it gets on your machine.
3. Report it on #3 or #7, or pick an issue above.

Before you open a pull request, read [CONTRIBUTING.md](CONTRIBUTING.md). Its hard rule: nothing that came out of the
game goes into the repository, not in commits, issues or pull requests. Run `python tools/check_content.py --staged`
before committing; CI runs the same check. Questions go to
[Discussions](https://github.com/Lucas-blip-png/dkb-pc-recomp/discussions). Everyone taking part follows the
[code of conduct](CODE_OF_CONDUCT.md).

## Support the project

If you want to support the work without writing code, tips go to
[ko-fi.com/lucasblippng](https://ko-fi.com/lucasblippng). A tip pays for time on the project; it buys no game files,
builds or early access, and everything stays open source here. Starring the repository and sharing it with people who
know GPUs, ARM64 or the Switch also helps.

## Building from source

The toolchain is TotK Recomp's ([docs/building.md](docs/building.md)): MSYS2 UCRT64 Clang, Ninja, Python 3.12 and the
.NET SDK for the shader translator. With the Bananza ExeFS and RomFS from your own dump:

```
.venv\Scripts\python tools\build_xlate.py
.venv\Scripts\python recomp\gen.py --exefs <exefs> --out generated\dkb100 --modules main,sdk --patches recomp\patches-dkb100.txt
.venv\Scripts\python tools\dkb_expected.py --exefs <exefs> --name dkb100 --display 1.0.0
.venv\Scripts\python tools\dkb_pack_romfs.py --dir <romfs folder> --out build\extracted\dkb100\romfs
.venv\Scripts\python tools\build_game.py --version dkb100 --expected tools\data\expected-dkb100.json --exefs <exefs> --romfs build\extracted\dkb100\romfs
```

Everything the build writes stays under `build\` and `generated\`, which git ignores. The game uses about 13 GB of
RAM, so 16 GB is the minimum for now. Running and testing: [docs/dkb-testing.md](docs/dkb-testing.md).

## FAQ

**Can I play it?** Not yet. It reaches the tutorial and crashes often. Follow the
[roadmap](https://github.com/Lucas-blip-png/dkb-pc-recomp/issues/10) or the [devlog](docs/devlog.md).

**Will there be a download?** No. The executable is made from the game's own code, so it cannot be shared. Everyone
builds it from their own dump; the installer does this for you ([docs/installer.md](docs/installer.md)).

**Which version of the game?** Base 1.0.0. Update 458752 has a different layout and is not supported yet.

**Linux?** TotK Recomp's toolchain supports Linux, so it is possible; nobody has tried with Bananza yet.

**Why GPL?** The shader lowering comes from Eglantine (Eden Emulator Project), which is GPL. Files that came from TotK
Recomp keep their MIT terms.

**How is AI used?** Most of the code and documentation is written by AI coding agents (Claude Code), as in TotK
Recomp, and checked by running the game and the differential tests. AI-assisted pull requests are welcome; you are
responsible for having read and run them.

## Credits

- [TotK Recomp](https://github.com/valentderah/totk-pc-recomp) by valentderah, the base of everything here, and the
  projects it builds on: [LAS Recomp](https://github.com/peiikai/LASRecomp),
  [MacNativeGames](https://github.com/ly05010419/MacNativeGames), [nxnative](https://github.com/seedds/nxnative),
  [SavageWindRecomp](https://github.com/Revivedx/SavageWindRecomp), [Ryujinx](https://github.com/Ryujinx/Ryujinx),
  [deko3d](https://github.com/devkitPro/deko3d), [hactool](https://github.com/SciresM/hactool) and the rest listed in
  [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).
- [GRAnimated/DKBananza](https://github.com/GRAnimated/DKBananza) for the game's symbols and research.
- [Eglantine](https://git.eden-emu.dev/Franseven/PokeDinner-a-Eglantine-Fork) (Eden Emulator Project) for the
  Ampere-to-Maxwell shader lowering and its Switch 2 notes, and [Mesa NAK](https://gitlab.freedesktop.org/mesa/mesa)
  for the SM70+ encodings both build on.
- [libvpx](https://chromium.googlesource.com/webm/libvpx) for the movies.
- [Switchbrew](https://switchbrew.org) for the Switch 2 `GetInfo` ids, and the Switch homebrew community.

## License

DKB Recomp as a whole is under the [GNU GPL v3 or later](LICENSE), because it includes Eglantine's GPL Ampere shader
lowering (`runtime/third_party/eglantine/`). The files that came from TotK Recomp keep their
[MIT License](LICENSE-MIT); third-party code keeps its own license ([THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)).
The license grants nothing for Nintendo's game.

DKB Recomp is an independent, non-commercial fan project, not affiliated with or endorsed by Nintendo. *Donkey Kong
Bananza* and *Nintendo Switch 2* are trademarks of Nintendo.
