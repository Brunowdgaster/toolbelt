-- Fixture mínimo para cobertura.lua.
--
-- "Zig" aparece em DOIS projetos de propósito: é o que faz a soma por projeto
-- (5) divergir do conjunto de distintas (4), que é o número que a contagem à
-- mão erra.
return {
  meta = 10,
  projetos = {
    PA = { nome = "alfa", itens_no_plano = 4, planejadas = 3, feitas = { "Zig", "Nim" } },
    PB = { nome = "beta", itens_no_plano = 5, planejadas = 4, feitas = { "Zig", "Ada", "D" } },
    PC = { nome = "gama", itens_no_plano = 2, planejadas = 2, feitas = {} },
  },
}
