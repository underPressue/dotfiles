#!/usr/bin/env node
import { chromium } from 'playwright';

const url = process.argv[2] || 'about:blank';
import { homedir } from 'os';
import { join } from 'path';
const profileDir = join(homedir(), '.playwright-profiles');

console.log(`Opening ${url} with profile at ${profileDir}`);
console.log('Log in, then close the browser window to save session.\n');

const context = await chromium.launchPersistentContext(profileDir, {
  headless: false,
  channel: 'chrome',
  viewport: null,
  args: ['--start-maximized', '--disable-blink-features=AutomationControlled'],
});

const page = context.pages()[0] || await context.newPage();
await page.goto(url);
await page.waitForEvent('close', { timeout: 0 }).catch(() => {});
await context.close();

console.log('Session saved.');
