#!/usr/bin/env pwsh
#
# Audita-Repos.ps1 — cada repositório do portfólio tem o mínimo?
#
#   pwsh pwsh/Audita-Repos.ps1 ..
#   pwsh pwsh/Audita-Repos.ps1 -Raiz .. -Json
#
# ## Por que esta ferramenta existe
#
# O portfólio tem 5 repositórios publicados e 10 pastas ainda por publicar, e
# eles divergiram: um ganhou `.gitattributes` depois de o CRLF quebrar um
# script no runner, outro ainda não tem. Um tem `LICENSE`, outro foi criado sem.
#
# A auditoria é trivial de fazer à mão **uma vez** e impossível de manter: cada
# repositório novo reabre a pergunta.
#
# ## Por que em PowerShell, e por que existe um par em Bash
#
# O plano do portfólio pede o par POSIX↔Windows: "o mesmo script, duas
# culturas". `bash/audita-repos.sh` faz o MESMO trabalho, e a dupla existe para
# a comparação ser lado a lado em vez de teórica.
#
# A diferença que importa não é sintaxe, é **o que a linguagem considera um
# valor**:
#
#   * em Bash, a saída de um comando é TEXTO, e estruturar significa escolher
#     um separador e esperar que ele não apareça nos dados;
#   * em PowerShell, é um OBJETO, e `Where-Object`/`Select-Object` operam em
#     campos nomeados. O `-Json` abaixo é uma linha; em Bash é uma função de
#     escape que eu teria de escrever.
#
# A recíproca também vale, e está anotada no par em Bash: para "rodar um
# comando e olhar o código de saída", o Bash é mais direto, e o PowerShell
# precisa de `$LASTEXITCODE` com a ressalva de que `$?` significa outra coisa.
#
# ## Códigos de saída
#
#   0  todos os repositórios têm o mínimo
#   1  algum item obrigatório falta
#   2  erro de uso

[CmdletBinding()]
param(
    # A raiz onde os repositórios moram. O padrão é o diretório acima deste,
    # que é onde o portfólio fica.
    [string] $Raiz = (Join-Path $PSScriptRoot '..' '..'),

    # Saída em JSON, para consumo por outra ferramenta.
    [switch] $Json,

    # Lista os itens verificados e sai.
    [switch] $Listar
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ---------------------------------------------------------------- o que checar
#
# Cada item diz POR QUE é obrigatório. Um checklist sem o motivo vira cerimônia
# e alguém o apaga na primeira vez que incomoda.

$Itens = @(
    @{
        Nome = 'README.md'
        Tipo = 'arquivo'
        Porque = 'o projeto precisa se explicar sem que alguem abra o codigo'
    }
    @{
        Nome = 'LICENSE'
        Tipo = 'arquivo'
        Porque = 'repositorio publico sem licenca nao pode ser usado por ninguem'
    }
    @{
        Nome = '.gitattributes'
        Tipo = 'arquivo'
        Porque = 'editado no Windows, executado no Linux: sem eol=lf, um script com CRLF falha no runner com erro que nao menciona CRLF'
    }
    @{
        Nome = '.github/workflows'
        Tipo = 'diretorio'
        Porque = 'verificacao que nao roda sozinha nao e verificacao'
    }
    @{
        Nome = '.gitignore'
        Tipo = 'arquivo'
        Porque = 'sem ele, artefato de build entra no repositorio -- o p12 tem um build autocontido de 84 MB'
    }
)

if ($Listar) {
    Write-Output "Itens verificados em cada repositorio:`n"
    foreach ($i in $Itens) {
        Write-Output ("  {0,-22} ({1})" -f $i.Nome, $i.Tipo)
        Write-Output ("  {0,-22}  porque: {1}" -f '', $i.Porque)
        Write-Output ''
    }
    exit 0
}

# ------------------------------------------------------------------ descoberta

if (-not (Test-Path -LiteralPath $Raiz -PathType Container)) {
    Write-Error "raiz nao encontrada: $Raiz"
    exit 2
}

# Um repositório é uma pasta com `.git`. Não basta ser pasta: a raiz do
# portfólio tem pastas de apoio.
$repos = Get-ChildItem -LiteralPath $Raiz -Directory |
    Where-Object { Test-Path (Join-Path $_.FullName '.git') } |
    Sort-Object Name

if ($repos.Count -eq 0) {
    Write-Error "nenhum repositorio git encontrado em $Raiz"
    exit 2
}

# ------------------------------------------------------------------- auditoria
#
# O resultado é uma coleção de OBJETOS, não de linhas de texto. É isto que
# torna `-Json`, a ordenação e o filtro abaixo triviais -- e é a diferença
# central em relação ao par em Bash.

$resultado = foreach ($repo in $repos) {
    $faltando = [System.Collections.Generic.List[string]]::new()

    foreach ($item in $Itens) {
        $caminho = Join-Path $repo.FullName $item.Nome
        $tipo = if ($item.Tipo -eq 'diretorio') { 'Container' } else { 'Leaf' }

        if (-not (Test-Path -LiteralPath $caminho -PathType $tipo)) {
            $faltando.Add($item.Nome)
        }
    }

    # Tem remoto? Um repositório local sem remoto não está publicado, e isso
    # não é falha -- é estado. A auditoria reporta, não julga.
    $temRemoto = $false
    try {
        Push-Location $repo.FullName
        $null = & git remote 2>$null
        # `$LASTEXITCODE` e NAO `$?`: para executaveis externos, `$?` indica se
        # o PowerShell conseguiu INVOCAR o comando, nao o codigo que ele
        # devolveu. Confundir os dois e o erro classico de quem vem do shell
        # POSIX, e ele e silencioso.
        if ($LASTEXITCODE -eq 0) {
            $temRemoto = [bool](& git remote)
        }
    }
    finally {
        Pop-Location
    }

    [PSCustomObject]@{
        Repo      = $repo.Name
        Completo  = ($faltando.Count -eq 0)
        Faltando  = $faltando.ToArray()
        Publicado = $temRemoto
    }
}

# --------------------------------------------------------------------- relatório

if ($Json) {
    # Uma linha. Em Bash, serializar isto corretamente exige escapar aspas,
    # barras e quebras de linha à mão -- e é onde essa comparação deixa de ser
    # sobre gosto.
    $resultado | ConvertTo-Json -Depth 4
}
else {
    Write-Output ''
    Write-Output ('{0,-18} {1,-10} {2,-11} {3}' -f 'repo', 'completo', 'publicado', 'faltando')
    Write-Output ('-' * 70)

    foreach ($r in $resultado) {
        Write-Output ('{0,-18} {1,-10} {2,-11} {3}' -f
            $r.Repo,
            $(if ($r.Completo) { 'sim' } else { 'NAO' }),
            $(if ($r.Publicado) { 'sim' } else { '-' }),
            $(if ($r.Faltando) { $r.Faltando -join ', ' } else { '' }))
    }

    Write-Output ('-' * 70)

    $incompletos = @($resultado | Where-Object { -not $_.Completo })

    Write-Output ('{0} repositorio(s), {1} completo(s), {2} incompleto(s)' -f
        $resultado.Count,
        ($resultado.Count - $incompletos.Count),
        $incompletos.Count)

    if ($incompletos.Count -gt 0) {
        Write-Output ''
        Write-Output 'Por que cada item e obrigatorio:'
        $pendentes = $incompletos.Faltando | Select-Object -Unique | Sort-Object
        foreach ($nome in $pendentes) {
            $item = $Itens | Where-Object { $_.Nome -eq $nome }
            Write-Output ("  {0,-22} {1}" -f $nome, $item.Porque)
        }
    }
}

exit $(if (@($resultado | Where-Object { -not $_.Completo }).Count -gt 0) { 1 } else { 0 })
