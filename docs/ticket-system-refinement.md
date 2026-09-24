# Refinamento do sistema de Tickets

## Economia confirmada no código

- Saldo inicial: 3 Tickets.
- Recompensa: 1 Ticket ao concluir qualquer carro.
- Custos por conservação: 1, 2, 3, 5 ou 8 Tickets.
- Tickets são salvos junto com os demais dados do jogador.
- Uma oferta só pode ser adquirida uma vez por jogador em cada rodada do catálogo.
- Compras com falha confirmada realizam estorno do valor debitado.

Nenhum desses valores foi alterado nesta etapa porque ainda não existe teste de balanceamento suficiente para justificar uma mudança econômica.

## Refinamentos implementados

- O botão rápido do catálogo mostra o saldo de Tickets mesmo com o catálogo fechado.
- Ofertas sem saldo suficiente ficam visualmente bloqueadas.
- O botão informa quantos Tickets faltam para a oferta.
- Os cartões são reavaliados automaticamente quando o saldo muda.
- O rodapé explica a fonte dos Tickets e a faixa de custos das ofertas.
- A mensagem de carro concluído informa o bônus em dinheiro e `+1 Ticket`.

## Correções técnicas relacionadas

- Corrigida a chamada de recuperação de peças: `boxOrigin` já era um `CFrame` e não podia usar `.CFrame` novamente.
- O Studio passa a usar armazenamento temporário em memória em todas as sessões. Isso elimina tentativas de DataStore quando a opção de acesso às APIs está desativada.
- Servidores publicados continuam usando DataStore persistente e session locking.

## Limitação intencional do Studio

No Studio, os dados existem apenas durante a sessão atual do servidor de teste. Ao encerrar o Play, esse progresso temporário é descartado. O comportamento persistente permanece reservado aos servidores publicados.
