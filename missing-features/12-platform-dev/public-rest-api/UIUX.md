# UIUX: Public REST API

## Principles
- Documentation is the product. The portal is the primary touchpoint; everything copy-pastes and runs.
- Least-privilege by default. Scope picker defaults unchecked, with a plain-language hint per scope.
- Show the curl. Every endpoint shows a runnable example with the user's own token after sign-in.

## Screen 1: Developer Portal Home (Web)
```
+-------------------------------------------------------+
| Flicko Developers          [Docs] [Apps] [Status]     |
+-------------------------------------------------------+
| Build on Flicko                                        |
|                                                        |
|  curl -X POST https://api.flicko.io/v1/messages \      |
|       -H "Authorization: Bearer $TOKEN" \              |
|       -d '{"channel_id":"abc","body":"hi"}'             |
|                                                        |
|  [Copy]   [Run in sandbox]                             |
|                                                        |
| Quickstart                                              |
|  1. Create an app                                       |
|  2. Add a redirect URI                                  |
|  3. Authorize a server                                  |
|  4. Send your first message                             |
|                                                        |
| [Create app]   [Read the spec]                         |
+-------------------------------------------------------+
```

## Screen 2: App Detail (Credentials + Scopes)
```
+-------------------------------------------------------+
| Apps > Recipe Bot                          [Settings] |
+-------------------------------------------------------+
| Client ID:    flk_app_01H...                           |
| Client Secret: flk_sec_***  [Reveal once]  [Rotate]   |
|                                                        |
| Redirect URIs                                          |
|  https://recipebot.io/oauth/callback         [x]      |
|  + add URI                                            |
|                                                        |
| Scopes you may request                                |
|  [x] read:messages    read messages in approved chans |
|  [x] write:messages   send messages                   |
|  [ ] manage:plugins   install/remove plugins           |
|  [ ] read:members     list members                     |
|                                                        |
| API Tokens (server-to-server)                          |
|  Recipe Bot CI    scopes: write:messages   [revoke]   |
|  + create token                                        |
|                                                        |
| Rate limit usage (24h)                                 |
|  ###########.....  62% of 600 rpm cap                  |
+-------------------------------------------------------+
```
- Secret reveal banner: "We will not show this again. Save it now."
- Scope row hover shows example endpoints unlocked.

## Screen 3: OAuth Authorization (Mobile + Web)
```
+----------------------------------------------------+
|  Recipe Bot wants to:                               |
|                                                     |
|   - read messages in channels you choose            |
|   - send messages in channels you choose            |
|                                                     |
|  Acting on server:  [My Cooking Club v]             |
|                                                     |
|  Channels:  [#recipes] [+ choose]                   |
|                                                     |
|     [Cancel]              [Authorize]               |
|                                                     |
|  You can revoke this anytime in Settings > Apps.    |
+----------------------------------------------------+
```

## Motion
- Scope checkbox toggles 100 ms ease.
- Secret reveal slides 220 ms then auto-redacts after 30 s with a soft fade.
- Rate-limit usage bar animates in 400 ms once on mount.

## Accessibility
- Code blocks have a "Copy" button with `aria-label="Copy curl example"`.
- Scope checkboxes are real `<input type=checkbox>` with associated `<label>`.
- Authorization screen announces scope list as `<ul>` with each item readable.
- Color is never the only signal in rate-limit bar; percentage and remaining text always shown.
- Keyboard traversal in app detail: Tab through credentials, Enter to copy.

## Empty / Error States
- No apps yet: illustration + "Create your first app".
- Token revoked while in use: 401 problem+json with `type: token_revoked` and human-readable hint pointing to portal.
- Rate-limited: friendly 429 page in sandbox shows "Slow down. Try again in N seconds."

## Sandbox
- `developer.flicko.io/playground` lets a signed-in dev hit every documented endpoint with their token, with a "test server" pre-provisioned.
- Response panel shows headers including `X-RateLimit-*` so devs see the contract live.

## Copy Tone
- Plain, declarative, no marketing fluff. Examples use `recipe-bot` / `cooking-club` not `foo` / `bar`.
- Errors begin with what happened, then what to do: "Token expired. Refresh it via /oauth/token."
