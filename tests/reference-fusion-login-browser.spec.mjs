import { test, expect } from '@playwright/test';

const base = 'https://totichat-login-review-20261013.vercel.app';
for (const width of [360, 390, 430]) {
  test('TotiChat Google login UI renders on '+width+'px viewport', async ({ page }) => {
    await page.setViewportSize({ width, height: 800 });
    const consoleErrors=[];
    page.on('pageerror', err=>consoleErrors.push(String(err).slice(0,250)));
    const response=await page.goto(base+'/', {waitUntil:'domcontentloaded',timeout:30000});
    expect(response?.status()).toBe(200);
    await expect(page.getByRole('button',{name:/Continue with Google/})).toBeVisible();
    await expect(page.locator('#signed-out-panel')).toBeVisible();
    await expect(page.locator('#signed-in-panel')).toBeHidden();
    await expect(page.locator('.brand-name')).toHaveText('TotiChat');
    const layout=await page.evaluate(()=>({
      windowWidth:innerWidth,
      scrollWidth:document.documentElement.scrollWidth,
      buttonWidth:document.getElementById('google-button').getBoundingClientRect().width,
      headingWidth:document.getElementById('signin-title').getBoundingClientRect().width
    }));
    expect(layout.scrollWidth).toBeLessThanOrEqual(layout.windowWidth+1);
    expect(layout.buttonWidth).toBeGreaterThan(250);
    expect(layout.headingWidth).toBeGreaterThan(240);
    await page.screenshot({ path:'test-results/login-mobile-'+width+'.png',fullPage:true,animations:'disabled' });
    expect(consoleErrors,consoleErrors.join('\n')).toEqual([]);
  });
}

test('Desktop split-screen and accessible Google button', async ({page})=>{
  await page.setViewportSize({width:1280,height:900});
  await page.goto(base+'/', {waitUntil:'domcontentloaded'});
  await expect(page.locator('.story')).toBeVisible();
  await expect(page.locator('.signin')).toBeVisible();
  await expect(page.getByRole('button',{name:/Continue with Google/})).toBeVisible();
  const geometry=await page.locator('.story').boundingBox();
  expect(geometry?.width).toBeGreaterThan(450);
  await page.screenshot({ path:'test-results/login-desktop.png',fullPage:true,animations:'disabled' });
});
