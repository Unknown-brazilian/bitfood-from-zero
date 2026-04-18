const { gql } = require('apollo-server-express');

module.exports = gql`
  type OrderItem {
    _id: ID
    food: ID
    title: String
    image: String
    quantity: Int
    variation: OrderVariation
    addons: [OrderAddon]
    specialInstructions: String
    unitPrice: Int
    totalPrice: Int
  }

  type OrderVariation {
    title: String
    price: Int
  }

  type OrderAddon {
    title: String
    options: [OrderOption]
  }

  type OrderOption {
    title: String
    price: Int
  }

  type OrderAddress {
    address: String
    details: String
    location: Location
  }

  type StatusEntry {
    status: String
    timestamp: String
    note: String
  }

  type Order {
    _id: ID!
    orderId: String
    user: User
    restaurant: Restaurant
    rider: User
    items: [OrderItem]
    deliveryAddress: OrderAddress
    itemsTotal: Int
    deliveryFee: Int
    tax: Int
    discount: Int
    tip: Int
    total: Int
    paymentStatus: String
    btcpayInvoiceId: String
    btcpayCheckoutUrl: String
    lightningInvoice: String
    paymentHash: String
    paidAt: String
    orderStatus: String
    statusHistory: [StatusEntry]
    couponCode: String
    specialInstructions: String
    estimatedDeliveryTime: Int
    restaurantEarnings: Int
    riderEarnings: Int
    platformFee: Int
    isActive: Boolean
    createdAt: String
    updatedAt: String
  }

  type InvoiceResponse {
    order: Order!
    lightningInvoice: String
    checkoutUrl: String!
    paymentHash: String
    amountSats: Int!
    qrCode: String
  }

  type OrdersPage {
    orders: [Order]!
    total: Int!
    pages: Int!
  }

  type RiderLocation {
    riderId: ID
    lat: Float
    lng: Float
    orderId: ID
  }

  extend type Query {
    myOrders(status: String, page: Int, limit: Int): OrdersPage!
    order(_id: ID, orderId: String): Order
    restaurantOrders(status: String, page: Int, limit: Int): OrdersPage!
    riderOrders(status: String, page: Int, limit: Int): OrdersPage!
    availableOrders(lat: Float, lng: Float): [Order]!
    allOrders(
      restaurantId: ID
      status: String
      page: Int
      limit: Int
      dateFrom: String
      dateTo: String
    ): OrdersPage!
    checkPayment(orderId: ID!): Order!
  }

  extend type Mutation {
    placeOrder(
      restaurantId: ID!
      items: [OrderItemInput]!
      deliveryAddress: AddressInput!
      couponCode: String
      specialInstructions: String
      tip: Int
    ): InvoiceResponse!

    cancelOrder(orderId: ID!): Order!

    # Restaurant
    acceptOrder(orderId: ID!): Order!
    rejectOrder(orderId: ID!, reason: String): Order!
    markPreparing(orderId: ID!): Order!
    markReady(orderId: ID!): Order!

    # Rider
    acceptDelivery(orderId: ID!): Order!
    markPicked(orderId: ID!): Order!
    markDelivered(orderId: ID!): Order!
  }

  extend type Subscription {
    orderStatusChanged(orderId: ID!): Order
    newOrderForRestaurant(restaurantId: ID!): Order
    newOrderForRider(zoneId: ID!): Order
    riderLocationUpdated(orderId: ID!): RiderLocation
    paymentConfirmed(orderId: ID!): Order
  }

  input OrderItemInput {
    foodId: ID!
    quantity: Int!
    variationId: ID
    addons: [OrderAddonInput]
    specialInstructions: String
  }

  input OrderAddonInput {
    title: String
    options: [OrderOptionInput]
  }

  input OrderOptionInput {
    title: String
    price: Int
  }
`;
