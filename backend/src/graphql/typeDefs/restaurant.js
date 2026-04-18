const { gql } = require('apollo-server-express');

module.exports = gql`
  type AddonOption {
    _id: ID
    title: String
    price: Int
  }

  type Addon {
    _id: ID
    title: String
    description: String
    quantityMinimum: Int
    quantityMaximum: Int
    options: [AddonOption]
  }

  type Variation {
    _id: ID
    title: String
    price: Int
    isActive: Boolean
  }

  type Food {
    _id: ID!
    title: String!
    description: String
    image: String
    variations: [Variation]
    addons: [Addon]
    isActive: Boolean
    priceSats: Int
  }

  type Category {
    _id: ID!
    title: String!
    isActive: Boolean
    foods: [Food]
  }

  type ReviewData {
    rating: Float
    reviews: Int
  }

  type Zone {
    _id: ID!
    title: String!
    description: String
    isActive: Boolean
    deliveryFee: Int
    tax: Float
  }

  type Restaurant {
    _id: ID!
    name: String!
    slug: String
    description: String
    image: String
    logo: String
    address: String
    location: Location
    phone: String
    email: String
    isActive: Boolean
    isAvailable: Boolean
    shopType: String
    cuisines: [String]
    categories: [Category]
    foods: [Food]
    deliveryTime: Int
    minimumOrder: Int
    zone: Zone
    reviewData: ReviewData
    createdAt: String
  }

  extend type Query {
    restaurants(
      zoneId: ID
      cuisines: [String]
      search: String
      lat: Float
      lng: Float
      page: Int
      limit: Int
    ): [Restaurant]!

    restaurant(_id: ID, slug: String): Restaurant
    myRestaurant: Restaurant
    nearbyRestaurants(lat: Float!, lng: Float!, radius: Float): [Restaurant]!
    zones: [Zone]!
  }

  extend type Mutation {
    createRestaurant(
      name: String!
      address: String!
      lat: Float!
      lng: Float!
      phone: String!
      email: String!
      username: String!
      password: String!
      zoneId: ID!
      shopType: String
      cuisines: [String]
      commissionRate: Float
    ): Restaurant!

    updateRestaurant(
      name: String
      description: String
      image: String
      phone: String
      shopType: String
      cuisines: [String]
      deliveryTime: Int
      minimumOrder: Int
    ): Restaurant!

    toggleRestaurantActive(_id: ID!): Restaurant!
    toggleRestaurantAvailable: Restaurant!

    addCategory(title: String!): Restaurant!
    deleteCategory(categoryId: ID!): Restaurant!

    addFood(
      categoryId: ID!
      title: String!
      description: String
      image: String
      priceSats: Int
      variations: [VariationInput]
      addons: [AddonInput]
    ): Restaurant!

    updateFood(
      foodId: ID!
      title: String
      description: String
      image: String
      priceSats: Int
      isActive: Boolean
    ): Restaurant!

    deleteFood(foodId: ID!): Restaurant!

    createZone(
      title: String!
      description: String
      deliveryFee: Int
      tax: Float
    ): Zone!
  }

  input VariationInput {
    title: String!
    price: Int!
  }

  input AddonInput {
    title: String!
    description: String
    quantityMinimum: Int
    quantityMaximum: Int
    options: [AddonOptionInput]
  }

  input AddonOptionInput {
    title: String!
    price: Int
  }
`;
