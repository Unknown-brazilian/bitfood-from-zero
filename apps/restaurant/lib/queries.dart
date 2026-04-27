const loginRestaurantMutation = r'''
  mutation LoginRestaurant($emailOrUsername: String!, $password: String!) {
    loginRestaurant(emailOrUsername: $emailOrUsername, password: $password) {
      token userId userType name restaurantId
    }
  }
''';

const registerRestaurantMutation = r'''
  mutation RegisterRestaurant($name: String!, $email: String!, $password: String!, $phone: String, $address: String) {
    registerRestaurant(name: $name, email: $email, password: $password, phone: $phone, address: $address) {
      token userId userType name restaurantId
    }
  }
''';

const meRestaurantQuery = r'''
  query MyRestaurantProfile {
    myRestaurant {
      _id name email phone address logo nameLocked isAvailable lightningAddress
    }
  }
''';

const updateRestaurantProfileMutation = r'''
  mutation UpdateRestaurantProfile($name: String, $phone: String, $address: String, $logo: String, $lightningAddress: String) {
    updateRestaurantProfile(name: $name, phone: $phone, address: $address, logo: $logo, lightningAddress: $lightningAddress) {
      _id name email phone address logo nameLocked lightningAddress
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

const addCategoryMutation = r'''
  mutation AddCategory($title: String!) {
    addCategory(title: $title) {
      _id categories { _id title foods { _id title priceSats isActive } }
    }
  }
''';

const addFoodMutation = r'''
  mutation AddFood($categoryId: ID!, $title: String!, $description: String, $priceSats: Int) {
    addFood(categoryId: $categoryId, title: $title, description: $description, priceSats: $priceSats) {
      _id categories { _id title foods { _id title priceSats isActive } }
    }
  }
''';

const updateFoodMutation = r'''
  mutation UpdateFood($foodId: ID!, $isActive: Boolean) {
    updateFood(foodId: $foodId, isActive: $isActive) {
      _id categories { _id title foods { _id title priceSats isActive } }
    }
  }
''';
