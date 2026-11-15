#!/usr/bin/env bash
#
# audita-repos.sh — cada repositório do portfólio tem o mínimo?
#
#   bash bash/audita-repos.sh ..
#   bash bash/audita-repos.sh --json ..
#   bash bash/audita-repos.sh --listar
#
# ## O par POSIX↔Windows
#
# Este script faz **o mesmo trabalho** que `pwsh/Audita-Repos.ps1`, e a dupla
# existe porque o plano do portfólio pede a comparação lado a lado em vez de
# teórica: "o mesmo script, duas culturas".
#
# A diferença que importa não é sintaxe. É **o que a linguagem considera um
# valor**:
#
# | | Bash | PowerShell |
# |---|---|---|
# | saída de comando | texto | objeto com campos |
# | estruturar | escolher separador e esperar que não apareça nos dados | `Select-Object`, campos nomeados |
# | emitir JSON | escapar à mão (ver `json_escapa` abaixo) | `ConvertTo-Json`, uma linha |
# | código de saída de um comando | `$?`, direto | `$LASTEXITCODE`, e `$?` significa outra coisa |
#
# As duas primeiras linhas favorecem o PowerShell, e a última favorece o Bash.
# É por isso que os dois existem aqui: a comparação honesta tem as duas
# direções.
#
# ## O caso concreto desta diferença
#
# A função `json_escapa` abaixo tem 12 linhas e trata aspas, barras e controle.
# No par em PowerShell, o equivalente é `ConvertTo-Json -Depth 4`.
#
# Isso não quer dizer que Bash seja ruim: quer dizer que **a estrutura é
# acidental em Bash e nativa em PowerShell**, e que escolher a ferramenta pelo
# tipo de dado é mais útil que escolher por hábito.
#
# ## Códigos de saída
#
#   0  todos os repositórios têm o mínimo
#   1  algum item obrigatório falta
#   2  erro de uso

set -uo pipefail

RAIZ=""
JSON=0
LISTAR=0

while [ $# -gt 0 ]; do
  case "$1" in
    --json) JSON=1 ;;
    --listar) LISTAR=1 ;;
    --ajuda)
      echo "uso: audita-repos.sh [--json] [--listar] <raiz>"
      exit 0
      ;;
    -*)
      echo "opcao desconhecida: $1" >&2
      exit 2
      ;;
    *) RAIZ="$1" ;;
  esac
  shift
done

[ -z "$RAIZ" ] && RAIZ="$(cd "$(dirname "$0")/../.." && pwd)"

# ---------------------------------------------------------------- o que checar
#
# Arrays paralelos, porque Bash não tem registro.
#
# É o ponto da comparação em miniatura: no par em PowerShell isto é uma lista
# de hashtables com campos `Nome`, `Tipo` e `Porque`, e aqui são três arrays
# que têm de permanecer alinhados por disciplina. Desalinhá-los é um bug que
# nada detecta.
NOMES=(
  "README.md"
  "LICENSE"
  ".gitattributes"
  ".github/workflows"
  ".gitignore"
)

TIPOS=(arquivo arquivo arquivo diretorio arquivo)

PORQUES=(
  "o projeto precisa se explicar sem que alguem abra o codigo"
  "repositorio publico sem licenca nao pode ser usado por ninguem"
  "editado no Windows, executado no Linux: sem eol=lf, um script com CRLF falha no runner com erro que nao menciona CRLF"
  "verificacao que nao roda sozinha nao e verificacao"
  "sem ele, artefato de build entra no repositorio -- o p12 tem um build autocontido de 84 MB"
)

# Guarda-corpo para o desalinhamento acima: se alguém acrescentar um item e
# esquecer de um dos arrays, o script para aqui em vez de auditar errado.
if [ "${#NOMES[@]}" -ne "${#TIPOS[@]}" ] || [ "${#NOMES[@]}" -ne "${#PORQUES[@]}" ]; then
  echo "ERRO INTERNO: os arrays de itens estao desalinhados" >&2
  echo "  nomes=${#NOMES[@]} tipos=${#TIPOS[@]} porques=${#PORQUES[@]}" >&2
  exit 2
fi

if [ "$LISTAR" -eq 1 ]; then
  echo "Itens verificados em cada repositorio:"
  echo
  for i in "${!NOMES[@]}"; do
    printf '  %-22s (%s)\n' "${NOMES[$i]}" "${TIPOS[$i]}"
    printf '  %-22s  porque: %s\n\n' '' "${PORQUES[$i]}"
  done
  exit 0
fi

# ------------------------------------------------------------------ descoberta

if [ ! -d "$RAIZ" ]; then
  echo "raiz nao encontrada: $RAIZ" >&2
  exit 2
fi

repos=()
while IFS= read -r d; do
  [ -e "$d/.git" ] && repos+=("$d")
done < <(find "$RAIZ" -mindepth 1 -maxdepth 1 -type d | sort)

if [ "${#repos[@]}" -eq 0 ]; then
  echo "nenhum repositorio git encontrado em $RAIZ" >&2
  exit 2
fi

# ------------------------------------------------------------------- auditoria

# Escapa uma string para JSON.
#
# ESTA FUNÇÃO É O ARGUMENTO da comparação com o PowerShell: ela existe porque
# Bash não tem tipo estruturado, e portanto não tem serializador. No par em
# PowerShell, a linha equivalente é `ConvertTo-Json -Depth 4`.
json_escapa() {
  local s="$1"
  s="${s//\\/\\\\}"   # barra invertida primeiro, senão ela escapa o que vem depois
  s="${s//\"/\\\"}"
  s="${s//$'\t'/\\t}"
  s="${s//$'\n'/\\n}"
  s="${s//$'\r'/\\r}"
  printf '%s' "$s"
}

incompletos=0
total=0
faltando_global=()
linhas_json=()
linhas_texto=()

for repo in "${repos[@]}"; do
  total=$((total + 1))
  nome_repo=$(basename "$repo")
  faltando=()

  for i in "${!NOMES[@]}"; do
    caminho="$repo/${NOMES[$i]}"

    if [ "${TIPOS[$i]}" = "diretorio" ]; then
      [ -d "$caminho" ] || faltando+=("${NOMES[$i]}")
    else
      [ -f "$caminho" ] || faltando+=("${NOMES[$i]}")
    fi
  done

  # Tem remoto? Repositório local sem remoto não está publicado, e isso não é
  # falha -- é estado. A auditoria reporta, não julga.
  #
  # Aqui o Bash ganha: `git remote` e olhar o código de saída é direto, e no
  # PowerShell exige `$LASTEXITCODE` com a ressalva de que `$?` significa
  # "o PowerShell conseguiu invocar", não "o comando deu certo".
  publicado="-"
  if [ -n "$(git -C "$repo" remote 2>/dev/null)" ]; then
    publicado="sim"
  fi

  if [ "${#faltando[@]}" -eq 0 ]; then
    completo="sim"
  else
    completo="NAO"
    incompletos=$((incompletos + 1))
    faltando_global+=("${faltando[@]}")
  fi

  # Variaveis intermediarias em vez de aninhamento profundo.
  #
  # A primeira versao escrevia tudo numa expressao, com `$( ... "$(...)" ... )`
  # dentro de `"..."`, e o bash reclamou de "unexpected EOF while looking for
  # matching quote" -- apontando a ULTIMA linha do arquivo, nao a expressao.
  #
  # E outro ponto da comparacao com o par em PowerShell: la cada campo e uma
  # propriedade de objeto e o aninhamento nao existe.
  lista_faltando=""
  if [ "${#faltando[@]}" -gt 0 ]; then
    lista_faltando=$(IFS=,; printf '%s' "${faltando[*]}")
    lista_faltando=${lista_faltando//,/, }
  fi

  linha=$(printf '%-18s %-10s %-11s %s' \
    "$nome_repo" "$completo" "$publicado" "$lista_faltando")
  linhas_texto+=("$linha")

  itens_json=""
  for f in ${faltando[@]+"${faltando[@]}"}; do
    [ -n "$itens_json" ] && itens_json="${itens_json},"
    itens_json="${itens_json}\"$(json_escapa "$f")\""
  done

  if [ "$completo" = "sim" ]; then completo_json=true; else completo_json=false; fi
  if [ "$publicado" = "sim" ]; then publicado_json=true; else publicado_json=false; fi

  linha_json=$(printf '  {"Repo": "%s", "Completo": %s, "Faltando": [%s], "Publicado": %s}' \
    "$(json_escapa "$nome_repo")" "$completo_json" "$itens_json" "$publicado_json")
  linhas_json+=("$linha_json")
done

# --------------------------------------------------------------------- relatório

if [ "$JSON" -eq 1 ]; then
  echo "["
  printf '%s' "${linhas_json[0]}"
  for i in "${!linhas_json[@]}"; do
    [ "$i" -eq 0 ] && continue
    printf ',\n%s' "${linhas_json[$i]}"
  done
  echo
  echo "]"
else
  echo
  printf '%-18s %-10s %-11s %s\n' repo completo publicado faltando
  printf '%s\n' "$(printf '%.0s-' {1..70})"
  printf '%s\n' "${linhas_texto[@]}"
  printf '%s\n' "$(printf '%.0s-' {1..70})"
  printf '%d repositorio(s), %d completo(s), %d incompleto(s)\n' \
    "$total" "$((total - incompletos))" "$incompletos"

  if [ "$incompletos" -gt 0 ]; then
    echo
    echo "Por que cada item e obrigatorio:"
    for nome in $(printf '%s\n' "${faltando_global[@]}" | sort -u); do
      for i in "${!NOMES[@]}"; do
        if [ "${NOMES[$i]}" = "$nome" ]; then
          printf '  %-22s %s\n' "$nome" "${PORQUES[$i]}"
          break
        fi
      done
    done
  fi
fi

[ "$incompletos" -gt 0 ] && exit 1
exit 0
