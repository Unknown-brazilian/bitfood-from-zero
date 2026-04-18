'use client';
import { useQuery } from '@apollo/client';
import Sidebar from '../components/Sidebar';
import { DASHBOARD_STATS } from '@/lib/queries';

function StatCard({ label, value, sub, color }: any) {
  return (
    <div className="bg-white rounded-2xl p-5 border border-gray-100 shadow-sm">
      <p className="text-xs font-medium text-gray-500 mb-1">{label}</p>
      <p className={`text-2xl font-bold ${color || 'text-ifood-dark'}`}>{value}</p>
      {sub && <p className="text-xs text-gray-400 mt-1">{sub}</p>}
    </div>
  );
}

export default function DashboardPage() {
  const { data, loading } = useQuery(DASHBOARD_STATS, { pollInterval: 30000 });
  const s = data?.dashboardStats;
  const c = data?.configuration;

  const fmt = (sats: number) => {
    if (!sats) return '0 sats';
    if (sats >= 1e8) return `${(sats / 1e8).toFixed(4)} BTC`;
    return `${sats.toLocaleString('pt-BR')} sats`;
  };

  const fmtBRL = (sats: number) => {
    if (!sats || !c?.btcPriceBRL) return '';
    const brl = (sats / 1e8) * c.btcPriceBRL;
    return `≈ R$ ${brl.toLocaleString('pt-BR', { maximumFractionDigits: 2 })}`;
  };

  return (
    <div className="flex min-h-screen bg-ifood-bg">
      <Sidebar />
      <main className="flex-1 p-8">
        <div className="mb-6 flex items-center justify-between">
          <div>
            <h1 className="text-xl font-bold text-ifood-dark">Dashboard</h1>
            <p className="text-sm text-gray-500">Visão geral da plataforma</p>
          </div>
          {c?.btcPriceBRL && (
            <div className="bg-white border border-gray-100 rounded-xl px-4 py-2 text-sm">
              <span className="text-gray-500">BTC</span>{' '}
              <span className="font-bold text-ifood-dark">
                R$ {c.btcPriceBRL.toLocaleString('pt-BR', { maximumFractionDigits: 0 })}
              </span>
            </div>
          )}
        </div>

        {loading ? (
          <div className="grid grid-cols-2 lg:grid-cols-4 gap-4">
            {Array(8).fill(0).map((_, i) => (
              <div key={i} className="bg-white rounded-2xl p-5 h-24 animate-pulse border border-gray-100" />
            ))}
          </div>
        ) : (
          <>
            <div className="grid grid-cols-2 lg:grid-cols-4 gap-4 mb-4">
              <StatCard label="Pedidos Hoje" value={s?.todayOrders || 0} color="text-primary" />
              <StatCard label="Receita Hoje" value={fmt(s?.todayRevenueSats)} sub={fmtBRL(s?.todayRevenueSats)} color="text-ifood-green" />
              <StatCard label="Pedidos Pendentes" value={s?.pendingOrders || 0} color="text-ifood-orange" />
              <StatCard label="Total de Pedidos" value={s?.totalOrders || 0} />
            </div>
            <div className="grid grid-cols-2 lg:grid-cols-4 gap-4">
              <StatCard label="Receita Total" value={fmt(s?.totalRevenueSats)} sub={fmtBRL(s?.totalRevenueSats)} color="text-ifood-green" />
              <StatCard label="Restaurantes Ativos" value={s?.activeRestaurants || 0} />
              <StatCard label="Entregadores Ativos" value={s?.activeRiders || 0} />
              <StatCard label="BTC Preço USD" value={c?.btcPriceUSD ? `$${c.btcPriceUSD.toLocaleString('en-US', { maximumFractionDigits: 0 })}` : '-'} />
            </div>
          </>
        )}
      </main>
    </div>
  );
}
