const { gql } = require('apollo-server-express');

module.exports = gql`
  type Query { _empty: String }
  type Mutation { _empty: String }
  type Subscription { _empty: String }

  type Location {
    lat: Float
    lng: Float
  }

  input LocationInput {
    lat: Float!
    lng: Float!
  }

  input AddressInput {
    address: String!
    details: String
    lat: Float
    lng: Float
  }
`;
