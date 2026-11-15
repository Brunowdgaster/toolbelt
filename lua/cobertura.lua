-- cobertura.lua — planejado contra feito, por projeto e no total.
--
--   lua5.4 cobertura.lua registro.lua
--   lua5.4 cobertura.lua registro.lua --roadmap ../../poliglota/ROADMAP.md
--
-- ## Por que esta ferramenta existe
--
-- O portfólio tem 14 projetos e ~130 linguagens planejadas, e a contagem de
-- "quantas já estão feitas" foi respondida à mão três vezes nesta sessão — e
-- **errada uma delas**, porque eu contei a mesma linguagem duas vezes em dois
-- projetos.
--
-- A conta tem três armadilhas que um humano erra e um programa não:
--
--   1. **sobreposição** — Rust aparece no P01 e no P03; conta uma vez no total
--      e duas na soma por projeto;
--   2. **ferramentas que não são linguagens** — Makefile, CMake, YAML,
--      Dockerfile estão no plano e não contam como "linguagem dominada";
--   3. **planejado contra feito** — o plano lista 15 itens para o P01, dos
--      quais 12 são linguagens de fato.
--
-- ## Por que em Lua
--
-- Porque o registro é **dado declarativo que precisa ser lido por código**, e
-- essa é a razão de Lua existir. O arquivo `registro.lua` é uma tabela Lua
-- literal: nem parser, nem schema, nem biblioteca de YAML. O programa faz
-- `dofile` e tem a estrutura na mão, com comentários e tudo.
--
-- É o mesmo papel que Lua tem em Nginx, Redis e Neovim: a configuração é
-- programa.
--
-- ## O que ela NÃO faz
--
-- Não decide se uma linguagem está "dominada" — isso é julgamento, e está
-- registrado à mão no `registro.lua` com a evidência ao lado. A ferramenta faz
-- a **conta**, que é onde o humano erra.

local function uso(codigo)
  io.stderr:write([[
cobertura.lua - planejado contra feito, por projeto

uso:
  cobertura.lua <registro.lua> [--roadmap <ROADMAP.md>]

Sem --roadmap, usa so o que o registro declara como planejado.
]])
  os.exit(codigo or 2)
end

-- ------------------------------------------------------------- argumentos

local caminho_registro, caminho_roadmap

do
  local i = 1
  while i <= #arg do
    local a = arg[i]
    if a == "--roadmap" then
      i = i + 1
      caminho_roadmap = arg[i] or uso()
    elseif a == "--ajuda" then
      uso(0)
    elseif a:sub(1, 1) == "-" then
      io.stderr:write("opcao desconhecida: " .. a .. "\n")
      os.exit(2)
    else
      caminho_registro = a
    end
    i = i + 1
  end
end

if not caminho_registro then uso() end

-- ------------------------------------------------------------- o registro
--
-- `dofile` em vez de parser: o registro É um programa Lua que devolve uma
-- tabela. Se tiver erro de sintaxe, o Lua diz onde -- melhor que qualquer
-- mensagem que eu escreveria.

local ok, registro = pcall(dofile, caminho_registro)

if not ok then
  io.stderr:write("erro ao ler " .. caminho_registro .. ": " .. tostring(registro) .. "\n")
  os.exit(1)
end

if type(registro) ~= "table" or not registro.projetos then
  io.stderr:write(caminho_registro .. ": esperava uma tabela com campo 'projetos'\n")
  os.exit(1)
end

-- Validação do registro. Falha alto: um campo faltando daria contagem errada
-- em silêncio, que é o erro que esta ferramenta existe para evitar.
for id, p in pairs(registro.projetos) do
  if type(p.planejadas) ~= "number" then
    io.stderr:write(("%s: 'planejadas' faltando ou nao numerico\n"):format(id))
    os.exit(1)
  end
  if type(p.feitas) ~= "table" then
    io.stderr:write(("%s: 'feitas' faltando ou nao e lista\n"):format(id))
    os.exit(1)
  end
  if #p.feitas > p.planejadas then
    io.stderr:write(("%s: %d feitas mas so %d planejadas\n")
      :format(id, #p.feitas, p.planejadas))
    os.exit(1)
  end
end

-- --------------------------------------------------------- opcional: roadmap
--
-- Confere a contagem declarada contra o ROADMAP de verdade. Se o plano mudar e
-- o registro nao, a ferramenta avisa -- em vez de reportar com confianca um
-- numero que ficou velho.

local aviso_roadmap

if caminho_roadmap then
  local fh = io.open(caminho_roadmap, "r")
  if not fh then
    io.stderr:write("nao consegui abrir " .. caminho_roadmap .. "\n")
    os.exit(1)
  end

  local itens_por_projeto = {}
  local atual

  for linha in fh:lines() do
    local id = linha:match("^###%s+(P%d+)")
    if id then atual = id end

    local lista = linha:match("^%*%*Linguagens:%*%*%s*(.+)$")
    if lista and atual then
      local n = 1
      for _ in lista:gmatch(",") do n = n + 1 end
      itens_por_projeto[atual] = n
    end
  end

  fh:close()

  local divergencias = {}
  for id, p in pairs(registro.projetos) do
    local no_plano = itens_por_projeto[id]
    if no_plano and p.itens_no_plano and no_plano ~= p.itens_no_plano then
      table.insert(divergencias,
        ("%s: registro diz %d itens no plano, ROADMAP tem %d")
          :format(id, p.itens_no_plano, no_plano))
    end
  end

  if #divergencias > 0 then
    table.sort(divergencias)
    aviso_roadmap = divergencias
  end
end

-- ------------------------------------------------------------------ a conta

local ids = {}
for id in pairs(registro.projetos) do table.insert(ids, id) end
table.sort(ids)

-- Conjunto de linguagens distintas: é aqui que a sobreposição é resolvida.
-- Rust no P01 e no P03 entra uma vez.
local distintas, ocorrencias = {}, {}

for _, id in ipairs(ids) do
  for _, ling in ipairs(registro.projetos[id].feitas) do
    if not distintas[ling] then
      distintas[ling] = true
      ocorrencias[ling] = {}
    end
    table.insert(ocorrencias[ling], id)
  end
end

local n_distintas = 0
for _ in pairs(distintas) do n_distintas = n_distintas + 1 end

local soma_feitas, soma_planejadas = 0, 0
for _, id in ipairs(ids) do
  local p = registro.projetos[id]
  soma_feitas = soma_feitas + #p.feitas
  soma_planejadas = soma_planejadas + p.planejadas
end

-- ---------------------------------------------------------------- relatório

local function barra(feito, total, largura)
  if total == 0 then return ("-"):rep(largura) end
  local cheio = math.floor(feito / total * largura + 0.5)
  return ("#"):rep(cheio) .. ("."):rep(largura - cheio)
end

print()
print(("%-6s %-10s %10s %8s %s"):format("proj", "nome", "feitas/plan", "pct", "progresso"))
print(("-"):rep(62))

for _, id in ipairs(ids) do
  local p = registro.projetos[id]
  local pct = p.planejadas > 0 and (#p.feitas / p.planejadas * 100) or 0
  print(("%-6s %-10s %6d/%-4d %7.0f%% %s")
    :format(id, p.nome or "", #p.feitas, p.planejadas, pct,
            barra(#p.feitas, p.planejadas, 16)))
end

print(("-"):rep(62))
print(("%-6s %-10s %6d/%-4d %7.0f%% %s")
  :format("TOTAL", "", soma_feitas, soma_planejadas,
          soma_planejadas > 0 and (soma_feitas / soma_planejadas * 100) or 0,
          barra(soma_feitas, soma_planejadas, 16)))
print()

-- A diferença entre a soma e o conjunto é a sobreposição, e é o número que a
-- contagem à mão erra.
print(("linguagens DISTINTAS: %d   (a soma por projeto da %d)")
  :format(n_distintas, soma_feitas))

local repetidas = {}
for ling, onde in pairs(ocorrencias) do
  if #onde > 1 then
    table.sort(onde)
    table.insert(repetidas, ("%s (%s)"):format(ling, table.concat(onde, ", ")))
  end
end

if #repetidas > 0 then
  table.sort(repetidas)
  print(("  sobreposicao em %d: %s"):format(#repetidas, table.concat(repetidas, "; ")))
else
  print("  sem sobreposicao entre projetos")
end

if registro.meta then
  local faltam = registro.meta - n_distintas
  print()
  if faltam > 0 then
    print(("meta: %d linguagens. Faltam %d."):format(registro.meta, faltam))
  else
    print(("meta de %d linguagens ATINGIDA."):format(registro.meta))
  end
end

if aviso_roadmap then
  print()
  print("AVISO: o registro divergiu do ROADMAP.")
  for _, d in ipairs(aviso_roadmap) do print("  " .. d) end
  print("  O plano mudou e o registro nao -- corrija antes de confiar na conta.")
  os.exit(1)
end

os.exit(0)
