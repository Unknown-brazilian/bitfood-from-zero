const { gql } = require('apollo-server-express');

module.exports = gql`
  type Configuration {
    _id: ID
    appName: String
    currency: String
    currencySymbol: String
    deliveryFee: Int
    minDeliveryFee: Int
    maxDeliveryFee: Int
    commissionRate: Float
    riderCommission: Float
    enableTipping: Boolean
    btcpayUrl: String
    btcpayStoreId: String
    supportEmail: String
    supportPhone: String
    customerAppVersion: String
    riderAppVersion: String
    restaurantAppVersion: String
    btcPriceBRL: Float
    btcPriceUSD: Float
  }

  type DashboardStats {
    totalOrders: Int
    totalRevenueSats: Int
    activeRestaurants: Int
    activeRiders: Int
    todayOrders: Int
    todayRevenueSats: Int
    pendingOrders: Int
  }

  type Coupon {
    _id: ID!
    code: String!
    title: String
    discount: Float
    maxDiscount: Int
    minOrderAmount: Int
    enabled: Boolean
    usageLimit: Int
    usedCount: Int
    expiresAt: String
  }

  type EarningsSummary {
    totalSats: Int
    todaySats: Int
    weekSats: Int
    monthSats: Int
    totalOrders: Int
  }

  extend type Query {
    configuration: Configuration!
    dashboardStats: DashboardStats!
    coupons: [Coupon]!
    validateCoupon(code: String!, restaurantId: ID!, orderAmount: Int!): Coupon
    myEarnings: EarningsSummary!
  }

  extend type Mutation {
    updateConfiguration(
      currency: String
      currencySymbol: String
      deliveryFee: Int
      minDeliveryFee: Int
      maxDeliveryFee: Int
      commissionRate: Float
      riderCommission: Float
      enableTipping: Boolean
      btcpayUrl: String
      btcpayStoreId: String
      btcpayApiKey: String
      btcpayWebhookSecret: String
      supportEmail: String
      supportPhone: String
    ): Configuration!

    createCoupon(
      code: String!
      title: String
      discount: Float!
      maxDiscount: Int
      minOrderAmount: Int
      usageLimit: Int
      expiresAt: String
    ): Coupon!

    updateCoupon(_id: ID!, enabled: Boolean, discount: Float): Coupon!
    deleteCoupon(_id: ID!): Boolean!
  }
`;
