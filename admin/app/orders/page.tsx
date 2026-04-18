'use client';
import { useState } from 'react';
import { useQuery } from '@apollo/client';
import Sidebar from '../components/Sidebar';
import { ALL_ORDERS } from '@/lib/queries';

const STATUS_COLORS: Record<string, string> = {
  PENDING: 'bg-yellow-50 text-yellow-700',
  PAID: 'bg-blue-50 text-blue-700',
  ACCEPTED: 'bg-blue-100 text-blue-800',
  PREPARING: 'bg-orange-50 text-ifood-orange',
  READY: 'bg-purple-50 text-purple-700',
  ASSIGNED: 'bg-indigo-50 text-indigo-700',
  PICKED: 'bg-indigo-100 text-indigo-800',
  DELIVERING: 'bg-cyan-50 text-cyan-700',
  DELIVERED: 'bg-green-50 text-ifood-green',
  CANCELLED: 'bg-gray-100 text-gray-500',
  REJECTED: 'bg-red-50 text-primary',
};

export default function OrdersPage() {
  const [status, setStatus] = useState('');
  const [page, setPage] = useState(1);
  const { data, loading } = useQuery(ALL_ORDERS, {
    variables: { status: status || undefined, page, limit: 25 },
    pollInterval: 15000,
  });

  const orders = data?.allOrders?.orders || [];
  const pages = data?.allOrders?.pages || 1;

  return (
    <div className="flex min-h-screen bg-ifood-bg">
      <Sidebar />
      <main className="flex-1 p-8">
        <div className="flex items-center justify-between mb-6">
          <div>
            <h1 className="text-xl font-bold text-ifood-dark">Pedidos</h1>
            <p className="text-sm text-gray-500">{data?.allOrders?.total || 0} no total</p>
          </div>
          <select value={status} onChange={e => { setStatus(e.target.value); setPage(1); }}
            className="border border-gray-200 rounded-xl px-3 py-2 text-sm focus:outline-none focus:border-primary bg-white">
            <option value="">Todos os status</option>
            {Object.keys(STATUS_COLORS).map(s => <option key={s} value={s}>{s}</option>)}
          </select>
        </div>

        <div className="bg-white rounded-2xl border border-gray-100 overflow-hidden">
          <table className="w-full text-sm">
            <thead>
              <tr className="border-b border-gray-100">
                {['Pedido', 'Cliente', 'Restaurante', 'Entregador', 'Total', 'Status', 'Data'].map(h => (
                  <th key={h} className="text-left px-4 py-3 text-xs font-semibold text-gray-500">{h}</th>
                ))}
              </tr>
            </thead>
            <tbody>
              {loading ? (
                <tr><td colSpan={7} className="text-center py-8 text-gray-400">Carregando...</td></tr>
              ) : orders.map((o: any) => (
                <tr key={o._id} className="border-b border-gray-50 hover:bg-gray-50/50">
                  <td className="px-4 py-3 font-mono text-xs text-gray-600">{o.orderId}</td>
                  <td className="px-4 py-3">
                    <p className="font-medium text-ifood-dark">{o.user?.name}</p>
                    <p className="text-xs text-gray-400">{o.user?.phone}</p>
                  </td>
                  <td className="px-4 py-3 text-gray-600">{o.restaurant?.name}</td>
                  <td className="px-4 py-3 text-gray-600">{o.rider?.name || '—'}</td>
                  <td className="px-4 py-3 font-medium text-ifood-dark">{o.total?.toLocaleString()} sats</td>
                  <td className="px-4 py-3">
                    <span className={`px-2 py-1 rounded-full text-xs font-medium ${STATUS_COLORS[o.orderStatus] || ''}`}>
                      {o.orderStatus}
                    </span>
                  </td>
                  <td className="px-4 py-3 text-xs text-gray-400">
                    {new Date(parseInt(o.createdAt)).toLocaleString('pt-BR', { dateStyle: 'short', timeStyle: 'short' })}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>

        {/* Pagination */}
        {pages > 1 && (
          <div className="flex items-center justify-center gap-2 mt-4">
            <button disabled={page === 1} onClick={() => setPage(p => p - 1)} className="px-3 py-1.5 text-sm border border-gray-200 rounded-lg disabled:opacity-40 hover:bg-gray-50">←</button>
            <span className="text-sm text-gray-600">{page} / {pages}</span>
            <button disabled={page === pages} onClick={() => setPage(p => p + 1)} className="px-3 py-1.5 text-sm border border-gray-200 rounded-lg disabled:opacity-40 hover:bg-gray-50">→</button>
          </div>
        )}
      </main>
    </div>
  );
}
