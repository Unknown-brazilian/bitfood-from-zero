'use client';
import { useState } from 'react';
import { useQuery, useMutation } from '@apollo/client';
import Sidebar from '../components/Sidebar';
import { USERS, CREATE_RIDER, TOGGLE_USER, ZONES } from '@/lib/queries';

export default function UsersPage() {
  const [userType, setUserType] = useState('CUSTOMER');
  const [showForm, setShowForm] = useState(false);
  const [form, setForm] = useState<any>({});
  const { data, loading, refetch } = useQuery(USERS, { variables: { userType, page: 1 } });
  const { data: zonesData } = useQuery(ZONES);
  const [createRider] = useMutation(CREATE_RIDER);
  const [toggleUser] = useMutation(TOGGLE_USER);

  const f = (k: string) => (e: any) => setForm((p: any) => ({ ...p, [k]: e.target.value }));

  const handleCreateRider = async (e: React.FormEvent) => {
    e.preventDefault();
    try {
      await createRider({ variables: form });
      setShowForm(false);
      setForm({});
      refetch();
    } catch (err: any) { alert(err.message); }
  };

  return (
    <div className="flex min-h-screen bg-ifood-bg">
      <Sidebar />
      <main className="flex-1 p-8">
        <div className="flex items-center justify-between mb-6">
          <div>
            <h1 className="text-xl font-bold text-ifood-dark">Usuários</h1>
            <p className="text-sm text-gray-500">{data?.users?.length || 0} encontrados</p>
          </div>
          <div className="flex gap-3">
            <select value={userType} onChange={e => setUserType(e.target.value)}
              className="border border-gray-200 rounded-xl px-3 py-2 text-sm focus:outline-none focus:border-primary bg-white">
              <option value="CUSTOMER">Clientes</option>
              <option value="RIDER">Entregadores</option>
              <option value="RESTAURANT">Restaurantes</option>
            </select>
            {userType === 'RIDER' && (
              <button onClick={() => setShowForm(true)} className="bg-primary hover:bg-primary-dark text-white text-sm font-semibold px-4 py-2 rounded-xl transition-colors">
                + Entregador
              </button>
            )}
          </div>
        </div>

        {showForm && (
          <div className="fixed inset-0 bg-black/40 flex items-center justify-center z-50 p-4">
            <div className="bg-white rounded-2xl w-full max-w-sm p-6">
              <h2 className="font-bold text-ifood-dark mb-4">Novo Entregador</h2>
              <form onSubmit={handleCreateRider} className="space-y-3">
                {[['name','Nome',true],['phone','Telefone',true],['password','Senha',true]].map(([k,l,r]) => (
                  <div key={k as string}>
                    <label className="block text-xs text-gray-500 mb-1">{l as string}</label>
                    <input type={k === 'password' ? 'password' : 'text'} required={!!r} onChange={f(k as string)}
                      className="w-full border border-gray-200 rounded-xl px-3 py-2.5 text-sm focus:outline-none focus:border-primary" />
                  </div>
                ))}
                <div>
                  <label className="block text-xs text-gray-500 mb-1">Zona</label>
                  <select onChange={f('zoneId')} required className="w-full border border-gray-200 rounded-xl px-3 py-2.5 text-sm focus:outline-none focus:border-primary">
                    <option value="">Selecione...</option>
                    {zonesData?.zones?.map((z: any) => <option key={z._id} value={z._id}>{z.title}</option>)}
                  </select>
                </div>
                <div>
                  <label className="block text-xs text-gray-500 mb-1">Veículo</label>
                  <select onChange={f('vehicleType')} className="w-full border border-gray-200 rounded-xl px-3 py-2.5 text-sm focus:outline-none focus:border-primary">
                    <option value="">Selecione...</option>
                    <option>Moto</option><option>Bicicleta</option><option>Carro</option>
                  </select>
                </div>
                <div className="flex gap-3 pt-1">
                  <button type="button" onClick={() => setShowForm(false)} className="flex-1 border border-gray-200 text-gray-600 py-2.5 rounded-xl text-sm">Cancelar</button>
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
                {['Nome', 'Contato', 'Tipo', 'Status', 'Ações'].map(h => (
                  <th key={h} className="text-left px-4 py-3 text-xs font-semibold text-gray-500">{h}</th>
                ))}
              </tr>
            </thead>
            <tbody>
              {loading ? (
                <tr><td colSpan={5} className="text-center py-8 text-gray-400">Carregando...</td></tr>
              ) : data?.users?.map((u: any) => (
                <tr key={u._id} className="border-b border-gray-50 hover:bg-gray-50/50">
                  <td className="px-4 py-3 font-medium text-ifood-dark">{u.name}</td>
                  <td className="px-4 py-3 text-gray-500">
                    <p>{u.email || u.phone}</p>
                  </td>
                  <td className="px-4 py-3">
                    <span className="px-2 py-1 bg-gray-100 rounded-full text-xs text-gray-600">{u.userType}</span>
                  </td>
                  <td className="px-4 py-3">
                    <span className={`px-2 py-1 rounded-full text-xs font-medium ${u.isActive ? 'bg-green-100 text-ifood-green' : 'bg-red-50 text-primary'}`}>
                      {u.isActive ? 'Ativo' : 'Inativo'}
                    </span>
                  </td>
                  <td className="px-4 py-3">
                    <button onClick={async () => { await toggleUser({ variables: { _id: u._id } }); refetch(); }}
                      className="text-xs text-gray-500 hover:text-primary underline">
                      {u.isActive ? 'Desativar' : 'Ativar'}
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
