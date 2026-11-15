# toolbelt — automação e higiene do próprio portfólio

Ferramentas que **fazem trabalho real neste portfólio**, cada uma na linguagem
que é a escolha natural daquele terreno.

```
bash verifica.sh          # todas as ferramentas, nas duas direções
bash verifica.sh perl     # só essa
```

> **Status:** 5 das 10 linguagens previstas. Perl, AWK, Lua, Raku e Tcl/Expect
> estão completas e verificadas, com **29 testes**. Groovy, Nix, PowerShell,
> AutoHotkey e VBA pendentes — ver [Roadmap](#roadmap).

## O princípio: nenhuma ferramenta é demonstração

Cada uma resolve um problema que este portfólio **teve de verdade**, e duas
delas corrigiram erros meus na primeira execução.

| ferramenta | linguagem | o problema que resolve | como surgiu |
|---|---|---|---|
| `perl/lint_medicoes.pl` | Perl | número publicado sem dispersão ao lado | a auditoria do P03 corrigiu **7** afirmações com esse defeito, e eu as achei lendo à mão |
| `awk/estatistica.awk` | AWK | faixa, dispersão e a regra de decisão | reescrevi essa lógica em Elixir, Bash e Shell, **três vezes** |
| `lua/cobertura.lua` | Lua | planejado contra feito, com sobreposição | contei as linguagens à mão três vezes e **errei uma** |
| `raku/gramatica_fasm.raku` | Raku | parser do assembly do P01, verificado contra o desmontador em C | o P01 tem 7 implementações da VM e **nenhum parser independente** do `.fasm` |
| `tcl/dirige_repl.exp` | Tcl/Expect | dirigir um REPL e conferir a resposta | os portes de OCaml e Lua foram testados por linha de comando, que **não testa o REPL** |

## `perl/lint_medicoes.pl` — o lint que a auditoria me fez falta

A auditoria do p03-otp-mesh revisou toda afirmação numérica daquele README e
**corrigiu sete**. Todas tinham o mesmo defeito de forma: um número de tempo
publicado sem dispersão, sem contagem de repetições, sem dizer se a medição foi
alternada.

Eu fiz aquela auditoria lendo. Esta ferramenta é o que eu queria ter tido.

```
$ perl lint_medicoes.pl --resumo ../p0*/README.md

arquivo                                      achados
--------------------------------------------------------------
p01-metal-vm/README.md                       0
p02-forge-lang/README.md                     4
p03-otp-mesh/README.md                       26
```

**O P01 em zero é a validação**: é o projeto que estabeleceu a disciplina de
dispersão, e a ferramenta concorda.

### Por que em Perl

O problema é regex pesado **com estrutura**: unidades compostas (`ops/s`,
`µs`), números em duas convenções decimais (`1.234` e `1,234`), e contexto que
pode estar na linha, no cabeçalho de uma tabela ou num parágrafo acima. Perl
faz isso com `qr//` composto e `/x` legível, e o programa fica menor que a
descrição do problema.

### O que ela não é

Um lint, não um provador. Ela acerta por heurística, e tem **dispensa
explícita** porque silenciar por omissão seria o mesmo pecado que combate:

```markdown
O limite é de 1 ms por NIF. <!-- lint-medicao: ignorar -->
```

As duas classes de exclusão foram derivadas dos **falsos positivos da primeira
execução contra os READMEs reais**, não de imaginação:

* **parâmetro**, não medição — `9 vezes com 120 ms de intervalo` configura o
  experimento; `3 reinícios em 5 segundos` é um limite documentado do OTP;
* **menção histórica** — um número citado para dizer que estava errado não é
  afirmação nova, é a correção dele. Exigir dispersão ali penalizaria
  justamente o texto que faz a coisa certa.

Com as duas, os achados caíram de **85 para 32**, e o P01 foi para zero.

## `awk/estatistica.awk` — a regra de decisão do portfólio, em 60 linhas

Todo benchmark aqui terminou precisando da mesma coisa: N amostras por
implementação, achar melhor, pior e dispersão, e decidir se a diferença supera
o ruído. Eu reescrevi isso **três vezes** — em Elixir, em Bash e em Shell.

É exatamente o trabalho do AWK: entrada em colunas, agrupamento por chave,
agregação numérica. Com o laço implícito, os arrays associativos e a divisão em
campos já na linguagem, a versão em AWK ficou mais clara que as três.

```
$ awk -f estatistica.awk amostras.txt

rotulo               n         melhor           pior       disp        media
----------------------------------------------------------------------------
atomiclong           7       40735479       12375528     229.2%   21682503.3
counters             7      120918984       48152161     151.1%   99280510.6

razao dos melhores : 0.337x   margem: 66.3%   pior dispersao: 229.2%

DECIDIDO: counters e melhor, e as faixas NAO SE TOCAM.
  A pior amostra dele (48152161) supera a melhor do outro (40735479).
  Fator conservador: 1.18x
```

Esses são os dados reais da medição de contadores do p03-otp-mesh, e a
ferramenta **reproduz a conclusão daquele harness** — faixas disjuntas, fator
conservador de 1,18x. Ter chegado ao mesmo veredito por um caminho
independente é a melhor verificação que a regra podia receber.

### A regra, em três níveis

1. **faixas disjuntas** → decidido, com fator conservador (pior do vencedor ÷
   melhor do perdedor). Dispersão alta não importa aqui;
2. **faixas se sobrepõem, margem supera a dispersão** → provável, não certo;
3. **nada disso** → **não determinado**, que é uma resposta.

Com três ou mais rótulos ela **apenas tabula**: comparar vários pares pede
correção para múltiplas comparações, e inventar uma seria pior que não
concluir.

### `menor_melhor` e o teste que prova o perigo

Por padrão, maior é melhor (vazão). Com `-v menor_melhor=1`, menor é melhor
(latência). Errar isso **inverte o relatório e deixa a tabela plausível** — por
isso o cabeçalho imprime o critério em uso, e por isso a suíte tem um teste
que roda o mesmo arquivo nos dois modos e verifica que o vencedor troca:

| arquivo de latência | critério | vencedor |
|---|---|---|
| `latencia.txt` | `menor_melhor=1` (correto) | **beam** |
| `latencia.txt` | padrão (errado) | **loom** |

O teste existe para demonstrar que o perigo é real, não hipotético.

## `lua/cobertura.lua` — a conta que o humano erra

A contagem de "quantas linguagens já estão feitas" foi respondida à mão três
vezes nesta sessão, e **errada uma delas**. A conta tem três armadilhas:

1. **sobreposição** — Rust aparece no P01 e no P03: conta uma vez no total e
   duas na soma por projeto;
2. **itens que não são linguagens** — Makefile, CMake, YAML e Dockerfile estão
   no plano e não contam como linguagem dominada;
3. **planejado contra feito** — o ROADMAP lista 15 itens para o P01, dos quais
   12 são linguagens de fato.

```
$ lua5.4 cobertura.lua registro.lua --roadmap ../poliglota/ROADMAP.md

proj   nome       feitas/plan      pct progresso
--------------------------------------------------------------
P01    metal-vm        7/12        58% #########.......
P02    forge-lang      3/15        20% ###.............
P03    otp-mesh        8/8        100% ################
P12    toolbelt        3/10        30% #####...........
--------------------------------------------------------------
TOTAL                 21/120       18% ###.............

linguagens DISTINTAS: 20   (a soma por projeto da 21)
  sobreposicao em 1: Rust (P01, P03)

meta: 100 linguagens. Faltam 80.
```

**A ferramenta corrigiu minha contagem na primeira execução**: eu vinha dizendo
17, e são 20 — eu não estava contando Perl, AWK e Lua, que acabei de escrever.
É literalmente o caso de uso.

### Por que em Lua

Porque o registro é **dado declarativo que precisa ser lido por código**, e
essa é a razão de Lua existir. O `registro.lua` é uma tabela Lua literal: nem
parser, nem schema, nem biblioteca de YAML. O programa faz `dofile` e tem a
estrutura na mão, com comentários e evidência ao lado de cada linguagem.

É o mesmo papel que Lua tem em Nginx, Redis e Neovim: **a configuração é
programa**.

### O cruzamento com o ROADMAP, e o teste contra o falso OK

Com `--roadmap`, a ferramenta confere a contagem declarada contra o ROADMAP de
verdade e **falha** se o plano mudou e o registro não.

Esse cruzamento é a parte mais fácil de passar vacuamente: se o parser do
roadmap não achasse nada, não haveria divergência e o teste passaria sem ter
comparado coisa alguma. Por isso a suíte tem um fixture com `itens_no_plano =
99` e exige que a ferramenta **acuse**.

## `raku/gramatica_fasm.raku` — uma grammar, verificada contra o C

O plano diz que Raku entra para mostrar **a evolução sobre Perl**, e a
diferença que importa é esta: em Perl, um parser de formato é uma pilha de
regexes com nomes em comentário. Em Raku é uma `grammar` — regras nomeadas,
compostas, com a classe de ações separada da sintaxe.

O `lint_medicoes.pl` deste mesmo repositório é o contraste direto: lá o
problema é casamento oportunista em texto livre, e **Perl ganha**. Aqui o
problema tem gramática, e é outro jogo.

### O que torna isto verificável, e não decorativo

O subcomando `dis` emite o **mesmo formato** que o `fvm dis` do P01, com os
offsets em bytes:

```
000000  PUSH     7
000018  CALL     26 2
000024  PRINT
```

Casar isso obriga a grammar a conhecer o **tamanho de codificação de cada
instrução** e a resolver rótulos em endereços — ou seja, a fazer **as duas
passagens de um montador de verdade**. Um offset errado aparece na hora.

**Resultado: 9/9 byte a byte** contra o desmontador em C. É o mesmo padrão dos
portes do P01 (bytecode byte-idêntico) aplicado a um parser, e a verificação é
contra uma implementação independente, em outra linguagem.

### A lacuna que a verificação cruzada achou

A primeira versão da grammar só aceitava decimal, e o `arith.fasm` falhava em
`PUSH 0x10` com a mensagem inútil *"a grammar nao casou com o arquivo
inteiro"*.

A causa: o montador em C usa `strtoll(s, &end, 0)` — **base 0**, que aceita
`0x..`, `0..` e decimal. **Eu não sabia que o formato aceitava hexadecimal**, e
quem me disse foi o diff contra o C, não a leitura do meu próprio código.

É o argumento inteiro a favor de verificar contra implementação independente em
vez de contra a própria expectativa.

E a ordem das alternativas na gramática importa: hex antes de octal antes de
decimal. Se decimal viesse primeiro, `0x10` casaria o `0` e deixaria `x10` para
trás — silenciosamente.

### O espaço que ninguém vê

O diff inicial acusou **todos os 9 casos**, e a diferença era um espaço:

```
C:     000024  PRINT
Raku:  000024  PRINT
                    ^ um espaço a mais
```

O `fvm dis` emite `%-8s` para o mnemônico e depois `" %d"` para **cada**
operando. Eu havia escrito `%-8s %s`, o que acrescenta um espaço mesmo sem
operandos. Reproduzir um formato byte a byte inclui reproduzir o espaço em
branco final.

## `tcl/dirige_repl.exp` — o que a linha de comando não testa

Os portes do verificador em OCaml e F# foram testados **por linha de comando**:
rodar o binário, comparar a saída. O que isso não testa é o **REPL**: o estado
acumulado entre expressões, o prompt que muda de forma, o eco da entrada.

Em OCaml, `let x = 40;;` seguido de `x + 2;;` depende de o toplevel ter
guardado `x`. Nenhum teste de linha de comando exercita isso.

```
ocaml — o toplevel, e o estado que acumula entre expressoes
  ok  2 + 3 infere int = 5
  ok  let x = 40 liga o nome
  ok  x + 2 USA o nome ligado antes
  ok  identidade infere 'a -> 'a
  ok  1 + true e erro de tipo
  ok  sobrevive ao erro anterior

lua — o prompt que muda quando a expressao esta incompleta
  ok  o REPL anunciou a versao
  ok  print de soma, com sonda inequivoca
  ok  variavel global persiste
  ok  le a variavel da linha anterior
  ok  prompt de continuacao apareceu (>> para expressao incompleta)
  ok  a funcao fecha e e chamavel
```

Automatizar programa interativo é o terreno onde **Expect não tem
substituto**. Não é "Tcl é bom nisso": `spawn`, `expect` e `send` são a razão
pela qual o Expect foi escrito.

### O achado: o mesmo programa emite bytes diferentes num terminal

O teste do erro de tipo em OCaml falhava por *timeout* — parecendo que o REPL
não respondia, quando ele respondia perfeitamente.

Sob um **pty**, o OCaml liga as mensagens coloridas:

```
<ESC>[0m<ESC>[1;31mError<ESC>[0m: The constructor <ESC>[4mtrue<ESC>[0m has type bool
```

O padrão `has type bool` não casa, porque há escapes entre as palavras. Ele
também emite `<ESC>[1A` para redesenhar a linha de entrada.

**Nada disso aparece quando o mesmo comando lê de um pipe**: o OCaml detecta
que não é terminal e desliga as cores. Ou seja, o mesmo programa emite bytes
diferentes num terminal e num pipe — e é exatamente por isso que automatizar
programa interativo precisa de Expect, e por que **um teste por pipe não é o
mesmo teste**.

A correção foi `-color never` no `spawn`, documentada no arquivo.

### Três armadilhas do Expect, pagas em sequência

**`spawn` dentro de um `proc` torna `spawn_id` uma variável local.** O proc que
envia e espera, sendo outro escopo, lê o `spawn_id` **global**, que está vazio
— então `send` vai para o nada e `expect` vê `eof` na hora, com a mensagem "o
REPL morreu antes de responder". O sintoma é perfeito para enganar: parece que
o REPL caiu, e o REPL nunca foi falado. Resolve com `global spawn_id`.

**Casar a redação inteira de uma mensagem a quebra na próxima versão.** Eu
esperava `This expression has type bool`, de memória; o OCaml 5.4 diz `The
constructor true has type bool`. Casar o trecho **estável** é a diferença entre
um teste que sobrevive à atualização do compilador e um que não.

**Uma sonda genérica casa com o que não devia.** O teste do Lua esperava `5` e
casava o "5" de **"Lua 5.4"** — o banner ainda estava no buffer. Era um falso
positivo: o teste passaria sem o REPL ter calculado nada. Ajustar o regex não
resolve; a correção é tornar a **sonda** inequívoca (`SOMA=5`). Se a asserção
pode casar com algo sem relação, ela não é asserção.

## A suíte: 29 testes, nas duas direções

Cada ferramenta é testada **nas duas direções**: tem de achar o que deve achar
(fixture sujo) e ficar calada no que está certo (fixture limpo). São **29
verificações** no total.

Testar só uma direção é o erro clássico em ferramenta de análise: um lint
testado só contra código ruim passa mesmo se acusar tudo, e um testado só
contra código bom passa mesmo se não acusar nada.

### O que a suíte já pegou

No `lint_medicoes.pl`, três falsos negativos que eu **não acharia lendo o
código**:

* o contexto do parágrafo **atravessava o cabeçalho da seção seguinte**, e um
  título como `## Tabela sem coluna de dispersão` silenciava o achado pela
  palavra "dispersão" — contexto que parece justificar e não justifica, que é
  exatamente o que o lint combate;
* faltava `use utf8`, então o padrão `/µs/` era **dois bytes** no fonte contra
  **um caractere** na entrada: `318 µs` passava impune enquanto `318 us` era
  pego;
* a saída saía como mojibake, por ler em UTF-8 e escrever em bytes.

Os três são de categorias diferentes e nenhum aparece em revisão de código.

E nos meus próprios testes, **três** vezes a mesma família de erro — o
instrumento de observação corrompendo a observação:

* medi `$?` depois de `| tail`, medindo o `tail` em vez do programa: todos os
  casos "passavam" com 0;
* canalizei a saída do Expect por `head -8`, e quando o pipe fechou o Expect
  quebrou com `error writing "stdout": bad file number` — um erro sem relação
  nenhuma com o teste;
* e no P02, `pipefail` fazia a linha de base falhar sempre, porque os casos de
  erro saem com código não-zero **de propósito**.

É a razão de cada verificação aqui **redirecionar para arquivo em vez de
canalizar**.

## Roadmap

| linguagem | ferramenta prevista | terreno |
|---|---|---|
| **Groovy** | pipeline declarativo | Jenkins e Gradle de verdade |
| **Nix** | `nix develop` com o ambiente dos 14 projetos | o entregável que o plano chama de impressionante |
| **PowerShell** | o par POSIX↔Windows do mesmo trabalho | duas culturas, um problema |
| **AutoHotkey** | automação de desktop | desprezado e extremamente empregável |
| **VBA** | automação de planilha | idem — com a ressalva de exigir Office |
