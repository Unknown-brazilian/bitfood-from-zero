const mongoose = require('mongoose');

const userSchema = new mongoose.Schema({
  name: { type: String, required: true },
  email: { type: String, unique: true, sparse: true },
  phone: { type: String, unique: true, sparse: true },
  password: { type: String, required: true },
  userType: {
    type: String,
    enum: ['CUSTOMER', 'RIDER', 'RESTAURANT', 'ADMIN'],
    default: 'CUSTOMER'
  },
  isActive: { type: Boolean, default: true },
  avatar: String,
  // Customer
  addresses: [{
    label: String,
    address: String,
    details: String,
    location: {
      type: { type: String, default: 'Point' },
      coordinates: [Number]
    },
    isDefault: Boolean
  }],
  // Rider
  available: { type: Boolean, default: false },
  vehicleType: String,
  zone: { type: mongoose.Schema.Types.ObjectId, ref: 'Zone' },
  currentLocation: {
    type: { type: String, default: 'Point' },
    coordinates: [Number]
  },
  // Restaurant
  restaurant: { type: mongoose.Schema.Types.ObjectId, ref: 'Restaurant' },
  // Notifications token (FCM)
  notificationToken: String,
}, { timestamps: true });

userSchema.index({ currentLocation: '2dsphere' });

module.exports = mongoose.model('User', userSchema);
