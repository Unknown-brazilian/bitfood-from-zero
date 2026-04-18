require('dotenv').config();

const express = require('express');
const cors = require('cors');
const http = require('http');
const mongoose = require('mongoose');
const { ApolloServer } = require('apollo-server-express');
const { makeExecutableSchema } = require('@graphql-tools/schema');
const { WebSocketServer } = require('ws');
const { useServer } = require('graphql-ws/lib/use/ws');

const { typeDefs, resolvers } = require('./src/graphql');
const { getUser, verifyToken } = require('./src/utils/auth');
const { pubsub, EVENTS } = require('./src/utils/pubsub');
const Order = require('./src/models/Order');
const btcpay = require('./src/services/btcpay');

const PORT = process.env.PORT || 4000;
const MONGO_URI = process.env.MONGO_URI || 'mongodb://localhost:27017/bitfood';

async function start() {
  await mongoose.connect(MONGO_URI);
  console.log('✅ MongoDB conectado');

  const app = express();
  app.use(cors());
  app.use(express.json());

  app.get('/health', (_, res) =>
    res.json({ status: 'ok', timestamp: new Date().toISOString() })
  );

  // ── BTCPay Server Webhook ───────────────────────────────────────────
  app.post('/webhook/btcpay',
    express.raw({ type: 'application/json' }),
    async (req, res) => {
      try {
        const rawBody = req.body;
        const signature = req.headers['btcpay-sig'] || '';
        const secret = process.env.BTCPAY_WEBHOOK_SECRET || '';

        if (!btcpay.verifyWebhook(rawBody, signature, secret)) {
          console.warn('BTCPay: assinatura inválida');
          return res.status(401).json({ error: 'Invalid signature' });
        }

        const event = JSON.parse(rawBody.toString('utf8'));
        const { type, invoiceId, metadata } = event;

        if (type !== 'InvoiceSettled' && type !== 'InvoicePaymentSettled') {
          return res.json({ ok: true, ignored: true });
        }

        const order = await Order.findOne({ btcpayInvoiceId: invoiceId })
          || (metadata?.orderId ? await Order.findOne({ orderId: metadata.orderId }) : null);

        if (!order) return res.status(404).json({ error: 'Order not found' });
        if (order.paymentStatus === 'PAID') return res.json({ ok: true });

        order.paymentStatus = 'PAID';
        order.orderStatus = 'PAID';
        order.paidAt = new Date();
        order.statusHistory.push({ status: 'PAID', note: 'Pagamento confirmado via BTCPay webhook' });
        await order.save();

        pubsub.publish(EVENTS.PAYMENT_CONFIRMED, { paymentConfirmed: order, orderId: order._id.toString() });
        pubsub.publish(EVENTS.ORDER_STATUS_CHANGED, { orderStatusChanged: order, orderId: order._id.toString() });
        pubsub.publish(EVENTS.NEW_ORDER, { newOrderForRestaurant: order, restaurantId: order.restaurant.toString() });

        console.log(`⚡ Pago: ${order.orderId} (${order.total} sats)`);
        res.json({ ok: true });
      } catch (err) {
        console.error('Webhook error:', err);
        res.status(500).json({ error: 'Internal error' });
      }
    }
  );

  // ── Apollo GraphQL ──────────────────────────────────────────────────
  const schema = makeExecutableSchema({ typeDefs, resolvers });

  const apolloServer = new ApolloServer({
    schema,
    context: ({ req }) => ({ user: getUser(req), req }),
    formatError: (err) => { console.error('GQL:', err.message); return err; },
  });

  await apolloServer.start();
  apolloServer.applyMiddleware({ app, path: '/graphql' });

  // ── HTTP + WebSocket ────────────────────────────────────────────────
  const httpServer = http.createServer(app);
  const wsServer = new WebSocketServer({ server: httpServer, path: '/graphql' });

  useServer({
    schema,
    context: (ctx) => {
      const auth = ctx.connectionParams?.authorization || '';
      return { user: auth.startsWith('Bearer ') ? verifyToken(auth.slice(7)) : null };
    },
  }, wsServer);

  httpServer.listen(PORT, () => {
    console.log(`🚀 GraphQL:  http://localhost:${PORT}/graphql`);
    console.log(`⚡ WS:       ws://localhost:${PORT}/graphql`);
    console.log(`🔔 Webhook:  http://localhost:${PORT}/webhook/btcpay`);
  });

  await seedAdmin();
}

async function seedAdmin() {
  const User = require('./src/models/User');
  const bcrypt = require('bcryptjs');
  if (await User.findOne({ userType: 'ADMIN' })) return;
  const hash = await bcrypt.hash(process.env.ADMIN_PASSWORD || 'admin123', 10);
  await User.create({
    name: 'Admin BitFood',
    email: process.env.ADMIN_EMAIL || 'admin@bitfood.app',
    password: hash,
    userType: 'ADMIN',
    isActive: true,
  });
  console.log('👤 Admin: admin@bitfood.app / admin123 — TROQUE A SENHA!');
}

start().catch((err) => { console.error('Erro de inicialização:', err); process.exit(1); });
