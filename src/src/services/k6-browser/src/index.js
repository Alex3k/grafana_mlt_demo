import { chromium } from 'k6/experimental/browser';

export default async function() {
  const browser = chromium.launch({
    headless: true,
  });
  const context = browser.newContext();
  const page = context.newPage();

  try {
    // Goto front page
    await page.goto(__ENV.FRONTEND_URL + "/", { waitUntil: 'networkidle' });

    // get the add-to-cart buttons
    const addToCartButtons = page.$$('//button')
    console.log(`Found ${addToCartButtons.length} add-to-cart buttons`);

    // select one at random and click it
    const randomAddToCartButton = addToCartButtons[Math.floor(Math.random() * addToCartButtons.length)];
    randomAddToCartButton.click();

    // wait for the cart to update
    const cartCount = page.waitForSelector('//a[contains(@class, "animated")]//div[text()="1"]');
    console.log(`Cart count: ${cartCount.innerText()}`);

    // go to cart
    await page.goto(__ENV.FRONTEND_URL + '/cart', { waitUntil: 'networkidle' });

    // go to checkout
    await page.goto(__ENV.FRONTEND_URL + '/checkout', { waitUntil: 'networkidle' });

    await Promise.all([
      page.waitForNavigation(),
      page.locator('//button').click(),
    ]);
    // TODO: add confirmation check?
  } finally {
    page.close();
    browser.close();
  }
}