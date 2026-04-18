const { gql } = require('apollo-server-express');

module.exports = gql`
  type AuthPayload {
    token: String!
    userId: ID!
    userType: String!
    name: String!
    email: String
    phone: String
    restaurantId: ID
  }

  type Address {
    _id: ID
    label: String
    address: String
    details: String
    location: Location
    isDefault: Boolean
  }

  type User {
    _id: ID!
    name: String!
    email: String
    phone: String
    userType: String!
    isActive: Boolean
    avatar: String
    addresses: [Address]
    available: Boolean
    vehicleType: String
    zone: Zone
    restaurant: Restaurant
    createdAt: String
  }

  extend type Query {
    me: User
    users(userType: String, page: Int, limit: Int): [User]!
    rider(_id: ID!): User
  }

  extend type Mutation {
    register(
      name: String!
      email: String
      phone: String
      password: String!
    ): AuthPayload!

    login(
      emailOrPhone: String!
      password: String!
    ): AuthPayload!

    loginAdmin(
      email: String!
      password: String!
    ): AuthPayload!

    loginRestaurant(
      username: String!
      password: String!
    ): AuthPayload!

    updateProfile(
      name: String
      avatar: String
      notificationToken: String
    ): User!

    addAddress(
      label: String
      address: String!
      details: String
      lat: Float
      lng: Float
      isDefault: Boolean
    ): User!

    updateRiderAvailability(available: Boolean!): User!
    updateRiderLocation(lat: Float!, lng: Float!): Boolean!

    toggleUserActive(_id: ID!): User!
    createRider(
      name: String!
      phone: String!
      password: String!
      zoneId: ID!
      vehicleType: String
    ): User!
  }
`;
