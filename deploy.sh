#!/usr/bin/env bash
# ══════════════════════════════════════════════════════════════════════
#  BitFood — Deploy de produção em VPS limpo (Ubuntu 22.04 / Debian 12)
#
#  Uso:
#    git clone https://github.com/Unknown-brazilian/bitfood-from-zero
#    cd bitfood-from-zero
#    bash deploy.sh
#
#  O que este script faz:
#    1. Instala Docker + Docker Compose v2
#    2. Instala cloudflared
#    3. Cria o backend/.env com segredos gerados automaticamente
#    4. Configura e ativa o Cloudflare Tunnel como serviço do sistema
#    5. Sobe o stack Docker (MongoDB + API + Landing page)
#    6. Verifica que o backend está respondendo
# ══════════════════════════════════════════════════════════════════════
set -euo pipefail

# ── Cores ─────────────────────────────────────────────────────────────
B='\033[1m'; R='\033[0;31m'; G='\033[0;32m'
Y='\033[1;33m'; C='\033[0;36m'; W='\033[1;37m'; RST='\033[0m'

log()  { echo -e "${C}[bitfood]${RST} $*"; }
ok()   { echo -e "${G}[✓]${RST} $*"; }
warn() { echo -e "${Y}[!]${RST} $*"; }
err()  { echo -e "${R}[✗]${RST} $*"; exit 1; }
ask()  { echo -en "${W}[?]${RST} $* "; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TUNNEL_NAME="bitfood"
ENV_FILE="$SCRIPT_DIR/backend/.env"

echo ""
echo -e "  ${W}${B}⚡ BitFood — Deploy de Produção${RST}"
echo    "  ════════════════════════════════"
echo ""

# ══════════════════════════════════════════════════════════════════════
# 1. DOCKER
# ══════════════════════════════════════════════════════════════════════
log "Verificando Docker..."
if ! command -v docker &>/dev/null; then
  log "Instalando Docker..."
  curl -fsSL https://get.docker.com | sudo bash
  sudo usermod -aG docker "$USER"
  ok "Docker instalado — pode ser necessário reconectar SSH para usar sem sudo"
else
  ok "Docker $(docker --version | grep -oP '\d+\.\d+\.\d+' | head -1) já instalado"
fi

# docker compose v2
if ! docker compose version &>/dev/null 2>&1; then
  log "Instalando Docker Compose plugin..."
  sudo apt-get install -y docker-compose-plugin 2>/dev/null \
    || sudo pip3 install docker-compose 2>/dev/null \
    || err "Não foi possível instalar docker compose. Instale manualmente."
fi
ok "Docker Compose $(docker compose version --short 2>/dev/null || echo 'ok')"

# ══════════════════════════════════════════════════════════════════════
# 2. CLOUDFLARED
# ══════════════════════════════════════════════════════════════════════
log "Verificando cloudflared..."
if ! command -v cloudflared &>/dev/null; then
  log "Instalando cloudflared..."
  ARCH=$(dpkg --print-architecture 2>/dev/null || echo "amd64")
  curl -fsSL "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-${ARCH}.deb" \
    -o /tmp/cloudflared.deb
  sudo dpkg -i /tmp/cloudflared.deb
  rm /tmp/cloudflared.deb
  ok "cloudflared instalado"
else
  ok "cloudflared $(cloudflared --version 2>&1 | head -1)"
fi

# ══════════════════════════════════════════════════════════════════════
# 3. BACKEND .env
# ══════════════════════════════════════════════════════════════════════
log "Verificando backend/.env..."

gen_secret() { openssl rand -base64 48 | tr -dc 'a-zA-Z0-9' | head -c "$1"; }

if [ ! -f "$ENV_FILE" ]; then
  warn ".env não encontrado. Criando a partir do template..."
  echo ""

  ask "URL do BTCPay Server (ex: https://btcpay.bitfood.app) [Enter para pular]:"; read -r BTCPAY_URL
  ask "BTCPay API Key [Enter para pular]:"; read -r BTCPAY_KEY
  ask "BTCPay Store ID [Enter para pular]:"; read -r BTCPAY_STORE
  ask "Email do admin (ex: admin@bitfood.app):"; read -r ADMIN_EMAIL
  ask "Senha do admin:"; read -rs ADMIN_PASS; echo ""

  JWT_SECRET=$(gen_secret 48)
  MONGO_PASS=$(gen_secret 32)
  WEBHOOK_SECRET=$(gen_secret 32)

  cat > "$ENV_FILE" <<EOF
PORT=4000
NODE_ENV=production

# Gerado automaticamente — NÃO compartilhe
MONGO_URI=mongodb://bitfood:${MONGO_PASS}@mongo:27017/bitfood?authSource=admin
JWT_SECRET=${JWT_SECRET}

ADMIN_EMAIL=${ADMIN_EMAIL}
ADMIN_PASSWORD=${ADMIN_PASS}

BTCPAY_URL=${BTCPAY_URL:-}
BTCPAY_API_KEY=${BTCPAY_KEY:-}
BTCPAY_STORE_ID=${BTCPAY_STORE:-}
BTCPAY_WEBHOOK_SECRET=${WEBHOOK_SECRET}

PUBLIC_URL=https://api.bitfood.app
DISPLAY_CURRENCY=BRL
EOF

  # MONGO_PASSWORD no .env raiz para o docker-compose
  echo "MONGO_PASSWORD=${MONGO_PASS}" > "$SCRIPT_DIR/.env"
  ok ".env criado com segredos gerados automaticamente"
else
  ok ".env já existe — mantendo"
  # Garantir que MONGO_PASSWORD está no .env raiz
  if [ ! -f "$SCRIPT_DIR/.env" ] || ! grep -q "MONGO_PASSWORD" "$SCRIPT_DIR/.env"; then
    MONGO_PASS=$(gen_secret 32)
    echo "MONGO_PASSWORD=${MONGO_PASS}" >> "$SCRIPT_DIR/.env"
    warn "MONGO_PASSWORD gerado e adicionado ao .env raiz"
  fi
fi

# ══════════════════════════════════════════════════════════════════════
# 4. CLOUDFLARE TUNNEL
# ══════════════════════════════════════════════════════════════════════
log "Configurando Cloudflare Tunnel..."

if [ ! -f ~/.cloudflared/cert.pem ]; then
  echo ""
  warn "Autenticação Cloudflare necessária."
  echo "  Execute e faça login no browser:"
  echo ""
  echo -e "    ${C}cloudflared tunnel login${RST}"
  echo ""
  echo "  Depois rode novamente: bash deploy.sh"
  exit 0
fi
ok "Autenticação Cloudflare OK"

TUNNEL_ID=$(cloudflared tunnel list 2>/dev/null | awk "/$TUNNEL_NAME/"'{print $1}' | head -1)
if [ -z "$TUNNEL_ID" ]; then
  log "Criando tunnel '$TUNNEL_NAME'..."
  cloudflared tunnel create "$TUNNEL_NAME"
  TUNNEL_ID=$(cloudflared tunnel list | awk "/$TUNNEL_NAME/"'{print $1}' | head -1)
fi
ok "Tunnel: $TUNNEL_NAME ($TUNNEL_ID)"

mkdir -p ~/.cloudflared
cat > ~/.cloudflared/config.yml <<EOF
tunnel: ${TUNNEL_ID}
credentials-file: ${HOME}/.cloudflared/${TUNNEL_ID}.json

ingress:
  - hostname: bitfood.app
    service: http://localhost:3000

  - hostname: www.bitfood.app
    service: http://localhost:3000

  - hostname: api.bitfood.app
    service: http://localhost:4000

  - hostname: btcpay.bitfood.app
    service: http://localhost:8080

  - service: http_status:404
EOF
ok "Tunnel config escrita em ~/.cloudflared/config.yml"

log "Configurando rotas DNS..."
cloudflared tunnel route dns "$TUNNEL_NAME" bitfood.app     2>&1 | grep -v "^$" || true
cloudflared tunnel route dns "$TUNNEL_NAME" www.bitfood.app 2>&1 | grep -v "^$" || true
cloudflared tunnel route dns "$TUNNEL_NAME" api.bitfood.app 2>&1 | grep -v "^$" || true
cloudflared tunnel route dns "$TUNNEL_NAME" btcpay.bitfood.app 2>&1 | grep -v "^$" || true
ok "DNS configurado"

log "Ativando cloudflared como serviço..."
if systemctl is-active --quiet cloudflared 2>/dev/null; then
  sudo systemctl restart cloudflared
else
  sudo cloudflared service install
  sudo systemctl enable --now cloudflared
fi
ok "cloudflared ativo (systemctl status cloudflared)"

# ══════════════════════════════════════════════════════════════════════
# 5. STACK DOCKER
# ══════════════════════════════════════════════════════════════════════
log "Subindo stack Docker..."
cd "$SCRIPT_DIR"

# Garante permissão de execução para scripts
chmod +x backend/scripts/*.sh 2>/dev/null || true

docker compose pull mongo 2>/dev/null || true
docker compose up -d --build
ok "Stack rodando (mongo + backend + landing)"

# ══════════════════════════════════════════════════════════════════════
# 6. HEALTH CHECK
# ══════════════════════════════════════════════════════════════════════
log "Aguardando backend..."
for i in $(seq 1 30); do
  if curl -sf http://localhost:4000/health &>/dev/null; then
    ok "Backend respondendo (:4000)"
    break
  fi
  if [ "$i" -eq 30 ]; then
    warn "Backend demorou para responder — verifique: docker compose logs backend"
  fi
  sleep 3
done

# ══════════════════════════════════════════════════════════════════════
# PRONTO
# ══════════════════════════════════════════════════════════════════════
echo ""
echo -e "  ${G}${B}✅ BitFood está no ar!${RST}"
echo ""
echo -e "  ${C}Landing page${RST}   https://bitfood.app"
echo -e "  ${C}API GraphQL${RST}    https://api.bitfood.app/graphql"
echo -e "  ${C}BTCPay${RST}         https://btcpay.bitfood.app  (se configurado)"
echo ""
echo    "  Comandos úteis:"
echo -e "    ${W}docker compose logs -f backend${RST}   — logs da API"
echo -e "    ${W}docker compose logs -f mongo${RST}     — logs do banco"
echo -e "    ${W}docker compose restart backend${RST}   — reiniciar API"
echo -e "    ${W}docker compose down${RST}              — parar tudo"
echo -e "    ${W}docker compose up -d --build${RST}     — rebuild + subir"
echo ""
echo    "  BTCPay Server (opcional, separado):"
echo -e "    ${W}cd btcpay && bash setup.sh${RST}"
echo ""
