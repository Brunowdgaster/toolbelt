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
    #
    # `Join-Path` ANINHADO, e não `Join-Path a b c`: a forma de três argumentos
    # (`-AdditionalChildPath`) só existe no PowerShell 7+, e no Windows
    # PowerShell 5.1 ela falha com "PositionalParameterNotFound" -- e falha na
    # avaliação do PADRÃO, então só aparece quando o parâmetro NÃO é passado.
    #
    # É a primeira das duas fricções que este par expôs entre as versões, e
    # ambas estão documentadas no README.
    [string] $Raiz = (Join-Path (Join-Path $PSScriptRoot '..') '..'),

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
# `@( ... )` aqui pelo MESMO motivo do `$resultado` abaixo: com um repositorio
# so, o pipeline devolve o objeto e nao um array, e `$repos.Count` lanca sob
# StrictMode. Cada `.Count` neste arquivo tem a fonte envolvida em `@()`.
$repos = @(Get-ChildItem -LiteralPath $Raiz -Directory |
    Where-Object { Test-Path (Join-Path $_.FullName '.git') } |
    Sort-Object Name)

if ($repos.Count -eq 0) {
    Write-Error "nenhum repositorio git encontrado em $Raiz"
    exit 2
}

# ------------------------------------------------------------------- auditoria
#
# O resultado é uma coleção de OBJETOS, não de linhas de texto. É isto que
# torna `-Json`, a ordenação e o filtro abaixo triviais -- e é a diferença
# central em relação ao par em Bash.

# `@( ... )` em volta do laço É NECESSÁRIO, e a falta dele passou local e
# quebrou no CI.
#
# Em PowerShell, um pipeline que produz UM objeto devolve o objeto, não um
# array de um elemento -- e sob `Set-StrictMode`, `.Count` nesse objeto lança
# "The property 'Count' cannot be found on this object".
#
# Local havia 5 repositórios e o laço devolvia array; no runner o repositório
# está sozinho e devolveu um objeto só. É o caso de borda clássico do
# PowerShell, e é a terceira fricção que este par expôs -- as duas primeiras
# foram `Join-Path` de três argumentos e o BOM que o 5.1 exige.
#
# No par em Bash isso não existe: array é explícito, e um elemento é um array
# de um elemento.
$resultado = @(foreach ($repo in $repos) {
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
    #
    # ## Chamar um programa externo em PowerShell tem TRÊS camadas
    #
    # Esta é a terceira fricção que este par expôs, e a que mais favorece o
    # Bash:
    #
    #   1. `$?` indica se o PowerShell conseguiu INVOCAR o comando, não o
    #      código que ele devolveu. Confundir os dois é o erro clássico de quem
    #      vem do POSIX, e é silencioso;
    #   2. o código de verdade está em `$LASTEXITCODE`;
    #   3. e com `$ErrorActionPreference = 'Stop'`, o que o programa escreve em
    #      STDERR vira erro TERMINANTE -- então um `git remote` num diretório
    #      com `.git` inválido (repositório corrompido, submódulo, arquivo
    #      `.git` de worktree) aborta a auditoria inteira.
    #
    # A terceira camada apareceu num teste com um `.git` falso, e é por isso
    # que o `$ErrorActionPreference` é rebaixado só em volta da chamada nativa.
    #
    # Em Bash as três colapsam em `if git -C "$repo" remote >/dev/null 2>&1`.
    $temRemoto = $false

    $eapAnterior = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'

    try {
        $saidaGit = & git -C $repo.FullName remote 2>&1
        if ($LASTEXITCODE -eq 0) {
            $temRemoto = [bool](@($saidaGit | Where-Object { $_ -and "$_".Trim() }).Count)
        }
    }
    catch {
        $temRemoto = $false
    }
    finally {
        $ErrorActionPreference = $eapAnterior
    }

    [PSCustomObject]@{
        Repo      = $repo.Name
        Completo  = ($faltando.Count -eq 0)
        Faltando  = $faltando.ToArray()
        Publicado = $temRemoto
    }
})

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
        @($resultado).Count,
        (@($resultado).Count - $incompletos.Count),
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
