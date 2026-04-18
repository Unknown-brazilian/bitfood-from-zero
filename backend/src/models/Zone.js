const mongoose = require('mongoose');

const zoneSchema = new mongoose.Schema({
  title: { type: String, required: true },
  description: String,
  isActive: { type: Boolean, default: true },
  tax: { type: Number, default: 0 },
  deliveryFee: { type: Number, default: 1000 }, // sats
  boundaries: {
    type: { type: String, default: 'Polygon' },
    coordinates: [[[Number]]]
  }
}, { timestamps: true });

module.exports = mongoose.model('Zone', zoneSchema);
