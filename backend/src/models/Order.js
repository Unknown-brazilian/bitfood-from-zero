const mongoose = require('mongoose');

const orderItemSchema = new mongoose.Schema({
  food: { type: mongoose.Schema.Types.ObjectId },
  title: String,
  image: String,
  quantity: { type: Number, required: true, min: 1 },
  variation: { title: String, price: Number },
  addons: [{ title: String, options: [{ title: String, price: Number }] }],
  specialInstructions: String,
  unitPrice: Number,
  totalPrice: Number
});

const orderSchema = new mongoose.Schema({
  orderId: { type: String, unique: true },
  user: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
  restaurant: { type: mongoose.Schema.Types.ObjectId, ref: 'Restaurant', required: true },
  rider: { type: mongoose.Schema.Types.ObjectId, ref: 'User' },
  items: [orderItemSchema],
  deliveryAddress: {
    address: String,
    details: String,
    location: {
      type: { type: String, default: 'Point' },
      coordinates: [Number]
    }
  },
  // Amounts (satoshis)
  itemsTotal: { type: Number, required: true },
  deliveryFee: { type: Number, default: 0 },
  tax: { type: Number, default: 0 },
  discount: { type: Number, default: 0 },
  tip: { type: Number, default: 0 },
  total: { type: Number, required: true },
  // Payment
  paymentStatus: {
    type: String,
    enum: ['PENDING', 'PAID', 'REFUNDED', 'FAILED'],
    default: 'PENDING'
  },
  btcpayInvoiceId: String,
  btcpayCheckoutUrl: String,
  lightningInvoice: String,
  paymentHash: String,
  paidAt: Date,
  // Order flow
  orderStatus: {
    type: String,
    enum: [
      'PENDING', 'PAID', 'ACCEPTED', 'PREPARING',
      'READY', 'ASSIGNED', 'PICKED', 'DELIVERING',
      'DELIVERED', 'CANCELLED', 'REJECTED'
    ],
    default: 'PENDING'
  },
  statusHistory: [{
    status: String,
    timestamp: { type: Date, default: Date.now },
    note: String
  }],
  coupon: { type: mongoose.Schema.Types.ObjectId, ref: 'Coupon' },
  couponCode: String,
  specialInstructions: String,
  estimatedDeliveryTime: Number,
  isActive: { type: Boolean, default: true },
  // Revenue split (satoshis)
  restaurantEarnings: Number,
  riderEarnings: Number,
  platformFee: Number,
}, { timestamps: true });

orderSchema.pre('save', function(next) {
  if (!this.orderId) {
    this.orderId = 'BF' + Date.now().toString(36).toUpperCase() +
      Math.random().toString(36).slice(2, 5).toUpperCase();
  }
  next();
});

module.exports = mongoose.model('Order', orderSchema);
