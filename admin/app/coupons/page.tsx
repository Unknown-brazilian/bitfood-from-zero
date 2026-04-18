'use client';
import { useState } from 'react';
import { useQuery, useMutation } from '@apollo/client';
import Sidebar from '../components/Sidebar';
import { COUPONS, CREATE_COUPON, UPDATE_COUPON } from '@/lib/queries';

export default function CouponsPage() {
  const { data, refetch } = useQuery(COUPONS);
  const [createCoupon] = useMutation(CREATE_COUPON);
  const [updateCoupon] = useMutation(UPDATE_COUPON);
  const [show, setShow] = useState(false);
  const [form, setForm] = useState<any>({});
  const f = (k: string) => (e: any) => setForm((p: any) => ({ ...p, [k]: e.target.value }));

  const handleCreate = async (e: React.FormEvent) => {
    e.preventDefault();
    try {
      await createCoupon({ variables: { ...form, discount: parseFloat(form.discount), maxDiscount: form.maxDiscount ? parseInt(form.maxDiscount) : undefined, minOrderAmount: form.minOrderAmount ? parseInt(form.minOrderAmount) : undefined } });
      setShow(false); setForm({}); refetch();
    } catch (err: any) { alert(err.message); }
  };

  return (
    <div className="flex min-h-screen bg-ifood-bg">
      <Sidebar />
      <main className="flex-1 p-8">
        <div className="flex items-center justify-between mb-6">
          <h1 className="text-xl font-bold text-ifood-dark">Cupons</h1>
          <button onClick={() => setShow(true)} className="bg-primary hover:bg-primary-dark text-white text-sm font-semibold px-4 py-2.5 rounded-xl">
            + Novo Cupom
          </button>
        </div>

        {show && (
          <div className="fixed inset-0 bg-black/40 flex items-center justify-center z-50 p-4">
            <div className="bg-white rounded-2xl w-full max-w-sm p-6">
              <h2 className="font-bold text-ifood-dark mb-4">Novo Cupom</h2>
              <form onSubmit={handleCreate} className="space-y-3">
                {[['code','Código (ex: BITCOIN10)'],['title','Título']].map(([k,l]) => (
                  <div key={k}>
                    <label className="block text-xs text-gray-500 mb-1">{l}</label>
                    <input required={k==='code'} onChange={f(k)} className="w-full border border-gray-200 rounded-xl px-3 py-2.5 text-sm focus:outline-none focus:border-primary" />
                  </div>
                ))}
                <div className="grid grid-cols-2 gap-3">
                  <div>
                    <label className="block text-xs text-gray-500 mb-1">Desconto (%)</label>
                    <input type="number" step="0.1" required onChange={f('discount')} className="w-full border border-gray-200 rounded-xl px-3 py-2.5 text-sm focus:outline-none focus:border-primary" />
                  </div>
                  <div>
                    <label className="block text-xs text-gray-500 mb-1">Máx. Desc. (sats)</label>
                    <input type="number" onChange={f('maxDiscount')} className="w-full border border-gray-200 rounded-xl px-3 py-2.5 text-sm focus:outline-none focus:border-primary" />
                  </div>
                  <div>
                    <label className="block text-xs text-gray-500 mb-1">Pedido Mín. (sats)</label>
                    <input type="number" onChange={f('minOrderAmount')} className="w-full border border-gray-200 rounded-xl px-3 py-2.5 text-sm focus:outline-none focus:border-primary" />
                  </div>
                  <div>
                    <label className="block text-xs text-gray-500 mb-1">Limite de Uso</label>
                    <input type="number" onChange={f('usageLimit')} placeholder="0 = ilimitado" className="w-full border border-gray-200 rounded-xl px-3 py-2.5 text-sm focus:outline-none focus:border-primary" />
                  </div>
                </div>
                <div className="flex gap-3 pt-1">
                  <button type="button" onClick={() => setShow(false)} className="flex-1 border border-gray-200 text-gray-600 py-2.5 rounded-xl text-sm">Cancelar</button>
                  <button type="submit" className="flex-1 bg-primary text-white py-2.5 rounded-xl text-sm font-semibold">Criar</button>
                </div>
              </form>
            </div>
          </div>
        )}

        <div className="bg-white rounded-2xl border border-gray-100 overflow-hidden">
          <table className="w-full text-sm">
            <thead>
              <tr className="border-b border-gray-100">
                {['Código', 'Título', 'Desconto', 'Mín. Pedido', 'Usos', 'Status', 'Ações'].map(h => (
                  <th key={h} className="text-left px-4 py-3 text-xs font-semibold text-gray-500">{h}</th>
                ))}
              </tr>
            </thead>
            <tbody>
              {data?.coupons?.map((c: any) => (
                <tr key={c._id} className="border-b border-gray-50 hover:bg-gray-50/50">
                  <td className="px-4 py-3 font-mono font-bold text-ifood-dark">{c.code}</td>
                  <td className="px-4 py-3 text-gray-600">{c.title || '-'}</td>
                  <td className="px-4 py-3 text-ifood-green font-medium">{c.discount}%</td>
                  <td className="px-4 py-3 text-gray-600">{c.minOrderAmount ? `${c.minOrderAmount.toLocaleString()} sats` : '-'}</td>
                  <td className="px-4 py-3 text-gray-500">{c.usedCount}/{c.usageLimit || '∞'}</td>
                  <td className="px-4 py-3">
                    <span className={`px-2 py-1 rounded-full text-xs font-medium ${c.enabled ? 'bg-green-100 text-ifood-green' : 'bg-gray-100 text-gray-500'}`}>
                      {c.enabled ? 'Ativo' : 'Inativo'}
                    </span>
                  </td>
                  <td className="px-4 py-3">
                    <button onClick={async () => { await updateCoupon({ variables: { _id: c._id, enabled: !c.enabled } }); refetch(); }}
                      className="text-xs text-gray-500 hover:text-primary underline">
                      {c.enabled ? 'Desativar' : 'Ativar'}
                    </button>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </main>
    </div>
  );
}
