# BitFood — Contexto do Projeto

## O que é
Plataforma de delivery de comida com pagamentos em Bitcoin Lightning.
3 apps Flutter (cliente, restaurante, entregador) + backend Node.js/GraphQL/MongoDB + BTCPay Server.

Repositório: https://github.com/Unknown-brazilian/bitfood-from-zero
Token no remote: já configurado no git config local.

## Estrutura
```
apps/customer/      Flutter — app do cliente
apps/restaurant/    Flutter — app do restaurante
apps/rider/         Flutter — app do entregador
backend/            Node.js + GraphQL + MongoDB (gitignored, mas existe em disco)
landing/            Landing page estática (servida pelo PM2: bitfood-landing)
btcpay/             docker-compose.yml do BTCPay Server + LND
release/            APKs por versão (gitignored)
admin/              Painel admin Next.js (gitignored)
```

## Infra em produção (servidor remoto)
- Backend PM2: `bitfood-backend` (porta 4000) — `pm2 restart bitfood-backend --update-env`
- Landing PM2: `bitfood-landing`
- BTCPay: https://btcpay.bitfood.app (Lightning only, LND interno)
- LND image: `btcpayserver/lnd:v0.18.5-beta` (v0.18.3 incompatível com Bitcoin Core 31.0)
- Backend env: `backend/.env` — contém BTCPAY_URL, BTCPAY_API_KEY, BTCPAY_STORE_ID, BTCPAY_WEBHOOK_SECRET

## Versão atual: v1.4.1 (lançada em 2026-04-29)
GitHub Release: https://github.com/Unknown-brazilian/bitfood-from-zero/releases/tag/v1.4.1
(Restaurante e Entregador permanecem em v1.4.0)

### O que foi feito no v1.4.0
- Cliente: barra de status corrigida — não sobrepõe mais conteúdo no topo
- Confirmação "ENTENDI" ao salvar carteira Lightning corrigida (todos os apps)
- Restaurante: seletor de endereço com GPS + cascata país/estado/cidade (Nominatim)
- Entregador: campo de endereço de casa no perfil (GPS obrigatório)
- Entregador: filtro "Em direção a casa" nos pedidos disponíveis (±60° de azimute, 1x a cada 8h)
- Backend: mutações `setRiderHomeAddress` e `activateTowardHome` + modelo `homeLocation` GeoJSON
- BTCPay: polling de invoice reduzido (timeout de 5s corrigido)
- Landing page: release notes v1.4.0 em 5 idiomas

### O que foi feito no v1.3.0
- CAPTCHA matemático anti-flood na criação de conta (todos os 3 apps)
- Confirmação "ENTENDI" obrigatória ao salvar carteira Lightning (todos os 3 apps)
- Escrow entregador: isenção automática para tier VETERAN (`escrowSats = 0`)
- Notificações de atualização in-app exibem notas da versão (release notes)
- Status banner corrigido: posição (MediaQuery.padding.top) + parsing da API (`data['api'] == 'ok'`)
- LND atualizado para v0.18.5-beta
- Landing page: seção escrow com isenção Veterano + release notes v1.3.0
- version.json: v1.3.0 com campo `notes` para os 3 apps

## Arquitetura de pagamento
- **Custodial**: plataforma segura o BTC, saldos em MongoDB (campo `sats` no User)
- Restaurante e entregador sacar via endereço Lightning externo (lightningAddress, bloqueado após 1º uso)
- Escrow: últimas 10 entregas travadas em `escrowOrders[]` / `escrowSats` — VETERAN fica com 0

## Tiers do entregador
Baseados em BTC recebido total, referência USD (conversão via btcprice.js):
- NOVO: < $5
- BASICO: $5–$10
- CONFIAVEL: $10–$50
- VETERAN: > $50 (isento de escrow)

## Padrões de código importantes
- Flutter: sem comentários desnecessários, widgets pequenos, sem abstrações prematuras
- Backend: GraphQL com Apollo Server, resolvers em `src/graphql/resolvers/`
- Status check: `GET /health` retorna `{api:'ok', mongodb:'ok', btcpay:'ok'}` (strings, não booleans)
- Update check: `GET /version` retorna `{customer:{version,url,notes}, restaurant:{...}, rider:{...}}`

## Tarefas pendentes (backlog)
1. Ciclo de teste completo: restaurante → prato → cliente → pedido → entregador → entrega → avaliação
2. Mensagens de erro amigáveis com detalhes expansíveis + botão copiar (nos 3 apps)
3. Rodar `pm2 restart bitfood-backend --update-env` após qualquer mudança no backend

## Como compilar os APKs
```bash
cd apps/customer && flutter build apk --release --no-pub
cd apps/restaurant && flutter build apk --release --no-pub
cd apps/rider && flutter build apk --release --no-pub
# Saída: apps/*/build/app/outputs/flutter-apk/app-release.apk
# Copiar para: release/bitfood-{app}-v{version}.apk
```

## Como publicar release no GitHub
```bash
TOKEN="<seu-token-aqui>"  # configure via: git config credential.helper store
# Criar release via API: POST https://api.github.com/repos/Unknown-brazilian/bitfood-from-zero/releases
# Upload APKs: POST https://uploads.github.com/repos/.../releases/{id}/assets?name=...
```
