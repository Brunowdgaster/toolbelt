#!/usr/bin/env bash
#
# verifica.sh — testa as ferramentas do toolbelt.
#
#   bash verifica.sh            # todas
#   bash verifica.sh perl awk   # só essas
#
# ## O princípio
#
# Cada ferramenta aqui é testada **nas duas direções**: tem de achar o que
# deve achar (fixture sujo) e tem de ficar calada no que está certo (fixture
# limpo).
#
# Testar só uma direção é o erro clássico em ferramenta de análise: um lint que
# só é testado contra código ruim passa mesmo se acusar tudo, e um testado só
# contra código bom passa mesmo se não acusar nada. As duas fixtures juntas
# prendem a ferramenta entre falso positivo e falso negativo.
#
# ## O que esta suíte já pegou
#
# Na primeira execução contra as fixtures, o `lint_medicoes.pl` tinha **três
# falsos negativos** que eu não teria achado lendo o código:
#
#   * o contexto do parágrafo atravessava o cabeçalho da seção SEGUINTE, e um
#     título como "## Tabela sem coluna de dispersão" silenciava o achado pela
#     palavra "dispersão" — contexto que parece justificar e não justifica, que
#     é exatamente o que o lint existe para combater;
#   * faltava `use utf8`, então o padrão `/µs/` era dois BYTES no fonte contra
#     um CARACTERE na entrada, e "318 µs" passava impune enquanto "318 us" era
#     pego;
#   * e a saída saía como mojibake, por ler em UTF-8 e escrever em bytes.
#
# Os três são de categorias diferentes e nenhum aparece em revisão de código.

set -uo pipefail

cd "$(dirname "$0")"

FERRAMENTAS=(perl awk lua raku tcl nix groovy par)
[ $# -gt 0 ] && FERRAMENTAS=("$@")

passou=0
falhou=0

ok() {
  printf '  \033[32mok\033[0m    %s\n' "$1"
  passou=$((passou + 1))
}

bad() {
  printf '  \033[31mFALHA\033[0m %s\n' "$1"
  [ -n "${2:-}" ] && printf '        %s\n' "$2"
  falhou=$((falhou + 1))
}

# Compara um número esperado com o obtido, e mostra os dois na falha — em vez
# de só dizer "falhou", que obriga quem lê a reexecutar à mão.
igual() { # $1 = rótulo, $2 = esperado, $3 = obtido
  if [ "$2" = "$3" ]; then
    ok "$1"
  else
    bad "$1" "esperado '$2', obtido '$3'"
  fi
}

echo
echo "=============================================================="
echo "  toolbelt — ferramentas de higiene do portfólio"
echo "=============================================================="

# ------------------------------------------------------------------- perl
if [[ " ${FERRAMENTAS[*]} " == *" perl "* ]]; then
  echo
  echo "perl/lint_medicoes.pl — número publicado sem dispersão ao lado"
  echo

  if ! command -v perl >/dev/null; then
    bad "perl ausente" "sudo apt-get install perl"
  else
    # `perl -c` antes de tudo: erro de sintaxe daria "0 achados" nas duas
    # fixtures, e os dois testes passariam pelo motivo errado.
    if perl -c perl/lint_medicoes.pl >/dev/null 2>&1; then
      ok "compila (perl -c)"
    else
      bad "não compila" "$(perl -c perl/lint_medicoes.pl 2>&1 | head -3)"
    fi

    total() {
      perl perl/lint_medicoes.pl --resumo "$1" 2>/dev/null |
        awk '/^TOTAL/ { print $2 }'
    }

    igual "fixture limpo: 0 achados (11 padrões legítimos)" "0" "$(total perl/t/limpo.md)"
    igual "fixture sujo: 6 achados (6 defeitos)" "6" "$(total perl/t/sujo.md)"

    # Código de saída: a ferramenta serve de portão de CI, então o código tem
    # de refletir o veredito.
    perl perl/lint_medicoes.pl --resumo perl/t/limpo.md >/dev/null 2>&1
    igual "sai 0 no fixture limpo" "0" "$?"

    perl perl/lint_medicoes.pl --resumo perl/t/sujo.md >/dev/null 2>&1
    igual "sai 1 no fixture sujo" "1" "$?"

    # O orçamento tem de deixar passar exatamente o que ele promete.
    perl perl/lint_medicoes.pl --orcamento 6 --resumo perl/t/sujo.md >/dev/null 2>&1
    igual "--orcamento 6 aceita 6 achados" "0" "$?"

    perl perl/lint_medicoes.pl --orcamento 5 --resumo perl/t/sujo.md >/dev/null 2>&1
    igual "--orcamento 5 recusa 6 achados" "1" "$?"

    # A exclusão de código inline tem de ser CIRÚRGICA: o último caso do
    # fixture sujo tem código inline E um número em prosa na mesma linha, e o
    # número tem de ser pego. Uma exclusão que descartasse a linha inteira
    # passaria neste teste pelo motivo errado.
    saida=$(perl perl/lint_medicoes.pl perl/t/sujo.md 2>&1)
    if grep -q '9,4 ms' <<<"$saida"; then
      ok "código inline é excluído sem descartar a linha"
    else
      bad "a exclusão de código inline engoliu a linha inteira"
    fi

    # E a ferramenta passa no PRÓPRIO README, que é cheio de números.
    perl perl/lint_medicoes.pl --resumo README.md >/dev/null 2>&1
    igual "passa no próprio README (orçamento 0)" "0" "$?"
  fi
fi

# -------------------------------------------------------------------- awk
if [[ " ${FERRAMENTAS[*]} " == *" awk "* ]]; then
  echo
  echo "awk/estatistica.awk — faixa e dispersão de uma coluna de medições"
  echo

  if ! command -v awk >/dev/null; then
    bad "awk ausente"
  else
    # 1. Vazão (maior é melhor): dados reais da medição de contadores do
    #    p03-otp-mesh. As faixas não se tocam, então trava a regra de nível 1.
    obtido=$(awk -f awk/estatistica.awk awk/t/amostras.txt 2>&1)
    esperado=$(cat awk/t/amostras.esperado)
    if [ "$obtido" = "$esperado" ]; then
      ok "vazão: saída idêntica ao esperado"
    else
      bad "vazão divergiu" "$(diff <(echo "$esperado") <(echo "$obtido") | head -8)"
    fi

    # 2. Latência (menor é melhor): o MESMO arquivo com o critério trocado dá
    #    o vencedor OPOSTO, e é por isso que o cabeçalho imprime o critério.
    obtido=$(awk -f awk/estatistica.awk -v menor_melhor=1 awk/t/latencia.txt 2>&1)
    esperado=$(cat awk/t/latencia.esperado)
    if [ "$obtido" = "$esperado" ]; then
      ok "latência: saída idêntica ao esperado"
    else
      bad "latência divergiu" "$(diff <(echo "$esperado") <(echo "$obtido") | head -8)"
    fi

    # 3. O critério errado inverte o vencedor. Este teste existe para provar
    #    que o perigo é real, não hipotético: a tabela fica plausível e a
    #    conclusão fica trocada.
    certo=$(awk -f awk/estatistica.awk -v menor_melhor=1 awk/t/latencia.txt |
            grep -o 'DECIDIDO: [a-z]*' | head -1)
    errado=$(awk -f awk/estatistica.awk awk/t/latencia.txt |
             grep -o 'DECIDIDO: [a-z]*' | head -1)
    if [ "$certo" = "DECIDIDO: beam" ] && [ "$errado" = "DECIDIDO: loom" ]; then
      ok "critério trocado inverte o vencedor (perigo demonstrado)"
    else
      bad "o critério não inverteu como esperado" "certo='$certo' errado='$errado'"
    fi

    # 4. Falha alto em linha malformada, em vez de tratar como zero. Zero
    #    silencioso viraria "melhor amostra" num relatório de latência.
    printf 'bom 10\nruim\n' | awk -f awk/estatistica.awk >/dev/null 2>&1
    igual "sai 1 em linha com um campo só" "1" "$?"

    printf 'bom 10\nruim abc\n' | awk -f awk/estatistica.awk >/dev/null 2>&1
    igual "sai 1 em campo não numérico" "1" "$?"

    printf '# so comentario\n' | awk -f awk/estatistica.awk >/dev/null 2>&1
    igual "sai 1 em entrada sem amostras" "1" "$?"

    # 5. Três rótulos: tabula e NÃO conclui, porque comparar vários pares
    #    exigiria correção para múltiplas comparações.
    saida=$(printf 'a 1\nb 2\nc 3\n' | awk -f awk/estatistica.awk 2>&1)
    if grep -q 'apenas TABULA' <<<"$saida"; then
      ok "três rótulos: tabula sem concluir"
    else
      bad "três rótulos deveriam apenas tabular" "$(echo "$saida" | tail -3)"
    fi
  fi
fi

# -------------------------------------------------------------------- lua
if [[ " ${FERRAMENTAS[*]} " == *" lua "* ]]; then
  echo
  echo "lua/cobertura.lua — planejado contra feito, por projeto"
  echo

  LUA=$(command -v lua5.4 || command -v lua || true)

  if [ -z "$LUA" ]; then
    bad "lua ausente" "sudo apt-get install lua5.4"
  else
    obtido=$("$LUA" lua/cobertura.lua lua/t/registro.lua 2>&1)
    esperado=$(cat lua/t/registro.esperado)
    if [ "$obtido" = "$esperado" ]; then
      ok "fixture: saída idêntica ao esperado"
    else
      bad "fixture divergiu" "$(diff <(echo "$esperado") <(echo "$obtido") | head -8)"
    fi

    # A SOBREPOSIÇÃO é o número que a contagem à mão erra: no fixture, uma
    # linguagem aparece em dois projetos, então a soma por projeto é maior que
    # o conjunto de distintas.
    saida=$("$LUA" lua/cobertura.lua lua/t/registro.lua 2>&1)
    if grep -q 'sobreposicao em 1' <<<"$saida"; then
      ok "detecta a sobreposição entre projetos"
    else
      bad "não detectou a sobreposição" "$(grep -i sobrepos <<<"$saida")"
    fi

    # Os códigos de saída, SEM pipe.
    #
    # A primeira versão destes testes media `$?` depois de `| tail`, e media o
    # tail em vez do programa — todos os casos "passavam" com 0. É a mesma
    # armadilha do pipefail no verificador do p02, e a razão de cada
    # verificação aqui redirecionar em vez de canalizar.
    "$LUA" lua/cobertura.lua lua/t/registro.lua >/dev/null 2>&1
    igual "sai 0 com registro válido" "0" "$?"

    "$LUA" lua/cobertura.lua lua/t/invalido.lua >/dev/null 2>&1
    igual "sai 1 com feitas > planejadas" "1" "$?"

    "$LUA" lua/cobertura.lua /dev/null/inexistente >/dev/null 2>&1
    igual "sai 1 com arquivo inexistente" "1" "$?"

    echo 'return { x = 1 }' > /tmp/toolbelt_sem_projetos.lua
    "$LUA" lua/cobertura.lua /tmp/toolbelt_sem_projetos.lua >/dev/null 2>&1
    igual "sai 1 sem o campo 'projetos'" "1" "$?"

    # O cruzamento com o ROADMAP não pode passar VACUAMENTE: se o parser do
    # roadmap não achasse nada, não haveria divergência e o teste passaria sem
    # ter comparado coisa alguma.
    if [ -f ../poliglota/ROADMAP.md ]; then
      "$LUA" lua/cobertura.lua lua/t/divergente.lua \
        --roadmap ../poliglota/ROADMAP.md >/dev/null 2>&1
      igual "sai 1 quando o registro divergiu do ROADMAP" "1" "$?"

      "$LUA" lua/cobertura.lua lua/registro.lua \
        --roadmap ../poliglota/ROADMAP.md >/dev/null 2>&1
      igual "o registro REAL confere com o ROADMAP real" "0" "$?"
    else
      ok "(ROADMAP não disponível; cruzamento não testado)"
    fi
  fi
fi

# ------------------------------------------------------------------- raku
if [[ " ${FERRAMENTAS[*]} " == *" raku "* ]]; then
  echo
  echo "raku/gramatica_fasm.raku — grammar do assembly, contra o desmontador em C"
  echo

  P01="${P01:-../p01-metal-vm}"
  FVM="$P01/build-switch/fvm"

  if ! command -v raku >/dev/null; then
    bad "raku ausente" "sudo apt-get install rakudo"
  elif [ ! -x "$FVM" ]; then
    # O p01 é um repositório separado. Sem ele, a verificação cruzada é
    # IMPOSSÍVEL -- e dizer isso é melhor que rodar meio teste.
    bad "o fvm do p01 não existe em $FVM" \
        "clone github.com/Brunowdgaster/metal-vm e rode bash build.sh"
  else
    casos=0
    iguais=0
    primeiro_diff=""

    for f in "$P01"/tests/cases/*.fasm; do
      casos=$((casos + 1))
      a=$("$FVM" dis "$f" 2>&1)
      b=$(raku raku/gramatica_fasm.raku dis "$f" 2>&1)

      if [ "$a" = "$b" ]; then
        iguais=$((iguais + 1))
      elif [ -z "$primeiro_diff" ]; then
        primeiro_diff=$(diff <(echo "$a") <(echo "$b") | head -6)
      fi
    done

    if [ "$casos" -eq 0 ]; then
      bad "nenhum caso .fasm encontrado em $P01/tests/cases"
    elif [ "$iguais" -eq "$casos" ]; then
      ok "$iguais/$casos byte a byte contra o fvm dis em C"
    else
      bad "$iguais/$casos" "$primeiro_diff"
    fi

    # Hexadecimal: o montador em C usa strtoll com base 0, e a primeira
    # versão da grammar só aceitava decimal. O arith.fasm usa `PUSH 0x10`,
    # e foi a verificação cruzada que achou a lacuna -- não a leitura do
    # meu código.
    printf '.entry m\nm:\n  PUSH 0x10\n  HALT\n' > /tmp/toolbelt_hex.fasm
    saida=$(raku raku/gramatica_fasm.raku dis /tmp/toolbelt_hex.fasm 2>&1)
    if grep -qE 'PUSH +16' <<<"$saida"; then
      ok "0x10 é lido como 16 (base 0, igual ao strtoll do C)"
    else
      bad "hexadecimal não foi convertido" "$(tail -3 <<<"$saida")"
    fi

    # Octal, pela mesma razão.
    printf '.entry m\nm:\n  PUSH 010\n  HALT\n' > /tmp/toolbelt_oct.fasm
    saida=$(raku raku/gramatica_fasm.raku dis /tmp/toolbelt_oct.fasm 2>&1)
    if grep -qE 'PUSH +8' <<<"$saida"; then
      ok "010 é lido como 8 (octal)"
    else
      bad "octal não foi convertido" "$(tail -3 <<<"$saida")"
    fi

    # Rótulo não definido FALHA ALTO, em vez de virar offset 0 -- um salto
    # para o endereço 0 é um programa que roda e faz a coisa errada.
    printf '.entry m\nm:\n  JMP lugar_nenhum\n' > /tmp/toolbelt_mau.fasm
    raku raku/gramatica_fasm.raku dis /tmp/toolbelt_mau.fasm >/dev/null 2>&1
    igual "sai != 0 com rótulo não definido" "65" "$?"
  fi
fi

# -------------------------------------------------------------------- tcl
if [[ " ${FERRAMENTAS[*]} " == *" tcl "* ]]; then
  echo
  echo "tcl/dirige_repl.exp — automação de REPL com Expect"
  echo

  if ! command -v expect >/dev/null; then
    bad "expect ausente" "sudo apt-get install expect"
  else
    # O roteiro imprime o próprio placar e sai != 0 se qualquer interação
    # falhar, então aqui basta executá-lo e olhar o código.
    #
    # A saída vai para arquivo, e NÃO para um pipe com head/tail: quando o
    # pipe fecha antes do fim, o expect quebra com "error writing stdout: bad
    # file number" e o erro não tem relação nenhuma com o teste. Já me custou
    # uma depuração.
    saida=$(mktemp)
    if timeout 180 expect tcl/dirige_repl.exp todos >"$saida" 2>&1; then
      placar=$(grep -oE '[0-9]+ passaram, [0-9]+ falharam' "$saida" | tail -1)
      ok "${placar:-todas as interações passaram}"
    else
      bad "alguma interação falhou" "$(grep -E 'FALHA' "$saida" | head -4)"
    fi
    rm -f "$saida"
  fi
fi

# -------------------------------------------------------------------- nix
if [[ " ${FERRAMENTAS[*]} " == *" nix "* ]]; then
  echo
  echo "nix/flake.nix — os ambientes dos projetos, declarados"
  echo

  if ! command -v nix >/dev/null; then
    bad "nix ausente" "sudo apt-get install nix-bin"
  else
    NIX="nix --extra-experimental-features nix-command --extra-experimental-features flakes"

    # AVALIAR e CONSTRUIR são verificações diferentes, e só uma cabe aqui.
    #
    # Avaliar prova que todo nome de pacote existe e que a expressão está
    # correta: segundos, nenhum download. Construir baixa de 575 MiB a 1,1 GiB
    # por shell, o que não cabe num teste de rotina.
    #
    # Então: avalia os quatro, e constrói UM (o mais leve dos reais) só com
    # NIX_CONSTROI=1. Sem essa separação, a escolha seria entre um teste de
    # 4 GiB e nenhum teste.
    if ! (cd nix && $NIX flake metadata >/dev/null 2>&1); then
      bad "o flake não avalia" "$(cd nix && $NIX flake metadata 2>&1 | tail -3)"
    else
      ok "o flake avalia (nixpkgs travado no flake.lock)"

      # O lock tem de existir: um flake sem lock resolve para o que estiver no
      # canal HOJE, e deixa de responder "com o que isso foi construído".
      if [ -f nix/flake.lock ]; then
        ok "flake.lock existe (a versão do nixpkgs está travada)"
      else
        bad "flake.lock não existe" "rode: cd nix && nix flake lock"
      fi

      # Cada shell é avaliado até o nome da derivação, o que prova que TODO
      # nome de pacote existe no nixpkgs travado. Um nome errado falha aqui,
      # em segundos, em vez de na metade de um download de 1 GiB.
      faltou=""
      for sh in p01 p02 p03 p12; do
        if ! (cd nix && $NIX eval --raw ".#devShells.x86_64-linux.$sh.name" \
              >/dev/null 2>&1); then
          faltou="$faltou $sh"
        fi
      done

      if [ -z "$faltou" ]; then
        ok "os 4 shells resolvem (p01, p02, p03, p12)"
      else
        bad "shells que não resolvem:$faltou"
      fi

      # O `default` aponta para um shell real, e não para a união de tudo: 28
      # ferramentas juntas passariam de 4 GiB e quase ninguém precisa delas ao
      # mesmo tempo.
      nome_default=$(cd nix && $NIX eval --raw \
        ".#devShells.x86_64-linux.default.name" 2>/dev/null)
      igual "default é o shell mais leve" "p12-toolbelt" "$nome_default"

      # A construção de verdade, sob demanda.
      if [ "${NIX_CONSTROI:-}" = "1" ]; then
        if (cd nix && timeout 3000 $NIX develop ".#p02" \
              --command ocaml -version >/dev/null 2>&1); then
          ok "nix develop .#p02 constrói e entrega o ocaml"
        else
          bad "nix develop .#p02 não funcionou"
        fi
      else
        echo "        (construção não testada; use NIX_CONSTROI=1 — baixa ~575 MiB)"
      fi
    fi
  fi
fi

# ----------------------------------------------------------------- groovy
if [[ " ${FERRAMENTAS[*]} " == *" groovy "* ]]; then
  echo
  echo "groovy/relatorio.groovy — saída dos verificadores em JUnit XML"
  echo

  if ! command -v groovy >/dev/null; then
    bad "groovy ausente" "sudo apt-get install groovy"
  else
    # O XML gerado tem de ser PARSEÁVEL. Um relatório que o painel de CI
    # recusa é pior que nenhum: ele aparece como erro de infraestrutura, não
    # como teste falhando.
    xml=$(groovy groovy/relatorio.groovy groovy/t/com_falha.txt 2>/dev/null)

    if python3 -c "
import sys, xml.etree.ElementTree as ET
ET.fromstring(sys.stdin.read())
" <<<"$xml" 2>/dev/null; then
      ok "o XML gerado é bem formado"
    else
      bad "o XML gerado não é parseável" "$(head -3 <<<"$xml")"
    fi

    # As contagens têm de bater com o fixture: 4 casos, 1 falha.
    t=$(python3 -c "
import sys, xml.etree.ElementTree as ET
r = ET.fromstring(sys.stdin.read())
print(r.get('tests'), r.get('failures'))
" <<<"$xml" 2>/dev/null)
    igual "contagens no raiz (4 testes, 1 falha)" "4 1" "$t"

    # O detalhe da falha, que são DUAS linhas no fixture, tem de chegar na
    # mensagem — perder o detalhe transforma o relatório em "falhou, descubra
    # por quê".
    if grep -q "obtido '3' | e uma segunda linha" <<<"$xml"; then
      ok "o detalhe multilinha da falha chega no <failure>"
    else
      bad "o detalhe da falha foi perdido"
    fi

    # Grupo SEM casos (o banner do verificador) não vira <testsuite> vazia.
    n_suites=$(grep -c '<testsuite ' <<<"$xml")
    igual "grupos vazios não geram testsuite" "2" "$n_suites"

    # Código de saída reflete o agregado, para servir de portão.
    groovy groovy/relatorio.groovy groovy/t/com_falha.txt >/dev/null 2>&1
    igual "sai 1 quando há falha" "1" "$?"

    # Entrada sem nenhum caso reconhecido FALHA ALTO, em vez de emitir um XML
    # vazio e verde — um relatório de zero testes passando parece sucesso.
    printf 'texto qualquer\nsem verificacoes\n' > /tmp/toolbelt_vazio.txt
    groovy groovy/relatorio.groovy /tmp/toolbelt_vazio.txt >/dev/null 2>&1
    igual "sai != 0 em entrada sem verificações" "65" "$?"

    # E a ponta a ponta: a saída REAL do verificador deste repositório.
    bash verifica.sh perl awk > /tmp/toolbelt_real.txt 2>&1
    real=$(groovy groovy/relatorio.groovy /tmp/toolbelt_real.txt 2>/dev/null)
    if grep -q 'name="perl/lint_medicoes.pl"' <<<"$real"; then
      ok "converte a saída real do verificador (nome curto no painel)"
    else
      bad "a saída real não foi convertida como esperado"
    fi
  fi
fi

# ------------------------------------------------------- par POSIX/Windows
if [[ " ${FERRAMENTAS[*]} " == *" par "* ]]; then
  echo
  echo "bash/audita-repos.sh × pwsh/Audita-Repos.ps1 — o mesmo trabalho, duas culturas"
  echo

  RAIZ_REPOS="${RAIZ_REPOS:-..}"

  if ! command -v bash >/dev/null; then
    bad "bash ausente"
  else
    # O par só vale se as duas implementações CONCORDAREM. Testar cada uma
    # isolada provaria que as duas rodam, não que fazem o mesmo trabalho.
    saida_bash=$(bash bash/audita-repos.sh --json "$RAIZ_REPOS" 2>/dev/null)

    if python3 -c "
import sys, json
json.loads(sys.stdin.read())
" <<<"$saida_bash" 2>/dev/null; then
      ok "o JSON do Bash é válido (escapado à mão, 12 linhas de função)"
    else
      bad "o JSON do Bash não parseia" "$(head -3 <<<"$saida_bash")"
    fi

    PWSH=$(command -v pwsh || true)

    if [ -z "$PWSH" ]; then
      echo "        (pwsh ausente; a comparação entre os dois pares não roda)"
      echo "        instale com: nix develop .#p12   ou   apt-get install powershell"
    else
      saida_pwsh=$("$PWSH" -NoProfile -File pwsh/Audita-Repos.ps1 \
        -Raiz "$RAIZ_REPOS" -Json 2>/dev/null)

      # Compara os dois JSON normalizados: a ordem das chaves e o espaçamento
      # diferem entre as linguagens, e comparar texto cru acusaria uma
      # divergência que não existe.
      norm() {
        python3 -c "
import sys, json
d = json.loads(sys.stdin.read())
if isinstance(d, dict): d = [d]
print(json.dumps(sorted(d, key=lambda r: r['Repo']), sort_keys=True))
"
      }

      a=$(norm <<<"$saida_bash" 2>/dev/null)
      b=$(norm <<<"$saida_pwsh" 2>/dev/null)

      if [ -n "$a" ] && [ "$a" = "$b" ]; then
        ok "Bash e PowerShell concordam, repositório por repositório"
      else
        bad "as duas implementações divergiram" \
            "$(diff <(echo "$a" | tr ',' '\n') <(echo "$b" | tr ',' '\n') | head -6)"
      fi
    fi

    # O --listar explica POR QUE cada item é obrigatório. Um checklist sem o
    # motivo vira cerimônia e alguém o apaga na primeira vez que incomoda.
    if bash bash/audita-repos.sh --listar 2>/dev/null | grep -q 'porque:'; then
      ok "--listar diz por que cada item é obrigatório"
    else
      bad "--listar não explica os itens"
    fi
  fi
fi

echo
echo "=============================================================="
printf "  %d passaram, %d falharam\n" "$passou" "$falhou"

[ "$falhou" -eq 0 ] || exit 1
exit 0
