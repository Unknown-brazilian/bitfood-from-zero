const QRCode = require('qrcode');
const Order = require('../../models/Order');
const Restaurant = require('../../models/Restaurant');
const User = require('../../models/User');
const Configuration = require('../../models/Configuration');
const Coupon = require('../../models/Coupon');
const btcpay = require('../../services/btcpay');
const { requireAuth, requireRole } = require('../../utils/auth');
const { pubsub, EVENTS } = require('../../utils/pubsub');

const PAGE_SIZE = 20;

async function getConfig() {
  let c = await Configuration.findOne({ singleton: true });
  if (!c) c = await Configuration.create({ singleton: true });
  return c;
}

function calcCommissions(total, deliveryFee, config) {
  const platformFee = Math.floor(total * (config.commissionRate / 100));
  const riderEarnings = Math.floor(deliveryFee * (config.riderCommission / 100));
  const restaurantEarnings = total - platformFee;
  return { platformFee, riderEarnings, restaurantEarnings };
}

module.exports = {
  Query: {
    myOrders: async (_, { status, page = 1, limit = PAGE_SIZE }, { user }) => {
      requireRole(user, 'CUSTOMER');
      const filter = { user: user.userId };
      if (status) filter.orderStatus = status;
      const [orders, total] = await Promise.all([
        Order.find(filter).populate('restaurant', 'name image').populate('rider', 'name phone').sort({ createdAt: -1 }).skip((page - 1) * limit).limit(limit),
        Order.countDocuments(filter),
      ]);
      return { orders, total, pages: Math.ceil(total / limit) };
    },

    order: async (_, { _id, orderId }, { user }) => {
      requireAuth(user);
      const filter = _id ? { _id } : { orderId };
      const order = await Order.findOne(filter).populate('restaurant').populate('user', 'name phone').populate('rider', 'name phone');
      if (!order) throw new Error('Pedido não encontrado');
      return order;
    },

    restaurantOrders: async (_, { status, page = 1, limit = PAGE_SIZE }, { user }) => {
      requireRole(user, 'RESTAURANT');
      const filter = { restaurant: user.restaurantId };
      if (status) filter.orderStatus = status;
      const [orders, total] = await Promise.all([
        Order.find(filter).populate('user', 'name phone').populate('rider', 'name phone').sort({ createdAt: -1 }).skip((page - 1) * limit).limit(limit),
        Order.countDocuments(filter),
      ]);
      return { orders, total, pages: Math.ceil(total / limit) };
    },

    riderOrders: async (_, { status, page = 1, limit = PAGE_SIZE }, { user }) => {
      requireRole(user, 'RIDER');
      const filter = { rider: user.userId };
      if (status) filter.orderStatus = status;
      const [orders, total] = await Promise.all([
        Order.find(filter).populate('restaurant', 'name address location').populate('user', 'name phone').sort({ createdAt: -1 }).skip((page - 1) * limit).limit(limit),
        Order.countDocuments(filter),
      ]);
      return { orders, total, pages: Math.ceil(total / limit) };
    },

    availableOrders: async (_, { lat, lng }, { user }) => {
      requireRole(user, 'RIDER');
      const rider = await User.findById(user.userId);
      const filter = { orderStatus: 'READY', rider: null };
      if (rider.zone) filter['restaurant.zone'] = rider.zone;
      return Order.find({ orderStatus: 'READY' }).populate('restaurant', 'name address location').populate('user', 'name').limit(20);
    },

    allOrders: async (_, { restaurantId, status, page = 1, limit = PAGE_SIZE, dateFrom, dateTo }, { user }) => {
      requireRole(user, 'ADMIN');
      const filter = {};
      if (restaurantId) filter.restaurant = restaurantId;
      if (status) filter.orderStatus = status;
      if (dateFrom || dateTo) {
        filter.createdAt = {};
        if (dateFrom) filter.createdAt.$gte = new Date(dateFrom);
        if (dateTo) filter.createdAt.$lte = new Date(dateTo);
      }
      const [orders, total] = await Promise.all([
        Order.find(filter).populate('user', 'name phone').populate('restaurant', 'name').populate('rider', 'name').sort({ createdAt: -1 }).skip((page - 1) * limit).limit(limit),
        Order.countDocuments(filter),
      ]);
      return { orders, total, pages: Math.ceil(total / limit) };
    },

    checkPayment: async (_, { orderId }, { user }) => {
      requireAuth(user);
      const order = await Order.findById(orderId).populate('restaurant', 'name');
      if (!order) throw new Error('Pedido não encontrado');
      if (order.paymentStatus === 'PAID') return order;

      if (order.btcpayInvoiceId) {
        try {
          const result = await btcpay.getInvoice(order.btcpayInvoiceId);
          if (result.paid && order.paymentStatus !== 'PAID') {
            order.paymentStatus = 'PAID';
            order.orderStatus = 'PAID';
            order.paidAt = new Date();
            order.statusHistory.push({ status: 'PAID', note: 'Pagamento confirmado via polling' });
            await order.save();
            pubsub.publish(EVENTS.PAYMENT_CONFIRMED, { paymentConfirmed: order, orderId: order._id.toString() });
            pubsub.publish(EVENTS.ORDER_STATUS_CHANGED, { orderStatusChanged: order, orderId: order._id.toString() });
            pubsub.publish(EVENTS.NEW_ORDER, { newOrderForRestaurant: order, restaurantId: order.restaurant._id.toString() });
          }
        } catch (e) {
          console.warn('checkPayment polling error:', e.message);
        }
      }
      return order;
    },
  },

  Mutation: {
    placeOrder: async (_, { restaurantId, items, deliveryAddress, couponCode, specialInstructions, tip = 0 }, { user }) => {
      requireRole(user, 'CUSTOMER');

      const [restaurant, config, customer] = await Promise.all([
        Restaurant.findById(restaurantId),
        getConfig(),
        User.findById(user.userId),
      ]);
      if (!restaurant) throw new Error('Restaurante não encontrado');
      if (!restaurant.isAvailable) throw new Error('Restaurante fechado no momento');

      // Build order items and calculate totals
      let itemsTotal = 0;
      const orderItems = items.map(item => {
        const food = restaurant.foods.id(item.foodId);
        if (!food || !food.isActive) throw new Error(`Produto não disponível: ${item.foodId}`);

        const variation = item.variationId
          ? food.variations.id(item.variationId)
          : food.variations[0];
        const basePrice = variation ? variation.price : (food.priceSats || 0);

        let addonsTotal = 0;
        const selectedAddons = (item.addons || []).map(a => {
          const opts = (a.options || []).map(o => ({ title: o.title, price: o.price || 0 }));
          addonsTotal += opts.reduce((s, o) => s + o.price, 0);
          return { title: a.title, options: opts };
        });

        const unitPrice = basePrice + addonsTotal;
        const totalPrice = unitPrice * item.quantity;
        itemsTotal += totalPrice;

        return {
          food: item.foodId,
          title: food.title,
          image: food.image,
          quantity: item.quantity,
          variation: variation ? { title: variation.title, price: variation.price } : null,
          addons: selectedAddons,
          specialInstructions: item.specialInstructions,
          unitPrice,
          totalPrice,
        };
      });

      const deliveryFee = config.deliveryFee || 1000;
      let discount = 0;

      // Apply coupon
      if (couponCode) {
        const coupon = await Coupon.findOne({ code: couponCode.toUpperCase(), enabled: true });
        if (coupon && itemsTotal >= (coupon.minOrderAmount || 0)) {
          discount = Math.floor(itemsTotal * (coupon.discount / 100));
          if (coupon.maxDiscount) discount = Math.min(discount, coupon.maxDiscount);
          coupon.usedCount++;
          await coupon.save();
        }
      }

      const tipSats = tip || 0;
      const total = itemsTotal + deliveryFee - discount + tipSats;
      const { platformFee, riderEarnings, restaurantEarnings } = calcCommissions(total, deliveryFee, config);

      const addr = {
        address: deliveryAddress.address,
        details: deliveryAddress.details || '',
      };
      if (deliveryAddress.lat && deliveryAddress.lng) {
        addr.location = { type: 'Point', coordinates: [deliveryAddress.lng, deliveryAddress.lat] };
      }

      const order = new Order({
        user: user.userId,
        restaurant: restaurantId,
        items: orderItems,
        deliveryAddress: addr,
        itemsTotal,
        deliveryFee,
        discount,
        tip: tipSats,
        total,
        specialInstructions,
        couponCode: couponCode || null,
        platformFee,
        riderEarnings,
        restaurantEarnings,
        statusHistory: [{ status: 'PENDING', note: 'Pedido criado' }],
      });
      await order.save();

      // Create BTCPay invoice
      const invoiceData = await btcpay.createInvoice({
        amountSats: total,
        orderId: order.orderId,
        buyerName: customer?.name || '',
        buyerEmail: customer?.email || '',
        description: `BitFood #${order.orderId} — ${restaurant.name}`,
      });

      order.btcpayInvoiceId = invoiceData.invoiceId;
      order.btcpayCheckoutUrl = invoiceData.checkoutUrl;
      order.lightningInvoice = invoiceData.lightningInvoice;
      order.paymentHash = invoiceData.paymentHash;
      await order.save();

      // Generate QR code for Lightning invoice if available
      const qrTarget = invoiceData.lightningInvoice || invoiceData.checkoutUrl;
      let qrCode = null;
      if (qrTarget) {
        try { qrCode = await QRCode.toDataURL(qrTarget); } catch {}
      }

      return {
        order,
        lightningInvoice: invoiceData.lightningInvoice,
        checkoutUrl: invoiceData.checkoutUrl,
        paymentHash: invoiceData.paymentHash,
        amountSats: total,
        qrCode,
      };
    },

    cancelOrder: async (_, { orderId }, { user }) => {
      requireAuth(user);
      const order = await Order.findById(orderId);
      if (!order) throw new Error('Pedido não encontrado');
      if (order.paymentStatus === 'PAID') throw new Error('Pedido já pago não pode ser cancelado');
      order.orderStatus = 'CANCELLED';
      order.statusHistory.push({ status: 'CANCELLED', note: 'Cancelado pelo cliente' });
      await order.save();
      pubsub.publish(EVENTS.ORDER_STATUS_CHANGED, { orderStatusChanged: order, orderId: order._id.toString() });
      return order;
    },

    acceptOrder: async (_, { orderId }, { user }) => {
      requireRole(user, 'RESTAURANT');
      const order = await Order.findOne({ _id: orderId, restaurant: user.restaurantId });
      if (!order) throw new Error('Pedido não encontrado');
      order.orderStatus = 'ACCEPTED';
      order.statusHistory.push({ status: 'ACCEPTED', note: 'Aceito pelo restaurante' });
      await order.save();
      pubsub.publish(EVENTS.ORDER_STATUS_CHANGED, { orderStatusChanged: order, orderId: order._id.toString() });
      return order;
    },

    rejectOrder: async (_, { orderId, reason }, { user }) => {
      requireRole(user, 'RESTAURANT');
      const order = await Order.findOne({ _id: orderId, restaurant: user.restaurantId });
      if (!order) throw new Error('Pedido não encontrado');
      order.orderStatus = 'REJECTED';
      order.statusHistory.push({ status: 'REJECTED', note: reason || 'Rejeitado pelo restaurante' });
      await order.save();
      pubsub.publish(EVENTS.ORDER_STATUS_CHANGED, { orderStatusChanged: order, orderId: order._id.toString() });
      return order;
    },

    markPreparing: async (_, { orderId }, { user }) => {
      requireRole(user, 'RESTAURANT');
      const order = await Order.findOne({ _id: orderId, restaurant: user.restaurantId });
      order.orderStatus = 'PREPARING';
      order.statusHistory.push({ status: 'PREPARING' });
      await order.save();
      pubsub.publish(EVENTS.ORDER_STATUS_CHANGED, { orderStatusChanged: order, orderId: order._id.toString() });
      return order;
    },

    markReady: async (_, { orderId }, { user }) => {
      requireRole(user, 'RESTAURANT');
      const order = await Order.findOne({ _id: orderId, restaurant: user.restaurantId });
      order.orderStatus = 'READY';
      order.statusHistory.push({ status: 'READY', note: 'Pronto para retirada' });
      await order.save();
      pubsub.publish(EVENTS.ORDER_STATUS_CHANGED, { orderStatusChanged: order, orderId: order._id.toString() });
      pubsub.publish(EVENTS.NEW_ORDER, { newOrderForRider: order, zoneId: order.zone?.toString() });
      return order;
    },

    acceptDelivery: async (_, { orderId }, { user }) => {
      requireRole(user, 'RIDER');
      const order = await Order.findById(orderId);
      if (order.rider) throw new Error('Pedido já atribuído');
      order.rider = user.userId;
      order.orderStatus = 'ASSIGNED';
      order.statusHistory.push({ status: 'ASSIGNED', note: 'Entregador atribuído' });
      await order.save();
      pubsub.publish(EVENTS.ORDER_STATUS_CHANGED, { orderStatusChanged: order, orderId: order._id.toString() });
      return order;
    },

    markPicked: async (_, { orderId }, { user }) => {
      requireRole(user, 'RIDER');
      const order = await Order.findOne({ _id: orderId, rider: user.userId });
      order.orderStatus = 'PICKED';
      order.statusHistory.push({ status: 'PICKED', note: 'Retirado pelo entregador' });
      await order.save();
      pubsub.publish(EVENTS.ORDER_STATUS_CHANGED, { orderStatusChanged: order, orderId: order._id.toString() });
      return order;
    },

    markDelivered: async (_, { orderId }, { user }) => {
      requireRole(user, 'RIDER');
      const order = await Order.findOne({ _id: orderId, rider: user.userId });
      order.orderStatus = 'DELIVERED';
      order.statusHistory.push({ status: 'DELIVERED', note: 'Entregue ao cliente' });
      await order.save();
      pubsub.publish(EVENTS.ORDER_STATUS_CHANGED, { orderStatusChanged: order, orderId: order._id.toString() });
      return order;
    },
  },

  Subscription: {
    orderStatusChanged: {
      subscribe: (_, { orderId }) =>
        pubsub.asyncIterator([EVENTS.ORDER_STATUS_CHANGED]),
      resolve: (payload) => payload.orderStatusChanged,
    },
    newOrderForRestaurant: {
      subscribe: (_, { restaurantId }) =>
        pubsub.asyncIterator([EVENTS.NEW_ORDER]),
      resolve: (payload) => payload.newOrderForRestaurant,
    },
    newOrderForRider: {
      subscribe: (_, { zoneId }) =>
        pubsub.asyncIterator([EVENTS.NEW_ORDER]),
      resolve: (payload) => payload.newOrderForRider,
    },
    riderLocationUpdated: {
      subscribe: () =>
        pubsub.asyncIterator([EVENTS.RIDER_LOCATION]),
      resolve: (payload) => payload.riderLocationUpdated,
    },
    paymentConfirmed: {
      subscribe: () =>
        pubsub.asyncIterator([EVENTS.PAYMENT_CONFIRMED]),
      resolve: (payload) => payload.paymentConfirmed,
    },
  },
};
