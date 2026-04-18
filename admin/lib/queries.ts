import { gql } from '@apollo/client';

export const LOGIN_ADMIN = gql`
  mutation LoginAdmin($email: String!, $password: String!) {
    loginAdmin(email: $email, password: $password) {
      token userId userType name email
    }
  }
`;

export const DASHBOARD_STATS = gql`
  query DashboardStats {
    dashboardStats {
      totalOrders totalRevenueSats activeRestaurants
      activeRiders todayOrders todayRevenueSats pendingOrders
    }
    configuration { btcPriceBRL btcPriceUSD currency currencySymbol }
  }
`;

export const RESTAURANTS = gql`
  query Restaurants($page: Int, $limit: Int) {
    restaurants(page: $page, limit: $limit) {
      _id name address phone email isActive isAvailable
      shopType cuisines deliveryTime minimumOrder
      reviewData { rating reviews }
      zone { _id title }
      createdAt
    }
  }
`;

export const CREATE_RESTAURANT = gql`
  mutation CreateRestaurant(
    $name: String! $address: String! $lat: Float! $lng: Float!
    $phone: String! $email: String! $username: String! $password: String!
    $zoneId: ID! $shopType: String $cuisines: [String] $commissionRate: Float
  ) {
    createRestaurant(
      name: $name address: $address lat: $lat lng: $lng
      phone: $phone email: $email username: $username password: $password
      zoneId: $zoneId shopType: $shopType cuisines: $cuisines commissionRate: $commissionRate
    ) { _id name }
  }
`;

export const TOGGLE_RESTAURANT = gql`
  mutation ToggleRestaurantActive($_id: ID!) {
    toggleRestaurantActive(_id: $_id) { _id isActive }
  }
`;

export const ALL_ORDERS = gql`
  query AllOrders($status: String, $page: Int, $limit: Int) {
    allOrders(status: $status, page: $page, limit: $limit) {
      orders {
        _id orderId orderStatus paymentStatus total createdAt
        user { name phone }
        restaurant { name }
        rider { name }
      }
      total pages
    }
  }
`;

export const ZONES = gql`
  query Zones { zones { _id title description isActive deliveryFee tax } }
`;

export const CREATE_ZONE = gql`
  mutation CreateZone($title: String!, $description: String, $deliveryFee: Int, $tax: Float) {
    createZone(title: $title, description: $description, deliveryFee: $deliveryFee, tax: $tax) {
      _id title
    }
  }
`;

export const USERS = gql`
  query Users($userType: String, $page: Int) {
    users(userType: $userType, page: $page) {
      _id name phone email userType isActive available vehicleType
      zone { title } createdAt
    }
  }
`;

export const CREATE_RIDER = gql`
  mutation CreateRider($name: String!, $phone: String!, $password: String!, $zoneId: ID!, $vehicleType: String) {
    createRider(name: $name, phone: $phone, password: $password, zoneId: $zoneId, vehicleType: $vehicleType) {
      _id name
    }
  }
`;

export const TOGGLE_USER = gql`
  mutation ToggleUserActive($_id: ID!) {
    toggleUserActive(_id: $_id) { _id isActive }
  }
`;

export const COUPONS = gql`
  query Coupons {
    coupons { _id code title discount maxDiscount minOrderAmount enabled usageLimit usedCount expiresAt }
  }
`;

export const CREATE_COUPON = gql`
  mutation CreateCoupon(
    $code: String! $title: String $discount: Float! $maxDiscount: Int
    $minOrderAmount: Int $usageLimit: Int $expiresAt: String
  ) {
    createCoupon(
      code: $code title: $title discount: $discount maxDiscount: $maxDiscount
      minOrderAmount: $minOrderAmount usageLimit: $usageLimit expiresAt: $expiresAt
    ) { _id code }
  }
`;

export const UPDATE_COUPON = gql`
  mutation UpdateCoupon($_id: ID!, $enabled: Boolean) {
    updateCoupon(_id: $_id, enabled: $enabled) { _id enabled }
  }
`;

export const CONFIGURATION = gql`
  query Configuration {
    configuration {
      _id appName currency currencySymbol
      deliveryFee minDeliveryFee maxDeliveryFee
      commissionRate riderCommission enableTipping
      btcpayUrl btcpayStoreId
      supportEmail supportPhone
    }
  }
`;

export const UPDATE_CONFIGURATION = gql`
  mutation UpdateConfiguration(
    $currency: String $currencySymbol: String
    $deliveryFee: Int $commissionRate: Float $riderCommission: Float
    $enableTipping: Boolean $supportEmail: String $supportPhone: String
    $btcpayUrl: String $btcpayStoreId: String
    $btcpayApiKey: String $btcpayWebhookSecret: String
  ) {
    updateConfiguration(
      currency: $currency currencySymbol: $currencySymbol
      deliveryFee: $deliveryFee commissionRate: $commissionRate
      riderCommission: $riderCommission enableTipping: $enableTipping
      supportEmail: $supportEmail supportPhone: $supportPhone
      btcpayUrl: $btcpayUrl btcpayStoreId: $btcpayStoreId
      btcpayApiKey: $btcpayApiKey btcpayWebhookSecret: $btcpayWebhookSecret
    ) { _id }
  }
`;
