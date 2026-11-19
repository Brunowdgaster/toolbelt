-- registro.lua — o estado declarado do portfólio, lido por cobertura.lua.
--
-- Este arquivo é **dado**, não código: ele devolve uma tabela. A decisão de
-- considerar uma linguagem "feita" é julgamento humano e fica aqui, com a
-- evidência ao lado. A ferramenta faz a conta, que é onde o humano erra.
--
-- ## O critério de "feita"
--
-- Uma linguagem conta quando tem, naquele projeto:
--
--   * código que faz trabalho real (não hello-world);
--   * verificação automatizada que falha se o código quebrar;
--   * uma seção de README explicando as decisões e o que a linguagem deu ou
--     cobrou.
--
-- Porte declarado como porte conta. Script de build não conta — é ferramenta,
-- não produto.
--
-- ## Por que `itens_no_plano` é separado de `planejadas`
--
-- O ROADMAP lista itens que não são linguagens: Makefile, CMake, YAML,
-- Dockerfile, Nix. `itens_no_plano` é a contagem literal do ROADMAP, e serve
-- para `cobertura.lua --roadmap` detectar que o plano mudou. `planejadas` é
-- quantas daquelas são linguagens de fato.

return {
  meta = 100,

  projetos = {
    P01 = {
      nome = "metal-vm",
      itens_no_plano = 15,  -- inclui Makefile, CMake, Nix
      planejadas = 12,
      feitas = {
        "C",     -- implementacao de referencia: VM + GC + montador
        "Rust",  -- segunda referencia, arena com handles, zero unsafe
        "Nim",   -- porte, 255 linhas, 9/9
        "Odin",  -- porte, virtual.Arena e context.allocator, 9/9
        "D",     -- porte, SumType exaustivo, 9/9
        "V",     -- porte, handle+arena imposto pelo tipo-soma, 9/9
        "Ada",   -- porte, subtipos restritos, 9/9
        "C++",   -- porte, shared_ptr (NAO coleta ciclo, ao contrario do ORC), 9/9
        "Zig",   -- porte, alocador na assinatura e comptime na tabela, 9/9
        "Assembly x86-64", -- ports/asm: o SUBCONJUNTO, sem libc, 4/4
        "Assembly ARM64",  -- idem, sob qemu-user: cset em vez de setcc+movzx
        "Assembly RISC-V", -- idem: slt em UMA instrucao, e nenhum flag
      },
      -- As 12 linguagens do plano estao feitas. Faltam os tres itens de BUILD
      -- (Makefile, CMake, Nix), que o itens_no_plano conta e que nao sao
      -- linguagens de programacao.
      --
      -- Os portes em Assembly sao um SUBCONJUNTO declarado -- pilha,
      -- aritmetica, saltos, locais, PRINT -- com suite propria, porque o
      -- plano pede "Assembly no dispatch loop com medicao" e opcodes de heap
      -- mediriam o alocador.
    },

    P02 = {
      nome = "forge-lang",
      itens_no_plano = 15,
      planejadas = 15,
      feitas = {
        "Haskell", -- compilador completo, Hindley-Milner total
        "OCaml",   -- porte do verificador, 23/23 byte a byte
        "F#",      -- porte do verificador, 23/23, 496 linhas
        "Prolog",  -- porte do verificador, 23/23, 338 linhas -- e a
                   -- expectativa REFUTADA: o `=/2` nao faz teste de
                   -- ocorrencia, e `unify_with_occurs_check/2` nao e o
                   -- padrao. O ganho veio do PARSER (DCG), nao da unificacao
        "Racket",  -- porte do verificador, 23/23, 397 linhas -- a primeira
                   -- linguagem DINAMICA: a estrutura do algoritmo sobrevive
                   -- inteira, e o que se perde e a rede. `var` e `app` sao
                   -- FORMAS DE PADRAO do racket/match, e o sombreamento
                   -- virou um curinga sem nenhum aviso
      },
    },

    P03 = {
      nome = "otp-mesh",
      itens_no_plano = 12,  -- inclui YAML, Dockerfile, Nix, Bash
      planejadas = 8,
      feitas = {
        "Elixir",
        "Erlang",
        "Gleam",
        "Go",
        "Rust",    -- NIF; tambem conta no P01, e a sobreposicao aparece
        "Scala",
        "Clojure",
        "HCL",
      },
    },
    P04 = {
      nome = "webstack",
      itens_no_plano = 12,
      -- 12, e nao 11: o `planejadas` dizia 11 porque o GraphQL era OMITIDO da
      -- lista para nao contar duas vezes com o P10. Agora ele esta listado
      -- (convencao do P03), e o numero acompanha -- senao a validacao do
      -- cobertura.lua reclama de 12 feitas com 11 planejadas, que foi
      -- exatamente o que aconteceu ao corrigir isto.
      planejadas = 12,
      feitas = {
        "JavaScript",   -- js/view.js: a referencia, sem transpilacao
        "TypeScript",   -- ts/view.ts: e os 4 bugs que o tsc recusa, com codigo
        "CoffeeScript", -- coffee/view.coffee: o arquivo arqueologico, que roda
        "PHP",          -- php/view.php: o legado, com strangler-fig
        "Ruby",         -- ruby/view.rb: o painel administrativo
        "HTML",         -- dados/esperado/view.html: o alvo que todos acertam
        "CSS",          -- css/orcamento.css: artefato gerado e verificado
        "Sass",         -- sass/orcamento.scss: e a decisao de que nao se paga
        "Elm",          -- View.elm: MVU e ports, e o PRECO da garantia
        "PureScript",   -- Main.purs: classes de tipo, e o FFI que quebrou
        "Dart",         -- view.dart: sound null safety, e quatro alvos
        "GraphQL", -- esquema.graphql: o contrato de tipos; tambem conta no P10
      },
      -- COMPLETO, 12 de 12. O GraphQL esta LISTADO acima e tambem conta no
      -- P10; o cobertura.lua desduplica. Antes ele era omitido daqui, e o
      -- projeto aparecia como 11 de 12 -- subestimando a si mesmo, porque o
      -- `graphql/esquema.graphql` existe neste repositorio.
      --
      -- A tabela de bundle size que o plano promete NAO existe ainda: medir
      -- exige empacotar com minificacao e tree-shaking iguais nos tres, e
      -- feito errado o numero compara configuracao de bundler em vez de
      -- linguagem. Entra quando o procedimento estiver escrito.
    },
    P05 = {
      nome = "datalab",
      itens_no_plano = 11,
      planejadas = 10,
      feitas = {
        "Fortran", -- modelo.f90: os DOIS algoritmos, a mao, no mesmo arquivo
        "R",       -- modelo.R: a formula como objeto de primeira classe
        "Octave",  -- modelo.m: algebra linear como sintaxe (dialeto MATLAB)
        "hansl",   -- modelo.inp: no lugar do Stata, que e pago
        "Julia",   -- modelo.jl: as DUAS familias, e a descoberta de que tres
                   -- fatoracoes de equacoes normais erram por uma ordem de
                   -- grandeza de diferenca ENTRE SI
        "Python",  -- referencia.py: a referencia com SVD; tambem conta no P10
        "SQL",     -- modelo.sql: equacoes normais por Cramer, e o achado de
                   -- que ate o AJUSTE erra 40%; tambem conta no P10
        "Mojo",    -- modelo.mojo: onde a tese do p05 PARA de valer -- mesmo
                   -- algoritmo que Fortran e Scala, mesmo numero no caso bem
                   -- (1,4e-14) e 3,5x pior no mal (1,2e-02), porque ali XtX e
                   -- numericamente singular e o erro deixa de ser reprodutivel
        "Scala",   -- modelo.scala: os MESMOS dois algoritmos do Fortran, a
                   -- mao e sem biblioteca -- e os numeros batem (1,4e-08 e
                   -- 3,4e-03 nos dois), fechando o experimento: mesmo
                   -- algoritmo em linguagens diferentes da o mesmo erro
      },
      -- Python e SQL estao LISTADOS, e nao omitidos, seguindo a convencao que
      -- o P03 usa para o Rust: o cobertura.lua desduplica, e o progresso por
      -- projeto passa a dizer a verdade.
      --
      -- Antes eles eram omitidos "para nao contar duas vezes", e o efeito era
      -- o P05 aparecer como 5/10 enquanto o README dele dizia 7/10 -- e o
      -- README estava certo, porque sao implementacoes reais no repositorio.
      --
      -- Faltam Scala/Spark, Mojo, Wolfram e SAS.
    },
    P06 = { nome = "gpu-arena",     itens_no_plano = 9,  planejadas = 8,  feitas = {} },
    P07 = { nome = "engine",        itens_no_plano = 7,  planejadas = 6,  feitas = {} },
    P08 = { nome = "tri-mobile",    itens_no_plano = 5,  planejadas = 5,  feitas = {} },
    P09 = { nome = "silicon",       itens_no_plano = 10, planejadas = 8,  feitas = {} },
    P10 = {
      nome = "query-lab",
      itens_no_plano = 8,
      planejadas = 8,
      feitas = {
        "Python",   -- referencia.py: o BFS sem magica que as outras 7 conferem
        "SQL",      -- alcance.sql: o MESMO arquivo em SQLite e PostgreSQL
        "PL/pgSQL", -- transferir.sql: atomicidade, e a classe QL de ERRCODE
        "Cypher",   -- alcance.cypher: travessia como primitiva, em Kuzu
        "SPARQL",   -- alcance.rq: o padrao NAO limita repeticao, e a inferencia
        "GraphQL",  -- esquema.graphql: o que o modelo NAO expressa, medido
        "T-SQL",    -- transferir.sql: um ROLLBACK aninhado DESTROI a transacao
                    -- do chamador (medido); 11 casos
        "PL/SQL",   -- transferir.sql: SELECT INTO e estrito por padrao, e todo
                    -- DDL faz COMMIT (medido); 11 casos
      },
      -- As 8 estao feitas. As imagens sao de 2,21 GB (SQL Server) e 13,8 GB
      -- (Oracle), MEDIDAS -- o registro antigo dizia 1,5 e 2,5, e o do Oracle
      -- errava por mais de cinco vezes.
      --
      -- O CI roda OS DOIS, o Oracle num job separado.
      --
      -- Eu havia dispensado o PL/SQL do CI dizendo que 13,8 GB "nao cabem nos
      -- ~14 GB do runner". Acrescentei um passo que mede o disco para dar
      -- evidencia a isso, e ele mediu 91 GB LIVRES -- refutando a afirmacao
      -- que eu fui buscar nele. O job separado existe pelo tempo do download,
      -- nao pelo espaco.
    },
    P11 = { nome = "chain",         itens_no_plano = 6,  planejadas = 6,  feitas = {} },

    P12 = {
      nome = "toolbelt",
      itens_no_plano = 15,  -- inclui Makefile, Nix, Dockerfile, YAML, HCL
      -- 11 linguagens: as 10 previstas mais o LibreOffice Basic, que entrou no
      -- lugar do VBA.
      --
      -- O VBA exige Microsoft Office, que e PAGO, e a regra declarada e
      -- "nenhum recurso pago". O LibreOffice Basic e livre (MPL-2.0), roda
      -- headless, e cobre o mesmo terreno -- mas e OUTRO DIALETO, e esta
      -- rotulado como tal. A macro NAO usa Option VBASupport, de proposito:
      -- o objetivo e a API nativa UNO, nao VBA fingido.
      planejadas = 11,
      feitas = {
        "Perl", -- lint_medicoes.pl: numero publicado sem dispersao ao lado
        "AWK",  -- estatistica.awk: faixa, dispersao e a regra de decisao
        "Lua",  -- cobertura.lua: esta propria conta
        "Raku", -- gramatica_fasm.raku: 9/9 contra o desmontador em C
        "Tcl",  -- dirige_repl.exp: 12 interacoes com REPL de verdade
        "Nix",  -- flake.nix: 4 devShells, versao escolhida por motivo medido
        "Groovy", -- relatorio.groovy: saida dos verificadores em JUnit XML
        "PowerShell", -- Audita-Repos.ps1, com par em bash: as duas concordam
        "Bash", -- bash/audita-repos.sh: o par POSIX do PowerShell
        "AutoHotkey", -- Verifica-Ambiente.ahk: nomeia a causa que o calibra.sh so sente
        "LibreOffice Basic", -- Cobertura.bas: a cobertura como planilha com =SUM() de verdade
      },
    },
    P13 = {
      nome = "legacy",
      itens_no_plano = 9,
      planejadas = 9,
      feitas = {
        "COBOL",  -- juros.cob: o lote original, e a especificacao executavel
        "C#",     -- Juros.cs: com decimal, identico ao COBOL byte a byte
        "VB.NET", -- Juros.vb: a ponte que as empresas de fato usaram
        "Object Pascal", -- juros.pas: Currency bate, e o FPC avalia literal real em Single
        "SQL",           -- juros.sql: O MESMO arquivo em dois motores -- o
                         -- PostgreSQL bate byte a byte com o COBOL e o SQLite
                         -- erra 13 das 14 contas, porque la NUMERIC e
                         -- AFINIDADE e nao tipo, e integer/integer trunca.
                         -- Tambem conta no P10; o cobertura.lua desduplica.
      },
      --
      -- O C# conta: ele existe so aqui, e um comentario antigo afirmava o
      -- contrario.
      -- Por isso a conta publicada dizia 45 linguagens distintas quando sao
      -- 46 -- achado por auditoria do CONTEXTO.md em 2026-11-16. O README do
      -- P13 sempre disse "3 das 9"; era este arquivo que estava errado.
      -- Faltam Object Pascal, PL/I, RPG, ABAP e Apex -- os tres ultimos
      -- exigem conta gratuita (PUB400, SAP BTP, Salesforce).
    },
    P14 = {
      nome = "first-code",
      itens_no_plano = 5,
      planejadas = 5,
      feitas = {
        "Pascal",   -- licoes.pas: a referencia, com aviso tratado como erro
        "Logo",     -- licoes.lg: openwrite/setwrite porque o build e so grafico
        "Scratch",  -- gera.py + simula.py: .sb3 gerado E interpretado aqui
        "Blockly",  -- blocos.js: dois geradores, um deles emite codigo forge
        "Smalltalk", -- licoes.st: classe de verdade, em Pharo 11 headless
      },
      -- COMPLETO. O Smalltalk exigiu Pharo por download: gnu-smalltalk nao
      -- existe mais no apt, e squeak-vm + etoys instalam mas a imagem do
      -- Etoys ignora o .st. O Pharo e livre (MIT) e autocontido -- registrado
      -- em AMBIENTE.md do indice, com o comando de remocao.
    },
  },
}
