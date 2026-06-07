// BitFood — painel de status (sem dependências).
// Sonda todos os serviços + progresso do sync do bitcoind e estado do LND.
import http from 'http';
import https from 'https';
import fs from 'fs';

const PORT = process.env.STATUS_PORT || 8090;
const ENV_PATH = new URL('../btcpay/.env', import.meta.url);

function rpcCreds() {
  try {
    const env = fs.readFileSync(ENV_PATH, 'utf8');
    return {
      u: env.match(/BTC_RPC_USER=(.*)/)?.[1]?.trim(),
      p: env.match(/BTC_RPC_PASS=(.*)/)?.[1]?.trim(),
    };
  } catch { return {}; }
}

function probe(url, timeoutMs = 6000) {
  return new Promise((resolve) => {
    const lib = url.startsWith('https') ? https : http;
    const req = lib.get(url, { rejectUnauthorized: false, timeout: timeoutMs }, (res) => {
      let d = '';
      res.on('data', (c) => (d += c));
      res.on('end', () => resolve({ ok: res.statusCode < 500, status: res.statusCode, body: d }));
    });
    req.on('error', () => resolve({ ok: false, status: 0 }));
    req.on('timeout', () => { req.destroy(); resolve({ ok: false, status: 0 }); });
  });
}

function rpc(method) {
  const { u, p } = rpcCreds();
  if (!u) return Promise.resolve(null);
  return new Promise((resolve) => {
    const data = JSON.stringify({ jsonrpc: '1.0', id: 'mon', method, params: [] });
    const req = http.request(
      { host: '127.0.0.1', port: 8332, method: 'POST', auth: `${u}:${p}`,
        headers: { 'Content-Type': 'text/plain', 'Content-Length': Buffer.byteLength(data) }, timeout: 6000 },
      (res) => { let d = ''; res.on('data', (c) => (d += c)); res.on('end', () => { try { resolve(JSON.parse(d).result); } catch { resolve(null); } }); }
    );
    req.on('error', () => resolve(null));
    req.on('timeout', () => { req.destroy(); resolve(null); });
    req.write(data); req.end();
  });
}

async function collect() {
  const [health, landing, admin, btcpayUi, pub] = await Promise.all([
    probe('http://localhost:4000/health'),
    probe('http://localhost:3000/'),
    probe('http://localhost:3001/login'),
    probe('http://localhost:8080/'),
    probe('https://bitfood.app/'),
  ]);
  const chain = await rpc('getblockchaininfo');
  const lnd = await probe('https://127.0.0.1:8081/v1/state', 4000);

  let healthJson = {};
  try { healthJson = JSON.parse(health.body || '{}'); } catch {}
  let lndState = null;
  try { lndState = JSON.parse(lnd.body || '{}').state; } catch {}

  const services = [
    { key: 'backend', name: 'Backend API (:4000)', up: health.ok && healthJson.api === 'ok', detail: health.ok ? `api=${healthJson.api} · mongo=${healthJson.mongodb}` : 'sem resposta' },
    { key: 'mongo', name: 'MongoDB', up: healthJson.mongodb === 'ok', detail: healthJson.mongodb || '—' },
    { key: 'landing', name: 'Landing (:3000)', up: landing.ok, detail: landing.ok ? `HTTP ${landing.status}` : 'down' },
    { key: 'admin', name: 'Admin (:3001)', up: admin.ok, detail: admin.ok ? `HTTP ${admin.status}` : 'down' },
    { key: 'public', name: 'bitfood.app (público)', up: pub.ok, detail: pub.ok ? `HTTP ${pub.status}` : 'túnel/down' },
    { key: 'btcpay', name: 'BTCPay UI (:8080)', up: btcpayUi.ok, detail: btcpayUi.ok ? `HTTP ${btcpayUi.status}` : 'iniciando' },
  ];

  // bitcoind
  let bitcoind = { up: false };
  if (chain) {
    const prog = chain.verificationprogress || 0;
    bitcoind = {
      up: true,
      ibd: chain.initialblockdownload,
      progress: prog,
      blocks: chain.blocks,
      headers: chain.headers,
      sizeGb: chain.size_on_disk ? (chain.size_on_disk / 1e9).toFixed(2) : null,
      pruned: chain.pruned,
      synced: !chain.initialblockdownload && prog > 0.9999,
    };
  }

  // LND state legível
  const lndLabels = {
    NON_EXISTING: 'wallet não criada',
    LOCKED: 'wallet bloqueada (precisa unlock)',
    UNLOCKED: 'desbloqueada, iniciando…',
    RPC_ACTIVE: 'aguardando criação da wallet',
    SERVER_ACTIVE: 'ativo',
    WAITING_TO_START: 'aguardando bitcoind',
  };
  const lndInfo = { up: lnd.ok, state: lndState, label: lndLabels[lndState] || lndState || 'sem resposta' };

  // Checklist do que falta
  const pending = [];
  if (!bitcoind.up) pending.push('bitcoind ainda iniciando');
  else if (!bitcoind.synced) pending.push(`bitcoind sincronizando (${(bitcoind.progress * 100).toFixed(2)}%)`);
  if (lndInfo.state && lndInfo.state !== 'SERVER_ACTIVE') pending.push(`LND: ${lndInfo.label}`);
  if (healthJson.btcpay !== 'ok') pending.push('backend ainda não aponta pro BTCPay (BTCPAY_* no .env)');

  return { ts: new Date().toISOString(), services, bitcoind, lnd: lndInfo, pending, ready: pending.length === 0 };
}

const PAGE = fs.readFileSync(new URL('./index.html', import.meta.url), 'utf8');

http.createServer(async (req, res) => {
  if (req.url.startsWith('/api/status')) {
    const data = await collect();
    res.writeHead(200, { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' });
    return res.end(JSON.stringify(data));
  }
  res.writeHead(200, { 'Content-Type': 'text/html; charset=utf-8' });
  res.end(PAGE);
}).listen(PORT, () => console.log(`[status] http://localhost:${PORT}`));
