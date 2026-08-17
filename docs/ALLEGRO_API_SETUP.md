# Allegro API setup

Optional. Without it PriceLens builds and runs fine — Allegro simply falls back to opening a search
link instead of showing offer cards in the app.

## Why the API and not the website

Allegro's public listing pages are served behind a DataDome anti-bot interstitial. Requesting one
programmatically returns a CAPTCHA page, not offers. PriceLens does not bypass challenges, so the
official REST API is the only supported route to real Allegro offer data.

## 1. Register an application

Go to <https://apps.developer.allegro.pl> and create an application.

| Field | Value | Why |
|---|---|---|
| Application type | **"Aplikacja ma dostęp do przeglądarki…"** (`authorization_code`) | Only this type issues a **Client Secret**, which the `client_credentials` flow needs. The `device_code` type creates a public client with no secret. |
| Purpose | "Tworzę aplikację tylko na swoje potrzeby" | Personal use |
| Redirect URI | `https://pricelens.local/oauth/callback` | Required by the form but never used — `client_credentials` performs no redirect. Any valid HTTPS URL works. |
| Permissions | `allegro:api:sale:offers:read` only | The form demands at least one. This is read-only and grants no personal or financial access. PriceLens never calls an account endpoint. |

Do **not** grant `profile`, `billing`, `payments`, `orders`, or any `:write` scope. The app has no
use for them.

## ⚠️ 2. Application verification is required — read this first

**Registering an application is not enough to search offers.** Allegro gates offer and product
search behind manual application verification. With valid, working credentials you will still get:

```
HTTP 403
{"code":"VerificationRequired",
 "userMessage":"No access to the specified resource.
                Access is possible only for verified applications."}
```

Verified against a real registered application (2026-08):

| Endpoint | Result |
|---|---|
| `POST /auth/oauth/token` (`client_credentials`) | ✅ 200 — token issued |
| `GET /sale/categories` | ✅ 200 — token is valid |
| `GET /sale/matching-categories` | ✅ 200 |
| `GET /offers/listing` | ❌ 403 `VerificationRequired` |
| `GET /sale/products` | ❌ 403 `AccessDeniedException` |

So the credentials work; the *permission* is missing. No code change unlocks this — request
verification for your application in the Allegro developer console. Until it is granted, PriceLens
correctly reports "Allegro app not verified" and falls back to a search link.

## 3. Generate a User-Agent

In the developer console, open **Generator i Walidator User-Agent** and generate one for your app.

> ⚠️ **This is not optional.** Allegro **blocks the API key** on any call with a missing or
> malformed `User-Agent` header. PriceLens sends it on both the token and listing requests, and
> refuses to call the API at all unless one is configured.

## 3. Add credentials locally

Copy the template and fill in your values:

```bash
cp PriceLens/Resources/Secrets.example.plist PriceLens/Resources/Secrets.plist
```

```xml
<key>clientID</key>
<string>your-client-id</string>
<key>clientSecret</key>
<string>your-client-secret</string>
<key>userAgent</key>
<string>the-generated-user-agent-string</string>
```

Then regenerate and build:

```bash
xcodegen generate
```

`Secrets.plist` is gitignored. **Never commit it.**

## How it is used

- `client_credentials` grant against `https://allegro.pl/auth/oauth/token`
- Token cached in an actor and refreshed a minute before expiry, so concurrent searches share one
- `GET https://api.allegro.pl/offers/listing?phrase=…` for public listings
- Offers are mapped to cards with title, price, image, seller, and product URL
- Delivery cost is only reported when the API states it — shipping is never assumed free

No user account is accessed. The application token reads public listing data only.

## Security

A credential bundled into an app **ships inside the binary and can be extracted from it.** No
amount of obfuscation changes that; it is inherent to calling a credentialed API directly from a
client with no server.

Consequences to accept before using this:

- Use a key you are willing to revoke.
- If it is abused, revoke and regenerate it in the Allegro console.
- Do not reuse a key that has access to anything that matters.

The only real fix is a small proxy that holds the secret server-side and forwards search requests.
That contradicts this project's no-backend goal, so it is not implemented here — but if you ship
PriceLens to real users, it is the correct next step.

## Troubleshooting

| Symptom | Likely cause |
|---|---|
| Allegro chip shows a fallback link | Credentials not configured, or `Secrets.plist` missing from the bundle |
| `Allegro auth failed (HTTP 401)` | Wrong Client ID/Secret, or the app type issued no secret |
| `Listing HTTP 403` | User-Agent missing/invalid, or the key was blocked |
| `API returned 0 usable offers` | Genuinely no Polish listings match — expected for many non-EU products |

Diagnostics for each provider are visible in Settings under a DEBUG build.
