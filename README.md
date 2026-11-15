# toolbelt — automação e higiene do próprio portfólio

Ferramentas que **fazem trabalho real neste portfólio**, cada uma na linguagem
que é a escolha natural daquele terreno.

```
bash verifica.sh          # todas as ferramentas, nas duas direções
bash verifica.sh perl     # só essa
```

> **Status:** 3 das 10 linguagens previstas. Perl, AWK e Lua estão completas e
> verificadas, com 22 testes. Tcl/Expect, Raku, Groovy, Nix, PowerShell,
> AutoHotkey e VBA pendentes — ver [Roadmap](#roadmap).

## O princípio: nenhuma ferramenta é demonstração

Cada uma resolve um problema que este portfólio **teve de verdade**, e duas
delas corrigiram erros meus na primeira execução.

| ferramenta | linguagem | o problema que resolve | como surgiu |
|---|---|---|---|
| `perl/lint_medicoes.pl` | Perl | número publicado sem dispersão ao lado | a auditoria do P03 corrigiu **7** afirmações com esse defeito, e eu as achei lendo à mão |
| `awk/estatistica.awk` | AWK | faixa, dispersão e a regra de decisão | reescrevi essa lógica em Elixir, Bash e Shell, **três vezes** |
| `lua/cobertura.lua` | Lua | planejado contra feito, com sobreposição | contei as linguagens à mão três vezes e **errei uma** |

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

## A suíte: 22 testes, nas duas direções

Cada ferramenta é testada **nas duas direções**: tem de achar o que deve achar
(fixture sujo) e ficar calada no que está certo (fixture limpo).

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

E nos meus próprios testes, duas vezes: eu medi `$?` depois de `| tail`,
medindo o `tail` em vez do programa — todos os casos "passavam" com 0. É a
mesma armadilha do `pipefail` que já havia aparecido no verificador do P02, e a
razão de cada verificação aqui **redirecionar em vez de canalizar**.

## Roadmap

| linguagem | ferramenta prevista | terreno |
|---|---|---|
| **Tcl/Expect** | dirigir um REPL de verdade | automação interativa, onde Expect não tem substituto |
| **Raku** | *grammar* para o `.fasm` do P01 | a evolução sobre Perl: regex nomeado e composicional |
| **Groovy** | pipeline declarativo | Jenkins e Gradle de verdade |
| **Nix** | `nix develop` com o ambiente dos 14 projetos | o entregável que o plano chama de impressionante |
| **PowerShell** | o par POSIX↔Windows do mesmo trabalho | duas culturas, um problema |
| **AutoHotkey** | automação de desktop | desprezado e extremamente empregável |
| **VBA** | automação de planilha | idem — com a ressalva de exigir Office |
