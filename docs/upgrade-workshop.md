# Oficina de melhorias do lote

Data: 23 de setembro de 2026

Este relatório distingue implementação, validação estática e teste ainda pendente no Roblox Studio.

## Objetivo desta etapa

Substituir os dois pads de melhoria isolados por uma construção integrada ao ferro-velho de cada jogador, mantendo os preços, níveis, efeitos e persistência já existentes.

## Estrutura criada em cada lote

- Modelo `UpgradeWorkshop` no canto frontal direito do lote.
- Piso de chapa industrial, parede traseira, parede lateral, cobertura e dois pilares frontais.
- Fachada física `CENTRO DE MELHORIAS`.
- Duas estações internas separadas:
  - `FERRAMENTAS`, com uma chave catraca física exposta na parede.
  - `MOBILIDADE`, com roda física exposta na parede.
- Iluminação própria azul na estação de ferramentas e verde na estação de mobilidade.
- Dois pontos fixos e invisíveis usados exclusivamente para posicionar os pads funcionais:
  - `ToolUpgradeAnchor`.
  - `SpeedUpgradeAnchor`.

## Integração com os sistemas existentes

### Ferramentas

- A compra continua custando R$ 1.000.
- O tempo continua mudando de 1,5 segundo para 1,2 segundo.
- O atributo persistido continua sendo `ToolLevel`.
- Após a compra, o pad desaparece e a estação mostra `CHAVE CATRACA INSTALADA`.
- Uma luz azul física acende para registrar visualmente a evolução do lote.

### Mobilidade

- Os cinco níveis continuam usando exatamente os valores existentes no `SpeedUpgradeConfig`:
  - Nível 1: 16 studs/s.
  - Nível 2: 18 studs/s por R$ 500.
  - Nível 3: 20 studs/s por R$ 1.500.
  - Nível 4: 22 studs/s por R$ 4.000.
  - Nível 5: 24 studs/s por R$ 10.000.
- O atributo persistido continua sendo `SpeedLevel`.
- A estação mostra nível atual, velocidade atual e estado da próxima melhoria.
- Cinco indicadores físicos acendem progressivamente conforme os níveis comprados.

## Correção de layout

O antigo pad de velocidade ficava em `(-14, 0, 14)` relativo ao lote e ocupava parte da mesma área do terminal de leilão em `(-16, 17)`. Os dois pads agora ficam dentro da oficina no lado direito do lote. O terminal de leilão, o spawn, a placa do proprietário, os carros e os guinchos não foram deslocados.

## Segurança e propriedade

- As validações anteriores continuam ativas: somente o proprietário do lote pode comprar.
- O pagamento continua sendo feito por `EconomyService.TrySpend` no servidor.
- A estação visual lê os atributos do jogador; ela não define dinheiro, preços ou progressão.
- Quando o jogador deixa o servidor, os mostradores voltam ao estado `AGUARDANDO DONO`.

## Validações executadas

- Compilação de todos os arquivos `.luau` com Luau: aprovada.
- Build completo com Rojo 7.7.0: aprovado.
- Geração de sourcemap: aprovada.
- `git diff --check`: aprovado.
- Busca confirmou a remoção dos offsets antigos dos pads.
- Busca confirmou que os preços e efeitos continuam vindo dos módulos de configuração existentes.

## Teste ainda necessário no Roblox Studio

Esta sessão não controla o Roblox Studio do proprietário. Portanto, ainda não estão confirmados ao vivo:

- leitura frontal das placas;
- ausência de bloqueio na entrada da oficina;
- compra real da catraca dentro da nova estação;
- quatro compras consecutivas de mobilidade, do nível 1 ao nível 5, e acendimento dos indicadores;
- persistência visual após sair e entrar novamente.
