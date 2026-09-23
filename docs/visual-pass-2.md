# Passe visual estrutural 2

Data: 23 de setembro de 2026

Este documento registra somente alterações presentes no código e verificações realmente executadas. Ele não declara teste visual no Roblox Studio.

## Motivo da revisão

O passe anterior acrescentou iluminação, veículos com silhuetas diferentes e objetos de ferro-velho, mas o mapa continuou visualmente aberto. Faltavam construções grandes para definir o espaço e diversos textos de gameplay ainda eram renderizados como `BillboardGui`, aparentando flutuar no cenário.

## Alterações implementadas

### Arquitetura do pátio

- Perímetro industrial fechado em três lados e entrada principal aberta no lado sul.
- Portão com dois pilares e placa física de entrada.
- Prédio de Administração e Contratos ao norte.
- Galpão da Prensa e Triturador no lado oeste.
- Galpão de Peças no lado leste.
- Portaria ao lado da entrada, sem ocupar o vão de passagem.
- Fachadas com fundação, paredes laterais e traseira, cobertura, portas metálicas, molduras, janelas iluminadas e placas físicas.
- Pilhas de sucata reposicionadas para pontos definidos, evitando interseção com os novos prédios.

### Oficinas dos quatro lotes

- Cobertura metálica sobre a área dos três boxes.
- Paredes laterais e parede traseira existentes formando um galpão aberto pela frente.
- Quatro vigas estruturais sob cada cobertura.
- Placa física `OFICINA DE DESMONTAGEM` na parede traseira.
- Dois postes sustentando a placa de proprietário na entrada do lote.
- Pontos lógicos de carro, guincho, spawn, terminal e upgrades não foram deslocados.

### Textos integrados ao cenário

- Informação de box bloqueado: de `BillboardGui` para `SurfaceGui` na barra física do portão.
- Upgrade de ferramenta: placa física com dois postes e `SurfaceGui`.
- Upgrade de velocidade: placa física com dois postes e `SurfaceGui`; removido o `SelectionBox` permanente.
- Esteira de peças: texto pintado sobre a superfície da esteira.
- Baia de motor: texto pintado sobre a superfície da baia.
- Título do Rei do Ferro-Velho: placa física no trono em vez de texto flutuante.
- O arquivo legado `AuctionHouseService.luau` ainda contém `BillboardGui`, mas esse serviço não é requerido nem iniciado por `init.server.luau`; ele não faz parte do mapa ativo atual.

### Iluminação e atmosfera

- Horário alterado de `17.35` para `16.8` para manter a luz dourada com mais claridade.
- Densidade da atmosfera reduzida de `0.32` para `0.20`.
- Haze reduzido de `2.2` para `1.35`.
- Nuvens procedurais adicionadas ao `Terrain`.

## Erros de animação informados

Foi feita busca textual por todos os IDs mostrados no Output e por criação de objetos `Animation` em todo o repositório. Nenhum desses IDs está nos arquivos do projeto e o projeto não cria animações próprias neste momento.

Os IDs `507765000`, `507765644` e `507770453`, entre outros da mesma família exibida no Output, aparecem na documentação oficial do Roblox em exemplos de animação de personagem. Portanto, a evidência disponível indica que as mensagens vêm do sistema de animação do avatar/Studio, não dos serviços de gameplay deste repositório.

Não foi aplicada uma substituição artificial do script `Animate`, pois isso apenas esconderia o sintoma sem provar a causa do bloqueio de carregamento. O diagnóstico final desse erro exige novo teste em um Place publicado ou inspeção do avatar durante uma sessão do Studio.

## Verificações executadas

- Todos os arquivos `.luau` em `src` compilados com Luau `0.739`: aprovado.
- Build completo com Rojo `7.7.0`: aprovado.
- Geração de sourcemap com Rojo `7.7.0`: aprovado.
- `git diff --check`: aprovado.
- Busca pelos IDs de animação informados: zero ocorrências no repositório.

## Ainda precisa ser confirmado no Roblox Studio

- Composição visual e escala dos quatro novos prédios.
- Visibilidade frontal das placas físicas em cada orientação de lote.
- Ausência de colisões inesperadas nas entradas dos galpões.
- Aparência das nuvens e da atmosfera no computador do proprietário.
- Se os erros de animação continuam após publicar o Place e testar novamente.

