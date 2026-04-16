Read and summarize a Twitter/X post using the Playwright browser.

Uses Chrome DevTools MCP tools to navigate to the tweet URL and extract content from the page snapshot.

## Instructions

1. Use `mcp__chrome-devtools__navigate_page` to go to the provided X.com URL
2. Use `mcp__chrome-devtools__wait_for` with a short timeout (5000ms) to let the tweet content load
3. From the snapshot, extract: author name, handle, tweet text, media descriptions, engagement stats (replies, reposts, likes, bookmarks, views), and timestamp
4. If the tweet is part of a thread, try clicking "Read replies" or scrolling to get more context
5. Summarize the tweet content for the user

## Notes

- X.com renders most single tweets without login — the page title and article elements contain the content
- If login is required, instruct the user to run: `node ~/.claude/scripts/playwright-login.mjs https://x.com`
- The tweet text is usually in an `article` element in the page snapshot
- Images are linked but not directly viewable — mention them if present and use `take_screenshot` if the user wants to see them

ARGUMENTS: $ARGUMENTS
