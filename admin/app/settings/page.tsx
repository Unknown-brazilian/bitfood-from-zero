'use client';
import { useState, useEffect } from 'react';
import { useQuery, useMutation } from '@apollo/client';
import Sidebar from '../components/Sidebar';
import { CONFIGURATION, UPDATE_CONFIGURATION } from '@/lib/queries';

function Section({ title, children }: { title: string; children: React.ReactNode }) {
  return (
    <div className="bg-white rounded-2xl border border-gray-100 p-6">
      <h2 className="font-semibold text-ifood-dark mb-4 flex items-center gap-2">{title}</h2>
      <div className="space-y-4">{children}</div>
    </div>
  );
}

function Field({ label, children }: { label: string; children: React.ReactNode }) {
  return (
    <div>
      <label className="block text-xs font-medium text-gray-500 mb-1.5">{label}</label>
      {children}
    </div>
  );
}

const inputCls = "w-full border border-gray-200 rounded-xl px-3 py-2.5 text-sm focus:outline-none focus:ring-2 focus:ring-primary/20 focus:border-primary";

export default function SettingsPage() {
  const { data, loading } = useQuery(CONFIGURATION);
  const [updateConfig, { loading: saving }] = useMutation(UPDATE_CONFIGURATION);
  const [form, setForm] = useState<any>({});
  const [saved, setSaved] = useState(false);

  useEffect(() => {
    if (data?.configuration) {
      const c = data.configuration;
      setForm({
        currency: c.currency || 'BRL',
        currencySymbol: c.currencySymbol || 'R$',
        deliveryFee: c.deliveryFee || 1000,
        commissionRate: c.commissionRate || 10,
        riderCommission: c.riderCommission || 80,
        enableTipping: c.enableTipping ?? true,
        btcpayUrl: c.btcpayUrl || '',
        btcpayStoreId: c.btcpayStoreId || '',
        btcpayApiKey: '',
        btcpayWebhookSecret: '',
        supportEmail: c.supportEmail || '',
        supportPhone: c.supportPhone || '',
      });
    }
  }, [data]);

  const set = (k: string) => (e: any) =>
    setForm((f: any) => ({ ...f, [k]: e.target.type === 'checkbox' ? e.target.checked : e.target.value }));

  const handleSave = async (e: React.FormEvent) => {
    e.preventDefault();
    const vars = { ...form, deliveryFee: parseInt(form.deliveryFee), commissionRate: parseFloat(form.commissionRate), riderCommission: parseFloat(form.riderCommission) };
    if (!vars.btcpayApiKey) delete vars.btcpayApiKey;
    if (!vars.btcpayWebhookSecret) delete vars.btcpayWebhookSecret;
    await updateConfig({ variables: vars });
    setSaved(true);
    setTimeout(() => setSaved(false), 3000);
  };

  if (loading) return (
    <div className="flex min-h-screen bg-ifood-bg"><Sidebar /><main className="flex-1 p-8"><p className="text-gray-400">Carregando...</p></main></div>
  );

  return (
    <div className="flex min-h-screen bg-ifood-bg">
      <Sidebar />
      <main className="flex-1 p-8">
        <div className="max-w-2xl">
          <h1 className="text-xl font-bold text-ifood-dark mb-6">Configurações</h1>

          <form onSubmit={handleSave} className="space-y-4">
            <Section title="⚡ BTCPay Server">
              <Field label="URL do BTCPay Server">
                <input value={form.btcpayUrl || ''} onChange={set('btcpayUrl')} className={inputCls} placeholder="https://seu-btcpay.com" />
              </Field>
              <Field label="Store ID">
                <input value={form.btcpayStoreId || ''} onChange={set('btcpayStoreId')} className={inputCls} placeholder="Seu Store ID" />
              </Field>
              <Field label="API Key (deixe em branco para não alterar)">
                <input type="password" value={form.btcpayApiKey || ''} onChange={set('btcpayApiKey')} className={inputCls} placeholder="••••••••" />
              </Field>
              <Field label="Webhook Secret (deixe em branco para não alterar)">
                <input type="password" value={form.btcpayWebhookSecret || ''} onChange={set('btcpayWebhookSecret')} className={inputCls} placeholder="••••••••" />
              </Field>
            </Section>

            <Section title="💱 Moeda de Exibição">
              <div className="grid grid-cols-2 gap-4">
                <Field label="Código (ex: BRL, USD)">
                  <input value={form.currency || ''} onChange={set('currency')} className={inputCls} />
                </Field>
                <Field label="Símbolo (ex: R$, $)">
                  <input value={form.currencySymbol || ''} onChange={set('currencySymbol')} className={inputCls} />
                </Field>
              </div>
            </Section>

            <Section title="💸 Taxas (Satoshis)">
              <Field label="Taxa de Entrega Base">
                <input type="number" value={form.deliveryFee || ''} onChange={set('deliveryFee')} className={inputCls} />
              </Field>
              <Field label="Comissão da Plataforma (%)">
                <input type="number" step="0.1" value={form.commissionRate || ''} onChange={set('commissionRate')} className={inputCls} />
              </Field>
              <Field label="% da Taxa de Entrega para o Entregador">
                <input type="number" step="0.1" value={form.riderCommission || ''} onChange={set('riderCommission')} className={inputCls} />
              </Field>
              <div className="flex items-center gap-3">
                <input type="checkbox" id="tip" checked={form.enableTipping || false} onChange={set('enableTipping')} className="w-4 h-4 accent-primary" />
                <label htmlFor="tip" className="text-sm text-ifood-dark">Habilitar gorjeta</label>
              </div>
            </Section>

            <Section title="📞 Suporte">
              <Field label="E-mail de Suporte">
                <input value={form.supportEmail || ''} onChange={set('supportEmail')} className={inputCls} placeholder="suporte@bitfood.app" />
              </Field>
              <Field label="Telefone de Suporte">
                <input value={form.supportPhone || ''} onChange={set('supportPhone')} className={inputCls} />
              </Field>
            </Section>

            <button type="submit" disabled={saving}
              className="w-full bg-primary hover:bg-primary-dark disabled:opacity-60 text-white font-semibold py-3 rounded-xl transition-colors text-sm">
              {saving ? 'Salvando...' : saved ? '✅ Configurações salvas!' : 'Salvar Configurações'}
            </button>
          </form>
        </div>
      </main>
    </div>
  );
}
