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
      },
    },

    P02 = {
      nome = "forge-lang",
      itens_no_plano = 15,
      planejadas = 15,
      feitas = {
        "Haskell", -- compilador completo, Hindley-Milner total
        "OCaml",   -- porte do verificador, 23/23 byte a byte
        "F#",      -- porte do verificador, 23/23, 496 linhas
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

    P04 = { nome = "webstack",      itens_no_plano = 12, planejadas = 10, feitas = {} },
    P05 = { nome = "datalab",       itens_no_plano = 11, planejadas = 10, feitas = {} },
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
      },
      -- Faltam T-SQL e PL/SQL, que exigem imagens de 1,5 GB e 2,5 GB. A suite
      -- ja esta preparada para pular os dois, e QLAB_EXIGE=1 recusa pular no
      -- CI.
    },
    P11 = { nome = "chain",         itens_no_plano = 6,  planejadas = 6,  feitas = {} },

    P12 = {
      nome = "toolbelt",
      itens_no_plano = 15,  -- inclui Makefile, Nix, Dockerfile, YAML, HCL
      -- 10 linguagens previstas, e o VBA e o PRIMEIRO BLOQUEIO REAL do
      -- portfolio: exige Office, que e pago, e a regra declarada e "nenhum
      -- recurso pago". Verificado nesta maquina: nao ha Office nem
      -- LibreOffice. O caminho livre e LibreOffice Basic, que e OUTRO
      -- DIALETO -- sera feito e rotulado como tal, nao como VBA.
      planejadas = 10,
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
      },
    },

    P13 = { nome = "legacy",        itens_no_plano = 9,  planejadas = 9,  feitas = {} },
    P14 = {
      nome = "first-code",
      itens_no_plano = 5,
      planejadas = 5,
      feitas = {
        "Pascal",   -- licoes.pas: a referencia, com aviso tratado como erro
        "Logo",     -- licoes.lg: openwrite/setwrite porque o build e so grafico
        "Scratch",  -- gera.py + simula.py: .sb3 gerado E interpretado aqui
        "Blockly",  -- blocos.js: dois geradores, um deles emite codigo forge
      },
      -- Falta SMALLTALK, e e a segunda ressalva declarada do portfolio junto
      -- com o VBA do P12. Tentado: gnu-smalltalk nao existe mais no apt;
      -- squeak-vm + etoys instalam e a VM sobe, mas a imagem do Etoys ignora
      -- o .st; baixar Pharo (livre, MIT, roda headless) esta bloqueado pela
      -- politica de rede da sessao.
    },
  },
}
