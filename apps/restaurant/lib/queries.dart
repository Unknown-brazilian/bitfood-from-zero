const loginRestaurantMutation = r'''
  mutation LoginRestaurant($username: String!, $password: String!) {
    loginRestaurant(username: $username, password: $password) {
      token userId userType name restaurantId
    }
  }
''';

const restaurantOrdersQuery = r'''
  query RestaurantOrders($status: String, $page: Int) {
    restaurantOrders(status: $status, page: $page, limit: 30) {
      orders {
        _id orderId orderStatus paymentStatus total createdAt
        user { name phone }
        items { title quantity totalPrice }
        deliveryAddress { address }
        specialInstructions
      }
      total pages
    }
  }
''';

const acceptOrderMutation = r'''
  mutation AcceptOrder($orderId: ID!) {
    acceptOrder(orderId: $orderId) { _id orderStatus }
  }
''';

const rejectOrderMutation = r'''
  mutation RejectOrder($orderId: ID!, $reason: String) {
    rejectOrder(orderId: $orderId, reason: $reason) { _id orderStatus }
  }
''';

const markPreparingMutation = r'''
  mutation MarkPreparing($orderId: ID!) {
    markPreparing(orderId: $orderId) { _id orderStatus }
  }
''';

const markReadyMutation = r'''
  mutation MarkReady($orderId: ID!) {
    markReady(orderId: $orderId) { _id orderStatus }
  }
''';

const myRestaurantQuery = r'''
  query MyRestaurant {
    myRestaurant {
      _id name isAvailable
      categories { _id title foods { _id title priceSats isActive } }
    }
  }
''';

const toggleAvailableMutation = r'''
  mutation ToggleAvailable {
    toggleRestaurantAvailable { _id isAvailable }
  }
''';

const newOrderSub = r'''
  subscription NewOrderForRestaurant($restaurantId: ID!) {
    newOrderForRestaurant(restaurantId: $restaurantId) {
      _id orderId total user { name phone }
    }
  }
''';

const myEarningsQuery = r'''
  query MyEarnings {
    myEarnings { totalSats todaySats weekSats monthSats totalOrders }
  }
''';
