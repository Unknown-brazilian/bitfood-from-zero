const Configuration = require('../../models/Configuration');
const Coupon = require('../../models/Coupon');
const Order = require('../../models/Order');
const Restaurant = require('../../models/Restaurant');
const User = require('../../models/User');
const { getBTCPrice } = require('../../services/price');
const { requireRole, requireAuth } = require('../../utils/auth');

module.exports = {
  Query: {
    configuration: async () => {
      let c = await Configuration.findOne({ singleton: true });
      if (!c) c = await Configuration.create({ singleton: true });
      const [btcPriceBRL, btcPriceUSD] = await Promise.all([
        getBTCPrice('brl').catch(() => 0),
        getBTCPrice('usd').catch(() => 0),
      ]);
      return { ...c.toObject(), btcPriceBRL, btcPriceUSD };
    },

    dashboardStats: async (_, __, { user }) => {
      requireRole(user, 'ADMIN');
      const today = new Date();
      today.setHours(0, 0, 0, 0);
      const [totalOrders, todayOrders, pendingOrders, activeRestaurants, activeRiders, revenue, todayRevenue] =
        await Promise.all([
          Order.countDocuments(),
          Order.countDocuments({ createdAt: { $gte: today } }),
          Order.countDocuments({ orderStatus: { $in: ['PAID', 'ACCEPTED', 'PREPARING', 'READY', 'ASSIGNED', 'PICKED', 'DELIVERING'] } }),
          Restaurant.countDocuments({ isActive: true }),
          User.countDocuments({ userType: 'RIDER', isActive: true }),
          Order.aggregate([{ $match: { paymentStatus: 'PAID' } }, { $group: { _id: null, total: { $sum: '$total' } } }]),
          Order.aggregate([{ $match: { paymentStatus: 'PAID', createdAt: { $gte: today } } }, { $group: { _id: null, total: { $sum: '$total' } } }]),
        ]);
      return {
        totalOrders,
        totalRevenueSats: revenue[0]?.total || 0,
        activeRestaurants,
        activeRiders,
        todayOrders,
        todayRevenueSats: todayRevenue[0]?.total || 0,
        pendingOrders,
      };
    },

    coupons: async (_, __, { user }) => {
      requireRole(user, 'ADMIN');
      return Coupon.find().sort({ createdAt: -1 });
    },

    validateCoupon: async (_, { code, restaurantId, orderAmount }) => {
      const coupon = await Coupon.findOne({
        code: code.toUpperCase(),
        enabled: true,
        $or: [{ expiresAt: null }, { expiresAt: { $gt: new Date() } }],
      });
      if (!coupon) throw new Error('Cupom inválido ou expirado');
      if (coupon.usageLimit > 0 && coupon.usedCount >= coupon.usageLimit) throw new Error('Cupom esgotado');
      if (orderAmount < coupon.minOrderAmount) throw new Error(`Pedido mínimo: ${coupon.minOrderAmount} sats`);
      return coupon;
    },

    myEarnings: async (_, __, { user }) => {
      requireRole(user, 'RESTAURANT', 'RIDER');
      const isRider = user.userType === 'RIDER';
      const field = isRider ? 'rider' : 'restaurant';
      const earningField = isRider ? 'riderEarnings' : 'restaurantEarnings';
      const id = user.restaurantId || user.userId;
      const now = new Date();
      const todayStart = new Date(now); todayStart.setHours(0, 0, 0, 0);
      const weekStart = new Date(now); weekStart.setDate(weekStart.getDate() - 7);
      const monthStart = new Date(now); monthStart.setDate(1);

      const [total, today, week, month, totalOrders] = await Promise.all([
        Order.aggregate([{ $match: { [field]: id, paymentStatus: 'PAID' } }, { $group: { _id: null, v: { $sum: `$${earningField}` } } }]),
        Order.aggregate([{ $match: { [field]: id, paymentStatus: 'PAID', paidAt: { $gte: todayStart } } }, { $group: { _id: null, v: { $sum: `$${earningField}` } } }]),
        Order.aggregate([{ $match: { [field]: id, paymentStatus: 'PAID', paidAt: { $gte: weekStart } } }, { $group: { _id: null, v: { $sum: `$${earningField}` } } }]),
        Order.aggregate([{ $match: { [field]: id, paymentStatus: 'PAID', paidAt: { $gte: monthStart } } }, { $group: { _id: null, v: { $sum: `$${earningField}` } } }]),
        Order.countDocuments({ [field]: id, paymentStatus: 'PAID' }),
      ]);
      return {
        totalSats: total[0]?.v || 0,
        todaySats: today[0]?.v || 0,
        weekSats: week[0]?.v || 0,
        monthSats: month[0]?.v || 0,
        totalOrders,
      };
    },
  },

  Mutation: {
    updateConfiguration: async (_, args, { user }) => {
      requireRole(user, 'ADMIN');
      let c = await Configuration.findOne({ singleton: true });
      if (!c) c = new Configuration({ singleton: true });
      Object.assign(c, args);
      await c.save();
      return c;
    },

    createCoupon: async (_, args, { user }) => {
      requireRole(user, 'ADMIN');
      return Coupon.create(args);
    },

    updateCoupon: async (_, { _id, ...args }, { user }) => {
      requireRole(user, 'ADMIN');
      return Coupon.findByIdAndUpdate(_id, args, { new: true });
    },

    deleteCoupon: async (_, { _id }, { user }) => {
      requireRole(user, 'ADMIN');
      await Coupon.findByIdAndDelete(_id);
      return true;
    },
  },
};
