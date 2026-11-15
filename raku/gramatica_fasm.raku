#!/usr/bin/env raku

# gramatica_fasm.raku — uma grammar de verdade para o assembly do p01-metal-vm.
#
#   raku gramatica_fasm.raku listar prog.fasm
#   raku gramatica_fasm.raku dis    prog.fasm    # formato do `fvm dis`
#   raku gramatica_fasm.raku json   prog.fasm
#
# ## Por que esta ferramenta existe, e por que em Raku
#
# O plano do portfólio diz que Raku entra para mostrar **a evolução sobre
# Perl**, e a diferença que importa é esta: em Perl, um parser de formato é uma
# pilha de regexes com nomes em comentário. Em Raku, é uma `grammar` — regras
# nomeadas, compostas, com uma classe de ações separada da sintaxe.
#
# O `lint_medicoes.pl` deste mesmo repositório é o contraste direto: lá o
# problema é casamento oportunista em texto livre, e Perl ganha. Aqui o
# problema tem **gramática**, e é outro jogo.
#
# ## O que torna isto verificável, e não decorativo
#
# O subcomando `dis` emite o **mesmo formato** que o `fvm dis` do p01, com os
# offsets em bytes:
#
#     000000  PUSH     7
#     000018  CALL     26 2
#
# Casar isso obriga a grammar a conhecer o **tamanho de codificação de cada
# instrução** e a resolver rótulos em endereços — ou seja, a fazer as duas
# passagens de um montador de verdade. Um offset errado aparece na hora.
#
# É o mesmo padrão dos portes do p01 (bytecode byte-idêntico) aplicado a um
# parser: a verificação é contra uma implementação independente, em C.
#
# ## O formato, conforme docs/ISA.md do p01
#
#   * `; comentário` até o fim da linha
#   * `.entry <rótulo>` — diretiva
#   * `<rótulo>:` — define endereço
#   * `MNEMÔNICO [operandos]` — instrução
#
# Tamanhos: 1 byte de opcode, mais 8 para o imediato de `PUSH`, 4 para os
# operandos i32 (`JMP`, `JZ`, `JNZ`, `LOAD`, `STORE`, `RESERVE`), 5 para
# `CALL` (i32 + u8), 1 para `CALLI` (u8), e 0 para o resto.

use v6.d;

# ----------------------------------------------------------------- a grammar
#
# `token` em vez de `rule` de propósito: `rule` liga o espaçamento implícito,
# e num formato ORIENTADO A LINHA isso faria a regra atravessar quebras de
# linha silenciosamente. Aqui o espaço horizontal (`\h`) é explícito e a
# quebra de linha é um separador significativo.

grammar Fasm {
    token TOP {
        <linha>* $
    }

    token linha {
        | <.vazia>
        | <diretiva>
        | <rotulo>
        | <instrucao>
        | <.so-comentario>
    }

    token vazia         { \h* \n }
    token so-comentario { \h* <.comentario> \n? }
    token comentario    { ';' \N* }

    token diretiva {
        \h* '.' $<nome>=[\w+] \h+ $<arg>=[<.nome-id>] \h* <.comentario>? \n?
    }

    token rotulo {
        \h* $<nome>=[<.nome-id>] ':' \h* <.comentario>? \n?
    }

    token instrucao {
        \h* $<mnemonico>=[<.upper>+] <operandos> \h* <.comentario>? \n?
    }

    # Zero, um ou dois operandos. `CALL rotulo 2` tem dois; `PUSH 7` tem um.
    token operandos {
        [ \h+ <operando> ]*
    }

    # Hexadecimal e octal entram porque o montador em C usa
    # `strtoll(s, &end, 0)` -- base 0, que aceita `0x..`, `0..` e decimal. A
    # primeira versão desta grammar só aceitava decimal, e o `arith.fasm`
    # falhava em `PUSH 0x10` com a mensagem inútil "a grammar nao casou com o
    # arquivo inteiro".
    #
    # Quem achou foi a verificação cruzada contra o desmontador em C, não a
    # leitura do meu próprio código: eu não sabia que o formato aceitava hex.
    #
    # A ORDEM das alternativas importa: hex antes de octal antes de decimal.
    # Se decimal viesse primeiro, `0x10` casaria o `0` e deixaria `x10` para
    # trás.
    token operando {
        | $<hex>=[ '-'? '0' <[xX]> <[0..9a..fA..F]>+ ]
        | $<oct>=[ '-'? '0' <[0..7]>+ ]
        | $<dec>=[ '-'? \d+ ]
        | $<simbolo>=[ <.nome-id> ]
    }

    token nome-id { <[A..Za..z_]> <[\w]>* }
}

# ------------------------------------------------------------------- ações
#
# A classe de ações é SEPARADA da gramática, e essa separação é o ponto:
# a sintaxe fica num lugar, o significado noutro. Em Perl, os dois ficam
# misturados no mesmo bloco de regex.

class Montador {
    has @.itens;   # rótulos e instruções, em ordem
    has $.entrada is rw = 'main';

    method diretiva($/) {
        if ~$<nome> eq 'entry' {
            $!entrada = ~$<arg>;
        }
        else {
            die "diretiva desconhecida: .{$<nome>}";
        }
    }

    method rotulo($/) {
        @!itens.push: %( tipo => 'rotulo', nome => ~$<nome> );
    }

    method instrucao($/) {
        my @ops = $<operandos><operando>.map: -> $o {
            # O desmontador em C imprime todo operando em DECIMAL, então
            # converter aqui é parte de casar a saída: `PUSH 0x10` tem de sair
            # como `PUSH 16`.
            if $o<hex> {
                my $t = ~$o<hex>;
                my $neg = $t.starts-with('-');
                my $n = :16($t.subst(/^ '-'? '0' <[xX]>/, ''));
                %( k => 'int', v => ($neg ?? -$n !! $n) );
            }
            elsif $o<oct> {
                my $t = ~$o<oct>;
                my $neg = $t.starts-with('-');
                my $n = :8($t.subst(/^ '-'? '0'/, ''));
                %( k => 'int', v => ($neg ?? -$n !! $n) );
            }
            elsif $o<dec> {
                %( k => 'int', v => (+~$o<dec>) );
            }
            else {
                %( k => 'sim', v => ~$o<simbolo> );
            }
        };

        @!itens.push: %(
            tipo       => 'instrucao',
            mnemonico  => ~$<mnemonico>,
            operandos  => @ops,
        );
    }
}

# ------------------------------------------------- tamanhos de codificação
#
# Esta tabela É o contrato com o p01: errar um tamanho aqui desloca todos os
# offsets seguintes, e o diff contra o `fvm dis` aponta exatamente onde.

my %TAMANHO-OPERANDOS =
    PUSH    => 8,   # i64 imediato, ou endereço de rótulo
    JMP     => 4,   # i32
    JZ      => 4,
    JNZ     => 4,
    LOAD    => 4,
    STORE   => 4,
    RESERVE => 4,
    CALL    => 5,   # i32 endereço + u8 nargs
    CALLI   => 1,   # u8 nargs
    ;

my @MNEMONICOS = <
    HALT PUSH POP DUP SWAP ADD SUB MUL DIV MOD NEG
    LT LE GT GE EQ NE JMP JZ JNZ LOAD STORE RESERVE
    CALL RET PRINT NEWARR AGET ASET ALEN GC CALLI
>;

sub tamanho($mnemonico) {
    die "mnemonico desconhecido: $mnemonico" unless $mnemonico ∈ @MNEMONICOS;
    return 1 + (%TAMANHO-OPERANDOS{$mnemonico} // 0);
}

# ---------------------------------------------------- duas passagens
#
# Igual ao montador em C: a primeira passagem atribui offsets e coleta
# rótulos, a segunda resolve as referências. Rótulo usado antes de ser
# definido é o caso normal (salto para frente), e é por isso que uma passagem
# só não basta.

sub montar(Montador $m) {
    my %rotulos;
    my @instrucoes;
    my $offset = 0;

    for $m.itens -> %it {
        if %it<tipo> eq 'rotulo' {
            die "rotulo duplicado: %it<nome>" if %rotulos{%it<nome>}:exists;
            %rotulos{%it<nome>} = $offset;
        }
        else {
            # `%( )` explicito, e nao `{ }`.
            #
            # Em Raku, `{ ... }` e AMBIGUO: vira Hash se parecer um compositor
            # de hash, e Block caso contrario. `{ |%it, offset => $offset }`
            # comeca com um slip, o Raku decide que e Block, e o erro aparece
            # longe daqui -- "expected Associative but got Block", no `for`
            # que itera a lista. `%( )` nunca e ambiguo.
            @instrucoes.push: %( |%it, offset => $offset );
            $offset += tamanho(%it<mnemonico>);
        }
    }

    # Segunda passagem: resolve símbolos.
    #
    # Nota de idioma: `@instrucoes` aqui é uma variável de array, e o `for`
    # itera elemento por elemento. Mas quando a mesma lista sai dentro de um
    # hash (`%prog<instrucoes>`), ela vem ITEMIZADA, e o `for` passa a ver UM
    # item -- a lista inteira. O sintoma é "expected Associative but got
    # Array", longe da causa. Por isso as saídas abaixo usam `.list`.
    for @instrucoes -> %ins {
        %ins<resolvidos> = %ins<operandos>.map(-> %op {
            if %op<k> eq 'sim' {
                die "rotulo nao definido: %op<v>" unless %rotulos{%op<v>}:exists;
                %rotulos{%op<v>};
            }
            else {
                %op<v>;
            }
        }).Array;
    }

    return %( instrucoes => @instrucoes, rotulos => %rotulos,
              bytes => $offset, entrada => $m.entrada );
}

# ------------------------------------------------------------------- saídas

sub emitir-dis(%prog) {
    my $entrada = %prog<rotulos>{%prog<entrada>}
        // die "entrada '%prog<entrada>' nao e um rotulo definido";

    # O cabeçalho casa com o do `fvm dis` do p01, incluindo o espaçamento.
    say "; entry = $entrada, %prog<bytes> bytes";

    for %prog<instrucoes>.list -> %ins {
        # O `fvm dis` em C emite `%-8s` para o mnemônico e depois `" %d"`
        # para CADA operando. A diferença aparece só no espaço em branco à
        # direita, e é real: com `%-8s %s`, uma instrução sem operandos ganha
        # um espaço extra, e o diff contra o C acusou as linhas de `HALT`,
        # `PRINT`, `ADD`, `MUL`, `GE`... em todos os 9 casos.
        #
        # Reproduzir um formato byte a byte inclui reproduzir o espaço que
        # ninguém vê.
        print sprintf("%06d  %-8s", %ins<offset>, %ins<mnemonico>);
        print " $_" for %ins<resolvidos>.list;
        print "\n";
    }
}

sub emitir-listagem(%prog) {
    say "entrada : %prog<entrada> (offset {%prog<rotulos>{%prog<entrada>} // '?'})";
    say "bytes   : %prog<bytes>";
    say "rotulos : {%prog<rotulos>.keys.sort.join(', ')}";
    say "";

    for %prog<instrucoes>.list -> %ins {
        my @nomes = %ins<operandos>.map({ $_<k> eq 'sim' ?? $_<v> !! $_<v> });
        printf "%06d  %-8s %-16s %s\n",
            %ins<offset>, %ins<mnemonico>, @nomes.join(' '),
            %ins<resolvidos>.join(' ');
    }
}

sub emitir-json(%prog) {
    # Sem biblioteca: JSON::Fast não vem no Rakudo do apt, e uma dependência
    # para serializar quatro campos seria desproporcional.
    say '{';
    say "  \"entrada\": \"%prog<entrada>\",";
    say "  \"bytes\": %prog<bytes>,";
    say '  "instrucoes": [';

    my @linhas = %prog<instrucoes>.list.map: -> %ins {
        '    { "offset": ' ~ %ins<offset>
          ~ ', "mnemonico": "' ~ %ins<mnemonico>
          ~ '", "operandos": [' ~ %ins<resolvidos>.join(', ') ~ '] }';
    };

    say @linhas.join(",\n");
    say '  ]';
    say '}';
}

# --------------------------------------------------------------------- CLI

sub MAIN($comando, $arquivo) {
    unless $arquivo.IO.e {
        note "arquivo nao encontrado: $arquivo";
        exit 66;
    }

    my $fonte = $arquivo.IO.slurp;

    # Garante a quebra final: a gramática trata a linha como terminada por \n,
    # e um arquivo sem newline no fim falharia na última linha.
    $fonte ~= "\n" unless $fonte.ends-with("\n");

    my $acoes = Montador.new;
    my $casou = Fasm.parse($fonte, :actions($acoes));

    unless $casou {
        note "$arquivo: a grammar nao casou com o arquivo inteiro";
        exit 65;
    }

    my %prog;
    try {
        %prog = montar($acoes);
        CATCH {
            default {
                note "$arquivo: $_";
                exit 65;
            }
        }
    }

    given $comando {
        when 'dis'     { emitir-dis(%prog) }
        when 'listar'  { emitir-listagem(%prog) }
        when 'json'    { emitir-json(%prog) }
        default {
            note "comando desconhecido: $comando (use dis, listar ou json)";
            exit 64;
        }
    }

    exit 0;
}
