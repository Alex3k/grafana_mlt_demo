
import { sleep } from 'k6';
import { chromium } from 'k6/experimental/browser';

let addToCartButtons;

export default async function () {
  const browser = chromium.launch({
    headless: true
  });
  const context = browser.newContext();
  const page = context.newPage();

  const rollTheDice = Math.random() * 100;
  console.log(`Rolled the dice: ${rollTheDice}`)

  try {
    if (rollTheDice <= 30) {
      await journey1(page);
    } else if (rollTheDice > 30 && rollTheDice <= 40) {
      await journey2(page);
    } else {
      await journey3(page);
    }
  }
  finally {
    page.close();
    browser.close();
  }
}

async function journey1(page) {
  console.log('Running journey 1')
  await navigateToHomepage(page)
  await addToCart(page)
  await navigateToCart(page)
  await removeFromCart(page)
}

async function journey2(page) {
  console.log('Running journey 2')
  await navigateToHomepage(page)
  await addToCart(page)
  await navigateToCart(page)
  await navigateToCheckout(page)
  // no submitCheckout
}

async function journey3(page) {
  console.log('Running journey 3')
  await navigateToHomepage(page)
  await addToCart(page)
  await navigateToCart(page)
  await navigateToCheckout(page)
  await submitCheckout(page)
}

async function navigateToHomepage(page) {
  // Goto front page
  await page.goto(__ENV.FRONTEND_URL, { waitUntil: 'networkidle' });

  // get the add-to-cart buttons
  addToCartButtons = page.$$('//button')
  console.log(`Found ${addToCartButtons.length} add-to-cart buttons`);
}

async function addToCart(page) {
  // select a random add-to-cart and click it
  const randomAddToCartButton = addToCartButtons[Math.floor(Math.random() * addToCartButtons.length)];
  randomAddToCartButton.click();

  // wait for the cart to update
  const cartCount = page.waitForSelector('//a[contains(@class, "animated")]//div[text()="1"]');
  console.log(`Cart count: ${cartCount.innerText()}`);
}

async function navigateToCart(page) {
  await page.goto(__ENV.FRONTEND_URL + '/cart', { waitUntil: 'networkidle' });
}

async function removeFromCart(page) {
  page.click('//button[text()="Remove"]');
}

async function navigateToCheckout(page) {
  await page.goto(__ENV.FRONTEND_URL + '/checkout', { waitUntil: 'networkidle' });
}

async function submitCheckout(page) {
  await Promise.all([
    page.waitForNavigation(),
    page.locator('//button').click(),
  ]);
  // TODO: add confirmation check?
}