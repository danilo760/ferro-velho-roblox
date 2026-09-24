# Menu lateral de melhorias

## Objetivo

Substituir os pads físicos de compra por um botão lateral `MELHORIAS`, mantendo a oficina física do lote como parte do cenário e apresentando a progressão como uma árvore visual.

## Melhorias exibidas

O menu utiliza diretamente os valores já existentes nos módulos compartilhados. Nenhum nível ou preço novo foi criado.

### Ferramentas

- Nível 1: Ferramentas básicas — 1,5 segundo por peça.
- Nível 2: Chave catraca — 1,2 segundo por peça — R$ 1.000.

### Mobilidade

- Nível 1: Passo Padrão — 16 studs/s.
- Nível 2: Tênis Reforçado — 18 studs/s — R$ 500.
- Nível 3: Passada Ágil — 20 studs/s — R$ 1.500.
- Nível 4: Corrida Atlética — 22 studs/s — R$ 4.000.
- Nível 5: Velocidade Máxima — 24 studs/s — R$ 10.000.

## Interface

- Botão permanente `MELHORIAS` na lateral direita da tela.
- Janela responsiva para computador e celular.
- Saldo atualizado em tempo real.
- Nó raiz `SEU FERRO-VELHO`, dividido nos ramos Ferramentas e Mobilidade.
- Cada nível aparece como um nó conectado ao nível anterior.
- Estados visuais distintos para `CONCLUÍDO`, `ATUAL`, próximo nó comprável e `BLOQUEADO`.
- Apenas o próximo nó de cada ramo aceita compra.
- Fechamento pelo botão `X`, tecla Escape ou toque fora da janela.
- Mensagem visual de sucesso ou erro depois da tentativa de compra.

## Segurança da compra

O cliente apenas solicita a categoria. O servidor valida:

- dados do jogador carregados;
- existência de lote atribuído;
- nível atual verdadeiro;
- próxima melhoria existente;
- saldo suficiente;
- compra concorrente ou clique duplicado.

O custo e o novo nível são decididos pelo servidor a partir dos módulos de configuração. O cliente não envia preço nem nível.

## Alteração no mundo físico

Os pads físicos de compra deixaram de ser criados. A construção `CENTRO DE MELHORIAS` continua no lote, e seus painéis e indicadores continuam acompanhando os níveis adquiridos pelo jogador.

## Validação

- Parser oficial Luau em todos os arquivos do projeto.
- `git diff --check`.
- `rojo build` com Rojo 7.7.0.
- Geração do sourcemap do projeto.

O teste visual e funcional no Roblox Studio deve ser confirmado depois da sincronização pelo proprietário. Ele não é declarado como concluído neste documento.
