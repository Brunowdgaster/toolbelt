#!/usr/bin/env pwsh
#
# verifica.ps1 — a metade WINDOWS da suíte.
#
#   pwsh verifica.ps1
#   powershell -File verifica.ps1
#
# ## Por que existe um segundo verificador
#
# `verifica.sh` roda em bash e cobre as ferramentas POSIX. Mas duas ferramentas
# aqui são **do mundo Windows**, e fingir que bash as testa seria pior que
# declarar a separação:
#
#   * `ahk/Verifica-Ambiente.ahk` — AutoHotkey só existe no Windows, e o que a
#     ferramenta faz (ler a lista de janelas visíveis do desktop) não tem
#     equivalente num runner Linux;
#   * `pwsh/Audita-Repos.ps1` — tem par em bash, e o `verifica.sh` já compara
#     os dois. Aqui ele é testado do lado nativo.
#
# A separação é a mesma do par POSIX↔Windows que o projeto já tem: duas
# culturas, cada uma verificada na sua.
#
# ## A armadilha que custou duas janelas na tela do usuário
#
# O AutoHotkey reporta erro por **caixa de diálogo**, e o processo fica parado
# esperando alguém fechar. Em automação isso é fatal: o script pendura e nada
# no log diz por quê.
#
# `/ErrorStdOut` manda erro de SCRIPT para stdout. Mas erro de **launcher**
# ("script not found") acontece ANTES de o script ser lido, e a janela aparece
# de todo jeito. Aconteceu duas vezes durante o desenvolvimento desta
# ferramenta: uma com `/validate` sem `/ErrorStdOut`, outra ao passar um
# caminho POSIX (`./ahk/...`) para um programa Windows.
#
# Por isso este verificador:
#
#   1. confere que o arquivo EXISTE antes de invocar o AHK;
#   2. usa sempre caminho absoluto do Windows;
#   3. passa sempre `/ErrorStdOut`.

Set-StrictMode -Version Latest

$passou = 0
$falhou = 0

function Ok($msg) {
    Write-Host "  ok    $msg" -ForegroundColor Green
    $script:passou++
}

function Bad($msg, $detalhe = '') {
    Write-Host "  FALHA $msg" -ForegroundColor Red
    if ($detalhe) { Write-Host "        $detalhe" }
    $script:falhou++
}

function Igual($rotulo, $esperado, $obtido) {
    if ("$esperado" -eq "$obtido") { Ok $rotulo }
    else { Bad $rotulo "esperado '$esperado', obtido '$obtido'" }
}

$Raiz = $PSScriptRoot

Write-Host ''
Write-Host '=============================================================='
Write-Host '  toolbelt — a metade Windows da suíte'
Write-Host '=============================================================='

# ------------------------------------------------------------------- pwsh
Write-Host ''
Write-Host 'pwsh/Audita-Repos.ps1 — cada repositório tem o mínimo?'
Write-Host ''

$auditor = Join-Path $Raiz 'pwsh\Audita-Repos.ps1'

if (-not (Test-Path $auditor)) {
    Bad 'pwsh/Audita-Repos.ps1 não existe'
}
else {
    # O JSON tem de ser parseável: é a ponta que outra ferramenta consome.
    $json = & $auditor -Raiz (Join-Path $Raiz '..') -Json 2>$null | Out-String
    try {
        $obj = $json | ConvertFrom-Json
        Ok "o JSON parseia ($(@($obj).Count) repositorios)"
    }
    catch {
        Bad 'o JSON não parseia' $_.Exception.Message
    }

    # `--listar` explica POR QUE cada item é obrigatório. Checklist sem motivo
    # vira cerimônia, e alguém o apaga na primeira vez que incomoda.
    $listagem = & $auditor -Listar 2>$null | Out-String
    if ($listagem -match 'porque:') { Ok '-Listar diz por que cada item é obrigatório' }
    else { Bad '-Listar não explica os itens' }
}

# -------------------------------------------------------------------- ahk
Write-Host ''
Write-Host 'ahk/Verifica-Ambiente.ahk — o que no desktop contamina a medição'
Write-Host ''

$script = Join-Path $Raiz 'ahk\Verifica-Ambiente.ahk'

# Candidatos, em ordem: instalação padrão, portátil no perfil do usuário.
$ahk = @(
    "$env:LOCALAPPDATA\ahk2\AutoHotkey64.exe"
    "$env:ProgramFiles\AutoHotkey\v2\AutoHotkey64.exe"
    "$env:ProgramFiles\AutoHotkey\AutoHotkey.exe"
) | Where-Object { Test-Path $_ } | Select-Object -First 1

if (-not $ahk) {
    Bad 'AutoHotkey v2 não encontrado' 'baixe ahk-v2.zip de autohotkey.com e extraia em %LOCALAPPDATA%\ahk2'
}
elseif (-not (Test-Path $script)) {
    # ESTA verificação existe por causa da janela de "script not found": o AHK
    # abre diálogo para erro de launcher, e `/ErrorStdOut` não cobre isso.
    # Conferir a existência AQUI garante que o AHK nunca recebe caminho ruim.
    Bad 'ahk/Verifica-Ambiente.ahk não existe'
}
else {
    # 1. Sintaxe. `/validate` compila e sai, sem executar.
    & $ahk /ErrorStdOut /validate $script 2>&1 | Out-Null
    Igual 'o script valida (sintaxe)' 0 $LASTEXITCODE

    # 2. As funções puras, com entradas fixas. Não dependem do desktop, então
    #    rodam igual em qualquer máquina.
    $auto = & $ahk /ErrorStdOut $script --autoteste 2>&1 | Out-String
    $codAuto = $LASTEXITCODE

    if ($auto -match '(\d+) passaram, (\d+) falharam') {
        Igual "autoteste: $($Matches[1]) passaram, $($Matches[2]) falharam" '0' $Matches[2]
    }
    else {
        Bad 'o autoteste não reportou placar' ($auto -split "`n" | Select-Object -First 2)
    }

    Igual 'o autoteste sai 0' 0 $codAuto

    # 3. O JSON tem de ser UTF-8 SEM BOM e parseável.
    #
    #    Sem o encoding explícito, o AHK escreve na codificação ANSI do
    #    sistema, e um título de janela com acento sai como "dom?nio" --
    #    inválido para qualquer consumidor que espere UTF-8. E com `"UTF-8"`
    #    (em vez de `"UTF-8-RAW"`) viria BOM, que invalida JSON para parser
    #    estrito. As duas pontas são testadas aqui.
    $tmp = Join-Path $env:TEMP 'toolbelt_ahk.json'
    Remove-Item $tmp -ErrorAction SilentlyContinue
    cmd /c "`"$ahk`" /ErrorStdOut `"$script`" --json > `"$tmp`" 2>&1" | Out-Null

    if (-not (Test-Path $tmp)) {
        Bad 'o modo --json não produziu saída'
    }
    else {
        $bytes = [System.IO.File]::ReadAllBytes($tmp)

        if ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) {
            Bad 'o JSON tem BOM' 'use "UTF-8-RAW" no FileAppend, não "UTF-8"'
        }
        else {
            Ok 'o JSON não tem BOM'
        }

        try {
            $texto = [System.Text.Encoding]::UTF8.GetString($bytes)
            $o = $texto | ConvertFrom-Json
            Ok "o JSON parseia ($(@($o.processos).Count) processos)"

            if ($null -ne $o.limiar) { Ok 'o JSON traz o limiar usado' }
            else { Bad 'o JSON não traz o limiar' }
        }
        catch {
            Bad 'o JSON não parseia' $_.Exception.Message
        }
    }

    # 4. Opção desconhecida sai 2, em vez de ignorar em silêncio.
    & $ahk /ErrorStdOut $script --opcao-que-nao-existe 2>&1 | Out-Null
    Igual 'opção desconhecida sai 2' 2 $LASTEXITCODE
}

Write-Host ''
Write-Host '=============================================================='
Write-Host "  $passou passaram, $falhou falharam"

exit $(if ($falhou -eq 0) { 0 } else { 1 })
