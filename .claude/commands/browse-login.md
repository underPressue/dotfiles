Login to a website for authenticated browsing.

Opens a visible browser so you can manually log in. Cookies persist for headless browsing afterwards.

## Usage

Run this in your terminal:

```
node ~/.claude/scripts/playwright-login.mjs <url>
```

Examples:
- `node ~/.claude/scripts/playwright-login.mjs https://x.com`
- `node ~/.claude/scripts/playwright-login.mjs https://reddit.com`
- `node ~/.claude/scripts/playwright-login.mjs https://github.com`

After logging in, close the browser window. Your session is saved to `~/.playwright-profiles/` and will be used by the Playwright MCP server for authenticated headless browsing.
