# Fixture: deve passar sem nenhum achado

Cada número de tempo aqui tem método declarado por perto. Se o lint acusar
qualquer linha deste arquivo, ele tem um FALSO POSITIVO.

## Dispersão na mesma linha

A travessia custa 30 ns por chamada (dispersão 3%).

## Dispersão em coluna de tabela

Medido com 9 repetições alternadas:

| impl | tempo | dispersão |
|---|---|---|
| C | 11,1 ms | 8% |
| Nim | 13,9 ms | 13% |

## Método no começo do parágrafo, número no fim

Sete repetições alternadas entre as plataformas, melhor de cada lado, com a
máquina calibrada antes e depois: o agent fez 534 mil ops/s contra 493 mil do
GenServer, e a razão de 1,2x não decide nada.

## Veredito explícito de indeterminação

O ganho foi de 3,4x, mas ficou no ruído desta máquina.

## Parâmetro de configuração, não medição

O script mata o processo 9 vezes com 120 ms de intervalo, e o prazo de
convergência é de 5 s.

A intensidade de reinício padrão do OTP é 3 reinícios em 5 segundos.

## Menção histórica a número corrigido

A primeira versão desta seção publicou 8,9 s de convergência e 5,83 ms de
reinício. Os dois eram amostras.

## Bloco de código é saída de programa, não afirmação

```
convergência          : 8914 ms
Stats reiniciou em    : 5.83 ms
tempo                 : 18.41 s  (38015 por segundo)
```

## Dispensa explícita

O limite é de 1 ms por NIF. <!-- lint-medicao: ignorar -->

<!-- lint-medicao: ignorar -->
Esta linha tem 250 ms e está dispensada pela linha anterior.

## Números que NÃO são medição de tempo

A conexão custa 3.534 bytes. O porte tem 255 linhas. A suíte passa 35 testes
de 35. O arquivo tem 84 MB e a imagem 8,63 MB.

## Numero dentro de codigo inline nao e afirmacao

O montador usa `strtoll(s, &end, 0)`, que aceita `0x..` e `0..`.
O desmontador emite `%-8s` para o mnemonico e `" %d"` por operando.
