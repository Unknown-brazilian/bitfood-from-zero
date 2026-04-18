const mongoose = require('mongoose');

const configSchema = new mongoose.Schema({
  singleton: { type: Boolean, default: true, unique: true },
  appName: { type: String, default: 'BitFood' },
  currency: { type: String, default: 'BRL' },
  currencySymbol: { type: String, default: 'R$' },
  deliveryFee: { type: Number, default: 1000 },
  minDeliveryFee: { type: Number, default: 500 },
  maxDeliveryFee: { type: Number, default: 10000 },
  commissionRate: { type: Number, default: 10 },
  riderCommission: { type: Number, default: 80 },
  enableTipping: { type: Boolean, default: true },
  // BTCPay Server
  btcpayUrl: { type: String, default: '' },
  btcpayStoreId: String,
  btcpayApiKey: String,
  btcpayWebhookSecret: String,
  // Contact
  supportEmail: String,
  supportPhone: String,
  // App version gating
  customerAppVersion: { type: String, default: '1.0.0' },
  riderAppVersion: { type: String, default: '1.0.0' },
  restaurantAppVersion: { type: String, default: '1.0.0' },
}, { timestamps: true });

module.exports = mongoose.model('Configuration', configSchema);
