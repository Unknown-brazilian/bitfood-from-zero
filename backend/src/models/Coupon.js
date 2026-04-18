const mongoose = require('mongoose');

const couponSchema = new mongoose.Schema({
  code: { type: String, required: true, unique: true, uppercase: true },
  title: String,
  discount: { type: Number, required: true },   // percentage
  maxDiscount: Number,                            // max sats discount
  minOrderAmount: { type: Number, default: 0 },  // sats
  enabled: { type: Boolean, default: true },
  restaurant: { type: mongoose.Schema.Types.ObjectId, ref: 'Restaurant' },
  usageLimit: { type: Number, default: 0 },       // 0 = unlimited
  usedCount: { type: Number, default: 0 },
  expiresAt: Date,
}, { timestamps: true });

module.exports = mongoose.model('Coupon', couponSchema);
