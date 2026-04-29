# Northstar

Northstar is a Flutter app for building complete travel plans from a small trip brief. The first app shell focuses on a clean mobile UI for iOS and Android:

- Trip brief input for dates, origin, destination, interests, and constraints.
- Generated itinerary view with simple day-by-day cards.
- Calendar timeline that separates anchors from flexible suggestions.
- Reminder and readiness screen for bookings, documents, packing, and notifications.
- Agent control panel that models the LLM, tools, state, constraints, and evaluation layers.

## Run

```sh
flutter run \
  --dart-define=SUPABASE_URL=https://fukhtizbaoovlmxikmou.supabase.co \
  --dart-define=SUPABASE_PUBLISHABLE_KEY=your-supabase-publishable-key \
  --dart-define=CLERK_PUBLISHABLE_KEY=your-clerk-publishable-key \
  --dart-define=SUPABASE_AUTH_REDIRECT_URL=com.morrison.northstar://login-callback \
  --dart-define=MAPBOX_ACCESS_TOKEN=your-mapbox-public-token \
  --dart-define=AGENT_SERVER_URL=http://localhost:3000
```

`SUPABASE_PUBLISHABLE_KEY` is the public client key from Supabase. Older
commands that pass `SUPABASE_ANON_KEY` still work as a fallback, but new setup
should use `SUPABASE_PUBLISHABLE_KEY`.

`SUPABASE_AUTH_REDIRECT_URL` is where Supabase email confirmations and password
reset links return after verification. The default is
`com.morrison.northstar://login-callback`, which is registered in the iOS and
Android native projects.

`CLERK_PUBLISHABLE_KEY` is required for the Clerk sign-in/sign-up flow. The app
defaults to Clerk auth now; if this value is missing, it shows a configuration
message instead of falling back to the old Supabase Auth screens. Pass
`--dart-define=LEGACY_SUPABASE_AUTH=true` only when intentionally testing the
legacy auth UI.

`MAPBOX_ACCESS_TOKEN` is used by the Flutter app for Mapbox map tiles and
driving routes on the Map tab. Use a public Mapbox token with URL restrictions
for deployed web builds when applicable. Native mobile apps cannot use Mapbox
URL restrictions.

## iOS TestFlight Builds

TestFlight builds do not inherit terminal environment variables from previous
`flutter run` commands or plain Xcode archives. Build the IPA through Flutter so
the client-safe Dart defines are compiled into the app.

Create a local release env file:

```sh
cp config/ios.release.env.example config/ios.release.env
```

Fill in the real publishable/client-safe values in `config/ios.release.env`,
then build the signed IPA:

```sh
scripts/build_ios_ipa.sh
```

Upload the generated IPA from `build/ios/ipa/` with Xcode Organizer or Apple
Transporter, then install the new build from TestFlight.

Do not put server secrets in `config/ios.release.env`. Keep
`SUPABASE_SECRET_KEY`, `CLERK_SECRET_KEY`, `OPENAI_API_KEY`, `TAVILY_API_KEY`,
and `FOURSQUARE_API_KEY` only on the backend.

## Clerk Auth

The app renders Clerk authentication by default. Pass `CLERK_PUBLISHABLE_KEY`
to Flutter as a `--dart-define`, using the publishable key from Clerk's API keys
page, normally prefixed with `pk_test_` for development and `pk_live_` for
production.

Before Clerk can be the production auth system for trip data, configure the
Supabase side too:

- In Clerk, enable email/password and any social providers you want, such as
  Google and Apple. Configure first and last name as required attributes if the
  product should always collect names during sign-up.
- In Supabase, add Clerk as a Third-Party Auth provider so Supabase accepts
  Clerk session tokens.
- Update RLS policies to use Clerk token claims such as `auth.jwt()->>'sub'`
  instead of Supabase Auth's `auth.uid()`.
- Migrate `user_id` columns from Supabase Auth UUIDs to Clerk user IDs, or add
  a mapping table if you need to preserve existing Supabase users.
- Update the Fly server to verify Clerk tokens directly or rely on the same
  Supabase Third-Party Auth trust path before using Clerk in production.

Needed Clerk values:

- `CLERK_PUBLISHABLE_KEY` for the Flutter app.
- `CLERK_SECRET_KEY` for the Fly server if the server verifies Clerk tokens.
- Your Clerk domain or issuer, for example `your-app.clerk.accounts.dev`, when
  configuring Supabase Third-Party Auth.
- Confirmation that Apple, Google, password, email verification, and self-delete
  should be enabled in the Clerk dashboard.

## Supabase Auth Redirects

In the Supabase dashboard, open Authentication > URL Configuration:

- Set Site URL to `com.morrison.northstar://login-callback` for a mobile-only
  app, or to your production web URL if you have one.
- Add `com.morrison.northstar://login-callback` to Redirect URLs.

If the email templates have been customized, make sure confirmation and recovery
links use `{{ .RedirectTo }}` rather than hardcoding `{{ .SiteURL }}`.

For Google and Apple buttons, enable the matching providers in Supabase
Authentication > Providers. In the Google and Apple developer consoles, use the
callback URL shown on each Supabase provider page, normally:

```text
https://fukhtizbaoovlmxikmou.supabase.co/auth/v1/callback
```

## Server Env

The Node agent server lives in `server/`. For local development:

```sh
cd server
SUPABASE_URL=https://fukhtizbaoovlmxikmou.supabase.co \
SUPABASE_SECRET_KEY=your-supabase-secret-key \
OPENAI_API_KEY=your-openai-api-key \
TAVILY_API_KEY=your-tavily-api-key \
FOURSQUARE_API_KEY=your-foursquare-api-key \
MAPBOX_ACCESS_TOKEN=your-mapbox-access-token \
PORT=3000 \
npm run dev
```

For Fly.io, set the same server-only values as secrets:

```sh
cd server
fly secrets set \
  SUPABASE_URL=https://fukhtizbaoovlmxikmou.supabase.co \
  SUPABASE_SECRET_KEY=your-supabase-secret-key \
  OPENAI_API_KEY=your-openai-api-key \
  TAVILY_API_KEY=your-tavily-api-key \
  FOURSQUARE_API_KEY=your-foursquare-api-key \
  MAPBOX_ACCESS_TOKEN=your-mapbox-access-token
```

Do not put `SUPABASE_SECRET_KEY`, `OPENAI_API_KEY`, `TAVILY_API_KEY`, or
`FOURSQUARE_API_KEY` into Flutter `--dart-define` values. Keep
`MAPBOX_ACCESS_TOKEN` on the server too; the agent uses it for Mapbox Search Box
geocoding of trip stops. The Flutter app also needs a public Mapbox token for
tiles and route estimates.

## Validate

```sh
flutter analyze
flutter test
cd server && npm run build && npm test
```

## Product Direction

The AI execution loop should belong to the model, while the app controls permissions, tool scope, run state, timeouts, and output validation. The UI should stay simple: Northstar asks for only the inputs needed, then turns the resulting plan into readable calendars, lists, reminders, and notifications.
