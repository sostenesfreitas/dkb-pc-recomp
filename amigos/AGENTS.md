# Instruções para agentes de IA

Você está ajudando alguém a compilar *Donkey Kong Bananza* como executável nativo do Windows, usando a branch `local-prs` do fork [sostenesfreitas/dkb-pc-recomp](https://github.com/sostenesfreitas/dkb-pc-recomp), baseada em [dkb-pc-recomp](https://github.com/Lucas-blip-png/dkb-pc-recomp) `db77cdf` (branch `bananza`). O resultado é experimental: pode travar e faltam efeitos.

## Regras
- Trabalhe só com o dump da própria pessoa. Se ela não tiver, pare. Não explique como obter ou extrair o jogo, nem procure jogo, keys ou firmware.
- Nunca envie, publique ou compartilhe `dkb.exe`, `generated\`, `build\`, cache de shaders, saves ou o dump. Isso também vale para issues, PRs e pastes.
- Peça confirmação antes de instalar programas no sistema e antes de postar qualquer coisa no GitHub.
- Leia `AGENTS.md`, `CONTRIBUTING.md` e `docs/building.md` do projeto: se contradisserem este arquivo sobre como compilar, siga o projeto e avise.
- Não diga que funcionou sem verificar. Relate erros com a saída real.

## 1. Verificar antes de começar
- Windows x64, CPU com AVX2, Vulkan 1.3, 16 GB de RAM, cerca de 60 GB livres.
- O dump precisa ter `base\exefs` (`main`, `sdk`, `rtld`, `main.npdm`) e `base\romfs`.
- Só a versão base 1.0.0 serve: compare o SHA-256 dos arquivos de `exefs` com `tools\data\expected-dkb100.json`. A atualização 458752 e o DLC não têm suporte, e um `exefs` de atualização falha nessa checagem.

## 2. Ferramentas
Python 3.12 e Git, mais:
```powershell
winget install --id MSYS2.MSYS2 -e
winget install --id Microsoft.VisualStudio.BuildTools -e --override "--quiet --wait --norestart --add Microsoft.VisualStudio.Workload.VCTools --includeRecommended"
winget install --id Microsoft.DotNet.SDK.10 -e
```
Os instaladores podem pedir permissão de administrador: avise a pessoa. No shell do MSYS2 (UCRT64), rode `pacman -Syuu --noconfirm` duas vezes e depois instale os pacotes listados em `docs/building.md`.

## 3. Código
```powershell
git clone -b local-prs https://github.com/sostenesfreitas/dkb-pc-recomp
cd dkb-pc-recomp
py -3.12 -m venv .venv
.venv\Scripts\python -m pip install -r tools\requirements.txt
```

## 4. Compilar
Use `C:\msys64\ucrt64\bin` e `C:\Program Files (x86)\Microsoft Visual Studio\Installer` no início do PATH e `PYTHONUTF8=1`. Rode os comandos da etapa 4 do `README.md`, nesta ordem. A etapa do código gerado e a do `build_game.py` são as mais pesadas; rode-as em segundo plano.

Para verificar: `build\dkb100\dkb.exe --selftest` deve terminar com `selftest: passed (0 failures)`.

## 5. Rodar
Copie `amigos\totk.ini` para `build\dkb100` e use `amigos\jogar-dk.ps1`, como na etapa 5 do `README.md`. Sem o `totk.ini`, o terreno destrutível fica preto.
- Ajuste `TOTK_GPU_NAME` para parte do nome da placa, se o PC tiver mais de uma.
- Rode de dentro do repositório: o jogo acha o tradutor procurando `build\xlate` nas pastas acima dele.
- Os engasgos da primeira passada por uma área são normais: vêm de shaders e pipelines sendo preparados.

## 6. Se travar
O log é `build\dkb100\logs\totk.log`. Copie antes de reabrir, porque a execução seguinte o renomeia.

`device fault ... instruction pointer (invalid)` em uma placa NVIDIA é um problema conhecido e sem causa definida. Foi visto nas drivers 617.14, 617.42 e 621.01. `TOTK_PIPE_SYNC=1`, `TOTK_PIPE_WAIT=draw` e `TOTK_GPL=0` não resolveram na RTX 5090 testada.

Para investigar:
1. Rode com `DKB_GPU_CHECKPOINTS=1`. Na queda, o log mostra os últimos pipelines que a GPU alcançou, com os nomes NVN 2 dos shaders. O arquivo `logs\dkb-fault-*.bin` pode conter código de shader: nunca o envie.
2. Os suspeitos são os últimos pipelines antes da queda, não só o último, porque a GPU trabalha atrás do jogo.
3. Teste por metades com `DKB_SKIP_VS=<hex>,<hex>` (vertex) ou `DKB_SKIP_FS` (fragment), no máximo 16 valores cada. Isso faz sumir o que esses shaders desenham, então peça à pessoa para dizer o que mudou na tela.

A lista em `amigos\jogar-dk.ps1` só foi testada em uma RTX 5090, driver 617.14. Em AMD ou Intel, teste primeiro sem `DKB_SKIP_VS` e `DKB_SKIP_FS`. Desde o upstream `0f854a4`, o FMZ vem ligado nos vertex shaders (`DKB_FMZ=0` desliga) e evitou a queda da cutscene do fim do tutorial; talvez a lista nem seja mais necessária.

## Sobre esta branch
Ela é o upstream `bananza` (os PRs #67, #68 e #72 já entraram lá) mais esta pasta e o guia do `README.md`. Para atualizar, faça merge do upstream, não rebase: o instalador usa `git pull --ff-only`.
