-- itens_no_plano errado de propósito: o cruzamento com o ROADMAP real tem de
-- acusar. Se o parser do roadmap não achasse nada, este teste passaria
-- vacuamente -- é ele que prova que a comparação acontece.
return {
  projetos = {
    P01 = { nome = "metal-vm", itens_no_plano = 99, planejadas = 12, feitas = { "C" } },
  },
}
