const bcrypt = require('bcryptjs');
const Restaurant = require('../../models/Restaurant');
const Zone = require('../../models/Zone');
const { requireAuth, requireRole } = require('../../utils/auth');

module.exports = {
  Query: {
    restaurants: async (_, { zoneId, cuisines, search, page = 1, limit = 20 }) => {
      const filter = { isActive: true };
      if (zoneId) filter.zone = zoneId;
      if (cuisines?.length) filter.cuisines = { $in: cuisines };
      if (search) filter.name = { $regex: search, $options: 'i' };
      return Restaurant.find(filter)
        .populate('zone')
        .skip((page - 1) * limit)
        .limit(limit)
        .sort({ 'reviewData.rating': -1 });
    },

    restaurant: async (_, { _id, slug }) => {
      const filter = _id ? { _id } : { slug };
      return Restaurant.findOne(filter).populate('zone');
    },

    myRestaurant: async (_, __, { user }) => {
      requireRole(user, 'RESTAURANT');
      const r = await Restaurant.findById(user.restaurantId).populate('zone');
      if (!r) return null;
      const result = r.toObject();
      result.categories = result.categories.map(cat => ({
        ...cat,
        foods: result.foods.filter(f => f.category?.toString() === cat._id.toString()),
      }));
      return result;
    },

    nearbyRestaurants: async (_, { lat, lng, radius = 10 }) => {
      return Restaurant.find({
        isActive: true,
        location: {
          $near: {
            $geometry: { type: 'Point', coordinates: [lng, lat] },
            $maxDistance: radius * 1000
          }
        }
      }).populate('zone').limit(30);
    },

    zones: async () => Zone.find({ isActive: true }),
  },

  Mutation: {
    createRestaurant: async (_, { name, address, lat, lng, phone, email, username, password, zoneId, shopType, cuisines, commissionRate }, { user }) => {
      requireRole(user, 'ADMIN');
      const hash = await bcrypt.hash(password, 10);
      return Restaurant.create({
        name, address, phone, email, username, password: hash,
        location: { type: 'Point', coordinates: [lng, lat] },
        zone: zoneId, shopType, cuisines, commissionRate,
      });
    },

    updateRestaurant: async (_, args, { user }) => {
      requireRole(user, 'RESTAURANT');
      return Restaurant.findByIdAndUpdate(user.restaurantId, args, { new: true }).populate('zone');
    },

    toggleRestaurantActive: async (_, { _id }, { user }) => {
      requireRole(user, 'ADMIN');
      const r = await Restaurant.findById(_id);
      r.isActive = !r.isActive;
      await r.save();
      return r;
    },

    toggleRestaurantAvailable: async (_, __, { user }) => {
      requireRole(user, 'RESTAURANT');
      const r = await Restaurant.findById(user.restaurantId);
      r.isAvailable = !r.isAvailable;
      await r.save();
      return r;
    },

    addCategory: async (_, { title }, { user }) => {
      requireRole(user, 'RESTAURANT', 'ADMIN');
      const id = user.userType === 'ADMIN' ? null : user.restaurantId;
      if (!id) throw new Error('restaurantId não encontrado');
      const r = await Restaurant.findById(id);
      r.categories.push({ title });
      await r.save();
      return r;
    },

    deleteCategory: async (_, { categoryId }, { user }) => {
      requireRole(user, 'RESTAURANT', 'ADMIN');
      const r = await Restaurant.findById(user.restaurantId);
      r.categories = r.categories.filter(c => c._id.toString() !== categoryId);
      await r.save();
      return r;
    },

    addFood: async (_, { categoryId, title, description, image, priceSats, variations, addons }, { user }) => {
      requireRole(user, 'RESTAURANT', 'ADMIN');
      const r = await Restaurant.findById(user.restaurantId);
      r.foods.push({ title, description, image, priceSats, variations, addons, category: categoryId });
      await r.save();
      return r;
    },

    updateFood: async (_, { foodId, ...args }, { user }) => {
      requireRole(user, 'RESTAURANT', 'ADMIN');
      const r = await Restaurant.findById(user.restaurantId);
      const food = r.foods.id(foodId);
      if (!food) throw new Error('Produto não encontrado');
      Object.assign(food, args);
      await r.save();
      return r;
    },

    deleteFood: async (_, { foodId }, { user }) => {
      requireRole(user, 'RESTAURANT', 'ADMIN');
      const r = await Restaurant.findById(user.restaurantId);
      r.foods = r.foods.filter(f => f._id.toString() !== foodId);
      await r.save();
      return r;
    },

    createZone: async (_, args, { user }) => {
      requireRole(user, 'ADMIN');
      return Zone.create(args);
    },
  },
};
