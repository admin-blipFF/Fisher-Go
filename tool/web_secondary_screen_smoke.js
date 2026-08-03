const fs = require('node:fs');
const path = require('node:path');
const { chromium } = require('playwright');

const args = Object.fromEntries(
  process.argv.slice(2).flatMap((value) => {
    const separator = value.indexOf('=');
    if (separator < 0) return [];
    return [[value.slice(0, separator).replace(/^--/, ''), value.slice(separator + 1)]];
  }),
);

const targetUrl = args.url || 'https://fisher-go.app/';
const outputPath = path.resolve(args.output || 'tmp/web-secondary-screen-smoke.json');

async function waitForGuest(page) {
  await page.locator('flutter-view').waitFor({
    state: 'attached',
    timeout: 30000,
  });
  const guestButton = page.getByRole('button', {name: '訪客遊玩', exact: true});
  for (let attempt = 0; attempt < 60; attempt += 1) {
    if (await guestButton.count() > 0 &&
        await guestButton.first().isVisible().catch(() => false)) {
      await guestButton.first().click();
      return;
    }
    const placeholder = page.locator('flt-semantics-placeholder');
    if (await placeholder.count() > 0) {
      await placeholder.first().evaluate((element) => element.click()).catch(() => {});
    }
    await page.waitForTimeout(250);
  }
  throw new Error('Semantics did not expose the guest action');
}

async function closeStartupOverlays(page) {
  const skipTutorial = page.getByRole('button', {name: '略過', exact: true});
  if (await skipTutorial.count() > 0 &&
      await skipTutorial.first().isVisible().catch(() => false)) {
    await skipTutorial.first().click();
  }
  for (let attempt = 0; attempt < 40; attempt += 1) {
    const identityVisible = await page.getByText('開始 FisherGO', {exact: true}).count() > 0 &&
      await page.getByText('開始 FisherGO', {exact: true}).first().isVisible().catch(() => false);
    const tutorialVisible = await skipTutorial.count() > 0 &&
      await skipTutorial.first().isVisible().catch(() => false);
    if (!identityVisible && !tutorialVisible) return;
    await page.waitForTimeout(250);
  }
  throw new Error('Identity or tutorial overlay remained visible');
}

async function openSecondaryScreen(page, screen) {
  const entry = page.getByRole('button', {name: screen.entry, exact: true});
  await entry.waitFor({state: 'visible', timeout: 20000});
  await entry.click();
  await page.getByText(screen.title, {exact: true}).waitFor({
    state: 'visible',
    timeout: 20000,
  });
  const stableContent = screen.stableRole
    ? page.getByRole(screen.stableRole, screen.stableName
        ? {name: screen.stableName}
        : undefined).last()
    : page.getByText(screen.stable, {exact: true}).last();
  await stableContent.waitFor({
    state: 'attached',
    timeout: 20000,
  });
  await stableContent.scrollIntoViewIfNeeded();
  await stableContent.waitFor({state: 'visible', timeout: 10000});
  const screenshot = `output/playwright/web-secondary-${screen.slug}.png`;
  await page.screenshot({path: screenshot});
  const returnButton = page.getByRole('button', {name: '返回地圖', exact: true});
  await returnButton.waitFor({state: 'visible', timeout: 10000});
  await returnButton.click();
  await page.locator('canvas.maplibregl-canvas').waitFor({
    state: 'attached',
    timeout: 20000,
  });
  return {entry: screen.entry, title: screen.title, stable: screen.stable, screenshot};
}

async function openProfileShopFromMap(page, shop) {
  const accountEntry = page.getByRole('button', {name: '帳戶', exact: true});
  await accountEntry.waitFor({state: 'visible', timeout: 20000});
  await accountEntry.click();
  await page.getByText('個人資料', {exact: true}).waitFor({
    state: 'visible',
    timeout: 20000,
  });

  const shopButton = page.getByRole('button', {name: shop.shop, exact: true});
  await page.mouse.move(195, 700);
  for (let attempt = 0; attempt < 10; attempt += 1) {
    if (await shopButton.count() > 0 &&
        await shopButton.first().isVisible().catch(() => false)) {
      break;
    }
    await page.mouse.wheel(0, 650);
    await page.waitForTimeout(250);
  }
  await shopButton.waitFor({state: 'attached', timeout: 10000});
  await shopButton.scrollIntoViewIfNeeded();
  await shopButton.waitFor({state: 'visible', timeout: 10000});
  await shopButton.click();
  await page.getByText(shop.shop, {exact: true}).last().waitFor({
    state: 'visible',
    timeout: 20000,
  });

  const stableText = page.getByText(shop.match || shop.stable, {exact: false}).last();
  const stableAction = shop.stableRole
    ? page.getByRole(shop.stableRole, shop.stableName
        ? {name: shop.stableName}
        : undefined).first()
    : null;
  let stableContent = null;
  await page.mouse.move(195, 700);
  for (let attempt = 0; attempt < 10; attempt += 1) {
    if (await stableText.count() > 0 &&
        await stableText.first().isVisible().catch(() => false)) {
      stableContent = stableText;
      break;
    }
    if (stableAction && await stableAction.count() > 0 &&
        await stableAction.first().isVisible().catch(() => false)) {
      stableContent = stableAction;
      break;
    }
    await page.mouse.wheel(0, 700);
    await page.waitForTimeout(250);
  }
  if (!stableContent) {
    throw new Error(`Shop content did not become accessible: ${shop.shop}`);
  }
  await stableContent.waitFor({state: 'attached', timeout: 10000});
  await stableContent.scrollIntoViewIfNeeded();
  await stableContent.waitFor({state: 'visible', timeout: 10000});
  const screenshot = `output/playwright/web-secondary-${shop.slug}.png`;
  await page.screenshot({path: screenshot});

  const backButton = page.getByRole('button', {name: '返回', exact: true});
  await backButton.waitFor({state: 'visible', timeout: 10000});
  await backButton.click();
  await page.getByText('個人資料', {exact: true}).waitFor({
    state: 'visible',
    timeout: 10000,
  });

  const returnButton = page.getByRole('button', {name: '返回地圖', exact: true});
  await returnButton.waitFor({state: 'visible', timeout: 10000});
  await returnButton.click();
  await page.locator('canvas.maplibregl-canvas').waitFor({
    state: 'attached',
    timeout: 20000,
  });
  return {
    entry: '帳戶',
    shop: shop.shop,
    title: shop.shop,
    stable: shop.stable,
    screenshot,
  };
}

async function main() {
  fs.mkdirSync(path.dirname(outputPath), {recursive: true});
  fs.mkdirSync(path.resolve('output/playwright'), {recursive: true});
  const browser = await chromium.launch({headless: true});
  const context = await browser.newContext({
    viewport: {width: 390, height: 844},
    geolocation: {latitude: 22.3819, longitude: 114.1874, accuracy: 15},
    permissions: ['geolocation'],
  });
  const page = await context.newPage();
  const startedAt = Date.now();
  try {
    await page.goto(targetUrl, {waitUntil: 'domcontentloaded', timeout: 60000});
    await waitForGuest(page);
    await closeStartupOverlays(page);
    await page.locator('canvas.maplibregl-canvas').waitFor({
      state: 'attached',
      timeout: 30000,
    });

    const screens = [
      {entry: '帳戶', title: '個人資料', stableRole: 'progressbar', slug: 'account'},
      {
        entry: '圖鑑',
        title: '香港魚類圖鑑',
        stableRole: 'checkbox',
        stableName: '全部',
        slug: 'encyclopedia',
      },
      {entry: '上魚獲', title: '魚獲記錄（離線佇列）', stable: '選擇魚獲相片', slug: 'catch-log'},
      {
        entry: '排行',
        title: '比賽活動',
        stableRole: 'group',
        stableName: /^真實捕獲排行榜，共 \d+ 項$/,
        slug: 'leaderboard',
      },
    ];
    const results = [];
    for (const screen of screens) {
      results.push(await openSecondaryScreen(page, screen));
    }
    const profileShops = [
      {
        shop: '裝備商店',
        stable: '可購買並裝備到外圍裝備槽：魚竿、釣箱、冰箱、上衣、褲、鞋、帽、防曬面罩',
        match: '可購買並裝備到外圍裝備槽',
        stableRole: 'button',
        stableName: '購買',
        slug: 'account-equipment-shop',
      },
      {
        shop: '釣魚道具商城',
        stable: '魚餌、誘餌、探測器與掃描券用於釣點刷魚、解鎖灰章及相片驗證活動。',
        match: '魚餌、誘餌、探測器與掃描券',
        stableRole: 'button',
        stableName: /金幣/,
        slug: 'account-fishing-item-shop',
      },
    ];
    for (const shop of profileShops) {
      results.push(await openProfileShopFromMap(page, shop));
    }
    const output = {
      smoke: 'FisherGO Web secondary screens',
      url: targetUrl,
      viewport: '390x844',
      duration_ms: Date.now() - startedAt,
      screens: results,
      api23_excluded: true,
    };
    fs.writeFileSync(outputPath, `${JSON.stringify(output, null, 2)}\n`);
    console.log(JSON.stringify(output, null, 2));
  } finally {
    await context.close();
    await browser.close();
  }
}

main().catch((error) => {
  console.error(error.stack || error);
  process.exitCode = 1;
});
