const { chromium } = require('playwright');
(async () => {
  const browser = await chromium.launch({ headless: true, args: ['--no-sandbox'] });
  const page = await browser.newPage();
  await page.setViewportSize({ width: 375, height: 812 });
  await page.goto('http://localhost:3847/prototype.html');
  await page.waitForTimeout(1000);
  await page.screenshot({ path: '/vol1/@apphome/trim.openclaw/data/workspace/accounting-app/screenshot.png', fullPage: false });
  await browser.close();
  console.log('done');
})();
