// ── Auth ──────────────────────────────────────────────────────────────
const String registerMutation = r'''
  mutation Register($name: String!, $phone: String, $email: String, $password: String!) {
    register(name: $name, phone: $phone, email: $email, password: $password) {
      token userId userType name email phone
    }
  }
''';

const String loginMutation = r'''
  mutation Login($emailOrPhone: String!, $password: String!) {
    login(emailOrPhone: $emailOrPhone, password: $password) {
      token userId userType name email phone
    }
  }
''';

// ── Restaurants ───────────────────────────────────────────────────────
const String nearbyRestaurantsQuery = r'''
  query NearbyRestaurants($lat: Float!, $lng: Float!) {
    nearbyRestaurants(lat: $lat, lng: $lng) {
      _id name description image address
      deliveryTime minimumOrder isAvailable shopType cuisines
      reviewData { rating reviews }
      zone { deliveryFee }
    }
  }
''';

const String restaurantsQuery = r'''
  query Restaurants($search: String, $page: Int) {
    restaurants(search: $search, page: $page, limit: 20) {
      _id name description image address
      deliveryTime minimumOrder isAvailable shopType cuisines
      reviewData { rating reviews }
      zone { deliveryFee }
    }
  }
''';

const String restaurantQuery = r'''
  query Restaurant($id: ID!) {
    restaurant(_id: $id) {
      _id name description image address phone
      deliveryTime minimumOrder isAvailable shopType cuisines
      reviewData { rating reviews }
      zone { _id deliveryFee }
      categories {
        _id title isActive
        foods {
          _id title description image priceSats isActive
          variations { _id title price }
          addons {
            _id title quantityMinimum quantityMaximum
            options { _id title price }
          }
        }
      }
    }
  }
''';

// ── Orders ────────────────────────────────────────────────────────────
const String placeOrderMutation = r'''
  mutation PlaceOrder(
    $restaurantId: ID!
    $items: [OrderItemInput]!
    $deliveryAddress: AddressInput!
    $couponCode: String
    $specialInstructions: String
    $tip: Int
  ) {
    placeOrder(
      restaurantId: $restaurantId
      items: $items
      deliveryAddress: $deliveryAddress
      couponCode: $couponCode
      specialInstructions: $specialInstructions
      tip: $tip
    ) {
      order {
        _id orderId total orderStatus paymentStatus
      }
      lightningInvoice
      checkoutUrl
      paymentHash
      amountSats
      qrCode
    }
  }
''';

const String checkPaymentQuery = r'''
  query CheckPayment($orderId: ID!) {
    checkPayment(orderId: $orderId) {
      _id orderId paymentStatus orderStatus total
    }
  }
''';

const String myOrdersQuery = r'''
  query MyOrders($status: String, $page: Int) {
    myOrders(status: $status, page: $page, limit: 15) {
      orders {
        _id orderId orderStatus paymentStatus total createdAt
        restaurant { name image }
        items { title quantity totalPrice }
        rider { name phone }
      }
      total pages
    }
  }
''';

const String orderDetailQuery = r'''
  query Order($id: ID!) {
    order(_id: $id) {
      _id orderId orderStatus paymentStatus total deliveryFee discount tip
      createdAt paidAt estimatedDeliveryTime
      items { title quantity unitPrice totalPrice image }
      restaurant { name address phone image }
      rider { name phone }
      deliveryAddress { address details }
      statusHistory { status timestamp note }
    }
  }
''';

const String meQuery = r'''
  query Me {
    me {
      _id name email phone lightningAddress lightningAddressLocked balanceSats
      tier reputationScore completedOrders totalOrders
      addresses {
        _id label address street number complement neighborhood postalCode city state country details isDefault
        location { lat lng }
      }
    }
  }
''';

const String setLightningAddressMutation = r'''
  mutation SetLightningAddress($lightningAddress: String) {
    setLightningAddress(lightningAddress: $lightningAddress) {
      _id lightningAddress lightningAddressLocked
    }
  }
''';

const String createDepositInvoiceMutation = r'''
  mutation CreateDepositInvoice($amountSats: Int!) {
    createDepositInvoice(amountSats: $amountSats) {
      invoiceId lightningInvoice checkoutUrl expiresAt
    }
  }
''';

const String addAddressMutation = r'''
  mutation AddAddress(
    $label: String
    $address: String!
    $street: String
    $number: String
    $complement: String
    $neighborhood: String
    $postalCode: String
    $city: String
    $state: String
    $country: String
    $details: String
    $lat: Float
    $lng: Float
    $isDefault: Boolean
  ) {
    addAddress(
      label: $label address: $address street: $street number: $number
      complement: $complement neighborhood: $neighborhood postalCode: $postalCode
      city: $city state: $state country: $country details: $details
      lat: $lat lng: $lng isDefault: $isDefault
    ) {
      _id addresses {
        _id label address street number complement neighborhood postalCode city state country details isDefault
        location { lat lng }
      }
    }
  }
''';

const String cancelOrderMutation = r'''
  mutation CancelOrder($orderId: ID!) {
    cancelOrder(orderId: $orderId) { _id orderStatus }
  }
''';

const String validateCouponQuery = r'''
  query ValidateCoupon($code: String!, $restaurantId: ID!, $orderAmount: Int!) {
    validateCoupon(code: $code, restaurantId: $restaurantId, orderAmount: $orderAmount) {
      _id code discount maxDiscount title
    }
  }
''';

// ── Subscriptions ─────────────────────────────────────────────────────
const String orderStatusSub = r'''
  subscription OrderStatusChanged($orderId: ID!) {
    orderStatusChanged(orderId: $orderId) {
      _id orderId orderStatus paymentStatus
    }
  }
''';

const String paymentConfirmedSub = r'''
  subscription PaymentConfirmed($orderId: ID!) {
    paymentConfirmed(orderId: $orderId) {
      _id orderId orderStatus paymentStatus total
    }
  }
''';
