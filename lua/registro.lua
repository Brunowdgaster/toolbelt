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
    P10 = { nome = "query-lab",     itens_no_plano = 8,  planejadas = 8,  feitas = {} },
    P11 = { nome = "chain",         itens_no_plano = 6,  planejadas = 6,  feitas = {} },

    P12 = {
      nome = "toolbelt",
      itens_no_plano = 15,  -- inclui Makefile, Nix, Dockerfile, YAML, HCL
      planejadas = 10,
      feitas = {
        "Perl", -- lint_medicoes.pl: numero publicado sem dispersao ao lado
        "AWK",  -- estatistica.awk: faixa, dispersao e a regra de decisao
        "Lua",  -- cobertura.lua: esta propria conta
      },
    },

    P13 = { nome = "legacy",        itens_no_plano = 9,  planejadas = 9,  feitas = {} },
    P14 = { nome = "first-code",    itens_no_plano = 5,  planejadas = 5,  feitas = {} },
  },
}
