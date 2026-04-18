'use client';
import { useState } from 'react';
import { useQuery, useMutation } from '@apollo/client';
import Sidebar from '../components/Sidebar';
import { RESTAURANTS, CREATE_RESTAURANT, TOGGLE_RESTAURANT, ZONES } from '@/lib/queries';

export default function RestaurantsPage() {
  const { data, loading, refetch } = useQuery(RESTAURANTS, { variables: { limit: 50 } });
  const { data: zonesData } = useQuery(ZONES);
  const [createRestaurant] = useMutation(CREATE_RESTAURANT);
  const [toggleActive] = useMutation(TOGGLE_RESTAURANT);
  const [showForm, setShowForm] = useState(false);
  const [form, setForm] = useState<any>({ lat: -23.55, lng: -46.63 });

  const handleCreate = async (e: React.FormEvent) => {
    e.preventDefault();
    try {
      await createRestaurant({ variables: form });
      setShowForm(false);
      setForm({ lat: -23.55, lng: -46.63 });
      refetch();
    } catch (err: any) {
      alert(err.message);
    }
  };

  const handleToggle = async (_id: string) => {
    await toggleActive({ variables: { _id } });
    refetch();
  };

  const f = (k: string) => (e: any) => setForm((p: any) => ({ ...p, [k]: e.target.value }));

  return (
    <div className="flex min-h-screen bg-ifood-bg">
      <Sidebar />
      <main className="flex-1 p-8">
        <div className="flex items-center justify-between mb-6">
          <div>
            <h1 className="text-xl font-bold text-ifood-dark">Restaurantes</h1>
            <p className="text-sm text-gray-500">{data?.restaurants?.length || 0} cadastrados</p>
          </div>
          <button onClick={() => setShowForm(true)} className="bg-primary hover:bg-primary-dark text-white text-sm font-semibold px-4 py-2.5 rounded-xl transition-colors">
            + Novo Restaurante
          </button>
        </div>

        {/* Modal */}
        {showForm && (
          <div className="fixed inset-0 bg-black/40 flex items-center justify-center z-50 p-4">
            <div className="bg-white rounded-2xl w-full max-w-lg p-6 max-h-[90vh] overflow-y-auto">
              <h2 className="font-bold text-ifood-dark mb-4">Novo Restaurante</h2>
              <form onSubmit={handleCreate} className="space-y-3">
                {[
                  ['name', 'Nome', 'text', true],
                  ['address', 'Endereço', 'text', true],
                  ['phone', 'Telefone', 'text', true],
                  ['email', 'E-mail', 'email', true],
                  ['username', 'Username (login)', 'text', true],
                  ['password', 'Senha', 'password', true],
                  ['shopType', 'Tipo (ex: Comida Japonesa)', 'text', false],
                ].map(([k, label, type, req]) => (
                  <div key={k as string}>
                    <label className="block text-xs text-gray-500 mb-1">{label as string}</label>
                    <input type={type as string} required={!!req} onChange={f(k as string)}
                      className="w-full border border-gray-200 rounded-xl px-3 py-2.5 text-sm focus:outline-none focus:border-primary" />
                  </div>
                ))}
                <div className="grid grid-cols-2 gap-3">
                  <div>
                    <label className="block text-xs text-gray-500 mb-1">Latitude</label>
                    <input type="number" step="any" value={form.lat} onChange={f('lat')}
                      className="w-full border border-gray-200 rounded-xl px-3 py-2.5 text-sm focus:outline-none focus:border-primary" />
                  </div>
                  <div>
                    <label className="block text-xs text-gray-500 mb-1">Longitude</label>
                    <input type="number" step="any" value={form.lng} onChange={f('lng')}
                      className="w-full border border-gray-200 rounded-xl px-3 py-2.5 text-sm focus:outline-none focus:border-primary" />
                  </div>
                </div>
                <div>
                  <label className="block text-xs text-gray-500 mb-1">Zona</label>
                  <select onChange={f('zoneId')} required
                    className="w-full border border-gray-200 rounded-xl px-3 py-2.5 text-sm focus:outline-none focus:border-primary">
                    <option value="">Selecione...</option>
                    {zonesData?.zones?.map((z: any) => <option key={z._id} value={z._id}>{z.title}</option>)}
                  </select>
                </div>
                <div className="flex gap-3 pt-2">
                  <button type="button" onClick={() => setShowForm(false)} className="flex-1 border border-gray-200 text-gray-600 py-2.5 rounded-xl text-sm hover:bg-gray-50">Cancelar</button>
                  <button type="submit" className="flex-1 bg-primary text-white py-2.5 rounded-xl text-sm font-semibold hover:bg-primary-dark">Criar</button>
                </div>
              </form>
            </div>
          </div>
        )}

        {/* Table */}
        <div className="bg-white rounded-2xl border border-gray-100 overflow-hidden">
          <table className="w-full text-sm">
            <thead>
              <tr className="border-b border-gray-100">
                {['Restaurante', 'Zona', 'Tipo', 'Avaliação', 'Status', 'Ações'].map(h => (
                  <th key={h} className="text-left px-4 py-3 text-xs font-semibold text-gray-500">{h}</th>
                ))}
              </tr>
            </thead>
            <tbody>
              {loading ? (
                <tr><td colSpan={6} className="text-center py-8 text-gray-400">Carregando...</td></tr>
              ) : data?.restaurants?.map((r: any) => (
                <tr key={r._id} className="border-b border-gray-50 hover:bg-gray-50/50">
                  <td className="px-4 py-3">
                    <p className="font-medium text-ifood-dark">{r.name}</p>
                    <p className="text-xs text-gray-400">{r.email}</p>
                  </td>
                  <td className="px-4 py-3 text-gray-600">{r.zone?.title || '-'}</td>
                  <td className="px-4 py-3 text-gray-600">{r.shopType || '-'}</td>
                  <td className="px-4 py-3">
                    <span className="text-yellow-500">★</span> {r.reviewData?.rating?.toFixed(1) || '0.0'}
                    <span className="text-gray-400 text-xs ml-1">({r.reviewData?.reviews || 0})</span>
                  </td>
                  <td className="px-4 py-3">
                    <span className={`px-2 py-1 rounded-full text-xs font-medium ${r.isActive ? 'bg-green-100 text-ifood-green' : 'bg-red-50 text-primary'}`}>
                      {r.isActive ? 'Ativo' : 'Inativo'}
                    </span>
                  </td>
                  <td className="px-4 py-3">
                    <button onClick={() => handleToggle(r._id)} className="text-xs text-gray-500 hover:text-primary underline">
                      {r.isActive ? 'Desativar' : 'Ativar'}
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
