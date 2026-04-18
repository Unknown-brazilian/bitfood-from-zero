const { PubSub } = require('graphql-subscriptions');

const pubsub = new PubSub();

const EVENTS = {
  ORDER_STATUS_CHANGED: 'ORDER_STATUS_CHANGED',
  NEW_ORDER: 'NEW_ORDER',
  PAYMENT_CONFIRMED: 'PAYMENT_CONFIRMED',
  RIDER_LOCATION: 'RIDER_LOCATION',
};

module.exports = { pubsub, EVENTS };
