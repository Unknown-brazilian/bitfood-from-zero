'use client';
import { useState } from 'react';
import { useQuery, useMutation } from '@apollo/client';
import Sidebar from '../components/Sidebar';
import { ZONES, CREATE_ZONE } from '@/lib/queries';

export default function ZonesPage() {
  const { data, refetch } = useQuery(ZONES);
  const [createZone] = useMutation(CREATE_ZONE);
  const [form, setForm] = useState<any>({});
  const [show, setShow] = useState(false);
  const f = (k: string) => (e: any) => setForm((p: any) => ({ ...p, [k]: e.target.value }));

  const handleCreate = async (e: React.FormEvent) => {
    e.preventDefault();
    try {
      await createZone({ variables: { ...form, deliveryFee: parseInt(form.deliveryFee), tax: parseFloat(form.tax || 0) } });
      setShow(false); setForm({}); refetch();
    } catch (err: any) { alert(err.message); }
  };

  return (
    <div className="flex min-h-screen bg-ifood-bg">
      <Sidebar />
      <main className="flex-1 p-8">
        <div className="flex items-center justify-between mb-6">
          <h1 className="text-xl font-bold text-ifood-dark">Zonas de Entrega</h1>
          <button onClick={() => setShow(true)} className="bg-primary hover:bg-primary-dark text-white text-sm font-semibold px-4 py-2.5 rounded-xl">
            + Nova Zona
          </button>
        </div>

        {show && (
          <div className="fixed inset-0 bg-black/40 flex items-center justify-center z-50 p-4">
            <div className="bg-white rounded-2xl w-full max-w-sm p-6">
              <h2 className="font-bold text-ifood-dark mb-4">Nova Zona</h2>
              <form onSubmit={handleCreate} className="space-y-3">
                {[['title','Nome da Zona',true],['description','Descrição',false]].map(([k,l,r]) => (
                  <div key={k as string}>
                    <label className="block text-xs text-gray-500 mb-1">{l as string}</label>
                    <input required={!!r} onChange={f(k as string)} className="w-full border border-gray-200 rounded-xl px-3 py-2.5 text-sm focus:outline-none focus:border-primary" />
                  </div>
                ))}
                <div className="grid grid-cols-2 gap-3">
                  <div>
                    <label className="block text-xs text-gray-500 mb-1">Taxa Entrega (sats)</label>
                    <input type="number" onChange={f('deliveryFee')} defaultValue={1000} className="w-full border border-gray-200 rounded-xl px-3 py-2.5 text-sm focus:outline-none focus:border-primary" />
                  </div>
                  <div>
                    <label className="block text-xs text-gray-500 mb-1">Imposto (%)</label>
                    <input type="number" step="0.1" onChange={f('tax')} defaultValue={0} className="w-full border border-gray-200 rounded-xl px-3 py-2.5 text-sm focus:outline-none focus:border-primary" />
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

        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
          {data?.zones?.map((z: any) => (
            <div key={z._id} className="bg-white rounded-2xl border border-gray-100 p-5">
              <h3 className="font-semibold text-ifood-dark">{z.title}</h3>
              {z.description && <p className="text-sm text-gray-500 mt-1">{z.description}</p>}
              <div className="flex items-center gap-4 mt-3 pt-3 border-t border-gray-100">
                <div>
                  <p className="text-xs text-gray-400">Taxa Entrega</p>
                  <p className="text-sm font-medium text-ifood-dark">{z.deliveryFee?.toLocaleString()} sats</p>
                </div>
                <div>
                  <p className="text-xs text-gray-400">Imposto</p>
                  <p className="text-sm font-medium text-ifood-dark">{z.tax || 0}%</p>
                </div>
              </div>
            </div>
          ))}
        </div>
      </main>
    </div>
  );
}
