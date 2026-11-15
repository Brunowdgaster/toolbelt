#!/usr/bin/env bash
# roda.sh — instala a macro no perfil do LibreOffice e a executa sem interface.
#
#     ./basic/roda.sh                       # gera basic/cobertura.ods
#     ./basic/roda.sh --saida /tmp/x.ods
#
# ## Por que isto é mais que `soffice macro.bas`
#
# Não existe "rodar um arquivo .bas". O LibreOffice Basic vive **dentro de uma
# biblioteca de macros**, que fica no perfil do usuário em
# `~/.config/libreoffice/4/user/basic/`, e cada biblioteca é descrita por um
# índice XML.
#
# Então executar uma macro de um repositório exige três passos:
#
#   1. instalar o `.bas` como um módulo `.xba` no perfil;
#   2. registrar o módulo no índice `script.xlb` da biblioteca;
#   3. invocar por URI `vnd.sun.star.script:...?language=Basic&location=application`.
#
# Isso é diferente do VBA, onde a macro mora **no próprio arquivo** .xlsm. A
# consequência prática é boa para um repositório: o código fica em texto
# versionável, e não embutido num binário.
#
# ## A troca de informação é por ARQUIVO e por ambiente
#
# Macro de LibreOffice não tem argumento de linha de comando nem stdout
# próprio. A comunicação é:
#
#   * entrada  -> variáveis de ambiente `QLAB_TSV`, `QLAB_ODS`, `QLAB_SAIDA`;
#   * saída    -> a macro escreve num arquivo, que este script imprime.
#
# E a macro NUNCA usa `MsgBox`: janela em automação pendura o processo até o
# timeout, que é exatamente o que o AutoHotkey deste repositório já custou
# duas vezes, e o UCBLogo do p14 uma terceira.

set -uo pipefail

AQUI="$(cd "$(dirname "$0")" && pwd)"
RAIZ="$(dirname "$AQUI")"

SAIDA_ODS="$AQUI/cobertura.ods"
while [ $# -gt 0 ]; do
    case "$1" in
        --saida) shift; SAIDA_ODS="${1:-}" ;;
        *) echo "opção desconhecida: $1" >&2; exit 64 ;;
    esac
    shift
done

if ! command -v soffice >/dev/null 2>&1; then
    echo "soffice ausente: sudo apt-get install --no-install-recommends \\" >&2
    echo "    libreoffice-core libreoffice-calc libreoffice-script-provider-python" >&2
    exit 69
fi

if ! command -v lua5.4 >/dev/null 2>&1; then
    echo "lua5.4 ausente: sudo apt-get install lua5.4" >&2
    exit 69
fi

TMP="$(mktemp -d)"
# shellcheck disable=SC2064
trap "rm -rf '$TMP'" EXIT

# 1. Os numeros, do contador em Lua.
TSV="$TMP/cobertura.tsv"
if ! lua5.4 "$RAIZ/lua/cobertura.lua" "$RAIZ/lua/registro.lua" --tsv > "$TSV"; then
    echo "o cobertura.lua falhou" >&2
    exit 1
fi

# 2. A macro, instalada no perfil.
#
# Um perfil DEDICADO, via `-env:UserInstallation`, e nao o do usuario: sem
# isto, rodar a suite mexeria na instalacao de LibreOffice de quem estiver na
# maquina -- e um teste que altera o ambiente do usuario e um teste que nao se
# pode rodar duas vezes com confianca.
PERFIL="$TMP/perfil"

# O perfil e INICIALIZADO pelo proprio LibreOffice antes de receber a macro.
#
# A primeira versao deste script criava a arvore `user/basic/Standard` a mao,
# com um `script.xlb` e um `script.xlc` escritos por mim. A macro NAO RODAVA, e
# sem mensagem nenhuma: stdout e stderr do soffice vazios, retorno 0.
#
# Deixando o LibreOffice criar o perfil, ve-se o que ele espera:
#
#     user/basic/script.xlc              (sem xlink:href, diferente do meu)
#     user/basic/Standard/script.xlb
#     user/basic/Standard/Module1.xba    <- um modulo JA REGISTRADO
#
# Entao o caminho certo nao e inventar o indice: e sobrescrever o modulo que
# ja existe. Menos codigo, e alinhado com o que a versao instalada faz.
if ! soffice --headless --norestore --nolockcheck --nodefault --nologo \
        "-env:UserInstallation=file://$PERFIL" --terminate_after_init \
        </dev/null >/dev/null 2>&1; then
    echo "falhou ao inicializar o perfil do LibreOffice" >&2
    exit 1
fi

LIB="$PERFIL/user/basic/Standard"
if [ ! -f "$LIB/script.xlb" ]; then
    echo "o perfil não foi inicializado como esperado: falta $LIB/script.xlb" >&2
    exit 1
fi

# O .xba e o .bas embrulhado em XML. O conteudo do script vai dentro de
# CDATA, o que evita ter de escapar `<`, `>` e `&` do codigo Basic.
#
# E o nome e `Module1`, que e o modulo que o LibreOffice ja criou e registrou
# no `script.xlb` do perfil. Usar outro nome exigiria editar o indice -- que
# foi exatamente o que nao funcionou.
{
    printf '%s\n' '<?xml version="1.0" encoding="UTF-8"?>'
    printf '%s\n' '<!DOCTYPE script:module PUBLIC "-//OpenOffice.org//DTD OfficeDocument 1.0//EN" "module.dtd">'
    printf '%s' '<script:module xmlns:script="http://openoffice.org/2000/script" '
    printf '%s\n' 'script:name="Module1" script:language="StarBasic"><![CDATA['
    cat "$AQUI/Cobertura.bas"
    printf '%s\n' ']]></script:module>'
} > "$LIB/Module1.xba"

# 3. A execucao.
RESULTADO="$TMP/resultado.txt"
export QLAB_TSV="$TSV"
export QLAB_ODS="$SAIDA_ODS"
export QLAB_SAIDA="$RESULTADO"

# `--norestore` e `--nolockcheck`: sem eles, uma execucao anterior
# interrompida deixa o LibreOffice tentando recuperar documento, o que no modo
# headless simplesmente nao termina.
if ! soffice \
        --headless --norestore --nolockcheck --nodefault --nologo \
        "-env:UserInstallation=file://$PERFIL" \
        "vnd.sun.star.script:Standard.Module1.Main?language=Basic&location=application" \
        </dev/null >"$TMP/so.out" 2>"$TMP/so.err"; then
    echo "o soffice falhou:" >&2
    head -5 "$TMP/so.err" >&2
    exit 1
fi

# Falha ALTO se a macro nao escreveu.
#
# Sem esta checagem, uma macro que nao rodou (nome errado, biblioteca nao
# registrada, erro de sintaxe no Basic) produziria saida vazia -- e o teste
# acusaria "numero divergente" em vez de "a macro nao executou".
if [ ! -s "$RESULTADO" ]; then
    echo "a macro não produziu saída." >&2
    echo "stdout/stderr do soffice:" >&2
    head -5 "$TMP/so.out" "$TMP/so.err" >&2
    exit 1
fi

if [ ! -s "$SAIDA_ODS" ]; then
    echo "a planilha não foi gravada em $SAIDA_ODS" >&2
    exit 1
fi

cat "$RESULTADO"
