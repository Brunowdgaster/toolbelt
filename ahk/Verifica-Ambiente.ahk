#Requires AutoHotkey v2.0
#SingleInstance Off

; Verifica-Ambiente.ahk — o que no desktop do Windows vai contaminar a medição.
;
;   AutoHotkey64.exe /ErrorStdOut Verifica-Ambiente.ahk
;   AutoHotkey64.exe /ErrorStdOut Verifica-Ambiente.ahk --json
;   AutoHotkey64.exe /ErrorStdOut Verifica-Ambiente.ahk --limiar 5
;
; ## Por que esta ferramenta existe
;
; Nesta sessão do portfólio, uma medição do p03-otp-mesh foi publicada e depois
; corrigida porque havia **um jogo e um navegador com vídeo** abertos enquanto
; ela rodava. O `bench/calibra.sh` daquele projeto nasceu disso: ele mede um
; laço fixo e detecta que a máquina está ocupada.
;
; Mas o `calibra.sh` roda dentro do WSL2, e lá ele detecta o **efeito** sem
; poder dizer a **causa**: processos do Windows não aparecem no `/proc` do
; Linux. Foi medido naquele projeto — com 4 núcleos do Windows ocupados, o laço
; inflou 74% e o `loadavg` do WSL2 mal se moveu.
;
; Esta ferramenta é a outra metade: ela olha o desktop do Windows e **nomeia**
; o que está consumindo CPU, com o nome do processo e o título da janela.
;
; ## Por que em AutoHotkey
;
; Porque o problema é acesso ao desktop do Windows, e esse é o terreno do AHK:
; lista de janelas visíveis, títulos, processo de cada uma, tudo em builtin sem
; biblioteca. O mesmo em PowerShell precisaria de `Get-Process` mais P/Invoke
; para os títulos de janela; em Python, de `pywin32`.
;
; AHK é desprezado por ser "linguagem de macro", e esta é a ferramenta que
; mostra por que isso é injusto: 200 linhas, zero dependência, e faz uma coisa
; que as alternativas fazem com mais cerimônia.
;
; ## O que a torna testável, e não uma demonstração
;
; AHK v2 escreve em stdout com `FileAppend(texto, "*")`, então a saída é
; comparável como a de qualquer script. E `--autoteste` exercita as funções
; puras (classificação, formatação, decisão) com entradas fixas, sem depender
; do que estiver aberto na máquina.
;
; Nenhuma `MsgBox` em lugar nenhum: uma caixa de diálogo num script de
; verificação pendura o processo esperando alguém fechar — e isso aconteceu de
; verdade durante o desenvolvimento, com o `/validate` abrindo janela em vez de
; escrever em stderr. Por isso a invocação exige `/ErrorStdOut`.
;
; ## Códigos de saída
;
;   0  desktop limpo o suficiente para medir
;   1  há processo consumindo CPU acima do limiar
;   2  erro de uso

; --------------------------------------------------------------- argumentos

limiar := 3.0        ; % de CPU a partir do qual o processo é reportado
formato := "texto"
autoteste := false

i := 1
while (i <= A_Args.Length) {
    arg := A_Args[i]

    if (arg = "--json")
        formato := "json"
    else if (arg = "--autoteste")
        autoteste := true
    else if (arg = "--limiar") {
        i++
        if (i > A_Args.Length) {
            Saida("--limiar exige um numero`n")
            ExitApp(2)
        }
        limiar := Number(A_Args[i])
    }
    else if (arg = "--ajuda") {
        Saida("Verifica-Ambiente.ahk - o que no desktop vai contaminar a medicao`n`n")
        Saida("uso: AutoHotkey64.exe /ErrorStdOut Verifica-Ambiente.ahk [--json] [--limiar N]`n")
        ExitApp(0)
    }
    else {
        Saida("opcao desconhecida: " . arg . "`n")
        ExitApp(2)
    }

    i++
}

; `FileAppend(texto, "*")` escreve em STDOUT. É o que torna este script
; comparável como qualquer outro, e a razão de não haver MsgBox aqui.
;
; O terceiro argumento, "UTF-8", NÃO é opcional na prática: sem ele o AHK
; escreve na codificação ANSI do sistema, e títulos de janela com acento saem
; como "dom?nio" e "H?rcules". O JSON gerado fica inválido para qualquer
; consumidor que espere UTF-8, que é o que todos esperam.
;
; Foi exatamente o que aconteceu na primeira execução desta ferramenta, e o
; título de janela é justamente onde o acento aparece -- porque é texto que vem
; do usuário, não do programa.
Saida(texto) {
    FileAppend(texto, "*", "UTF-8")
}

; ------------------------------------------------- funções puras, testáveis
;
; Separadas do acesso ao sistema de propósito: são elas que o --autoteste
; exercita, com entradas fixas, sem depender do que estiver aberto.

; Classifica um processo pelo nome. A lista veio dos casos REAIS desta sessão:
; o navegador com vídeo e o jogo que contaminaram a medição.
Classifica(nome) {
    navegadores := ["chrome.exe", "msedge.exe", "firefox.exe", "brave.exe", "opera.exe"]
    jogos := ["steam.exe", "steamwebhelper.exe", "EpicGamesLauncher.exe"
            , "RobloxPlayerBeta.exe", "javaw.exe"]
    compiladores := ["cl.exe", "gcc.exe", "clang.exe", "rustc.exe", "cargo.exe"
                   , "ghc.exe", "dotnet.exe", "MSBuild.exe", "node.exe"]
    sistema := ["MsMpEng.exe", "SearchIndexer.exe", "TiWorker.exe"
              , "TrustedInstaller.exe", "WmiPrvSE.exe"]

    for n in navegadores
        if (nome = n)
            return "navegador"
    for n in jogos
        if (nome = n)
            return "jogo"
    for n in compiladores
        if (nome = n)
            return "compilacao"
    for n in sistema
        if (nome = n)
            return "sistema"

    return "outro"
}

; O veredito. "sistema" conta como contaminação igual: a indexação do Windows
; e o antivírus roubam CPU do mesmo jeito, e a diferença é só que ninguém os
; abriu de propósito.
Contamina(categoria) {
    return (categoria = "navegador" || categoria = "jogo"
         || categoria = "compilacao" || categoria = "sistema")
}

; Escapa para JSON. AHK não tem serializador, então a função existe pelo mesmo
; motivo que a do par em Bash -- e é o mesmo argumento daquela comparação.
JsonEscapa(s) {
    s := StrReplace(s, "\", "\\")
    s := StrReplace(s, '"', '\"')
    s := StrReplace(s, "`t", "\t")
    s := StrReplace(s, "`n", "\n")
    s := StrReplace(s, "`r", "\r")
    return s
}

; ------------------------------------------------------------- autoteste
;
; Exercita as funções puras com entradas fixas. Não depende do desktop, então
; roda igual em qualquer máquina e serve de teste de rotina.

if (autoteste) {
    passou := 0
    falhou := 0

    Checa(rotulo, esperado, obtido) {
        global passou, falhou
        if (esperado = obtido) {
            Saida("  ok    " . rotulo . "`n")
            passou++
        } else {
            Saida("  FALHA " . rotulo . "`n")
            Saida("        esperado '" . esperado . "', obtido '" . obtido . "'`n")
            falhou++
        }
    }

    Saida("`nahk/Verifica-Ambiente.ahk -- autoteste das funcoes puras`n`n")

    Checa("chrome.exe e navegador", "navegador", Classifica("chrome.exe"))
    Checa("steam.exe e jogo", "jogo", Classifica("steam.exe"))
    Checa("cargo.exe e compilacao", "compilacao", Classifica("cargo.exe"))
    Checa("MsMpEng.exe e sistema", "sistema", Classifica("MsMpEng.exe"))
    Checa("notepad.exe e outro", "outro", Classifica("notepad.exe"))

    ; O veredito: 'outro' NAO contamina, e os quatro conhecidos contaminam.
    Checa("navegador contamina", true, Contamina("navegador"))
    Checa("jogo contamina", true, Contamina("jogo"))
    Checa("compilacao contamina", true, Contamina("compilacao"))
    Checa("sistema contamina (indexador rouba CPU igual)", true, Contamina("sistema"))
    Checa("outro NAO contamina", false, Contamina("outro"))

    ; O escape de JSON, com o caso que importa: a barra invertida PRIMEIRO,
    ; senao ela escapa o que vem depois.
    Checa("escapa aspas", 'a\"b', JsonEscapa('a"b'))
    Checa("escapa barra antes do resto", 'a\\b', JsonEscapa("a\b"))

    Saida("`n  " . passou . " passaram, " . falhou . " falharam`n")
    ExitApp(falhou = 0 ? 0 : 1)
}

; --------------------------------------------- o acesso ao desktop, de verdade

; CPU por processo via WMI. `Win32_PerfFormattedData_PerfProc_Process` já traz
; a porcentagem calculada -- consultar `Win32_Process` daria tempo acumulado e
; exigiria duas amostras e a subtração à mão.
wmi := ComObjGet("winmgmts:")

achados := []

try {
    consulta := wmi.ExecQuery("SELECT Name, PercentProcessorTime, IDProcess "
        . "FROM Win32_PerfFormattedData_PerfProc_Process")

    for proc in consulta {
        nome := proc.Name
        pct := proc.PercentProcessorTime + 0

        ; `_Total` e `Idle` são agregados do contador, não processos.
        if (nome = "_Total" || nome = "Idle")
            continue

        if (pct < limiar)
            continue

        ; O nome do contador vem sem `.exe` e com sufixo `#1` quando há
        ; homônimos. Normalizar é necessário para a classificação casar.
        base := RegExReplace(nome, "#\d+$", "") . ".exe"

        achados.Push({ nome: base
                     , pid: proc.IDProcess
                     , cpu: pct
                     , categoria: Classifica(base)
                     , titulo: TituloDaJanela(proc.IDProcess) })
    }
}
catch Error as e {
    Saida("FALHA: nao consegui consultar o WMI: " . e.Message . "`n")
    ExitApp(2)
}

; Título da janela visível de um PID, se houver.
;
; É O MOTIVO de isto ser AHK: `WinGetList` com `DetectHiddenWindows Off` dá as
; janelas que o usuário de fato vê, e o título é o que identifica "navegador
; tocando vídeo" contra "navegador parado numa aba de texto".
TituloDaJanela(pid) {
    DetectHiddenWindows false

    try {
        for hwnd in WinGetList() {
            if (WinGetPID(hwnd) = pid) {
                t := WinGetTitle(hwnd)
                if (t != "")
                    return t
            }
        }
    }
    catch {
        return ""
    }

    return ""
}

; ------------------------------------------------------------------ relatório

contaminantes := []
for a in achados
    if (Contamina(a.categoria))
        contaminantes.Push(a)

if (formato = "json") {
    Saida("{`n")
    Saida('  "limiar": ' . limiar . ",`n")
    Saida('  "contaminantes": ' . contaminantes.Length . ",`n")
    Saida('  "processos": [`n')

    for idx, a in achados {
        virgula := (idx < achados.Length) ? "," : ""
        Saida('    {"nome": "' . JsonEscapa(a.nome)
            . '", "pid": ' . a.pid
            . ', "cpu": ' . a.cpu
            . ', "categoria": "' . a.categoria
            . '", "contamina": ' . (Contamina(a.categoria) ? "true" : "false")
            . ', "titulo": "' . JsonEscapa(a.titulo) . '"}' . virgula . "`n")
    }

    Saida("  ]`n}`n")
}
else {
    Saida("`n")
    Saida("Processos acima de " . limiar . "% de CPU no desktop do Windows:`n")
    Saida("(instantaneo: o contador do WMI e por amostra, nao media)`n`n")

    if (achados.Length = 0) {
        Saida("  (nenhum)`n")
    } else {
        for a in achados {
            marca := Contamina(a.categoria) ? "!" : " "
            t := (a.titulo != "") ? ("  -- " . SubStr(a.titulo, 1, 40)) : ""
            Saida(Format("  {1} {2:-24} {3:5.1f}%  {4:-12}{5}`n"
                , marca, a.nome, a.cpu, a.categoria, t))
        }
    }

    Saida("`n")

    if (contaminantes.Length = 0) {
        Saida("Desktop limpo o suficiente para medir.`n")
    } else {
        Saida(contaminantes.Length . " processo(s) marcado(s) com ! vao contaminar"
            . " qualquer medicao de tempo.`n`n")
        Saida("Isto complementa o bench/calibra.sh do p03-otp-mesh: ele mede o`n")
        Saida("EFEITO (um laco fixo fica mais lento) e nao pode dizer a CAUSA,`n")
        Saida("porque processo do Windows nao aparece no /proc do WSL2.`n")
    }
}

ExitApp(contaminantes.Length = 0 ? 0 : 1)
