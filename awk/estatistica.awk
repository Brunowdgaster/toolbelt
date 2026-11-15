# estatistica.awk — faixa, mínimo, pior e dispersão de colunas de medição.
#
#   awk -f estatistica.awk amostras.txt
#   bench/run.sh | awk -f estatistica.awk
#   awk -f estatistica.awk -v menor_melhor=1 latencias.txt
#
# ## Por que esta ferramenta existe, e por que em AWK
#
# Todo benchmark deste portfólio terminou precisando da mesma coisa: pegar N
# amostras por implementação, achar o melhor, o pior e a dispersão, e decidir
# se a diferença supera o ruído. Eu reescrevi essa lógica em Elixir, em Bash e
# em Shell, três vezes, em três projetos.
#
# É **exatamente** o trabalho do AWK: entrada em colunas, agrupamento por
# chave, agregação numérica. Em 60 linhas de AWK ela fica mais clara que em
# qualquer das três versões anteriores, porque a linguagem já tem o laço
# implícito, os arrays associativos e a divisão em campos.
#
# ## Formato de entrada
#
# Uma medição por linha, dois campos:
#
#     <rotulo> <valor>
#
# Linhas vazias e comentários (`#`) são ignorados. Qualquer coisa além do
# segundo campo é ignorada, então a saída de outro benchmark pode ser
# canalizada direto se os dois primeiros campos estiverem certos.
#
# ## A decisão por sobreposição de faixas
#
# Com DOIS rótulos, o relatório aplica a regra do portfólio (ver
# `bench/cruzado.sh` do p03-otp-mesh): faixas disjuntas decidem mesmo com
# dispersão alta, porque "a pior amostra do vencedor supera a melhor do
# perdedor" é evidência forte; faixas que se sobrepõem só decidem se a margem
# superar a dispersão; e, se nada disso vale, o veredito é **não determinado**.
#
# Com três ou mais rótulos, ela só tabula — comparar vários pares pede
# correção para múltiplas comparações, e inventar uma aqui seria pior que não
# concluir.
#
# ## menor_melhor
#
# Por padrão, MAIOR é melhor (vazão). Com `-v menor_melhor=1`, MENOR é melhor
# (latência, tempo). Errar isso inverte o relatório inteiro, e é o tipo de bug
# que não aparece: a tabela fica plausível e a conclusão fica trocada. Por isso
# o cabeçalho **imprime qual critério está em uso**.

BEGIN {
    if (menor_melhor == "") menor_melhor = 0
}

# Ignora vazias e comentários.
/^[[:space:]]*$/ { next }
/^[[:space:]]*#/ { next }

# Precisa de dois campos, e um valor numérico. Linha malformada FALHA ALTO em
# vez de virar zero -- um zero silencioso viraria "melhor amostra" num
# relatório de latência e "pior" num de vazão.
{
    if (NF < 2) {
        printf "estatistica.awk: linha %d tem %d campo(s), esperava 2: %s\n",
               NR, NF, $0 > "/dev/stderr"
        erro = 1
        exit 1
    }

    if ($2 !~ /^-?[0-9]+([.][0-9]+)?([eE][-+]?[0-9]+)?$/) {
        printf "estatistica.awk: linha %d, campo 2 nao e numero: %s\n",
               NR, $2 > "/dev/stderr"
        erro = 1
        exit 1
    }

    rotulo = $1
    valor = $2 + 0

    if (!(rotulo in n)) {
        ordem[++k] = rotulo
        menor[rotulo] = valor
        maior[rotulo] = valor
    }

    n[rotulo]++
    soma[rotulo] += valor
    if (valor < menor[rotulo]) menor[rotulo] = valor
    if (valor > maior[rotulo]) maior[rotulo] = valor
}

END {
    if (erro) exit 1

    if (k == 0) {
        print "estatistica.awk: nenhuma amostra na entrada" > "/dev/stderr"
        exit 1
    }

    criterio = menor_melhor ? "MENOR e melhor (latencia)" : "MAIOR e melhor (vazao)"

    printf "amostras: %d em %d rotulo(s)   criterio: %s\n", NR_validas(), k, criterio
    printf "\n"
    printf "%-16s %5s %14s %14s %10s %12s\n",
           "rotulo", "n", "melhor", "pior", "disp", "media"
    printf "%s\n", repete("-", 76)

    for (i = 1; i <= k; i++) {
        r = ordem[i]

        # A dispersao e sempre (pior - melhor) / melhor em modulo, com "melhor"
        # definido pelo criterio -- nao (maior-menor)/menor cru, que daria
        # sinal trocado num relatorio de latencia.
        if (menor_melhor) {
            mel[r] = menor[r]; pio[r] = maior[r]
        } else {
            mel[r] = maior[r]; pio[r] = menor[r]
        }

        base = (pio[r] == 0) ? 1 : pio[r]
        if (menor_melhor) base = (mel[r] == 0) ? 1 : mel[r]

        disp[r] = (pio[r] - mel[r]) / base * 100
        if (disp[r] < 0) disp[r] = -disp[r]

        printf "%-16s %5d %14s %14s %9.1f%% %12s\n",
               r, n[r], fmt(mel[r]), fmt(pio[r]), disp[r],
               fmt(soma[r] / n[r])
    }

    printf "\n"

    if (k != 2) {
        printf "Com %d rotulo(s), este relatorio apenas TABULA.\n", k
        printf "Comparar varios pares exige correcao para multiplas comparacoes,\n"
        printf "e inventar uma aqui seria pior que nao concluir.\n"
        exit 0
    }

    a = ordem[1]; b = ordem[2]
    veredito(a, b)
}

function NR_validas() {
    t = 0
    for (r in n) t += n[r]
    return t
}

function repete(c, vezes,    s, i) {
    s = ""
    for (i = 0; i < vezes; i++) s = s c
    return s
}

# Imprime inteiro como inteiro e fracionario com uma casa: uma tabela em que
# "11" aparece como "11.0" e "106354693" como "106354693.0" fica ilegivel.
function fmt(x) {
    if (x == int(x) && x < 1e15) return sprintf("%d", x)
    return sprintf("%.1f", x)
}

# A regra de decisao do portfolio, em tres niveis.
function veredito(a, b,    fator, margem, pior_disp, razao, relacao) {
    pior_disp = (disp[a] > disp[b]) ? disp[a] : disp[b]

    razao = (mel[b] == 0) ? 0 : mel[a] / mel[b]
    margem = (razao > 1 ? razao - 1 : 1 - razao) * 100

    printf "razao dos melhores : %.3fx   margem: %.1f%%   pior dispersao: %.1f%%\n",
           razao, margem, pior_disp
    printf "\n"

    # Nivel 1: faixas DISJUNTAS. A pior amostra de um lado supera a melhor do
    # outro, e a dispersao deixa de importar.
    if (menor_melhor) {
        a_ganha = (pio[a] < mel[b])
        b_ganha = (pio[b] < mel[a])
    } else {
        a_ganha = (pio[a] > mel[b])
        b_ganha = (pio[b] > mel[a])
    }

    if (a_ganha || b_ganha) {
        venc = a_ganha ? a : b
        perd = a_ganha ? b : a

        fator = menor_melhor ? mel[perd] / pio[venc] : pio[venc] / mel[perd]

        printf "DECIDIDO: %s e melhor, e as faixas NAO SE TOCAM.\n", venc
        # A relacao muda com o criterio: em vazao a pior amostra do
        # vencedor SUPERA a melhor do perdedor; em latencia ela e MENOR.
        # Imprimir "supera" nos dois casos deixaria a frase invertida
        # justamente no relatorio de latencia, que e onde o leitor menos
        # espera -- e onde o erro passaria por descuido de leitura.
        relacao = menor_melhor ? "e menor que" : "supera"

        printf "  A pior amostra dele (%s) %s a melhor do outro (%s).\n",
               fmt(pio[venc]), relacao, fmt(mel[perd])
        printf "  Fator conservador: %.2fx\n", fator
        exit 0
    }

    # Nivel 2: faixas se sobrepoem, mas a margem supera a dispersao.
    if (margem > pior_disp) {
        venc = (razao > 1) ? a : b
        printf "PROVAVEL: %s e melhor por %.1f%%, acima da dispersao de %.1f%%.\n",
               venc, margem, pior_disp
        printf "  As faixas se sobrepoem, entao vale como 'provavelmente',\n"
        printf "  nao como 'certamente'.\n"
        exit 0
    }

    # Nivel 3: nada a declarar, e isso e uma resposta.
    printf "NAO DETERMINADO: faixas sobrepostas e margem de %.1f%% dentro da\n", margem
    printf "dispersao de %.1f%%. A diferenca nao e distinguivel do ruido.\n", pior_disp
    exit 0
}
