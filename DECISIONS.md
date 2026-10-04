# Decisions

## 1. Architecture and state management

**Feature-first layers.** `features/location`, `features/routing` and `features/navigation` each have `domain` (models, interfaces, typed errors), `data` (channel, HTTP, ticker) and `presentation` (controllers). All the maths lives in `core/` as **pure Dart** driven by an injected time step, so the animation is tested without a map widget (288 tests).

**Why GetX.** I know Bloc/Cubit is the most natural fit for a task like this, and I know how it works, but I'm not an expert in it. I am an expert in GetX. With a short deadline, GetX let me build quickly and, just as important, explain every line confidently in the code walkthrough. There is nothing in this brief that GetX can't handle cleanly. For a long-lived production app with a bigger team, I would choose Bloc/Cubit for its stricter event/state separation and tooling.

I did **not** use GetX shortcuts to get around the requirements:
- Dependencies are registered in one place (`NavigationBinding`) and passed through **constructors**, so tests use hand-written fakes, not global lookups.
- No GetX navigation, snackbars or context helpers. Controllers never touch widgets.
- Cleanup is explicit: workers, timers, the ticker and the location subscription are disposed in `onClose`.
- `Obx` wraps the smallest widget possible. Only the car layer rebuilds every frame. The remaining distance and time update at most every 200 ms.

## 2. Flutter ↔ native location bridge

**Channels.** A `MethodChannel` for commands (`checkPermission`, `requestPermission`, `isLocationServiceEnabled`, `getCurrentLocation(timeoutMs)`, `openAppSettings`, `openLocationSettings`) and an `EventChannel` for the continuous stream. All names, keys and error codes are constants in one contract file, mirrored in Kotlin and Swift. I chose plain channels over Pigeon: six methods and one stream are easy to read in review and need no code generation.

**Typed errors.** Native code always replies with a known code (`PERMISSION_DENIED`, `PERMISSION_DENIED_FOREVER`, `SERVICES_DISABLED`, `TIMEOUT`, `LOCATION_UNAVAILABLE`, `REQUEST_IN_PROGRESS`, `NOT_SUPPORTED`, …). Dart maps each one to a **sealed** `LocationException` subclass, so the UI's `switch` must handle every case. A missing plugin becomes `LocationNotSupported` instead of a crash. The rest of the app only sees the `LocationService` interface, never the channel.

This contract is why **iOS was added without changing any Dart code**. The Swift plugin maps iOS rules onto the same codes: "Don't Allow" becomes `deniedForever` (iOS never asks twice), and device-wide Location Services off becomes `SERVICES_DISABLED`.

**Android permanent denial.** Android doesn't report it directly, so the plugin remembers "we asked before". Denied + asked before + no rationale = `deniedForever`, and the card offers Open Settings.

**Stream lifecycle.** `onListen` checks permission and services and reports problems as stream errors. `onCancel` removes the location callback. Dart cancels the subscription when the app goes to the background and listens again on return. Checked with `dumpsys location`: 0 requests in the background, exactly 1 after returning.

## 3. Interpolation and bearing

1. **Clean the route.** Drop NaN points and points closer than 0.5 m to the previous one. Every remaining segment has length > 0, so there is no division by zero and no undefined direction.
2. **Distance-based progress.** Cumulative haversine distances per point. The car's progress is stored in **metres**: `distance += 13.9 m/s × multiplier × dt`, then a binary search finds the segment and the position is interpolated inside it. A 2-point and a 200-point route play at the same speed. `dt` is capped at 0.1 s, so a slow frame or returning from the background can't make the car jump.
3. **Bearing.** The car points at the spot 15 m ahead on the route, so it starts turning just before a corner and ignores tiny jagged segments.
4. **Smooth rotation.** Always turn the short way (350° → 10° is 20°, not 340°), smoothed with `1 − e^(−dt/τ)`, which looks the same at any frame rate and never overshoots.
5. **Guards.** A frame with any non-finite value is never shown. A fuzz test over 1,000 messy random routes checks every frame.

**Live GPS mode** reuses the same pieces. Each fix is projected onto the route. Within 25 m it is drawn **on** the line (snap to route), and the car glides toward each new fix instead of jumping. A reroute needs 3 accurate fixes in a row more than 50 m off the route, with at least 30 s between reroutes, and it goes through the same debounce and rate limit as every other request. While following, the map turns so the car always points up.

## 4. Flavor configuration

- **Native:** Gradle `productFlavors` (`dev`, `prod`) set the application id suffix, the app name and a dev launcher icon. On iOS, `Debug/Release/Profile-dev/prod` build configurations and `dev`/`prod` schemes do the same.
- **Dart:** Flutter's `appFlavor` is mapped to a typed `const AppConfig` (`dev_config.dart`, `prod_config.dart`). Switching the routing server is one line.
- **No flavor = clear error at startup.** A wrong build never runs silently with the wrong config.

## 5. When there is no location

If permission is denied, services are off, or no fix arrives, the user can **pick a start point on the map**. Blocking would make the core feature useless for exactly the users who refuse permission. A silent default start (for example a city centre) would draw a route from somewhere the user isn't. A manual start keeps the app useful and honest. Permission is only ever requested from a user tap, never at launch.

## 6. Before shipping to production

- **Battery:** high accuracy only while navigating, balanced power while idle, update intervals that adapt to speed.
- **Background location:** a foreground service with a notification on Android (and a Play policy justification), "Always" permission with background modes on iOS.
- **Routing server:** the public OSRM demo has no SLA. Self-host OSRM/Valhalla/GraphHopper, or use a paid provider with traffic data.
- **Tiles:** our own tile server or a CDN with on-device caching (which also fixes the grey map offline).
- **Cost at scale:** cache repeated origin/destination pairs, limit reroutes per trip, keep the client debounce, rate-limit on the server.
- **Other:** crash reporting, release signing in CI, Bangla localisation, accessibility.

## 7. Deliberately left out

- **Camera tilt.** `flutter_map` is a flat 2D map. Faking tilt stretches far tiles and breaks long-press hit-testing, which is how destinations are chosen. Rotation is done.
- Turn-by-turn instructions, alternative routes, offline tiles, a greyed-out travelled path.
- Integration tests on CI. The logic is unit-tested, and the device behaviour was checked by hand.

## 8. How I built it

I used AI to write much of the code and its comments, and I reviewed every part. The engineering decisions are mine:
- **Project architecture:** feature-first layers, with the maths in pure Dart so it can be tested without a map or a device.
- **Service organisation:** `LocationService` and `RouteRepository` interfaces that hide the channel and HTTP, constructor injection, and hand-written fakes for tests.
- **Native ↔ Dart communication:** one contract file for method names, keys and error codes, sealed typed errors, and a stream that really stops when Dart cancels it. The same contract let iOS plug in with no Dart change.
- **Flavor config:** native flavors plus one typed `AppConfig` per flavor, failing loudly when no flavor is given.
- **Map control:** one `MapCameraController` owns every camera move. A finger on the map stops following, Recenter brings it back, moves requested before the map is ready are queued, and route fits leave room for the cards.
- **Practical behaviour:** manual start without location, debounce and rate limiting for the free OSRM server, stale answers dropped, auto-pause in the background.
