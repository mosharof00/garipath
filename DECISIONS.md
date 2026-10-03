# Decisions

## 1. Architecture and state management

**Feature-first layers.** `features/location`, `features/routing` and `features/navigation` each have `domain` (models, interfaces, typed failures), `data` (channel, HTTP, ticker) and `presentation` (controllers). Everything that is just maths lives in `core/` as **pure Dart**, with no Flutter and no GetX: geometry, the polyline decoder, the animator and the heading smoother. That code is driven by an injected time step, so tests are exact and fast. There are 259 tests, most of them in this layer.

**GetX, used narrowly.** I chose GetX because it gives small reactive state (`Rx` + `Obx`) and simple dependency injection with very little code, which suits one screen. The rules I kept to:
- **One place registers objects:** `NavigationBinding`. Controllers receive their dependencies through constructors, so tests build them with hand-written fakes and never touch global lookups.
- **No GetX navigation, snackbars or context helpers.** Controllers never touch widgets.
- **`Obx` wraps the smallest widget possible.** Only the car layer listens to the per-frame value. The HUD text listens to a separate value updated at most every 200 ms, so text isn't rebuilt 60 times a second.

*Trade-off:* Bloc would give stricter event/state separation and better tooling. For one screen with three controllers, it would add ceremony without changing correctness. The narrow rules above keep GetX's global-service style from spreading.

## 2. Flutter ↔ native location bridge

**Channels.** A `MethodChannel` (`com.mosharof.garipath/location`) handles commands: `checkPermission`, `requestPermission`, `isLocationServiceEnabled`, `getCurrentLocation(timeoutMs)`, `openAppSettings` and `openLocationSettings`. An `EventChannel` (`com.mosharof.garipath/location_updates`) carries the continuous stream. All names, keys and error codes are constants in one Dart file, `location_channel_contract.dart`, mirrored in Kotlin.

I used raw channels instead of Pigeon. The surface is six methods and one stream, and hand-written channels are easier to read in a review and need no code generation.

**Errors.** Native code always replies with a `PlatformException` code:
- `PERMISSION_DENIED`, `PERMISSION_DENIED_FOREVER`
- `SERVICES_DISABLED`, `TIMEOUT`, `LOCATION_UNAVAILABLE`
- `REQUEST_IN_PROGRESS`, `ACTIVITY_UNAVAILABLE`
- `NOT_SUPPORTED`, `INVALID_ARGUMENT`, `UNKNOWN`

Dart maps each code to a **sealed** `LocationException` subclass, so the UI's `switch` is exhaustive: a new error type is a compile error until the UI handles it. A `MissingPluginException` maps to `LocationNotSupported`, so a platform with no native code shows a clear card instead of crashing. That is why iOS could be added **without changing any Dart code**, and it was. The Swift plugin (`CLLocationManager`) maps iOS's rules onto the same codes:
- "Don't Allow" is reported as `deniedForever`, because iOS never shows the dialog again.
- `denied` caused by device-wide Location Services being off is reported as `SERVICES_DISABLED`.

**Permanent denial (Android).** Android doesn't report "denied forever" directly. The plugin stores "we have asked before" in SharedPreferences. If the permission is denied, we've asked before, and `shouldShowRequestPermissionRationale` is false, the status is `deniedForever` and the card offers Open Settings.

**One-shot fix.** `getCurrentLocation` uses a `CurrentLocationRequest` and accepts a cached fix up to 30 s old. A watchdog fires at the timeout, and a once-only reply guard prevents double replies. If the request fails, a last-known location under 60 s old is used.

**Stream lifecycle.**
- `onListen` checks permission and services first and reports problems through `events.error`. It never throws.
- `onCancel` removes the location callback. It is idempotent.
- Detach handling depends on the cause. A configuration-change detach only drops the activity reference. A real detach from the activity or the engine also stops updates and answers any pending permission request.
- Dart cancels its subscription when the app is `hidden`/`paused` and resubscribes on `resumed`. `inactive` is ignored, because the permission dialog and the notification shade also trigger it.
- Checked on a device with `dumpsys location`: 0 requests in the background, exactly 1 after returning, including with "Don't keep activities" on.

## 3. Interpolation and bearing

1. **Clean the route.** Drop NaN points, drop points closer than 0.5 m to the previous one, and always keep the real destination. After this, every segment has length > 0, so there's no division by zero and no undefined direction.
2. **Cumulative distances.** Haversine distances (R = 6,371,008.8 m) are added up per point. Position at distance *d*: binary-search the segment, then interpolate linearly within it.
3. **Constant speed.** Progress is stored in **metres**, not point index: `distance += 13.9 m/s × multiplier × dt`. A route with 2 points and one with 200 points play identically; a test checks they stay within 0.5 m. `dt` comes from a `Ticker` and is **capped at 0.1 s**, so a slow frame or a return from the background can't make the car jump.
4. **Bearing.** The car points at the spot **15 m ahead** on the route, so it starts turning just before a corner. Very short jagged segments are averaged out.
5. **Smoothing.** `turn = ((target − current + 540) % 360) − 180` is always the short way: 350° → 10° turns 20°, not 340°. Each frame moves the heading by `turn × (1 − e^(−dt/τ))`, with τ = 0.12 s ÷ multiplier. It gives the same result at any frame rate and never overshoots. The first frame snaps, so the car doesn't spin when it appears.
6. **Guards.** A frame containing any non-finite value is never published; the previous frame is kept. A fuzz test with 1,000 random routes (duplicates, 1e-9° steps, NaN points) checks every frame is finite and the heading stays in [0, 360).

## 4. Flavor configuration

- **Gradle `productFlavors`** (`dev`, `prod`) set the application id suffix, the app name (`resValue`) and a dev launcher icon (`src/dev/res`).
- **Flutter's `appFlavor`** passes the flavor to Dart, where it is mapped to a typed `const AppConfig` (`dev_config.dart`, `prod_config.dart`). Switching the routing server is one string in one file.
- **No flavor = immediate, clear error.** A wrong build never runs silently with the wrong config.

*Rejected:*
- `--dart-define-from-file`: easy to forget, and nothing ties it to the native id or name.
- Separate `main_dev.dart` entry points: duplicated wiring.
- JSON assets: untyped, and read at runtime.

## 5. When there is no location

If permission is denied, services are off, or there's no fix indoors, the user can **pick a start point on the map**. The next long-press sets the start (green pin), and a chip switches back to the device location.

Blocking would make the core feature unusable for exactly the users who refuse permission. A silent default start (for example a city centre) would draw a route from a place the user isn't. An explicit manual start keeps the app useful and honest.

## 6. Before shipping to production

- **Battery:** today the stream uses high accuracy every 2 s / 5 m whenever the map is visible. In production: balanced-power priority while idle, high accuracy only while navigating, and intervals that adapt to speed.
- **Background location:** a foreground service with a notification, `ACCESS_BACKGROUND_LOCATION` with a Play policy justification, and on iOS "Always" permission with background modes.
- **Routing server:** the public OSRM demo server has no SLA. Use a self-hosted OSRM, Valhalla or GraphHopper (regional extract, autoscaled), or a paid provider with traffic data.
- **Tiles:** our own tile server or a commercial CDN, ideally vector tiles with on-device caching (which also fixes the grey map offline).
- **Cost at scale:** requests per trip × daily trips. Cache routes for repeated origin/destination pairs, limit reroutes per trip, debounce on the client (already done) and rate-limit on the server.
- **Reliability:** retries with backoff and jitter, crash reporting and analytics, a release signing config in CI.
- **Quality:** localisation (Bangla), accessibility (semantics on all controls), integration tests on CI devices.

## 7. Deliberately left out

- **Navigation camera:** tilt, and rotating the map with the heading. The map rotation is locked so the car's heading equals its screen angle.
- Turn-by-turn instructions, alternative routes, offline tiles.
- Showing the travelled part of the route in grey.
- Integration tests on CI. All logic is unit-tested, and the device behaviour was checked by hand with adb.
