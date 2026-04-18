/**
 * BTCPay Server — Greenfield API v1
 * Gratuito e open-source. Sem taxa de entrada, apenas taxas da rede Bitcoin/Lightning.
 * Docs: https://docs.btcpayserver.org/API/Greenfield/v1/
 */
const axios = require('axios');
const crypto = require('crypto');

const getApi = () => axios.create({
  baseURL: `${(process.env.BTCPAY_URL || '').replace(/\/$/, '')}/api/v1`,
  headers: {
    'Authorization': `token ${process.env.BTCPAY_API_KEY}`,
    'Content-Type': 'application/json',
  },
  timeout: 15000,
});

const STORE_ID = () => process.env.BTCPAY_STORE_ID;

/**
 * Cria um invoice no BTCPay Server
 * Retorna checkoutUrl (página BTCPay) + lightning invoice BOLT11 quando disponível
 */
exports.createInvoice = async ({ amountSats, orderId, buyerName, buyerEmail, description }) => {
  const api = getApi();
  const btcAmount = (amountSats / 1e8).toFixed(8);

  const body = {
    amount: btcAmount,
    currency: 'BTC',
    metadata: {
      orderId,
      buyerName: buyerName || '',
      buyerEmail: buyerEmail || '',
      itemDesc: description || `BitFood Pedido #${orderId}`,
    },
    checkout: {
      speedPolicy: 'HighSpeed',
      expirationMinutes: 10,
      monitoringMinutes: 20,
      paymentMethods: ['BTC-LightningNetwork', 'BTC'],
      defaultPaymentMethod: 'BTC-LightningNetwork',
      redirectAutomatically: false,
    },
    additionalSearchTerms: [orderId],
  };

  const { data: inv } = await api.post(`/stores/${STORE_ID()}/invoices`, body);

  let lightningInvoice = null;
  let paymentHash = null;

  try {
    const { data: methods } = await api.get(
      `/stores/${STORE_ID()}/invoices/${inv.id}/payment-methods`
    );
    const ln = methods.find(m =>
      (m.paymentMethodId || m.paymentMethod || '').includes('LightningNetwork')
    );
    if (ln) {
      lightningInvoice = ln.destination || ln.paymentLink;
      paymentHash = ln.paymentHash || null;
    }
  } catch (e) {
    console.warn('BTCPay: payment-methods ainda não disponíveis:', e.message);
  }

  return {
    invoiceId: inv.id,
    checkoutUrl: inv.checkoutLink,
    lightningInvoice,
    paymentHash,
    expiresAt: inv.expirationTime,
    status: inv.status,
  };
};

/**
 * Consulta status de um invoice
 * Status: New | Processing | Expired | Invalid | Settled
 */
exports.getInvoice = async (invoiceId) => {
  const { data } = await getApi().get(`/stores/${STORE_ID()}/invoices/${invoiceId}`);
  return {
    invoiceId: data.id,
    status: data.status,
    paid: data.status === 'Settled',
    amount: data.amount,
    metadata: data.metadata,
  };
};

/**
 * Verifica assinatura HMAC-SHA256 do webhook BTCPay
 * Header: BTCPay-Sig: sha256=<hex>
 */
exports.verifyWebhook = (rawBody, signature, secret) => {
  if (!secret) return true;
  const expected = 'sha256=' + crypto
    .createHmac('sha256', secret)
    .update(rawBody)
    .digest('hex');
  try {
    return crypto.timingSafeEqual(
      Buffer.from(expected, 'utf8'),
      Buffer.from(signature || '', 'utf8')
    );
  } catch {
    return false;
  }
};
