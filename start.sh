#!/usr/bin/env bash
# ══════════════════════════════════════════════════════════════
#  BitFood — Painel de inicialização do backend
# ══════════════════════════════════════════════════════════════

BACKEND_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/backend" && pwd)"
LANDING_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/landing" && pwd)"
export PATH=~/.npm-global/bin:$PATH

# ── Cores ────────────────────────────────────────────────────
# $'...' faz o shell converter \e para ESC real em tempo de atribuição,
# necessário para que printf %s imprima cores corretamente.
R=$'\e[0;31m'; Y=$'\e[1;33m'; G=$'\e[0;32m'; C=$'\e[0;36m'
W=$'\e[1;37m'; D=$'\e[2m';    B=$'\e[0;34m'; M=$'\e[0;35m'
RST=$'\e[0m';  BLD=$'\e[1m';  BG_R=$'\e[41m'; BG_BLK=$'\e[40m'
OK="${G}● online${RST}"; KO="${R}● offline${RST}"; WRN="${Y}● iniciando${RST}"

# ── Funções auxiliares ────────────────────────────────────────
port_up()   { ss -tlnp 2>/dev/null | grep -q ":$1 "; }
svc_active(){ systemctl is-active --quiet "$1" 2>/dev/null; }
pm2_up()    { pm2 list 2>/dev/null | grep -q "$1.*online"; }
public_ip() { curl -s --max-time 3 https://api.ipify.org 2>/dev/null || echo "—"; }
local_ip()  { hostname -I 2>/dev/null | awk '{print $1}'; }
conns()     { ss -tnp 2>/dev/null | grep -c ":4000" || echo 0; }
mem_used()  {
    local total free used pct
    total=$(awk '/MemTotal/{print $2}' /proc/meminfo)
    free=$(awk '/MemAvailable/{print $2}' /proc/meminfo)
    used=$(( (total - free) / 1024 ))
    pct=$(( (total - free) * 100 / total ))
    echo "${used}MB (${pct}%)"
}
node_mem()  {
    local pid
    pid=$(pm2 list 2>/dev/null | awk '/bitfood-api/{print $4}')
    [ -n "$pid" ] && awk '/VmRSS/{printf "%dMB", $2/1024}' /proc/$pid/status 2>/dev/null || echo "—"
}
uptime_fmt(){ uptime -p 2>/dev/null | sed 's/up //'; }

# ── Inicializa serviços ───────────────────────────────────────
start_services() {
    # MongoDB
    if ! port_up 27017; then
        mongod --fork --logpath /tmp/mongod.log --dbpath /var/lib/mongodb 2>/dev/null \
            || systemctl start mongod 2>/dev/null
    fi

    # Backend Node.js
    if pm2_up bitfood-api; then
        : # já rodando
    else
        cd "$BACKEND_DIR"
        pm2 start server.js --name bitfood-api --update-env 2>/dev/null \
            || pm2 restart bitfood-api 2>/dev/null
    fi

    # Landing page (:3000)
    if pm2_up bitfood-landing; then
        : # já rodando
    else
        pm2 start "$LANDING_DIR/serve.js" --name bitfood-landing --update-env 2>/dev/null \
            || pm2 restart bitfood-landing 2>/dev/null
    fi

    # Cloudflare Tunnel
    if ! pgrep -x cloudflared > /dev/null; then
        nohup cloudflared tunnel --config ~/.cloudflared/config.yml run \
            > /tmp/cloudflared.log 2>&1 &
    fi
}

# ── Logo ──────────────────────────────────────────────────────
draw_logo() {
    local r=$'\e[0;41m'   # reset + fundo vermelho
    local y=$'\e[1;33m'   # amarelo bold (raio)
    local w=$'\e[1;37m'   # branco bold (título)
    local RS=$'\e[0m'     # reset total
    local DM=$'\e[2;37m'  # branco dim (borda)
    local L="${DM}│${RS}"

    # ── Caixa vermelha com raio amarelo (20 chars de largura interna) ──
    #
    #  Forma do raio (⚡):
    #  ██████████                ← topo: 10 wide, alinha esquerda
    #   ██████████               ← desce e desloca 1 direita
    #    ██████████              ← idem
    #     █████████████████      ← "cintura": larga, conecta os dois lados
    #              ██████████    ← base: começa col 9, vai até a borda
    #               █████████   ← desloca +1
    #                ████████   ← desloca +1
    #                 ███████   ← ponta final

    echo -e "      ${DM}╭────────────────────╮${RS}"
    echo -e "      ${L}${r}                    ${RS}${L}"
    echo -e "      ${L}${r}${y}██████████${r}          ${RS}${L}"
    echo -e "      ${L}${r} ${y}██████████${r}         ${RS}${L}"
    echo -e "      ${L}${r}  ${y}██████████${r}        ${RS}${L}"
    echo -e "      ${L}${r}   ${y}█████████████████${RS}${L}"
    echo -e "      ${L}${r}          ${y}██████████${RS}${L}"
    echo -e "      ${L}${r}           ${y}█████████${RS}${L}"
    echo -e "      ${L}${r}            ${y}████████${RS}${L}"
    echo -e "      ${L}${r}             ${y}███████${RS}${L}"
    echo -e "      ${L}${r}                    ${RS}${L}"
    echo -e "      ${DM}╰────────────────────╯${RS}"
    echo ""
    echo -e "          ${w}B i t F o o d${RS}"
    echo ""
}

# ── Painel de status ──────────────────────────────────────────
draw_status() {
    local mongo_st node_st landing_st cf_st

    port_up 27017  && mongo_st="$OK" || mongo_st="$KO"
    pm2_up bitfood-api && node_st="$OK" || node_st="$KO"
    pm2_up bitfood-landing && landing_st="$OK" || landing_st="$KO"
    pgrep -x cloudflared > /dev/null && cf_st="$OK" || cf_st="$KO"

    local LIP; LIP=$(local_ip)
    local CONN; CONN=$(conns)
    local MEM; MEM=$(mem_used)
    local NMEM; NMEM=$(node_mem)
    local UP; UP=$(uptime_fmt)

    local EL='\033[K'  # apaga até o fim da linha (evita lixo ao sobrescrever)
    echo -e ""
    echo -e " ${W}${BLD}╔══════════════════════════════════════════╗${RST}${EL}"
    echo -e " ${W}${BLD}║  Serviços                                ║${RST}${EL}"
    echo -e " ${W}${BLD}╠══════════════════════════════════════════╣${RST}${EL}"
    printf  " ${W}${BLD}║${RST}  %-6s  MongoDB              %-12s${W}${BLD}║${RST}\033[K\n" "" "$mongo_st"
    printf  " ${W}${BLD}║${RST}  %-6s  Node.js API (:4000)  %-12s${W}${BLD}║${RST}\033[K\n" "" "$node_st"
    printf  " ${W}${BLD}║${RST}  %-6s  Landing page (:3000) %-12s${W}${BLD}║${RST}\033[K\n" "" "$landing_st"
    printf  " ${W}${BLD}║${RST}  %-6s  Cloudflare Tunnel    %-12s${W}${BLD}║${RST}\033[K\n" "" "$cf_st"
    echo -e " ${W}${BLD}╠══════════════════════════════════════════╣${RST}${EL}"
    echo -e " ${W}${BLD}║  Rede                                    ║${RST}${EL}"
    echo -e " ${W}${BLD}╠══════════════════════════════════════════╣${RST}${EL}"
    echo -e " ${W}${BLD}║${RST}  ${D}IP Local  ${RST}  ${C}${BLD}${LIP}${RST}${EL}"
    echo -e " ${W}${BLD}║${RST}  ${D}API       ${RST}  ${C}${BLD}https://api.bitfood.app/graphql${RST}${EL}"
    echo -e " ${W}${BLD}║${RST}  ${D}Admin     ${RST}  ${C}${BLD}https://bitfood.app${RST}${EL}"
    echo -e " ${W}${BLD}║${RST}  ${D}Conexões  ${RST}  ${Y}${BLD}${CONN} ativas${RST}${EL}"
    echo -e " ${W}${BLD}╠══════════════════════════════════════════╣${RST}${EL}"
    echo -e " ${W}${BLD}║  Sistema                                 ║${RST}${EL}"
    echo -e " ${W}${BLD}╠══════════════════════════════════════════╣${RST}${EL}"
    echo -e " ${W}${BLD}║${RST}  ${D}RAM total ${RST}  ${MEM}${EL}"
    echo -e " ${W}${BLD}║${RST}  ${D}Node RAM  ${RST}  ${NMEM}${EL}"
    echo -e " ${W}${BLD}║${RST}  ${D}Uptime    ${RST}  ${UP}${EL}"
    echo -e " ${W}${BLD}╠══════════════════════════════════════════╣${RST}${EL}"
    echo -e " ${W}${BLD}║  ${D}Atualiza a cada 5s · Ctrl+C para sair  ${W}${BLD}║${RST}${EL}"
    echo -e " ${W}${BLD}╚══════════════════════════════════════════╝${RST}${EL}"
}

# ── Loop principal ────────────────────────────────────────────
main() {
    # Entra no alternate screen buffer (como htop/vim) e esconde cursor
    printf '\033[?1049h\033[?25l'
    trap 'printf "\033[?25h\033[?1049l\n"; exit' INT TERM EXIT

    # Inicia serviços
    printf '\033[H\033[2J'
    echo -e "\n${Y}${BLD}  ⚡ Iniciando serviços BitFood...${RST}\n"
    start_services
    sleep 3

    # Dashboard sem piscar — no alternate screen, 2J não causa flicker
    while true; do
        printf '\033[2J\033[H'   # limpa + cursor home
        echo ""
        draw_logo
        draw_status
        sleep 5
    done
}

main
