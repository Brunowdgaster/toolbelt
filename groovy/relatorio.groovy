#!/usr/bin/env groovy

/*
 * relatorio.groovy — converte a saída dos verificadores em JUnit XML.
 *
 *   groovy relatorio.groovy saida.txt
 *   bash verifica.sh | groovy relatorio.groovy -
 *   groovy relatorio.groovy --saida resultado.xml saida1.txt saida2.txt
 *
 * ## Por que esta ferramenta existe
 *
 * Todo verificador deste portfólio emite TEXTO:
 *
 *     ok    fixture limpo: 0 achados
 *     FALHA o shell p03 não resolve
 *
 * É legível por humano e **invisível para CI**. O GitHub Actions, o Jenkins e
 * qualquer outro painel sabem ler **JUnit XML** — e com ele mostram cada
 * verificação como um teste, com nome, duração e a mensagem da falha, em vez
 * de um log em que alguém tem de procurar.
 *
 * Os 29 testes do toolbelt, os 23 do P02 e os 9 dos portes do P01 passam a
 * aparecer como 61 testes num relatório só.
 *
 * ## Por que em Groovy
 *
 * Porque o trabalho é **ler um formato e emitir outro**, e as duas pontas são
 * o terreno dos *builders* do Groovy:
 *
 *   * `MarkupBuilder` escreve XML com a forma do XML — sem concatenar string
 *     nem escapar `&` à mão;
 *   * e a JVM é onde o JUnit XML nasceu, então o formato não precisa ser
 *     adivinhado.
 *
 * É literalmente o papel que Groovy tem no Jenkins: a cola entre uma
 * ferramenta que produz texto e um painel que espera estrutura.
 *
 * ## O formato de entrada
 *
 * Linhas no padrão dos verificadores deste portfólio:
 *
 *     ok    <nome>                    passou
 *     FALHA <nome>                    falhou
 *           <detalhe>                 detalhe da falha anterior (indentado)
 *     <texto> — <descrição>           cabeçalho de grupo (vira <testsuite>)
 *
 * Códigos ANSI são removidos: os verificadores colorem a saída, e um `\u001b[32m`
 * no meio do nome do teste vira lixo no XML.
 */

import groovy.xml.MarkupBuilder

// ----------------------------------------------------------------- argumentos

def saidaXml = null
def arquivos = []

def argsIter = args.toList().iterator()
while (argsIter.hasNext()) {
    def a = argsIter.next()
    switch (a) {
        case '--saida':
            if (!argsIter.hasNext()) {
                System.err.println '--saida exige um caminho'
                System.exit(64)
            }
            saidaXml = argsIter.next()
            break
        case '--ajuda':
            println '''relatorio.groovy - converte a saida dos verificadores em JUnit XML

uso:
  relatorio.groovy [--saida arquivo.xml] <entrada.txt>...
  relatorio.groovy -                        le da entrada padrao'''
            System.exit(0)
        default:
            arquivos << a
    }
}

if (arquivos.isEmpty()) {
    System.err.println 'uso: relatorio.groovy [--saida x.xml] <entrada.txt>... (ou - para stdin)'
    System.exit(64)
}

// --------------------------------------------------------------------- modelo

class Caso {
    String nome
    boolean passou
    List<String> detalhe = []
}

class Grupo {
    String nome
    List<Caso> casos = []

    int getFalhas() { casos.count { !it.passou } }
    int getTotal() { casos.size() }

    /*
     * Nome curto para o painel: a parte antes do travessao.
     *
     * Os verificadores escrevem "perl/lint_medicoes.pl — numero publicado sem
     * dispersao ao lado", e a descricao inteira como `classname` deixa a
     * coluna de classe do painel ilegivel. O que identifica o grupo e o
     * caminho da ferramenta.
     */
    String getNomeCurto() {
        def i = nome.indexOf(' — ')
        if (i < 0) i = nome.indexOf(' -- ')
        i > 0 ? nome.substring(0, i).trim() : nome
    }
}

// ------------------------------------------------------------------- análise
//
// Os códigos ANSI saem ANTES de qualquer casamento. Os verificadores colorem a
// saída, e um `\u001b[32m` colado no nome do teste vira lixo dentro do XML --
// um atributo XML com byte de escape é inválido em alguns parsers e ilegível
// em todos.
def semCor = { String linha -> linha.replaceAll(/\u001b\[[0-9;]*m/, '') }

def grupos = []
def grupoAtual = null
def ultimoCaso = null

// Cabeçalho de grupo: uma linha com " — " que não é um caso. Os verificadores
// escrevem "perl/lint_medicoes.pl — número publicado sem dispersão".
def ehCabecalho = { String l ->
    (l.contains(' — ') || l.contains(' -- ')) &&
        !(l =~ /^\s*(ok|FALHA)\s/)
}

def lerLinhas = { String arq ->
    arq == '-' ? System.in.readLines() : new File(arq).readLines()
}

arquivos.each { arq ->
    if (arq != '-' && !new File(arq).exists()) {
        System.err.println "arquivo nao encontrado: ${arq}"
        System.exit(66)
    }

    lerLinhas(arq).each { bruta ->
        def linha = semCor(bruta)
        def aparada = linha.trim()

        if (aparada.isEmpty() || aparada.startsWith('===') || aparada.startsWith('---')) {
            return
        }

        def m = (linha =~ /^\s*(ok|FALHA)\s+(.+?)\s*$/)

        if (m.matches()) {
            if (grupoAtual == null) {
                // Casos antes de qualquer cabeçalho vão para um grupo
                // nomeado, e não são descartados: descartar silenciosamente é
                // como um relatório perde testes sem avisar.
                grupoAtual = new Grupo(nome: "sem-grupo")
                grupos << grupoAtual
            }

            ultimoCaso = new Caso(nome: m.group(2), passou: m.group(1) == 'ok')
            grupoAtual.casos << ultimoCaso
            return
        }

        // Linha indentada depois de um caso: é o detalhe da falha.
        if (bruta ==~ /^\s{6,}.*/ && ultimoCaso != null) {
            ultimoCaso.detalhe << aparada
            return
        }

        if (ehCabecalho(aparada)) {
            grupoAtual = new Grupo(nome: aparada)
            grupos << grupoAtual
            ultimoCaso = null
        }
    }
}

// Entrada sem nenhum caso reconhecido FALHA ALTO, em vez de emitir um XML
// vazio e verde. Um relatório de zero testes passando é o pior resultado
// possível: ele parece sucesso.
def totalCasos = grupos.sum { it.total } ?: 0

if (totalCasos == 0) {
    System.err.println 'relatorio.groovy: nenhuma verificacao reconhecida na entrada'
    System.err.println '  o formato esperado e "ok <nome>" ou "FALHA <nome>"'
    System.exit(65)
}

// --------------------------------------------------------------------- saída
//
// `MarkupBuilder` escreve XML com a FORMA do XML: cada chamada é um elemento,
// o mapa é o conjunto de atributos, o closure é o conteúdo. Escapar `&`, `<` e
// `"` é dele. Concatenar string para gerar XML é o jeito clássico de produzir
// um arquivo que o parser recusa na primeira mensagem de erro com `<`.

def escritor = new StringWriter()
def xml = new MarkupBuilder(escritor)
xml.doubleQuotes = true

def totalFalhas = grupos.sum { it.falhas } ?: 0

// Grupos VAZIOS saem do relatorio.
//
// O banner do verificador ("toolbelt — ferramentas de higiene") tem travessao
// e e reconhecido como cabecalho, mas nao tem caso nenhum embaixo. Uma
// <testsuite tests="0"> e ruido num painel de CI, e em alguns deles conta como
// suite "sem resultado", que parece problema.
def comCasos = grupos.findAll { it.total > 0 }

xml.testsuites(tests: totalCasos, failures: totalFalhas, name: 'toolbelt') {
    comCasos.each { g ->
        testsuite(name: g.nomeCurto, tests: g.total, failures: g.falhas) {
            g.casos.each { c ->
                testcase(name: c.nome, classname: g.nomeCurto) {
                    if (!c.passou) {
                        failure(message: c.detalhe ? c.detalhe.join(' | ') : 'falhou',
                                type: 'verificacao')
                    }
                }
            }
        }
    }
}

def documento = '<?xml version="1.0" encoding="UTF-8"?>\n' + escritor.toString() + '\n'

if (saidaXml) {
    new File(saidaXml).text = documento
    System.err.println "relatorio.groovy: ${totalCasos} verificacoes -> ${saidaXml}"
} else {
    print documento
}

// O resumo vai para STDERR, não stdout: assim `| groovy relatorio.groovy -` com
// o XML em stdout continua utilizável num pipe, e o humano ainda vê o placar.
System.err.println()
System.err.printf('%-44s %6s %6s%n', 'grupo', 'testes', 'falhas')
System.err.println('-' * 58)

comCasos.each { g ->
    def rotulo = g.nomeCurto.length() > 42 ? g.nomeCurto[0..41] + '…' : g.nomeCurto
    System.err.printf('%-44s %6d %6d%n', rotulo, g.total, g.falhas)
}

System.err.println('-' * 58)
System.err.printf('%-44s %6d %6d%n', 'TOTAL', totalCasos, totalFalhas)

// O código de saída reflete o RESULTADO AGREGADO, para a ferramenta servir de
// portão: um relatório que sempre sai 0 obriga o CI a reparsear o que ela
// acabou de parsear.
System.exit(totalFalhas == 0 ? 0 : 1)
