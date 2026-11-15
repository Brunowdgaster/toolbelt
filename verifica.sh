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

FERRAMENTAS=(perl awk lua)
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

    igual "fixture limpo: 0 achados (9 padrões legítimos)" "0" "$(total perl/t/limpo.md)"
    igual "fixture sujo: 5 achados (5 defeitos)" "5" "$(total perl/t/sujo.md)"

    # Código de saída: a ferramenta serve de portão de CI, então o código tem
    # de refletir o veredito.
    perl perl/lint_medicoes.pl --resumo perl/t/limpo.md >/dev/null 2>&1
    igual "sai 0 no fixture limpo" "0" "$?"

    perl perl/lint_medicoes.pl --resumo perl/t/sujo.md >/dev/null 2>&1
    igual "sai 1 no fixture sujo" "1" "$?"

    # O orçamento tem de deixar passar exatamente o que ele promete.
    perl perl/lint_medicoes.pl --orcamento 5 --resumo perl/t/sujo.md >/dev/null 2>&1
    igual "--orcamento 5 aceita 5 achados" "0" "$?"

    perl perl/lint_medicoes.pl --orcamento 4 --resumo perl/t/sujo.md >/dev/null 2>&1
    igual "--orcamento 4 recusa 5 achados" "1" "$?"
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

echo
echo "=============================================================="
printf "  %d passaram, %d falharam\n" "$passou" "$falhou"

[ "$falhou" -eq 0 ] || exit 1
exit 0
