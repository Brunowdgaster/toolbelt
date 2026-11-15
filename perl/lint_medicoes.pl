#!/usr/bin/env perl
#
# lint_medicoes.pl — acha número publicado sem dispersão nem método ao lado.
#
#   perl lint_medicoes.pl ../p03-otp-mesh/README.md
#   perl lint_medicoes.pl --resumo ../*/README.md
#   perl lint_medicoes.pl --orcamento 5 README.md    # tolera até 5 achados
#
# ## Por que esta ferramenta existe
#
# A auditoria do p03-otp-mesh revisou toda afirmação numérica daquele README e
# **corrigiu sete**. Todas tinham o mesmo defeito de forma: um número de tempo
# publicado sem dispersão, sem contagem de repetições e sem dizer se a medição
# foi alternada.
#
# Fiz aquela auditoria à mão, lendo. Esta ferramenta é o que eu queria ter
# tido: ela varre os READMEs e sinaliza **candidatos** — números cuja unidade
# indica medição e cuja vizinhança não menciona nenhum marcador de método.
#
# ## Por que em Perl
#
# Porque o problema é regex pesado com estrutura: unidades compostas
# (`ops/s`, `µs`), números em duas convenções decimais (`1.234` e `1,234`),
# contexto que pode estar na mesma linha, na linha de cabeçalho de uma tabela
# ou num parágrafo acima. Perl faz isso com `qr//` composto e `/x` legível, e
# o programa fica menor que a descrição do problema.
#
# ## O que ela NÃO é
#
# Um lint, não um provador. Ela acerta por heurística e **vai** produzir falso
# positivo: "3 reinícios em 5 segundos" é um limite documentado do OTP, não uma
# medição. Para isso existe o marcador de dispensa, e ele é obrigatório ser
# explícito — silenciar por omissão seria o mesmo pecado que a ferramenta
# combate.
#
#     <!-- lint-medicao: ignorar -->   na linha, ou na linha anterior
#
# ## Códigos de saída
#
#   0  nenhum achado acima do orçamento
#   1  achados acima do orçamento
#   2  erro de uso

use strict;
use warnings;
use feature 'say';

# `use utf8` e OBRIGATORIO aqui, e a falta dele custou um falso negativo que
# so a suite pegou.
#
# Os arquivos sao lidos com `:encoding(UTF-8)`, entao as linhas chegam como
# CARACTERES. Sem `use utf8`, os literais deste fonte sao lidos como BYTES --
# e o padrao /µs/ fica sendo a sequencia de dois bytes 0xC2 0xB5, que nunca
# casa com o caractere U+00B5 da entrada. O resultado: "318 µs" passava
# impune, enquanto "318 us" era pego.
#
# Mesma familia do mojibake na saida, logo abaixo: misturar semantica de byte
# com semantica de caractere na mesma passagem.
use utf8;

# A entrada é lida em UTF-8; sem isto a SAÍDA sai como bytes crus e o relatório
# mostra "vers\x{e3}o" em vez de "versão", mais um aviso "Wide character" por
# linha. Ler em UTF-8 e escrever em latin-1 é o jeito clássico de produzir
# mojibake em Perl.
binmode STDOUT, ':encoding(UTF-8)';
binmode STDERR, ':encoding(UTF-8)';

# ----------------------------------------------------------------- argumentos

my ($resumo, $orcamento, @arquivos) = (0, 0);

while (@ARGV) {
    my $a = shift @ARGV;
    if    ($a eq '--resumo')    { $resumo = 1 }
    elsif ($a eq '--orcamento') { $orcamento = shift(@ARGV) // uso() }
    elsif ($a eq '--ajuda')     { uso(0) }
    elsif ($a =~ /^-/)          { die "opcao desconhecida: $a\n" }
    else                        { push @arquivos, $a }
}

@arquivos or uso();

sub uso {
    my $cod = shift // 2;
    print STDERR <<'TXT';
lint_medicoes.pl - acha numero publicado sem dispersao nem metodo ao lado

uso:
  lint_medicoes.pl [--resumo] [--orcamento N] <arquivo.md>...

opcoes:
  --resumo       so a contagem por arquivo, sem listar cada achado
  --orcamento N  sai com 0 se houver no maximo N achados (padrao: 0)

dispensa, na propria linha ou na anterior:
  <!-- lint-medicao: ignorar -->
TXT
    exit $cod;
}

# ------------------------------------------------------- o que conta como medição
#
# Regexes compostos com qr// e /x. A composição é o ponto: cada peça é
# testável e legível isolada, e o padrão final é a soma delas em vez de uma
# linha de 200 caracteres.

# Número em qualquer das duas convenções decimais, com separador de milhar
# opcional: 8, 8.9, 8,9, 1.234, 1,234.56, 106.354.693
my $NUMERO = qr/
    \d{1,3}
    (?: [.,] \d{3} )*          # grupos de milhar
    (?: [.,] \d+ )?            # fração
  | \d+ (?: [.,] \d+ )?
/x;

# Unidades que indicam MEDIÇÃO DE TEMPO ou de taxa. Só estas: bytes, contagens
# de teste e linhas de código não são afetados por carga da máquina e não
# precisam de dispersão.
my $UNIDADE_TEMPO = qr/
    (?: ms | µs | us | ns | seg | segundos? )\b
  | s\b (?! \w )               # "8 s", mas não "8 slots"
  | (?: ops\/s | op\/s | \/s )\b
  | (?: por \s+ segundo )\b
/xi;

# Razões: "3,4x", "254x", "1.400x". São derivadas de medição e herdam o
# problema dela.
my $RAZAO = qr/ x \b /x;

# Marcadores de que o método foi declarado por perto.
my $MARCADOR = qr/
    disp (?: ersão | ersao | \. )?
  | desvio
  | melhor \s+ de
  | m[íi]nimo \s+ de
  | \b reps? \b
  | repetiç (?: ão | ões )
  | repetic (?: ao | oes )
  | alternad [ao]s?
  | intercalad [ao]s?
  | faixa
  | n[ãa]o \s+ determinad [ao]
  | amostra
  | no \s+ ru[íi]do
  | calibra
  | \b± \b?
/xi;

my $DISPENSA = qr/ lint-medicao: \s* ignorar /x;

# PARÂMETRO, não medição. "9 vezes com 120 ms de intervalo" configura o
# experimento; "3 reinícios em 5 segundos" é um limite documentado do OTP.
# Nenhum dos dois é resultado, e exigir dispersão deles seria ruído.
#
# Esta lista foi derivada dos falsos positivos da primeira execução contra os
# READMEs reais — não de imaginação sobre o que poderia aparecer.
my $PARAMETRO = qr/
    intervalo | espaçamento | espacamento
  | prazo | timeout | tempo \s+ limite | teto
  | a \s+ cada | por \s+ padrão | por \s+ padrao
  | limite | intensidade
  | tolerância | tolerancia
  | configur | padrão \s+ do | padrao \s+ do
  | aguard | espera
/xi;

# MENÇÃO HISTÓRICA. Um número citado para dizer que estava errado não é uma
# afirmação nova — é a correção dele. Exigir dispersão aqui penalizaria
# justamente o texto que faz a coisa certa.
my $HISTORICO = qr/
    publicou | publicad [ao]
  | primeira \s+ vers (?: ão | ao )
  | vers (?: ão | ao ) \s+ (?: original | anterior )
  | \b antes \b
  | \b era \b
  | correç (?: ão | ões ) | correc (?: ao | oes )
  | refeit [ao]
  | não \s+ estava | nao \s+ estava
  | deixou \s+ de
/xi;

# ------------------------------------------------------------------- varredura

my $total = 0;
my %por_arquivo;

for my $arq (@arquivos) {
    open my $fh, '<:encoding(UTF-8)', $arq
      or do { warn "nao consegui abrir $arq: $!\n"; next };
    my @linhas = <$fh>;
    close $fh;
    chomp @linhas;

    # Contexto de tabela: numa tabela Markdown, o método costuma estar no
    # CABEÇALHO (uma coluna "dispersão"), não na linha do número. Então o
    # cabeçalho mais recente conta como vizinhança.
    my $cabecalho_tabela = '';
    my @achados;

    for my $i (0 .. $#linhas) {
        my $linha = $linhas[$i];

        # Rastreia o cabeçalho da tabela corrente.
        if ($linha =~ /^\s*\|.*\|\s*$/) {
            $cabecalho_tabela = $linha
              if $i + 1 <= $#linhas && $linhas[$i + 1] =~ /^\s*\|[\s:|-]+\|\s*$/;
        }
        else {
            $cabecalho_tabela = '' unless $linha =~ /^\s*$/;
        }

        # Blocos de código são saída de programa, não afirmação do autor.
        next if dentro_de_bloco(\@linhas, $i);

        # A dispensa vale para o PARÁGRAFO, não só para a linha.
        #
        # A primeira versão olhava a linha e a anterior. Mas o lint raciocina
        # em parágrafos (ver `paragrafo` abaixo), e texto em Markdown quebra a
        # linha onde cabe, não onde o sentido termina: uma dispensa escrita
        # antes de um parágrafo de seis linhas não cobria a linha 4, onde o
        # número estava.
        #
        # As duas granularidades agora batem. O risco é uma dispensa silenciar
        # mais do que o autor queria — aceitável, porque ele ESCREVEU o
        # comentário. O que não é aceitável é silenciar por omissão.
        my $ini_p = ini_paragrafo(\@linhas, $i);
        my @ctx_dispensa = paragrafo(\@linhas, $i);
        push @ctx_dispensa, $linhas[$ini_p - 1] if $ini_p > 0;

        next if grep { $_ =~ $DISPENSA } @ctx_dispensa;

        # Código INLINE sai antes da busca.
        #
        # `` `0x..` `` virava a razão "0x" e `` `%-8s` `` virava "8 segundos".
        # Os dois são texto literal citado, não afirmação do autor — a mesma
        # razão pela qual blocos cercados (```) já eram excluídos. Só faltava
        # aplicar a regra ao código inline.
        #
        # Esta exclusão também veio de falso positivo real: a ferramenta
        # acusou o próprio README deste repositório em três linhas, todas com
        # número dentro de backtick.
        my $prosa = $linha;
        $prosa =~ s/`[^`]*`//g;

        # Acha as medições da PROSA, não da linha inteira.
        my @medicoes;
        while ($prosa =~ /($NUMERO)\s*($UNIDADE_TEMPO|$RAZAO)/g) {
            push @medicoes, "$1 $2";
        }
        next unless @medicoes;

        # A vizinhança é o PARÁGRAFO inteiro, não uma janela de linhas fixa.
        #
        # A primeira versão usava duas linhas antes e uma depois, e produzia
        # falso positivo sempre que o método estava declarado no começo do
        # parágrafo — que é onde um autor naturalmente o escreve. Texto em
        # Markdown tem a quebra de linha onde cabe, não onde o sentido termina.
        my $vizinhanca = join "\n", paragrafo(\@linhas, $i), $cabecalho_tabela;

        next if $vizinhanca =~ $MARCADOR;
        next if $vizinhanca =~ $PARAMETRO;
        next if $vizinhanca =~ $HISTORICO;

        push @achados, { linha => $i + 1, texto => $linha, medicoes => \@medicoes };
    }

    $por_arquivo{$arq} = scalar @achados;
    $total += @achados;

    next if $resumo;
    next unless @achados;

    say "";
    say "=== $arq ===";
    for my $a (@achados) {
        printf "  %4d: %s\n", $a->{linha}, recorta($a->{texto});
        printf "        -> %s, sem marcador de metodo por perto\n",
          join(', ', @{ $a->{medicoes} });
    }
}

# Índice da primeira linha do parágrafo que contém i.
#
# Usado para achar a linha IMEDIATAMENTE ANTES do parágrafo, que é onde uma
# dispensa naturalmente fica. É `sub` nomeada, e não `my $f = sub {}`, porque a
# chamada acontece no laço principal, ACIMA desta definição -- um lexical
# declarado aqui não estaria visível lá, e o erro seria "Can't use an undefined
# value as a subroutine reference" em tempo de execução.
sub ini_paragrafo {
    my ($linhas, $i) = @_;
    my $ini = $i;
    $ini-- while $ini > 0
      && $linhas->[$ini - 1] =~ /\S/
      && $linhas->[$ini - 1] !~ /^\s*#/;
    return $ini;
}

# O parágrafo que contém a linha i: as linhas contíguas não vazias em volta,
# mais a linha seguinte ao parágrafo (onde costuma vir a ressalva).
#
# Numa tabela, o "parágrafo" é a tabela inteira mais o texto imediatamente
# acima dela — que é onde a legenda com o método aparece.
sub paragrafo {
    my ($linhas, $i) = @_;

    my $ini = $i;
    $ini-- while $ini > 0
      && $linhas->[$ini - 1] =~ /\S/
      && $linhas->[$ini - 1] !~ /^\s*#/;

    my $fim = $i;
    $fim++ while $fim < $#{$linhas}
      && $linhas->[$fim + 1] =~ /\S/
      && $linhas->[$fim + 1] !~ /^\s*#/;

    # Uma linha de texto acima do parágrafo e uma abaixo: a legenda de uma
    # tabela fica separada dela por linha vazia.
    #
    # MAS o contexto NÃO ATRAVESSA CABEÇALHO. Esta condição foi acrescentada
    # depois de a própria suíte pegar três falsos negativos: o parágrafo de uma
    # seção alcançava o título da seção SEGUINTE, e um título como
    # "## Tabela sem coluna de dispersão" contém a palavra "dispersão" --
    # silenciando o achado por causa de texto que não tem relação com ele.
    #
    # É o mesmo erro, em miniatura, que o lint existe para combater: contexto
    # que parece justificar um número e não justifica.
    my @extra;

    push @extra, $linhas->[$ini - 2]
      if $ini >= 2 && $linhas->[$ini - 2] !~ /^\s*#/;

    push @extra, $linhas->[$fim + 2]
      if $fim + 2 <= $#{$linhas} && $linhas->[$fim + 2] !~ /^\s*#/;

    return (@{$linhas}[$ini .. $fim], @extra);
}

# Blocos ```...```: conta as cercas antes da linha i.
sub dentro_de_bloco {
    my ($linhas, $i) = @_;
    my $cercas = grep { /^\s*```/ } @{$linhas}[0 .. $i];
    return $cercas % 2 == 1;
}

sub recorta {
    my $t = shift;
    $t =~ s/^\s+//;
    return length($t) > 76 ? substr($t, 0, 73) . '...' : $t;
}

# -------------------------------------------------------------------- resultado

say "";
say "=" x 62;
printf "%-44s %s\n", 'arquivo', 'achados';
say "-" x 62;
for my $arq (sort keys %por_arquivo) {
    printf "%-44s %d\n", encurta($arq), $por_arquivo{$arq};
}
say "-" x 62;
printf "%-44s %d  (orcamento: %d)\n", 'TOTAL', $total, $orcamento;
say "";

sub encurta {
    my $p = shift;
    $p =~ s{^.*/([^/]+/[^/]+)$}{$1};
    return $p;
}

if ($total > $orcamento) {
    say "Acima do orcamento. Cada achado e um CANDIDATO, nao um veredito:";
    say "  * se for medicao, acrescente dispersao, repeticoes ou 'nao determinado';";
    say "  * se nao for (um limite documentado, um prazo de configuracao),";
    say "    dispense com <!-- lint-medicao: ignorar --> e o motivo ao lado.";
    exit 1;
}

say "Dentro do orcamento.";
exit 0;
