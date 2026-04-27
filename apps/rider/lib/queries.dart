const loginMutation = r'''
  mutation Login($emailOrPhone: String!, $password: String!) {
    login(emailOrPhone: $emailOrPhone, password: $password) {
      token userId userType name phone
    }
  }
''';

const registerRiderMutation = r'''
  mutation RegisterRider($name: String!, $email: String!, $password: String!, $phone: String, $vehicleType: String) {
    registerRider(name: $name, email: $email, password: $password, phone: $phone, vehicleType: $vehicleType) {
      token userId userType name phone
    }
  }
''';

const availableOrdersQuery = r'''
  query AvailableOrders {
    availableOrders {
      _id orderId total deliveryFee createdAt
      restaurant { name address location { lat lng } }
      deliveryAddress { address details location { lat lng } }
      user { name phone }
      items { title quantity }
    }
  }
''';

const riderOrdersQuery = r'''
  query RiderOrders($status: String, $page: Int) {
    riderOrders(status: $status, page: $page, limit: 20) {
      orders {
        _id orderId orderStatus total deliveryFee createdAt
        restaurant { name address }
        deliveryAddress { address details }
        user { name phone }
        items { title quantity }
      }
      total pages
    }
  }
''';

const acceptDeliveryMutation = r'''
  mutation AcceptDelivery($orderId: ID!) {
    acceptDelivery(orderId: $orderId) { _id orderStatus }
  }
''';

const markPickedMutation = r'''
  mutation MarkPicked($orderId: ID!) {
    markPicked(orderId: $orderId) { _id orderStatus }
  }
''';

const markDeliveredMutation = r'''
  mutation MarkDelivered($orderId: ID!) {
    markDelivered(orderId: $orderId) { _id orderStatus }
  }
''';

const updateLocationMutation = r'''
  mutation UpdateLocation($lat: Float!, $lng: Float!) {
    updateRiderLocation(lat: $lat, lng: $lng)
  }
''';

const updateAvailabilityMutation = r'''
  mutation UpdateAvailability($available: Boolean!) {
    updateRiderAvailability(available: $available) { _id available }
  }
''';

const riderEarningsQuery = r'''
  query MyEarnings {
    myEarnings { totalSats todaySats weekSats monthSats totalOrders }
  }
''';

const newOrderForRiderSub = r'''
  subscription NewOrderForRider($zoneId: ID!) {
    newOrderForRider(zoneId: $zoneId) {
      _id orderId total restaurant { name }
    }
  }
''';

const orderHeatmapQuery = r'''
  query OrderHeatmap {
    orderHeatmap { lat lng weight }
  }
''';

const meQuery = r'''
  query Me {
    me {
      _id name phone vehicleType nameLocked available lightningAddress zone { _id }
    }
  }
''';

const updateProfileMutation = r'''
  mutation UpdateProfile($name: String, $vehicleType: String) {
    updateProfile(name: $name, vehicleType: $vehicleType) {
      _id name vehicleType nameLocked
    }
  }
''';

const setLightningAddressMutation = r'''
  mutation SetLightningAddress($lightningAddress: String) {
    setLightningAddress(lightningAddress: $lightningAddress) {
      _id lightningAddress
    }
  }
''';
