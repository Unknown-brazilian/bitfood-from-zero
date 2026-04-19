#!/bin/bash
set -e

BLUE='\033[0;34m'; GREEN='\033[0;32m'; RED='\033[0;31m'; YELLOW='\033[1;33m'; NC='\033[0m'
log()  { echo -e "${BLUE}[bitfood]${NC} $1"; }
ok()   { echo -e "${GREEN}[✓]${NC} $1"; }
warn() { echo -e "${YELLOW}[!]${NC} $1"; }
err()  { echo -e "${RED}[✗]${NC} $1"; exit 1; }

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TUNNEL_NAME="bitfood"

echo ""
echo "  ⚡ BitFood — Deploy de Produção"
echo "  ================================"
echo ""

# ── 1. Cloudflare Tunnel ───────────────────────────────────────────────────
log "Verificando cloudflared..."
if ! command -v cloudflared &>/dev/null; then
  log "Instalando cloudflared..."
  curl -fsSL https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb -o /tmp/cloudflared.deb
  sudo dpkg -i /tmp/cloudflared.deb
  ok "cloudflared instalado"
else
  ok "cloudflared já instalado: $(cloudflared --version 2>&1 | head -1)"
fi

if [ ! -f ~/.cloudflared/cert.pem ]; then
  echo ""
  warn "Você ainda não autenticou no Cloudflare."
  echo "  Execute o comando abaixo e faça login no browser:"
  echo ""
  echo "    cloudflared tunnel login"
  echo ""
  echo "  Depois rode este script novamente: bash deploy.sh"
  exit 0
fi
ok "Autenticação Cloudflare OK"

# ── 2. Criar tunnel (se não existir) ──────────────────────────────────────
TUNNEL_ID=$(cloudflared tunnel list 2>/dev/null | awk "/$TUNNEL_NAME/"'{print $1}' | head -1)
if [ -z "$TUNNEL_ID" ]; then
  log "Criando tunnel '$TUNNEL_NAME'..."
  cloudflared tunnel create "$TUNNEL_NAME"
  TUNNEL_ID=$(cloudflared tunnel list | awk "/$TUNNEL_NAME/"'{print $1}' | head -1)
fi
ok "Tunnel ID: $TUNNEL_ID"

# ── 3. Escrever config ─────────────────────────────────────────────────────
mkdir -p ~/.cloudflared
cat > ~/.cloudflared/config.yml <<EOF
tunnel: $TUNNEL_ID
credentials-file: /home/$USER/.cloudflared/$TUNNEL_ID.json

ingress:
  - hostname: api.bitfood.app
    service: http://localhost:4000
    originRequest:
      noTLSVerify: true
  - hostname: admin.bitfood.app
    service: http://localhost:3000
  - service: http_status:404
EOF
ok "Config do tunnel escrita em ~/.cloudflared/config.yml"

# ── 4. Rotas DNS ────────────────────────────────────────────────────────────
log "Configurando DNS no Cloudflare..."
cloudflared tunnel route dns "$TUNNEL_NAME" api.bitfood.app   2>&1 | grep -v "^$" || true
cloudflared tunnel route dns "$TUNNEL_NAME" admin.bitfood.app 2>&1 | grep -v "^$" || true
ok "Rotas DNS configuradas"

# ── 5. Instalar como serviço do sistema ────────────────────────────────────
log "Instalando tunnel como serviço..."
if systemctl is-active --quiet cloudflared 2>/dev/null; then
  sudo systemctl restart cloudflared
else
  sudo cloudflared service install
  sudo systemctl enable cloudflared
  sudo systemctl start cloudflared
fi
ok "Serviço cloudflared ativo"

# ── 6. Subir stack Docker ─────────────────────────────────────────────────
log "Subindo serviços Docker (mongo + backend + admin)..."
cd "$SCRIPT_DIR"
docker compose up -d --build
ok "Stack Docker rodando"

# ── 7. Aguardar backend ────────────────────────────────────────────────────
log "Aguardando backend ficar disponível..."
for i in $(seq 1 30); do
  if curl -sf http://localhost:4000/health &>/dev/null; then
    ok "Backend respondendo em localhost:4000"
    break
  fi
  sleep 2
done

echo ""
ok "BitFood está no ar!"
echo ""
echo "  API GraphQL:  https://api.bitfood.app/graphql"
echo "  Admin:        https://admin.bitfood.app"
echo "  Health:       https://api.bitfood.app/health"
echo ""
echo "  Para ver os logs:   docker compose logs -f backend"
echo "  Para parar tudo:    docker compose down"
echo ""
