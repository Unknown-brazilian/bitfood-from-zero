#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════
#  BitFood — Primeiro setup do BTCPay Server
#  Execute uma vez: ./btcpay/setup.sh
# ═══════════════════════════════════════════════════════════════

set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMPOSE="docker compose -f $DIR/docker-compose.yml --env-file $DIR/.env"

# ── Verifica .env ─────────────────────────────────────────────
if [ ! -f "$DIR/.env" ]; then
    cp "$DIR/.env.example" "$DIR/.env"
    echo ""
    echo "⚠️  Arquivo .env criado. Edite as credenciais antes de continuar:"
    echo "   nano $DIR/.env"
    echo ""
    exit 1
fi

# ── Verifica docker ───────────────────────────────────────────
if ! command -v docker &>/dev/null; then
    echo "Docker não encontrado. Instalando..."
    curl -fsSL https://get.docker.com | sh
    sudo usermod -aG docker "$USER"
    echo "Docker instalado. Reinicie o terminal e rode o script novamente."
    exit 0
fi

# ── Sobe os containers ────────────────────────────────────────
echo ""
echo "⚡ Subindo BTCPay Server..."
$COMPOSE up -d

echo ""
echo "Aguardando LND iniciar (45s)..."
sleep 45

# ── Inicializa wallet LND (só na primeira vez) ────────────────
LND_CONTAINER=$($COMPOSE ps -q lnd)

if [ -n "$LND_CONTAINER" ]; then
    STATE=$(docker exec "$LND_CONTAINER" lncli state 2>/dev/null | grep -oP '"state": "\K[^"]+' || echo "")
    if [[ "$STATE" != "WALLET_UNLOCKED" && "$STATE" != "SERVER_ACTIVE" ]]; then
        echo ""
        echo "━━━ Criação da Wallet LND ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "  IMPORTANTE: anote a seed phrase em papel físico!"
        echo "  Sem ela, seus fundos Lightning ficam inacessíveis."
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        docker exec -it "$LND_CONTAINER" lncli create
    fi
fi

# ── Instruções finais ─────────────────────────────────────────
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ BTCPay Server rodando!"
echo ""
echo "  🌐 https://btcpay.bitfood.app"
echo ""
echo "  Próximos passos:"
echo "  1. Crie a conta admin em https://btcpay.bitfood.app"
echo "  2. Crie uma Store"
echo "  3. Account → API Keys → Generate"
echo "     Permissões: btcpay.store.cancreateinvoice, btcpay.store.canviewinvoices"
echo "  4. Preencha no backend/.env:"
echo ""
echo "     BTCPAY_URL=https://btcpay.bitfood.app"
echo "     BTCPAY_STORE_ID=<id da sua store>"
echo "     BTCPAY_API_KEY=<chave gerada>"
echo ""
echo "  ⏳ O nó Bitcoin sincroniza em background (1-3 dias)."
echo "     Acompanhe: docker logs -f btcpay-bitcoind-1"
echo "     Pagamentos Lightning só funcionam após sync completo."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
