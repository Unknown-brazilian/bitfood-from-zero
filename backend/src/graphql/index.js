const { mergeTypeDefs, mergeResolvers } = require('@graphql-tools/merge');

const typeDefs = mergeTypeDefs([
  require('./typeDefs/base'),
  require('./typeDefs/user'),
  require('./typeDefs/restaurant'),
  require('./typeDefs/order'),
  require('./typeDefs/config'),
]);

const resolvers = mergeResolvers([
  require('./resolvers/user'),
  require('./resolvers/restaurant'),
  require('./resolvers/order'),
  require('./resolvers/config'),
]);

module.exports = { typeDefs, resolvers };
