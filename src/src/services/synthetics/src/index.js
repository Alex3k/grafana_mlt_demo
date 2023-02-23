// Node.js packages
import dateFormat from 'dateformat'
import { faker } from '@faker-js/faker'
import { GenCC } from 'creditcard-generator'

// k6 packages
import http from 'k6/http'
import { sleep } from 'k6'

 // TODO: Revert default
const SERVICE_HOST_WEB_GATEWAY = __ENV.SERVICE_HOST_WEB_GATEWAY || 'web-gateway.default.svc.cluster.local'
const SERVICE_PORT_WEB_GATEWAY = __ENV.SERVICE_PORT_WEB_GATEWAY || 80
const BASE_URL = `http://${SERVICE_HOST_WEB_GATEWAY}:${SERVICE_PORT_WEB_GATEWAY}`

// k6 Configuration
export const options = {
  vus: parseInt(__ENV.NUM_VIRTUAL_USERS || '1'),
  duration: '36500d',
}


const countryCode = ['US', 'GB', 'GR', 'GL', 'BE', 'NL', 'DE']

// Utils
const pause = () => sleep(1 + Math.random() * 2)
const json = (data) => JSON.stringify(data)
const randomUser = () => {
  faker.setLocale('en_US')
  const postalCode = faker.address.zipCode().split('-')[0]
  const user = {
    tier: faker.helpers.arrayElement(['free', 'paid']),
    device: {
      id: faker.datatype.uuid(),
      user_agent: faker.internet.userAgent(),
      ip_address: faker.internet.ip(),
      country: countryCode[Math.floor(Math.random() * countryCode.length)]
    },
    address: {
      street_1: faker.address.streetAddress(),
      street_2: Math.random() > 0.8 ? faker.address.secondaryAddress() : '',
      city: faker.address.cityName(),
      state: faker.address.stateAbbr(),
      postal_code: postalCode,
      country: 'US'
    },
    card: {
      name: `${faker.name.firstName()} ${faker.name.lastName()}`,
      number: GenCC('VISA')[0],
      expiration: dateFormat(faker.date.future(), 'mm/yy'),
      security_code: faker.finance.creditCardCVV(),
      postal_code: postalCode
    }
  }
  return user
}

const journey1 = (session_id, params) => {
  // Browser XHR
  http.post(`${BASE_URL}/api/v1/product/search`, json({ query: '', page: { size: 6 }}), params)
  http.get(`${BASE_URL}/api/v1/content/sweet-tea.jpeg`)
  http.get(`${BASE_URL}/api/v1/content/cinnamon-tea.jpeg`)
  http.get(`${BASE_URL}/api/v1/content/coffee.jpeg`)
  http.get(`${BASE_URL}/api/v1/content/watermelon-juice.jpeg`)
  http.get(`${BASE_URL}/api/v1/content/mocha-latte.jpeg`)
  http.get(`${BASE_URL}/api/v1/content/hot-chocolate.jpeg`)

  pause()

  ////  Add product to cart   //////////////////////////////////////////////////

  // User XHR
  console.debug('Add product to cart...')
  http.put(`${BASE_URL}/api/v1/cart/f95e2475/1`, json({ session_id: session_id }), params)

  // Browser XHR
  http.post(`${BASE_URL}/api/v1/cart`, json({ session_id: session_id }), params)
  http.post(`${BASE_URL}/api/v1/product/documents`, json([ 'f95e2475' ]), params)

  pause()

  ////  View cart  /////////////////////////////////////////////////////////////

  // User request
  console.debug('View cart...')
  http.get(`${BASE_URL}/cart`)

  // Browser XHR
  http.post(`${BASE_URL}/api/v1/product/documents`, json([ 'f95e2475' ]), params)
  http.get(`${BASE_URL}/api/v1/content/sweet-tea.jpeg`)

  pause()

  ////  Remove From Cart   //////////////////////////////////////////////////

  // User request
  console.debug('Delete Cart...')
  http.delete(`${BASE_URL}/api/v1/cart/f95e2475`, json({ session_id: session_id }), params)

  pause()
}


const journey2 = (session_id, params) => {
  // Browser XHR
  http.post(`${BASE_URL}/api/v1/product/search`, json({ query: '', page: { size: 6 }}), params)
  http.get(`${BASE_URL}/api/v1/content/sweet-tea.jpeg`)
  http.get(`${BASE_URL}/api/v1/content/cinnamon-tea.jpeg`)
  http.get(`${BASE_URL}/api/v1/content/coffee.jpeg`)
  http.get(`${BASE_URL}/api/v1/content/watermelon-juice.jpeg`)
  http.get(`${BASE_URL}/api/v1/content/mocha-latte.jpeg`)
  http.get(`${BASE_URL}/api/v1/content/hot-chocolate.jpeg`)

  pause()

  ////  Add product to cart   //////////////////////////////////////////////////

  // User XHR
  console.debug('Add product to cart...')
  http.put(`${BASE_URL}/api/v1/cart/f95e2475/1`, json({ session_id: session_id }), params)

  // Browser XHR
  http.post(`${BASE_URL}/api/v1/cart`, json({ session_id: session_id }), params)
  http.post(`${BASE_URL}/api/v1/product/documents`, json([ 'f95e2475' ]), params)

  pause()

  ////  View cart  /////////////////////////////////////////////////////////////

  // User request
  console.debug('View cart...')
  http.get(`${BASE_URL}/cart`)

  // Browser XHR
  http.post(`${BASE_URL}/api/v1/product/documents`, json([ 'f95e2475' ]), params)
  http.get(`${BASE_URL}/api/v1/content/sweet-tea.jpeg`)

  pause()

  ////  Proceed to checkout   //////////////////////////////////////////////////

  // Request
  console.debug('Proceed to checkout...')
  http.get(`${BASE_URL}/checkout`)

  // Browser XHR
  http.post(`${BASE_URL}/api/v1/cart`, json({ session_id: session_id }), params)
  http.post(`${BASE_URL}/api/v1/product/documents`, json([ 'f95e2475' ]), params)

  http.post(`${BASE_URL}/api/v1/checkout/initiate`, json({}), params)


  pause()
}

const journey3 = (session_id, params, user) => {
  // Browser XHR
  http.post(`${BASE_URL}/api/v1/product/search`, json({ query: '', page: { size: 6 }}), params)
  http.get(`${BASE_URL}/api/v1/content/sweet-tea.jpeg`)
  http.get(`${BASE_URL}/api/v1/content/cinnamon-tea.jpeg`)
  http.get(`${BASE_URL}/api/v1/content/coffee.jpeg`)
  http.get(`${BASE_URL}/api/v1/content/watermelon-juice.jpeg`)
  http.get(`${BASE_URL}/api/v1/content/mocha-latte.jpeg`)
  http.get(`${BASE_URL}/api/v1/content/hot-chocolate.jpeg`)

  pause()

  ////  Add product to cart   //////////////////////////////////////////////////

  // User XHR
  console.debug('Add product to cart...')
  http.put(`${BASE_URL}/api/v1/cart/f95e2475/1`, json({ session_id: session_id }), params)

  // Browser XHR
  http.post(`${BASE_URL}/api/v1/cart`, json({ session_id: session_id }), params)
  http.post(`${BASE_URL}/api/v1/product/documents`, json([ 'f95e2475' ]), params)

  pause()

  ////  View cart  /////////////////////////////////////////////////////////////

  // User request
  console.debug('View cart...')
  http.get(`${BASE_URL}/cart`)

  // Browser XHR
  http.post(`${BASE_URL}/api/v1/product/documents`, json([ 'f95e2475' ]), params)
  http.get(`${BASE_URL}/api/v1/content/sweet-tea.jpeg`)

  pause()

  ////  Proceed to checkout   //////////////////////////////////////////////////

  // Request
  console.debug('Proceed to checkout...')
  http.get(`${BASE_URL}/checkout`)

  // Browser XHR
  http.post(`${BASE_URL}/api/v1/cart`, json({ session_id: session_id }), params)
  http.post(`${BASE_URL}/api/v1/product/documents`, json([ 'f95e2475' ]), params)
  
  http.post(`${BASE_URL}/api/v1/checkout/initiate`, json({}), params)

  pause()

  ////  Submit payment   ///////////////////////////////////////////////////////

  // User XHR
  console.debug('Submit payment...')
  http.post(`${BASE_URL}/api/v1/checkout/process`, json({
    amount: 3.5,
    shipping: {
      address: {
        street_1: user.address.street_1,
        street_2: user.address.street_2,
        city: user.address.city,
        state: user.address.state,
        postal_code: user.address.postal_code,
        country: user.address.country
      }
    },
    billing: {
      address: {
        street_1: user.address.street_1,
        street_2: user.address.street_2,
        city: user.address.city,
        state: user.address.state,
        postal_code: user.address.postal_code,
        country: user.address.country
      },
      card: {
        name: user.card.name,
        number: user.card.number,
        expiration: user.card.expiration,
        security_code: user.card.security_code,
        postal_code: user.card.postal_codde
      }
    },
    session_id: session_id
  }), params)

  // Browser XHR
  http.post(`${BASE_URL}/api/v1/cart`, json({ session_id: session_id }), params)

  pause()
}

export default () => {
  const user = randomUser();

  // User request
  console.debug('Load home...')
  http.get(`${BASE_URL}/`)

  const session_id = (http.cookieJar().cookiesForURL(`${BASE_URL}/`).session_id || ["missing"])[0]
  console.log(session_id)

  const params = { 
    headers: { 
      'Content-Type': 'application/json',
      'User-Agent': user.device.user_agent,
      'X-Customer-Tier': user.tier,
      'X-Device-Id': user.device.id,
      'X-Device-Country': user.device.country, // This is random, so unrelated to IP
      'X-Forwarded-For': user.device.ip_address,
      'X-Session-Id': session_id
    }
  }

  const rollTheDice = Math.random() * 100;
  console.log(`Rolled the dice: ${rollTheDice}`)

  if (rollTheDice <= 30) {
    console.log("Journey One")
    journey1(session_id, params);
  } else if (rollTheDice > 30 && rollTheDice <= 40) {
    console.log("Journey Two")
    journey2(session_id, params);
  } else {
    console.log("Journey Three")
    journey3(session_id, params, user);
  }
}
