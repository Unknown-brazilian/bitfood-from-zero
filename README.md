# ⚡ BitFood — iFood clone com Bitcoin Lightning

Clone completo do iFood usando **Bitcoin Lightning** para todos os pagamentos. Sem taxas de plataforma de pagamento — apenas as taxas da rede Bitcoin.

## Aplicações

| App | Tecnologia | Descrição |
|-----|-----------|-----------|
| `backend/` | Node.js + GraphQL + MongoDB | API principal |
| `admin/` | Next.js 14 | Painel administrativo web |
| `apps/customer/` | Flutter Android | App do cliente |
| `apps/restaurant/` | Flutter Android | App do restaurante |
| `apps/rider/` | Flutter Android | App do entregador |

## Pagamentos — BTCPay Server

Utiliza o **BTCPay Server** (open-source, gratuito):
- Sem taxas de entrada ou mensalidade
- Apenas taxas da rede Bitcoin/Lightning
- Self-hosted ou use um provedor como [btcpay.lnvoltz.com](https://btcpay.lnvoltz.com)
- Lightning Network (confirmação instantânea)
- Bitcoin on-chain como fallback

## Cores (tema iFood)

| Token | Valor | Uso |
|-------|-------|-----|
| `primary` | `#EA1D2C` | Vermelho iFood — botões, ícones |
| `orange` | `#FF6900` | Destaque de preços (Lightning) |
| `background` | `#F7F7F7` | Fundo geral |
| `success` | `#50A773` | Confirmações, status entregue |

## Fluxo de Pagamento

```
Cliente faz pedido
      ↓
Backend cria invoice BTCPay Server
      ↓
App exibe QR BOLT11 (Lightning)
      ↓ ou ↓
      Checkout BTCPay (fallback)
      ↓
Cliente paga com carteira Lightning
      ↓
BTCPay envia webhook → /webhook/btcpay
      ↓
Pedido confirmado → Notifica restaurante (WebSocket)
      ↓
PAID → ACCEPTED → PREPARING → READY → ASSIGNED → PICKED → DELIVERED
```

## Setup Rápido

### 1. Variáveis de ambiente

```bash
cp backend/.env.example backend/.env
nano backend/.env
```

Preencha:
- `BTCPAY_URL` — URL do seu BTCPay Server
- `BTCPAY_API_KEY` — Chave API (Greenfield v1)
- `BTCPAY_STORE_ID` — ID da sua loja no BTCPay
- `BTCPAY_WEBHOOK_SECRET` — Secret do webhook
- `JWT_SECRET` — String aleatória longa

### 2. Deploy com Docker

```bash
docker compose up -d
```

### 3. Apontar webhook no BTCPay

No painel BTCPay → Store → Webhooks → Adicionar:
- URL: `https://SEU_DOMINIO/webhook/btcpay`
- Eventos: `InvoiceSettled`, `InvoicePaymentSettled`
- Secret: mesmo valor de `BTCPAY_WEBHOOK_SECRET`

### 4. Build dos APKs Flutter

```bash
cd apps/customer
flutter pub get
flutter build apk --release \
  --dart-define=API_URL=https://SEU_DOMINIO/graphql \
  --dart-define=WS_URL=wss://SEU_DOMINIO/graphql
```

Repita para `apps/restaurant` e `apps/rider`.

## Acesso Admin

| Campo | Padrão |
|-------|--------|
| URL | `http://SEU_DOMINIO` |
| E-mail | `admin@bitfood.app` |
| Senha | `admin123` |

> ⚠️ **Mude a senha em produção!**

## API GraphQL

Playground disponível em `http://localhost:4000/graphql`

## Downloads

### BitFood

| App | Download | Versão |
|-----|----------|--------|
| 🛒 App do Cliente | [bitfood-customer-v1.4.1.apk](https://github.com/Unknown-brazilian/bitfood-from-zero/releases/download/v1.4.1/bitfood-customer-v1.4.1.apk) | v1.4.1 |
| 🍽️ App do Restaurante | [bitfood-restaurant-v1.4.0.apk](https://github.com/Unknown-brazilian/bitfood-from-zero/releases/download/v1.4.0/bitfood-restaurant-v1.4.0.apk) | v1.4.0 |
| 🏍️ App do Entregador | [bitfood-rider-v1.4.0.apk](https://github.com/Unknown-brazilian/bitfood-from-zero/releases/download/v1.4.0/bitfood-rider-v1.4.0.apk) | v1.4.0 |

### Outros apps

| App | Download | Descrição |
|-----|----------|-----------|
| ₿ SatsCalc | [satscalc-v1.0.0.apk](https://github.com/Unknown-brazilian/satscalc/releases/download/v1.0.0/satscalc-v1.0.0.apk) | Calculadora de satoshis líquidos — compara 14 exchanges, widget onchain, 6 idiomas |
| 🏃 Borderless Freedom | [borderless-freedom-v1.1.0.apk](https://github.com/Unknown-brazilian/borderless-freedom/releases/download/v1.1.0/borderless-freedom-v1.1.0.apk) | Runner Bitcoin estilo Metal Slug — 57 fases, 18 bosses |
| 🎮 Borderless Freedom RPG | [borderless-freedom-rpg-v0.2.0.apk](https://github.com/Unknown-brazilian/borderless-freedom-rpg/releases/download/v0.2.0/borderless-freedom-rpg-v0.2.0.apk) | RPG turn-based estilo Game Boy — seed BIP-39, eventos crypto |
| ⚡ LN Markets Bot | [lnmarkets-bot.html](https://bitfood.app/lnmarkets-bot.html) | Bot de trading automatizado — Trend Tabajara 3.0, Android + Linux |

## Licença

MIT
