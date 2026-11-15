' Cobertura.bas — a cobertura do portfólio como PLANILHA, em LibreOffice Basic.
'
' Rodar (sem interface):
'     ./basic/roda.sh
'
' ## Isto é LibreOffice Basic, e NÃO é VBA
'
' O plano original do portfólio pedia **VBA**. VBA exige Microsoft Office, que
' é **pago**, e a regra declarada é *nenhum recurso pago* — então VBA, como
' VBA, está fora, e isso está registrado em `AMBIENTE.md` do índice.
'
' LibreOffice Basic é livre (MPL-2.0), roda *headless*, e cobre a maior parte
' do mesmo terreno: mesma família sintática, mesmo modelo de "macro que
' automatiza documento". Mas é **outro dialeto**, com outra API de documento,
' e chamá-lo de VBA seria a mesma desonestidade que chamar o flake do Nix de
' "reproduz os números medidos".
'
' O que é compatível e o que não é, concretamente:
'
'   * `Sub`, `Dim`, `For...Next`, `If...Then`, `Option Explicit` — iguais;
'   * **o modelo de objetos é completamente diferente.** VBA tem
'     `Workbooks`, `Worksheets`, `Range("A1")`. Aqui é UNO:
'     `ThisComponent.Sheets.getByIndex(0).getCellByPosition(0, 0)`;
'   * o LibreOffice tem `Option VBASupport 1`, que liga uma camada de
'     compatibilidade e faz `Range` e `Cells` funcionarem. **Este arquivo NÃO
'     a usa**, de propósito: usar a camada de compatibilidade seria escrever
'     VBA fingido num produto que não é o Office, e o objetivo aqui é mostrar
'     a API nativa.
'
' ## Por que uma planilha resolve um problema real do portfólio
'
' A cobertura de linguagens é contada por `lua/cobertura.lua`, e o número que
' importa — **linguagens distintas** — não é a soma das colunas: Rust aparece
' no P01 e no P03 e conta uma vez.
'
' Uma planilha é o lugar natural para esse tipo de conta ficar **auditável**:
' quem abre o arquivo vê a fórmula, não o resultado. E é por isso que esta
' macro escreve `=SUM(...)` em vez de escrever o total já somado — a planilha
' é que calcula.
'
' Isso também dá a verificação: a macro escreve a fórmula, pede ao LibreOffice
' para recalcular, e **lê de volta** o valor. Se o número lido não bater com o
' que o Lua reportou, uma das duas contas está errada. É verificação cruzada
' entre duas implementações, igual ao resto do portfólio.
'
' ## A estrutura do arquivo gerado
'
'     A        B           C        D            E
'     projeto  nome        feitas   planejadas   pct
'     P01      metal-vm    7        12           =C2/D2
'     ...
'     TOTAL                =SUM()   =SUM()       =C16/D16
'     DISTINTAS            37       100          =C17/D17
'
' A linha DISTINTAS vem do Lua e **não** é uma soma — é justamente o número
' que a planilha não pode calcular, porque a sobreposição não está nas
' colunas. Ela fica ao lado do total somado para a diferença ser visível.

Option Explicit


' Lê o TSV que `lua/cobertura.lua --tsv` produziu.
'
' `FileSystemObject` não existe aqui: o LibreOffice Basic usa `Open ... For
' Input` do Basic clássico, que é o mesmo do VBA. Essa parte É compatível.
Function LeTSV(caminho As String) As Variant
    Dim linhas(200) As String
    Dim n As Integer
    Dim linha As String
    Dim canal As Integer

    canal = FreeFile
    Open caminho For Input As #canal

    n = 0
    Do While Not EOF(canal)
        Line Input #canal, linha
        If Len(Trim(linha)) > 0 Then
            linhas(n) = linha
            n = n + 1
        End If
    Loop

    Close #canal

    Dim fora(n - 1) As String
    Dim i As Integer
    For i = 0 To n - 1
        fora(i) = linhas(i)
    Next i

    LeTSV = fora
End Function


' Cria uma planilha nova, sem interface.
'
' `loadComponentFromURL` com `Hidden = True` é o que permite isto rodar em CI:
' o documento existe no modelo de objetos e nenhuma janela é aberta. Sem o
' `Hidden`, mesmo em `--headless`, o LibreOffice tenta criar a janela.
Function NovaPlanilha() As Object
    Dim desktop As Object
    Dim args(0) As New com.sun.star.beans.PropertyValue

    desktop = createUnoService("com.sun.star.frame.Desktop")

    args(0).Name = "Hidden"
    args(0).Value = True

    NovaPlanilha = desktop.loadComponentFromURL( _
        "private:factory/scalc", "_blank", 0, args())
End Function


Sub Main
    Dim entrada As String
    Dim saida As String
    Dim doc As Object
    Dim folha As Object
    Dim celula As Object
    Dim dados As Variant
    Dim campos As Variant
    Dim i As Integer, linha As Integer
    Dim primeira As Integer, ultima As Integer
    Dim distintas As Integer, meta As Integer
    Dim somaFeitas As Double, somaPlan As Double

    ' Os caminhos vêm do ambiente, e não embutidos: a macro é instalada no
    ' perfil do usuário pelo `roda.sh`, e o perfil não sabe onde o
    ' repositório está.
    entrada = Environ("QLAB_TSV")
    saida = Environ("QLAB_ODS")

    If entrada = "" Or saida = "" Then
        ' Falha ALTO. Sem isto, a macro geraria uma planilha vazia num lugar
        ' imprevisível, e o teste acusaria "valor errado" em vez de "faltou
        ' configurar".
        MsgBox "QLAB_TSV e QLAB_ODS precisam estar no ambiente"
        Exit Sub
    End If

    dados = LeTSV(entrada)

    doc = NovaPlanilha()
    folha = doc.Sheets.getByIndex(0)
    folha.Name = "cobertura"

    ' Cabeçalho.
    folha.getCellByPosition(0, 0).setString("projeto")
    folha.getCellByPosition(1, 0).setString("nome")
    folha.getCellByPosition(2, 0).setString("feitas")
    folha.getCellByPosition(3, 0).setString("planejadas")
    folha.getCellByPosition(4, 0).setString("pct")

    linha = 1
    primeira = 0
    ultima = 0
    distintas = -1
    meta = 0
    somaFeitas = 0
    somaPlan = 0

    ' A primeira linha do TSV é o cabeçalho do Lua, e é ignorada.
    For i = 1 To UBound(dados)
        campos = Split(dados(i), Chr(9))

        If campos(0) = "=DISTINTAS" Then
            ' Guardada para depois do total: ela não é uma soma.
            distintas = CInt(campos(2))
            meta = CInt(campos(3))
        Else
            folha.getCellByPosition(0, linha).setString(campos(0))
            folha.getCellByPosition(1, linha).setString(campos(1))
            folha.getCellByPosition(2, linha).setValue(CDbl(campos(2)))
            folha.getCellByPosition(3, linha).setValue(CDbl(campos(3)))

            ' A porcentagem é FÓRMULA, não valor calculado aqui. Quem abre o
            ' arquivo vê `=C2/D2` e pode auditar; se fosse valor, teria de
            ' confiar.
            folha.getCellByPosition(4, linha).setFormula( _
                "=IF(D" & (linha + 1) & "=0;0;C" & (linha + 1) & _
                "/D" & (linha + 1) & ")")

            somaFeitas = somaFeitas + CDbl(campos(2))
            somaPlan = somaPlan + CDbl(campos(3))

            If primeira = 0 Then primeira = linha + 1
            ultima = linha + 1
            linha = linha + 1
        End If
    Next i

    ' O TOTAL como SUM() de verdade.
    folha.getCellByPosition(0, linha).setString("TOTAL")
    folha.getCellByPosition(2, linha).setFormula( _
        "=SUM(C" & primeira & ":C" & ultima & ")")
    folha.getCellByPosition(3, linha).setFormula( _
        "=SUM(D" & primeira & ":D" & ultima & ")")
    folha.getCellByPosition(4, linha).setFormula( _
        "=C" & (linha + 1) & "/D" & (linha + 1))

    Dim linhaTotal As Integer
    linhaTotal = linha
    linha = linha + 1

    ' E a linha das DISTINTAS, que vem do Lua.
    folha.getCellByPosition(0, linha).setString("DISTINTAS")
    folha.getCellByPosition(1, linha).setString("(sem repetir)")
    folha.getCellByPosition(2, linha).setValue(distintas)
    folha.getCellByPosition(3, linha).setValue(meta)
    folha.getCellByPosition(4, linha).setFormula( _
        "=C" & (linha + 1) & "/D" & (linha + 1))

    ' A sobreposição como fórmula: a diferença entre a soma e o conjunto.
    ' É o número que a contagem à mão erra, e aqui ele aparece explicado.
    folha.getCellByPosition(0, linha + 1).setString("sobreposicao")
    folha.getCellByPosition(1, linha + 1).setString("soma - distintas")
    folha.getCellByPosition(2, linha + 1).setFormula( _
        "=C" & (linhaTotal + 1) & "-C" & (linha + 1))

    ' Recalcula e LÊ DE VOLTA.
    '
    ' Esta é a parte que torna a macro verificável: o valor impresso vem do
    ' motor de cálculo do LibreOffice, não da aritmética do Basic. Se ele
    ' divergir do que o `cobertura.lua` reporta, uma das duas contas está
    ' errada -- e a suíte compara os dois.
    doc.calculateAll()

    Dim totalLido As Double
    Dim sobreposicaoLida As Double
    totalLido = folha.getCellByPosition(2, linhaTotal).getValue()
    sobreposicaoLida = folha.getCellByPosition(2, linha + 1).getValue()

    ' Formatação mínima: cabeçalho em negrito e a coluna pct como
    ' porcentagem. Não é enfeite -- uma planilha em que `0,37` aparece como
    ' `0,37` em vez de `37%` força quem lê a adivinhar a unidade.
    Dim formatos As Object
    Dim idPct As Long
    formatos = doc.getNumberFormats()
    Dim locale As New com.sun.star.lang.Locale
    idPct = formatos.queryKey("0%", locale, False)
    If idPct = -1 Then
        idPct = formatos.addNew("0%", locale)
    End If

    Dim faixa As Object
    faixa = folha.getCellRangeByName("E2:E" & (linha + 1))
    faixa.NumberFormat = idPct

    folha.getCellRangeByName("A1:E1").CharWeight = _
        com.sun.star.awt.FontWeight.BOLD

    ' Salva em ODS.
    '
    ' `storeToURL` com FilterName explícito: sem o filtro, o LibreOffice
    ' escolhe pela extensão, e o comportamento muda entre versões.
    Dim salvar(0) As New com.sun.star.beans.PropertyValue
    salvar(0).Name = "FilterName"
    salvar(0).Value = "calc8"
    doc.storeToURL(ConvertToURL(saida), salvar())

    ' A saída em stdout é o que o `verifica.sh` compara. `MsgBox` abriria
    ' JANELA -- e janela em automação é a armadilha que o AutoHotkey deste
    ' mesmo repositório já custou duas vezes.
    Dim fora As Integer
    fora = FreeFile
    Open Environ("QLAB_SAIDA") For Output As #fora
    Print #fora, "total=" & CStr(CLng(totalLido))
    Print #fora, "distintas=" & CStr(distintas)
    Print #fora, "sobreposicao=" & CStr(CLng(sobreposicaoLida))
    Print #fora, "linhas=" & CStr(ultima - primeira + 1)
    Close #fora

    doc.close(False)
End Sub
