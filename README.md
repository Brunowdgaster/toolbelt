# toolbelt — automação e higiene do próprio portfólio

Ferramentas que **fazem trabalho real neste portfólio**, cada uma na linguagem
que é a escolha natural daquele terreno.

```
bash verifica.sh          # todas as ferramentas, nas duas direções
bash verifica.sh perl     # só essa
```

> **Status:** 11 linguagens, com **49 testes** POSIX + 9 Windows. O VBA foi
> **substituído por LibreOffice Basic** (livre), declarado como dialeto
> diferente — ver [LibreOffice Basic](#basiccoberturabas--a-planilha-que-confere-a-propria-conta).

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
| `nix/flake.nix` | Nix | os ambientes dos projetos, declarados | montei 25 toolchains à mão, e **nada disso estava declarado em lugar nenhum** |
| `groovy/relatorio.groovy` | Groovy | a saída dos verificadores em JUnit XML | 61 verificações do portfólio são **texto**, e nenhum painel de CI sabe lê-las |
| `pwsh/Audita-Repos.ps1` + `bash/audita-repos.sh` | PowerShell + Bash | cada repositório tem o mínimo? | os 5 repositórios **divergiram**, e a auditoria à mão é impossível de manter |
| `ahk/Verifica-Ambiente.ahk` | AutoHotkey | o que no desktop do Windows contamina a medição | o `calibra.sh` do P03 detecta o **efeito** e não pode dizer a **causa** |
| `basic/Cobertura.bas` | LibreOffice Basic | a cobertura como planilha **auditável** | o número que importa não é a soma das colunas, e numa planilha a fórmula fica à vista |

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

## `nix/flake.nix` — o ambiente que só existia no histórico de comandos

O plano chama isto de "o entregável que impressiona": um `nix develop` que
levanta o ambiente dos projetos. A razão prática é mais chata e mais
importante: **os ambientes foram montados à mão.**

O `setup.sh` do P03 instala 14 ferramentas com `apt-get`, e eu instalei outras
11 ao longo do portfólio — Nim, Odin, D, V, Ada, OCaml, .NET, Rakudo, Tcl,
Groovy, Nix. Duas delas (**Odin e V**) não estão no apt e vieram de release do
GitHub. Nada disso estava declarado em lugar nenhum: estava no histórico de
comandos de uma máquina.

```bash
cd nix
nix develop          # o mais leve (p12)
nix develop .#p01    # as 7 implementações da VM
nix develop .#p03    # erlang, elixir, gleam, go, rust, scala-cli, clojure, tofu
```

| shell | o que traz | download |
|---|---|---|
| `p01` | gcc, clang, cmake, rustc, nim, **odin**, ldc, **v**, gnat | 1,1 GiB |
| `p02` | ghc, ocaml, dotnet-sdk_10 | 576 MiB |
| `p03` | erlang, elixir, gleam, go, rustc, scala-cli, jdk, clojure, opentofu, docker, kind | 1,1 GiB |
| `p12` | perl, gawk, lua, rakudo, tcl, expect, groovy, pwsh, ocaml | 694 MiB |

**As 28 ferramentas do portfólio existem no nixpkgs**, inclusive as que não
estão no apt do Ubuntu: `odin`, `vlang`, `gnat14`, `gleam`, `rakudo`, `groovy`,
`powershell`, `opentofu`, `scala-cli`. Essa foi a surpresa agradável — eu
esperava ter de empacotar duas ou três à mão.

### A versão do nixpkgs foi escolhida por um motivo medido

A primeira versão deste flake travava em `nixos-25.05`, e ele **não serve**:
traz **Gleam 1.11**, enquanto o `manifest.toml` do P03 tem a stdlib travada
numa versão que declara `gleam >= 1.14`.

Com o 25.05, `nix develop .#p03` avalia, constrói, entra — e falha ao rodar
`gleam test`, com o mesmo erro *"Incompatible Gleam version"* que já tinha
derrubado o CI daquele projeto uma vez.

**Um flake que levanta um ambiente onde o projeto não compila é pior que
nenhum flake: ele promete e não entrega.** Trocado para `nixos-25.11`, que traz
Gleam 1.16.

E a mesma checagem achou outra lacuna: eu havia posto o pacote `scala`, mas o
P03 compila com **`scala-cli`** e precisa de **JDK ≥ 21** porque o experimento
usa `Thread.ofVirtual`. O `scala` do nixpkgs é o compilador, não a ferramenta
que os scripts invocam — o shell avaliaria e não rodaria o projeto.

### O que o flake NÃO promete

**Não reproduz os números medidos**, e isso precisa estar dito.

As medições do portfólio foram feitas com as versões do `apt` do Ubuntu 26.04;
o nixpkgs travado tem outras:

| | apt (medido com) | flake (nixos-25.11) |
|---|---|---|
| Erlang | 27 | 28.5.0.2 |
| Gleam | 1.19.2 | 1.16.0 |
| Go | 1.26.8 | 1.25.10 |
| Rust | 1.93.1 | 1.91.1 |
| OCaml | 5.4.0 | 5.3.0 |
| Lua | 5.4.8 | 5.4.7 |

Nix reproduz o **ambiente declarado**, com exatidão de hash. Mas *"o mesmo
ambiente"* e *"as mesmas versões que eu usei"* são coisas diferentes, e
confundir as duas seria prometer reprodutibilidade que não existe. Para
reproduzir uma medição é preciso casar as versões, e é por isso que cada
projeto registra as suas no README.

O que o flake entrega é o que importa na prática: **qualquer pessoa compila e
testa os projetos sem instalar nada à mão.**

### Avaliar e construir são verificações diferentes

Esta é a decisão de projeto do teste, e ela existe porque a alternativa era não
ter teste nenhum.

| | o que prova | custo |
|---|---|---|
| **avaliar** | todo nome de pacote existe; a expressão está correta | segundos, zero download |
| **construir** | o shell de fato funciona | 576 MiB a 1,1 GiB **por shell** |

A suíte avalia os quatro shells sempre, e constrói **um** só com
`NIX_CONSTROI=1`. Sem essa separação, a escolha seria entre um teste de 4 GiB e
nenhum teste.

A avaliação não é cerimônia: ela resolve cada `devShell` até o nome da
derivação, o que obriga **todo** nome de pacote a existir no nixpkgs travado.
Um nome errado falha em segundos, em vez de na metade de um download de 1 GiB.

E a construção, quando roda, faz a verificação mais forte que existe aqui:
entra no shell declarado e **roda a suíte deste repositório dentro dele**.

```
  ambiente: p12-toolbelt (automação e higiene)
  perl gawk lua rakudo tcl expect groovy pwsh ocaml

perl 5.40.0
Lua 5.4.8
Built on MoarVM version 2025.06
Groovy Version: 5.0.2 JVM: 21.0.10
PowerShell 7.5.4

  29 passaram, 0 falharam
```

### E o segundo ambiente achou o que o primeiro nunca acharia

Na primeira vez, a suíte deu **28 de 29 dentro do shell** e 29 de 29 fora. O
teste que falhava era o erro de tipo do OCaml no roteiro do Expect.

A causa: o flake traz **OCaml 5.3**, o apt traz **5.4**, e as duas versões
formatam a mesma mensagem de forma diferente:

```
5.3:  Error: The constructor "true" has type "bool"
5.4:  Error: The constructor true has type bool
```

O 5.3 põe os tipos **entre aspas**. O padrão `has type bool` não casa com
`has type "bool"`.

E o detalhe que torna isso uma lição e não um acidente: **essa linha já havia
sido corrigida uma vez.** A primeira versão casava `This expression has type
bool`, redação de uma versão mais antiga que escrevi de memória; corrigi para
`has type bool` justamente argumentando que era "o trecho estável". Não era.

A terceira versão afirma o **conteúdo** em vez da redação — `Error:` seguido de
`bool` em qualquer lugar da mensagem. É o que o teste de fato quer provar.

**Essa é a razão prática de ter um ambiente declarado**, acima da
reprodutibilidade: ele é um *segundo* ambiente, com versões diferentes, e um
segundo ambiente encontra as suposições que o primeiro nunca questionaria. O
flake pagou por si antes mesmo de ser publicado.

### Três decisões, e duas armadilhas

**Release, não `nixos-unstable`.** Um flake apontado para unstable muda de
versão a cada `nix flake update` e deixa de responder "com o que isso foi
construído". O `flake.lock` commitado é o que faz a declaração valer.

**O `default` não é a união de tudo.** As 28 ferramentas juntas passariam de
4 GiB, e quase ninguém precisa delas ao mesmo tempo. O padrão é o `p12`, o mais
leve, e a mensagem de entrada diz como pedir os outros — em vez de castigar
quem digitou `nix develop` sem argumento. A suíte testa isso, porque é o tipo
de decisão que se perde numa refatoração.

**Cada shell anuncia o que tem dentro.** Um shell que não diz o que trouxe
obriga quem entrou a adivinhar, e `nix develop` não tem `--list`.

**Armadilha 1: um flake num repositório git só vê arquivos rastreados.**
`nix flake show` falhou com *"Path 'nix/flake.nix' ... is not tracked by Git"*
até o `git add`. É o primeiro tropeço de todo mundo com flakes.

**Armadilha 2: `nix eval nixpkgs#foo` usa o REGISTRY, não o seu flake.** Eu
levantei a tabela de versões com `nix eval --raw nixpkgs#ghc.name` e publiquei
GHC 9.10.3 — mas o flake travado entrega **9.8.4**. O `nixpkgs#` resolve pelo
registry local, que aponta para outro commit. A consulta certa é pelo próprio
flake (`nix eval .#devShells...nativeBuildInputs`), e a tabela acima foi
refeita assim.

## `groovy/relatorio.groovy` — texto legível por humano, invisível para CI

Todo verificador deste portfólio emite texto:

```
ok    fixture limpo: 0 achados
FALHA o shell p03 não resolve
```

É legível por humano e **invisível para CI**. O GitHub Actions e o Jenkins sabem
ler **JUnit XML** — e com ele mostram cada verificação como um teste, com nome e
mensagem de falha, em vez de um log em que alguém tem de procurar.

Os 42 testes do toolbelt, os 23 do P02 e os 9 dos portes do P01 passam a
aparecer como **74 testes num relatório só**.

```xml
<testsuites tests="4" failures="1" name="toolbelt">
  <testsuite name="ferramenta/exemplo.sh" tests="3" failures="1">
    <testcase name="segunda verificação falha" classname="ferramenta/exemplo.sh">
      <failure message="esperado '5', obtido '3' | e uma segunda linha de detalhe"/>
    </testcase>
  </testsuite>
</testsuites>
```

### Por que em Groovy

Porque o trabalho é **ler um formato e emitir outro**, e as duas pontas são o
terreno dos *builders*: o `MarkupBuilder` escreve XML com a forma do XML, sem
concatenar string nem escapar `&` à mão. E a JVM é onde o JUnit XML nasceu,
então o formato não precisa ser adivinhado.

É literalmente o papel que Groovy tem no Jenkins: a cola entre uma ferramenta
que produz texto e um painel que espera estrutura.

### Três decisões que o teste trava

**Grupo vazio não vira `<testsuite>`.** O banner do verificador tem travessão e
é reconhecido como cabeçalho, mas não tem caso embaixo. Uma suíte com zero
testes é ruído no painel, e em alguns deles conta como "sem resultado", o que
parece problema.

**O detalhe multilinha chega na mensagem.** Perder o detalhe transforma o
relatório em "falhou, descubra por quê".

**Entrada sem nenhum caso reconhecido falha alto.** Um XML vazio e verde é o
pior resultado possível: **ele parece sucesso**. A ferramenta sai com 65 e diz
qual formato esperava.

## O par POSIX↔Windows: as duas culturas, lado a lado

O plano pede "o mesmo script, duas culturas". `pwsh/Audita-Repos.ps1` e
`bash/audita-repos.sh` auditam os repositórios do portfólio — README, LICENSE,
`.gitattributes`, CI, `.gitignore` — e **o teste exige que as duas concordem**,
repositório por repositório.

Testar cada uma isolada provaria que as duas rodam, não que fazem o mesmo
trabalho.

### A diferença não é sintaxe, é o que a linguagem considera um valor

| | Bash | PowerShell |
|---|---|---|
| saída de comando | texto | **objeto com campos** |
| estruturar | escolher separador e esperar que não apareça nos dados | `Select-Object`, campos nomeados |
| emitir JSON | **12 linhas** de função de escape | `ConvertTo-Json`, uma linha |
| lista de registros | três arrays paralelos, alinhados por disciplina | lista de hashtables |
| código de saída de um comando | `$?`, direto | `$LASTEXITCODE`, e `$?` significa outra coisa |

As quatro primeiras favorecem o PowerShell; **a última favorece o Bash**, e é
por isso que os dois existem aqui: comparação honesta tem as duas direções.

Os casos concretos estão no código, não na tabela:

* a função `json_escapa` do Bash tem 12 linhas e trata barra, aspas e controle
  — a barra invertida primeiro, senão ela escapa o que vem depois. No par em
  PowerShell é `ConvertTo-Json -Depth 4`;
* os itens verificados são **três arrays paralelos** em Bash, com um
  guarda-corpo que aborta se eles desalinharem, porque desalinhá-los é um bug
  que nada detecta. Em PowerShell são hashtables com campos nomeados;
* e no PowerShell, `$?` depois de chamar `git` indica se o PowerShell
  **conseguiu invocar** o comando, não o código que ele devolveu. Confundir os
  dois é o erro clássico de quem vem do shell POSIX, e ele é silencioso.

### E a comparação só roda no shell do Nix

O `pwsh` não está instalado no WSL desta máquina — ele vem do
`nix/flake.nix`. Então a verificação de que as duas implementações concordam
roda **dentro do ambiente declarado**:

```
$ nix develop .#p12 --command bash -c 'cd .. && bash verifica.sh par'
  ok    o JSON do Bash é válido (escapado à mão, 12 linhas de função)
  ok    Bash e PowerShell concordam, repositório por repositório
  ok    --listar diz por que cada item é obrigatório
```

É o flake servindo para algo concreto, e não só como declaração: **ele é o que
torna o teste do par possível nesta máquina.**

### A ferramenta achou uma lacuna no primeiro uso

```
repo               completo   publicado   faltando
----------------------------------------------------------------------
p01-metal-vm       sim        sim
p02-forge-lang     sim        sim
p03-otp-mesh       sim        sim
p12-toolbelt       sim        sim
poliglota          NAO        sim         .github/workflows
```

O repositório de índice do portfólio **não tinha CI**. Era documentação, então
parecia não ter o que verificar — e tinha duas coisas:

1. os números publicados ali têm dispersão ou método ao lado?
2. a contagem de linguagens declarada confere com o `ROADMAP`?

O CI foi acrescentado, clonando este toolbelt para rodar as duas verificações.
E a primeira execução do lint sobre o índice **achou dois números defasados**:
o `CONTEXTO.md` ainda carregava `1.400x` (ETS) e `254x` (`off_heap`), que são
os valores **pré-auditoria** — eu corrigi o README do P03 para ~912x e ~66x e
esqueci o índice.

Número publicado sem dispersão ao lado é número que ninguém revisita.

## `ahk/Verifica-Ambiente.ahk` — a outra metade do calibrador

Uma medição do p03-otp-mesh foi publicada e depois corrigida porque havia **um
jogo e um navegador com vídeo** abertos enquanto ela rodava. O
`bench/calibra.sh` daquele projeto nasceu disso: ele mede um laço fixo e detecta
que a máquina está ocupada.

Mas o `calibra.sh` roda dentro do WSL2, e lá ele detecta o **efeito** sem poder
dizer a **causa** — processos do Windows não aparecem no `/proc` do Linux. Foi
medido naquele projeto: com 4 núcleos do Windows ocupados, o laço inflou 74% e o
`loadavg` do WSL2 mal se moveu.

Esta ferramenta é a outra metade. Ela olha o desktop do Windows e **nomeia** o
que está consumindo CPU, com processo e título de janela:

```
Processos acima de 3.0% de CPU no desktop do Windows:
(instantaneo: o contador do WMI e por amostra, nao media)

    WindowsTerminal.exe        5.0%  outro       -- ◐ Projetos de domínio de linguagens
  ! WmiPrvSE.exe              10.0%  sistema
  ! chrome.exe                15.0%  navegador   -- (573) Hércules HD | Destripando la Histo
  ! chrome.exe               103.0%  navegador

4 processo(s) marcado(s) com ! vao contaminar qualquer medicao de tempo.
```

A primeira execução pegou **`chrome.exe` a 103% de CPU**, com o título da
janela mostrando um vídeo. É literalmente o cenário que contaminou a medição do
P03 — e agora ele é nomeado, não suposto.

### Por que em AutoHotkey

Porque o problema é **acesso ao desktop do Windows**: `WinGetList` com
`DetectHiddenWindows false` dá as janelas que o usuário de fato vê, e o título
é o que distingue "navegador tocando vídeo" de "navegador parado numa aba de
texto". Tudo builtin, zero dependência.

O mesmo em PowerShell precisaria de `Get-Process` mais P/Invoke para os
títulos; em Python, de `pywin32`.

AHK é desprezado por ser "linguagem de macro", e esta é a ferramenta que mostra
por que isso é injusto: 200 linhas, nenhuma dependência, e faz uma coisa que as
alternativas fazem com mais cerimônia.

### O que a torna testável

AHK v2 escreve em stdout com `FileAppend(texto, "*", "UTF-8-RAW")`, então a
saída é comparável como a de qualquer script. E `--autoteste` exercita as
funções puras — classificação de processo, veredito, escape de JSON — com
entradas fixas, **sem depender do que estiver aberto na máquina**:

```
  ok    chrome.exe e navegador
  ok    sistema contamina (indexador rouba CPU igual)
  ok    outro NAO contamina
  ok    escapa barra antes do resto
  12 passaram, 0 falharam
```

A separação entre funções puras e acesso ao sistema é o que permite isso: o
desktop é inerentemente irreprodutível, e o que se pode testar de rotina é a
lógica.

### Duas janelas na tela do usuário, e o que elas ensinaram

O AutoHotkey reporta erro por **caixa de diálogo**, e o processo fica parado
esperando alguém fechar. Em automação isso é fatal: o script pendura e nada no
log diz por quê. Aconteceu **duas vezes** durante o desenvolvimento — na tela
de quem estava acompanhando:

**1. `/validate` sem `/ErrorStdOut`.** O erro de sintaxe abriu janela em vez de
escrever em stderr. Com `/ErrorStdOut`, o mesmo erro vai para stdout e o
processo sai com 2.

**2. Caminho POSIX para um programa Windows.** Invoquei
`AutoHotkey64.exe ./ahk/Verifica-Ambiente.ahk` do Git Bash, o AHK não achou o
arquivo, e abriu "script not found" — e **`/ErrorStdOut` não cobre esse**,
porque é erro de *launcher*, antes de o script ser lido.

Por isso o `verifica.ps1` **confere que o arquivo existe antes de invocar o
AHK**, e sempre com caminho absoluto do Windows. A verificação não é
paranoia: é a única forma de o harness nunca entregar caminho ruim ao AHK.

## `basic/Cobertura.bas` — a planilha que confere a própria conta

O plano original pedia **VBA**. VBA exige Microsoft Office, que é **pago**, e a
regra declarada do portfólio é *nenhum recurso pago*. Então o item foi feito em
**LibreOffice Basic** — livre (MPL-2.0), roda *headless* — e está **rotulado
como tal**, não como VBA.

```
$ ./basic/roda.sh
total=40
distintas=39
sobreposicao=1
linhas=14
```

O `total=40` **não foi calculado pelo Basic**: ele saiu do motor de cálculo do
LibreOffice avaliando `=SUM(C2:C15)`, e a macro o **leu de volta** da célula.
O `distintas=39` vem do `cobertura.lua`. A suíte compara os dois, e a
sobreposição de 1 é o Rust, que aparece no P01 e no P03.

### Por que uma planilha, e não mais um relatório de texto

Porque a conta que importa **não é a soma das colunas**. A planilha gravada
tem `=SUM()` de verdade no `content.xml` — quem abre vê a fórmula e confere.
Se a macro escrevesse o total já somado, o arquivo pareceria igual e não
seria, e a suíte tem um teste exatamente para isso:

```
  ok    o .ods guarda =SUM() de verdade, não um valor pré-somado
```

### O que não é VBA, concretamente

| | VBA | LibreOffice Basic |
|---|---|---|
| sintaxe | `Sub`, `Dim`, `For...Next`, `Option Explicit` | **iguais** |
| modelo de objetos | `Workbooks`, `Worksheets`, `Range("A1")` | UNO: `ThisComponent.Sheets.getByIndex(0).getCellByPosition(0,0)` |
| onde a macro mora | dentro do `.xlsm` | numa biblioteca do perfil, em arquivo de texto |

O LibreOffice tem `Option VBASupport 1`, que liga uma camada de
compatibilidade e faz `Range` funcionar. **Este arquivo não a usa**, de
propósito — usá-la seria escrever VBA fingido num produto que não é o Office.
A suíte falha se o `Option` aparecer.

E a macro morar em **arquivo de texto** em vez de dentro de um binário é uma
vantagem real num repositório: o código é versionável e revisável.

### Três coisas que custaram tempo

**O perfil tem de ser inicializado pelo LibreOffice.** A primeira versão criava
a árvore `user/basic/Standard` à mão, com um `script.xlb` escrito por mim. A
macro **não rodava, e sem mensagem nenhuma**: stdout e stderr vazios, retorno
0. Deixando o LibreOffice criar o perfil, vê-se que ele já registra um módulo
`Module1` — e o caminho certo é sobrescrever esse módulo, não inventar o
índice.

**O perfil é dedicado, via `-env:UserInstallation`.** Um teste que mexe na
instalação de LibreOffice de quem está na máquina é um teste que não se pode
rodar duas vezes com confiança.

**Nenhum `MsgBox` no caminho normal.** Janela em automação pendura o processo
até o *timeout* — a mesma armadilha que o AutoHotkey deste repositório já
custou duas vezes. A macro escreve num arquivo, e a suíte verifica que só
existe um `MsgBox`, no caminho de erro de configuração.

## A metade Windows da suíte, e por que ela é separada

`verifica.sh` roda em bash e cobre as ferramentas POSIX. `verifica.ps1` cobre
as duas que são **do mundo Windows** — e fingir que bash as testa seria pior
que declarar a separação.

É a mesma divisão do par POSIX↔Windows que o projeto já tem: duas culturas,
cada uma verificada na sua. No CI são dois jobs, um em `ubuntu-latest` e um em
`windows-latest`.

### Três fricções reais, e a terceira só o CI podia achar

O par expôs três diferenças que não aparecem em tabela comparativa nenhuma:

**`Join-Path a b c` é só PowerShell 7+.** A forma de três argumentos
(`-AdditionalChildPath`) falha no 5.1 com `PositionalParameterNotFound` — e
falha na avaliação do **valor padrão** de um parâmetro, então só aparece quando
o parâmetro *não* é passado. A correção é `Join-Path` aninhado.

**O 5.1 lê script UTF-8 sem BOM como ANSI.** Os acentos saíam como `â€”` e
`mediÃ§Ã£o`. Os `.ps1` deste repositório são gravados **com BOM**, que é o que
o 5.1 exige.

**Um pipeline que produz UM objeto não é um array.** Sob `Set-StrictMode`,
`.Count` nesse objeto lança *"The property 'Count' cannot be found"*.

Essa terceira **só o CI podia achar**: localmente há 5 repositórios e o laço
devolvia array; no runner o repositório está sozinho, e devolveu um objeto só.
A correção é envolver cada fonte de `.Count` em `@( ... )`.

No par em Bash isso não existe — array é explícito, e um elemento é um array de
um elemento.

### E chamar um programa externo tem três camadas

Esta é a que mais favorece o Bash, e ela cresceu durante o desenvolvimento:

1. `$?` indica se o PowerShell conseguiu **invocar** o comando, não o código
   que ele devolveu — e é silencioso;
2. o código de verdade está em `$LASTEXITCODE`;
3. e com `$ErrorActionPreference = 'Stop'`, o que o programa escreve em
   **stderr** vira erro **terminante** — então um `git remote` num diretório com
   `.git` inválido (repositório corrompido, submódulo, arquivo `.git` de
   worktree) **aborta a auditoria inteira**.

A terceira camada apareceu num teste com um `.git` falso. Em Bash as três
colapsam em `if git -C "$repo" remote >/dev/null 2>&1`.

E o contraste que isso cria é o detalhe favorito desta seção:

| arquivo | BOM |
|---|---|
| `.ps1` | **obrigatório** — sem ele o PowerShell 5.1 lê como ANSI |
| JSON do AHK | **proibido** — com ele o JSON é inválido para parser estrito |

A mesma sequência de três bytes é exigida num lugar e proibida no outro, e as
duas coisas são testadas.

## A suíte: 42 testes, nas duas direções

Cada ferramenta é testada **nas duas direções**: tem de achar o que deve achar
(fixture sujo) e ficar calada no que está certo (fixture limpo). São **42
verificações**, mais uma que **só roda dentro do shell do Nix** — a comparação
entre o par Bash e PowerShell, porque o `pwsh` vem de lá.

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
| **LibreOffice Basic** | automação de planilha | no lugar do VBA, que exige Office pago — ver abaixo |

### VBA: o bloqueio, e o que entrou no lugar

Verificado nesta máquina: **não há Office nem LibreOffice instalado**, e
`Excel.Application`/`Word.Application` não estão registrados.

VBA exige Microsoft Office, que é **pago** — e a regra declarada do portfólio é
*nenhum recurso pago*. Então VBA, como VBA, está bloqueado, e isso é um
resultado: é o único item de 139 do plano que a restrição de custo barra.

O caminho livre é **LibreOffice Basic** com `Option VBASupport 1`, que cobre a
maior parte do mesmo terreno e roda *headless* (`soffice --headless
"macro:///..."`), o que o torna testável. Mas é um **dialeto diferente**, e
chamá-lo de VBA seria a mesma desonestidade que chamar o flake de "reproduz os
números medidos".

A decisão ficou declarada em vez de escondida, e foi executada:
`basic/Cobertura.bas` está feito, verificado por 7 testes, e **rotulado como
LibreOffice Basic**. O registro do que a instalação acrescentou à máquina — e
como removê-la — está em
[AMBIENTE.md](https://github.com/Brunowdgaster/poliglota/blob/main/AMBIENTE.md).
