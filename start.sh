#!/usr/bin/env bash
# ══════════════════════════════════════════════════════════════
#  BitFood — Painel de inicialização do backend
# ══════════════════════════════════════════════════════════════

BACKEND_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/backend" && pwd)"
LANDING_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/landing" && pwd)"
BTCPAY_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/btcpay"  && pwd)"
export PATH=~/.npm-global/bin:$PATH

# ── Cores ─────────────────────────────────────────────────────
R=$'\e[0;31m'; Y=$'\e[1;33m'; G=$'\e[0;32m'; C=$'\e[0;36m'
W=$'\e[1;37m'; D=$'\e[2m';    B=$'\e[0;34m'; M=$'\e[0;35m'
RST=$'\e[0m';  BLD=$'\e[1m'
OK="${G}● online${RST}"; KO="${R}● offline${RST}"; WRN="${Y}● iniciando${RST}"

# ── Funções auxiliares (rápidas — leem /proc ou ss) ───────────
port_up()   { ss -tlnp 2>/dev/null | grep -q ":$1 "; }
svc_active(){ systemctl is-active --quiet "$1" 2>/dev/null; }
local_ip()  { hostname -I 2>/dev/null | awk '{print $1}'; }
conns()     { ss -tnp 2>/dev/null | grep -c ":4000" || echo 0; }
mem_used()  {
    local total free used pct
    total=$(awk '/MemTotal/{print $2}'     /proc/meminfo)
    free=$(awk  '/MemAvailable/{print $2}' /proc/meminfo)
    used=$(( (total - free) / 1024 ))
    pct=$(( (total - free) * 100 / total ))
    echo "${used}MB (${pct}%)"
}
uptime_fmt(){ uptime -p 2>/dev/null | sed 's/up //'; }

# ── Cache de métricas lentas (pm2, docker) ────────────────────
# Atualizado a cada SLOW_EVERY segundos; leitura é apenas de variáveis.
SLOW_EVERY=5
_tick=0

_C_MONGO="—"; _C_NODE="—"; _C_LANDING="—"; _C_CF="—"
_C_NMEM="—";  _C_UP="—";   _C_LIP="—"
_C_BTC_ST="—"; _C_BTC_SYNC="—"; _C_LND_ST="—"

refresh_cache() {
    # Serviços
    port_up 27017        && _C_MONGO="$OK"   || _C_MONGO="$KO"
    pm2 list 2>/dev/null | grep -q "bitfood-api.*online"     && _C_NODE="$OK"    || _C_NODE="$KO"
    pm2 list 2>/dev/null | grep -q "bitfood-landing.*online" && _C_LANDING="$OK" || _C_LANDING="$KO"
    pgrep -x cloudflared >/dev/null 2>&1 && _C_CF="$OK" || _C_CF="$KO"

    # Node RAM (lê /proc diretamente após pegar PID do pm2)
    local pid
    pid=$(pm2 list 2>/dev/null | awk '/bitfood-api/{print $4}')
    [ -n "$pid" ] && _C_NMEM=$(awk '/VmRSS/{printf "%dMB",$2/1024}' /proc/$pid/status 2>/dev/null) || _C_NMEM="—"

    _C_UP=$(uptime_fmt)
    _C_LIP=$(local_ip)

    # ── BTCPay / Bitcoin / LND ────────────────────────────────
    local btc_running=false
    if command -v docker &>/dev/null; then
        # Verifica se algum container btcpay está up
        if docker ps --format '{{.Names}}' 2>/dev/null | grep -qE 'bitcoind|btcpay'; then
            btc_running=true
            _C_BTC_ST="$OK"

            # Progresso de sync da blockchain
            local info
            info=$(docker exec btcpay-bitcoind-1 \
                   bitcoin-cli getblockchaininfo 2>/dev/null || true)
            if [ -n "$info" ]; then
                local raw_pct blocks headers
                raw_pct=$(echo "$info" | grep -oP '"verificationprogress":\s*\K[0-9.]+' || echo "0")
                blocks=$(echo  "$info" | grep -oP '"blocks":\s*\K[0-9]+'                || echo "?")
                headers=$(echo "$info" | grep -oP '"headers":\s*\K[0-9]+'               || echo "?")
                # formata para 1 decimal sem python
                local pct_int pct_dec
                pct_int=$(echo "$raw_pct" | awk '{printf "%d", $1*100}')
                pct_dec=$(echo "$raw_pct" | awk '{printf "%.1f", $1*100}')
                if [ "$pct_int" -ge 100 ] 2>/dev/null; then
                    _C_BTC_SYNC="${G}100% sincronizado${RST}"
                else
                    _C_BTC_SYNC="${Y}${pct_dec}%${RST} (bloco ${blocks}/${headers})"
                fi
            else
                _C_BTC_SYNC="${Y}aguardando daemon…${RST}"
            fi

            # Status do LND
            local lnd_name
            lnd_name=$(docker ps --format '{{.Names}}' 2>/dev/null | grep lnd | head -1)
            if [ -n "$lnd_name" ]; then
                local lnd_state
                lnd_state=$(docker exec "$lnd_name" lncli state 2>/dev/null \
                            | grep -oP '"state":\s*"\K[^"]+' || echo "")
                case "$lnd_state" in
                    SERVER_ACTIVE|WALLET_UNLOCKED) _C_LND_ST="${G}${lnd_state}${RST}" ;;
                    "")                            _C_LND_ST="${Y}iniciando…${RST}"   ;;
                    *)                             _C_LND_ST="${Y}${lnd_state}${RST}" ;;
                esac
            else
                _C_LND_ST="${D}—${RST}"
            fi
        fi
    fi

    if ! $btc_running; then
        port_up 8080 && _C_BTC_ST="$OK" || _C_BTC_ST="${WRN} (rode: bash btcpay/setup.sh)"
        _C_BTC_SYNC="${D}—${RST}"
        _C_LND_ST="${D}—${RST}"
    fi
}

# ── Inicializa serviços ───────────────────────────────────────
start_services() {
    local jwt_secret
    jwt_secret=$(grep -oP '(?<=JWT_SECRET=).+' "$BACKEND_DIR/.env" 2>/dev/null || true)
    if [ -z "$jwt_secret" ] || [ "${#jwt_secret}" -lt 32 ]; then
        echo -e "\n${R}${BLD}  ERRO: JWT_SECRET ausente ou fraco em backend/.env${RST}"
        echo -e "  Gere um novo: openssl rand -base64 48"
        sleep 5
    fi

    # MongoDB
    if ! port_up 27017; then
        mkdir -p "$HOME/mongodb-data"
        mongod --fork --logpath /tmp/mongod.log --dbpath "$HOME/mongodb-data" 2>/dev/null \
            || mongod --fork --logpath /tmp/mongod.log --dbpath /var/lib/mongodb 2>/dev/null \
            || systemctl start mongod 2>/dev/null
    fi

    # Dependências do backend
    if [ "$BACKEND_DIR/package.json" -nt "$BACKEND_DIR/node_modules/.package-lock.json" ] 2>/dev/null \
       || [ ! -d "$BACKEND_DIR/node_modules/express-rate-limit" ]; then
        cd "$BACKEND_DIR" && npm install --silent 2>/dev/null || true
    fi

    # Backend Node.js
    if pm2 list 2>/dev/null | grep -q "bitfood-api.*online"; then
        :
    else
        cd "$BACKEND_DIR"
        pm2 start server.js --name bitfood-api --update-env 2>/dev/null \
            || pm2 restart bitfood-api 2>/dev/null
    fi

    # Landing page (:3000)
    if pm2 list 2>/dev/null | grep -q "bitfood-landing.*online"; then
        :
    else
        pm2 start "$LANDING_DIR/serve.js" --name bitfood-landing --update-env 2>/dev/null \
            || pm2 restart bitfood-landing 2>/dev/null
    fi

    # Cloudflare Tunnel
    if svc_active cloudflared; then
        :
    elif ! pgrep -x cloudflared >/dev/null; then
        nohup cloudflared tunnel --config ~/.cloudflared/config.yml run \
            >/tmp/cloudflared.log 2>&1 &
    fi
}

# ── Painel de status ──────────────────────────────────────────
draw_status() {
    # Métricas rápidas (sem cache — leitura direta de /proc e ss)
    local CONN MEM UP_SYS EL
    CONN=$(conns)
    MEM=$(mem_used)
    UP_SYS=$(uptime_fmt)
    EL='\033[K'

    echo -e ""
    echo -e " ${W}${BLD}╔════════════════════════════════════════════════╗${RST}${EL}"
    echo -e " ${W}${BLD}║  Serviços                                      ║${RST}${EL}"
    echo -e " ${W}${BLD}╠════════════════════════════════════════════════╣${RST}${EL}"
    printf  " ${W}${BLD}║${RST}  MongoDB                %-20b${W}${BLD}║${RST}\033[K\n" "$_C_MONGO"
    printf  " ${W}${BLD}║${RST}  Node.js API  (:4000)   %-20b${W}${BLD}║${RST}\033[K\n" "$_C_NODE"
    printf  " ${W}${BLD}║${RST}  Landing page (:3000)   %-20b${W}${BLD}║${RST}\033[K\n" "$_C_LANDING"
    printf  " ${W}${BLD}║${RST}  Cloudflare Tunnel       %-20b${W}${BLD}║${RST}\033[K\n" "$_C_CF"
    echo -e " ${W}${BLD}╠════════════════════════════════════════════════╣${RST}${EL}"
    echo -e " ${W}${BLD}║  Bitcoin / Lightning                           ║${RST}${EL}"
    echo -e " ${W}${BLD}╠════════════════════════════════════════════════╣${RST}${EL}"
    printf  " ${W}${BLD}║${RST}  BTCPay Server (:8080)   %-20b${W}${BLD}║${RST}\033[K\n" "$_C_BTC_ST"
    printf  " ${W}${BLD}║${RST}  ${D}Bitcoin sync  ${RST}  %b${EL}\n" "$_C_BTC_SYNC"
    printf  " ${W}${BLD}║${RST}  ${D}LND state     ${RST}  %b${EL}\n" "$_C_LND_ST"
    echo -e " ${W}${BLD}╠════════════════════════════════════════════════╣${RST}${EL}"
    echo -e " ${W}${BLD}║  Rede                                          ║${RST}${EL}"
    echo -e " ${W}${BLD}╠════════════════════════════════════════════════╣${RST}${EL}"
    echo -e " ${W}${BLD}║${RST}  ${D}IP Local   ${RST}  ${C}${BLD}${_C_LIP}${RST}${EL}"
    echo -e " ${W}${BLD}║${RST}  ${D}Landing    ${RST}  ${C}${BLD}https://bitfood.app${RST}${EL}"
    echo -e " ${W}${BLD}║${RST}  ${D}API        ${RST}  ${C}${BLD}https://api.bitfood.app/graphql${RST}${EL}"
    echo -e " ${W}${BLD}║${RST}  ${D}Conexões   ${RST}  ${Y}${BLD}${CONN} ativas${RST}${EL}"
    echo -e " ${W}${BLD}╠════════════════════════════════════════════════╣${RST}${EL}"
    echo -e " ${W}${BLD}║  Sistema                                       ║${RST}${EL}"
    echo -e " ${W}${BLD}╠════════════════════════════════════════════════╣${RST}${EL}"
    echo -e " ${W}${BLD}║${RST}  ${D}RAM total  ${RST}  ${MEM}${EL}"
    echo -e " ${W}${BLD}║${RST}  ${D}Node RAM   ${RST}  ${_C_NMEM}${EL}"
    echo -e " ${W}${BLD}║${RST}  ${D}Uptime     ${RST}  ${UP_SYS}${EL}"
    echo -e " ${W}${BLD}╠════════════════════════════════════════════════╣${RST}${EL}"
    echo -e " ${W}${BLD}║  ${D}Atualiza: rápido 1s · serviços ${SLOW_EVERY}s · Ctrl+C sair${W}${BLD}║${RST}${EL}"
    echo -e " ${W}${BLD}╚════════════════════════════════════════════════╝${RST}${EL}"
}

# ── Loop principal ────────────────────────────────────────────
main() {
    printf '\033[?1049h\033[?25l'
    trap 'printf "\033[?25h\033[?1049l\n"; exit' INT TERM EXIT

    printf '\033[H\033[2J'
    echo -e "\n${Y}${BLD}  ⚡ Iniciando serviços BitFood...${RST}\n"
    start_services

    # Primeiro preenchimento do cache antes de mostrar o painel
    refresh_cache
    sleep 1

    while true; do
        # Atualiza cache de métricas lentas a cada SLOW_EVERY segundos
        if (( _tick % SLOW_EVERY == 0 )); then
            refresh_cache &   # roda em background para não bloquear o frame
        fi
        _tick=$(( _tick + 1 ))

        printf '\033[2J\033[H'
        draw_status
        sleep 1
    done
}

main
