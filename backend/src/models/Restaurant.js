const mongoose = require('mongoose');

const categorySchema = new mongoose.Schema({
  title: { type: String, required: true },
  isActive: { type: Boolean, default: true }
});

const addonOptionSchema = new mongoose.Schema({
  title: String,
  price: { type: Number, default: 0 }
});

const addonSchema = new mongoose.Schema({
  title: String,
  description: String,
  quantityMinimum: { type: Number, default: 0 },
  quantityMaximum: { type: Number, default: 1 },
  options: [addonOptionSchema]
});

const variationSchema = new mongoose.Schema({
  title: String,
  price: Number,
  isActive: { type: Boolean, default: true }
});

const foodSchema = new mongoose.Schema({
  title: { type: String, required: true },
  description: String,
  image: String,
  category: { type: mongoose.Schema.Types.ObjectId, ref: 'Category' },
  variations: [variationSchema],
  addons: [addonSchema],
  isActive: { type: Boolean, default: true },
  priceSats: Number, // base price in satoshis
}, { timestamps: true });

const restaurantSchema = new mongoose.Schema({
  name: { type: String, required: true },
  slug: { type: String, unique: true },
  description: String,
  image: String,
  logo: String,
  address: String,
  location: {
    type: { type: String, default: 'Point' },
    coordinates: [Number]
  },
  phone: String,
  email: { type: String, unique: true, sparse: true },
  username: { type: String, unique: true },
  password: String,
  isActive: { type: Boolean, default: true },
  isAvailable: { type: Boolean, default: true },
  shopType: String,
  cuisines: [String],
  categories: [categorySchema],
  foods: [foodSchema],
  deliveryTime: { type: Number, default: 30 },
  minimumOrder: { type: Number, default: 0 },
  zone: { type: mongoose.Schema.Types.ObjectId, ref: 'Zone' },
  commissionRate: { type: Number, default: 10 },
  reviewData: {
    rating: { type: Number, default: 0 },
    reviews: { type: Number, default: 0 },
    total: { type: Number, default: 0 }
  },
  openingTimes: [{
    day: String,
    times: [{
      startTime: [String],
      endTime: [String]
    }]
  }]
}, { timestamps: true });

restaurantSchema.index({ location: '2dsphere' });
restaurantSchema.pre('save', function(next) {
  if (!this.slug) {
    this.slug = this.name
      .toLowerCase()
      .replace(/[^a-z0-9]+/g, '-')
      .replace(/(^-|-$)/g, '') +
      '-' + Date.now().toString(36);
  }
  next();
});

module.exports = mongoose.model('Restaurant', restaurantSchema);
