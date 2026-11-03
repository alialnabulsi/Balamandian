import { expect, test } from '@playwright/test';

const screens = [
  'splash',
  'campus',
  'community',
  'assistant',
  'getting-started',
  'sign-up',
  'sign-in',
  'account-setup',
];

for (const screen of screens) {
  test(`${screen}: assets, typography and responsive layout`, async ({ page }, info) => {
    const errors: string[] = [];
    const external: string[] = [];
    page.on('pageerror', (error) => errors.push(error.message));
    page.on('request', (request) => {
      if (!request.url().startsWith('http://127.0.0.1:5176')) external.push(request.url());
    });
    const theme = info.project.name === 'mobile-dark' ? 'dark' : 'light';
    await page.goto(`/?canvas&hold&screen=${screen}&theme=${theme}`);
    await expect(page.getByTestId('onboarding')).toHaveAttribute('data-screen', screen);
    await page.evaluate(() => document.fonts.ready);
    const metrics = await page.evaluate(() => ({
      overflow: document.documentElement.scrollWidth > window.innerWidth,
      missing: [...document.images]
        .filter((image) => !image.complete || !image.naturalWidth)
        .map((image) => image.src),
      font: getComputedStyle(document.querySelector('h1')!).fontFamily,
      background: getComputedStyle(document.querySelector('.onboarding')!).backgroundColor,
    }));
    expect(metrics.overflow).toBe(false);
    expect(metrics.missing).toEqual([]);
    expect(metrics.font).toContain('Inter');
    await expect(page.locator('.onb-brand-dot, .onb-step-label')).toHaveCount(0);
    if (screen === 'assistant') {
      await expect(page.locator('.onb-assistant-mascot')).toBeVisible();
      await expect(page.locator('.onb-assistant-heading svg')).toHaveCount(0);
    }
    if (screen === 'getting-started')
      await expect(page.getByRole('button', { name: 'Log in with SIS' })).toHaveCSS(
        'background-color',
        'rgb(255, 207, 54)',
      );
    expect(errors).toEqual([]);
    expect(external).toEqual([]);
    if (theme === 'dark') expect(metrics.background).toBe('rgb(16, 24, 33)');
    await page.screenshot({
      path: `docs/screenshots/${info.project.name}/${screen}.png`,
      fullPage: true,
      animations: 'disabled',
    });
  });
}

test('tour navigation and signup remain UI-only', async ({ page }, info) => {
  test.skip(info.project.name !== 'mobile-light');
  await page.goto('/?screen=campus');
  await expect(page.getByRole('button', { name: 'Back', exact: true })).toHaveCount(0);
  await page.getByRole('button', { name: 'Continue', exact: true }).click();
  await expect(page.getByTestId('onboarding')).toHaveAttribute('data-screen', 'community');
  await page.keyboard.press('ArrowRight');
  await expect(page.getByTestId('onboarding')).toHaveAttribute('data-screen', 'assistant');
  await expect(page.locator('.onb-step-count')).toHaveCount(0);
  await page.getByRole('button', { name: 'Get started', exact: true }).click();
  await page.getByRole('button', { name: 'Sign up with SIS', exact: true }).click();
  await page.getByRole('button', { name: 'Continue', exact: true }).click();
  await expect(page.getByText('Enter your SIS ID.', { exact: true })).toBeVisible();
  await expect(page.getByLabel('SIS ID', { exact: true })).toBeFocused();
  await page.getByLabel('SIS ID', { exact: true }).fill('entered-identifier');
  await page.getByLabel('Password', { exact: true }).fill('typed-password');
  await page.getByRole('button', { name: 'Show password' }).click();
  await expect(page.getByLabel('Password', { exact: true })).toHaveAttribute('type', 'text');
  await page.getByRole('button', { name: 'Continue', exact: true }).click();
  await expect(page.getByTestId('onboarding')).toHaveAttribute('data-screen', 'sign-up');
  await expect(page.getByLabel('Password', { exact: true })).toHaveValue('');
  await expect(page.getByRole('status')).toContainText('No service is connected');
  expect(
    await page.evaluate(() => ({ local: localStorage.length, session: sessionStorage.length })),
  ).toEqual({ local: 0, session: 0 });
});

test('photo and bio are the only editable profile values', async ({ page }, info) => {
  test.skip(info.project.name !== 'mobile-light');
  await page.goto('/?screen=account-setup');
  await expect(page.getByText('Provided by SIS', { exact: true })).toHaveCount(3);
  await expect(page.locator('.onboarding input:not([type=file]), .onboarding select')).toHaveCount(
    0,
  );
  await page.getByLabel('Profile photo', { exact: true }).setInputFiles({
    name: 'invalid.txt',
    mimeType: 'text/plain',
    buffer: Buffer.from('invalid image'),
  });
  await expect(page.getByRole('alert')).toContainText('JPG, PNG or WebP');
  await page
    .getByLabel('Profile photo', { exact: true })
    .setInputFiles('src/assets/images/onboarding-main-campus.png');
  await expect(page.getByAltText('Your selected profile photo')).toBeVisible();
  await page.getByRole('button', { name: 'Remove photo', exact: true }).click();
  await expect(page.getByAltText('Your selected profile photo')).toHaveCount(0);
  await page.getByRole('textbox', { name: 'Bio' }).fill('Personal bio entered in the form');
  await expect(page.getByText('32 / 240')).toBeVisible();
  await page.getByRole('button', { name: 'Finish setup', exact: true }).click();
  await expect(page.getByRole('status')).toContainText('No data was saved');
});

test('pending, error, narrow widths and reduced motion', async ({ page }, info) => {
  test.skip(info.project.name !== 'mobile-light');
  await page.goto('/?canvas&screen=sign-in&pending&error');
  await expect(page.getByRole('button', { name: /Please wait/ })).toBeDisabled();
  await expect(page.getByRole('alert')).toContainText('could not be completed');
  for (const width of [320, 390]) {
    await page.setViewportSize({ width, height: 844 });
    for (const screen of screens) {
      await page.goto(`/?canvas&hold&screen=${screen}`);
      expect(
        await page.evaluate(() => document.documentElement.scrollWidth <= window.innerWidth),
      ).toBe(true);
    }
  }
  await page.goto('/?canvas&hold&screen=splash');
  expect(
    await page.locator('.onb-coin').evaluate((node) => getComputedStyle(node).animationName),
  ).toBe('none');
});

test('splash advances and sign-in/guest emit events without building Home', async ({
  page,
}, info) => {
  test.skip(info.project.name !== 'mobile-light');
  await page.goto('/');
  await expect(page.getByTestId('onboarding')).toHaveAttribute('data-screen', 'campus');
  await page.getByRole('button', { name: 'Skip', exact: true }).click();
  await page.getByRole('button', { name: 'Continue as guest', exact: true }).click();
  await expect(page.getByRole('status')).toContainText('Guest entry requested');
  await page.getByRole('button', { name: 'Log in with SIS', exact: true }).click();
  await page.getByLabel('Email or SIS ID', { exact: true }).fill('entered-identifier');
  await page.getByLabel('Password', { exact: true }).fill('typed-password');
  await page.getByRole('button', { name: 'Log in', exact: true }).click();
  await expect(page.getByRole('status')).toContainText('No service is connected');
  await expect(page.getByTestId('onboarding')).toHaveAttribute('data-screen', 'sign-in');
});

test('coin animation and curved transition work with motion enabled', async ({ page }, info) => {
  test.skip(info.project.name !== 'mobile-light');
  await page.emulateMedia({ reducedMotion: 'no-preference' });
  await page.goto('/?canvas&hold&screen=splash');
  const coin = page.locator('.onb-coin');
  expect(await coin.evaluate((node) => getComputedStyle(node).animationName)).toBe('onb-coin-flip');
  const initialTransform = await coin.evaluate((node) => getComputedStyle(node).transform);
  await page.waitForTimeout(300);
  expect(await coin.evaluate((node) => getComputedStyle(node).transform)).not.toBe(
    initialTransform,
  );
  await page.goto('/?canvas&screen=campus');
  await page.getByRole('button', { name: 'Continue', exact: true }).click();
  await expect(page.getByTestId('onboarding')).toHaveAttribute('aria-busy', 'true');
  await page.evaluate(() => {
    for (let i = 0; i < 5; i++) document.querySelector<HTMLButtonElement>('.onb-primary')?.click();
  });
  await expect(page.getByTestId('onboarding')).toHaveAttribute('data-screen', 'community');
  await expect(page.getByTestId('onboarding')).toHaveAttribute('aria-busy', 'false');
});
