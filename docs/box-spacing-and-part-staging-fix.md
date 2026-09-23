# Correção de espaçamento dos boxes e posicionamento de peças

## Problemas relatados

1. Algumas peças atravessavam ou apareciam dentro da parede ao serem removidas do carro.
2. Os três boxes do lote estavam visual e funcionalmente muito próximos.

## Causa confirmada no código

O destino de uma peça recém-removida era calculado no eixo global do mapa com `carPosition.X - 8 - row * 4`. Isso sempre empurrava a peça para o lado negativo de X, sem considerar a rotação do carro nem qual box estava sendo usado. No Box 1, o destino calculado coincidia com a parede lateral do lote.

Os centros dos boxes estavam nos deslocamentos `-15`, `0` e `15`, portanto havia somente 15 studs de distância entre carros vizinhos. Os pisos tinham 13,5 studs de largura, restando aproximadamente 1,5 stud entre as marcações.

O descarte manual também colocava a peça cinco studs à frente do jogador sem testar a existência de uma parede. A recuperação de peças que caíam do mapa repetia a mesma escolha fixa do lado negativo de X.

## Alterações implementadas

- O lote passou de `48 x 48` para `68 x 54` studs.
- Os centros dos quatro lotes passaram de `±55` para `±64`, preservando a área livre da Central de Reciclagem.
- Os centros dos boxes passaram de `-15 / 0 / 15` para `-22 / 0 / 22`, um aumento de 15 para 22 studs entre boxes vizinhos.
- Os pisos, pórticos e portões foram redimensionados para representar corretamente as novas baias.
- A saída automática divide as peças em duas fileiras, uma de cada lado do carro, usando o `CFrame` local do próprio carro. Assim, a solução funciona mesmo quando o lote e o carro estão rotacionados.
- A recuperação de peças caídas usa exatamente a mesma área segura relativa ao box.
- Ao soltar uma peça manualmente, o servidor faz raycast à frente. Se não houver espaço suficiente, tenta atrás; se os dois lados estiverem bloqueados, devolve a peça ao último `SafeCFrame` conhecido.
- Estradas, orientação das docas, prédios laterais e duas pilhas de sucata foram reposicionados para acompanhar os lotes maiores sem criar novas interseções.

## Validação executada

- `git diff --check`: aprovado.
- Parser oficial Luau em todos os 24 arquivos `.luau`: aprovado.
- `rojo build` com Rojo 7.7.0: aprovado.
- Geração de sourcemap com Rojo 7.7.0: aprovada.

## Validação ainda necessária

O teste visual e de gameplay no Roblox Studio ainda precisa ser executado depois do `git pull`. Deve-se remover várias peças no Box 1 e conferir os Boxes 1, 2 e 3 em perspectiva. Esta etapa não foi marcada como testada no Studio neste relatório.
