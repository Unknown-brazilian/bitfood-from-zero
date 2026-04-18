const bcrypt = require('bcryptjs');
const User = require('../../models/User');
const Restaurant = require('../../models/Restaurant');
const { signToken, requireAuth, requireRole } = require('../../utils/auth');
const { pubsub, EVENTS } = require('../../utils/pubsub');

module.exports = {
  Query: {
    me: async (_, __, { user }) => {
      requireAuth(user);
      return User.findById(user.userId).populate('zone').populate('restaurant');
    },

    users: async (_, { userType, page = 1, limit = 30 }, { user }) => {
      requireRole(user, 'ADMIN');
      const filter = userType ? { userType } : {};
      return User.find(filter)
        .populate('zone')
        .skip((page - 1) * limit)
        .limit(limit)
        .sort({ createdAt: -1 });
    },

    rider: async (_, { _id }) => User.findById(_id).populate('zone'),
  },

  Mutation: {
    register: async (_, { name, email, phone, password }) => {
      if (!email && !phone) throw new Error('Email ou telefone é obrigatório');
      if (email) {
        const exists = await User.findOne({ email });
        if (exists) throw new Error('Email já cadastrado');
      }
      const hash = await bcrypt.hash(password, 10);
      const u = await User.create({ name, email, phone, password: hash, userType: 'CUSTOMER' });
      return { token: signToken({ userId: u._id.toString(), userType: 'CUSTOMER', name: u.name }), userId: u._id, userType: 'CUSTOMER', name: u.name, email: u.email, phone: u.phone };
    },

    login: async (_, { emailOrPhone, password }) => {
      const u = await User.findOne({
        $or: [{ email: emailOrPhone }, { phone: emailOrPhone }]
      });
      if (!u) throw new Error('Usuário não encontrado');
      if (!await bcrypt.compare(password, u.password)) throw new Error('Senha incorreta');
      if (!u.isActive) throw new Error('Conta desativada');
      const payload = { userId: u._id.toString(), userType: u.userType, name: u.name };
      if (u.restaurant) payload.restaurantId = u.restaurant.toString();
      return { token: signToken(payload), userId: u._id, userType: u.userType, name: u.name, email: u.email, phone: u.phone, restaurantId: u.restaurant };
    },

    loginAdmin: async (_, { email, password }) => {
      const u = await User.findOne({ email, userType: 'ADMIN' });
      if (!u) throw new Error('Credenciais inválidas');
      if (!await bcrypt.compare(password, u.password)) throw new Error('Credenciais inválidas');
      return { token: signToken({ userId: u._id.toString(), userType: 'ADMIN', name: u.name }), userId: u._id, userType: 'ADMIN', name: u.name, email: u.email };
    },

    loginRestaurant: async (_, { username, password }) => {
      const r = await Restaurant.findOne({ username });
      if (!r) throw new Error('Credenciais inválidas');
      const bcryptjs = require('bcryptjs');
      if (!await bcryptjs.compare(password, r.password)) throw new Error('Credenciais inválidas');
      if (!r.isActive) throw new Error('Restaurante desativado');
      const payload = { userId: r._id.toString(), userType: 'RESTAURANT', name: r.name, restaurantId: r._id.toString() };
      return { token: signToken(payload), userId: r._id, userType: 'RESTAURANT', name: r.name, restaurantId: r._id };
    },

    updateProfile: async (_, args, { user }) => {
      requireAuth(user);
      return User.findByIdAndUpdate(user.userId, args, { new: true });
    },

    addAddress: async (_, args, { user }) => {
      requireAuth(user);
      const u = await User.findById(user.userId);
      const addr = { ...args };
      if (args.lat && args.lng) addr.location = { type: 'Point', coordinates: [args.lng, args.lat] };
      if (args.isDefault) u.addresses.forEach(a => a.isDefault = false);
      u.addresses.push(addr);
      await u.save();
      return u;
    },

    updateRiderAvailability: async (_, { available }, { user }) => {
      requireRole(user, 'RIDER');
      return User.findByIdAndUpdate(user.userId, { available }, { new: true });
    },

    updateRiderLocation: async (_, { lat, lng }, { user }) => {
      requireRole(user, 'RIDER');
      await User.findByIdAndUpdate(user.userId, {
        currentLocation: { type: 'Point', coordinates: [lng, lat] }
      });
      pubsub.publish(EVENTS.RIDER_LOCATION, {
        riderLocationUpdated: { riderId: user.userId, lat, lng },
      });
      return true;
    },

    toggleUserActive: async (_, { _id }, { user }) => {
      requireRole(user, 'ADMIN');
      const u = await User.findById(_id);
      u.isActive = !u.isActive;
      await u.save();
      return u;
    },

    createRider: async (_, { name, phone, password, zoneId, vehicleType }, { user }) => {
      requireRole(user, 'ADMIN');
      const hash = await bcrypt.hash(password, 10);
      return User.create({ name, phone, password: hash, userType: 'RIDER', zone: zoneId, vehicleType });
    },
  },
};
