# Firmware Versioning Strategy

This project follows **Semantic Versioning (SemVer)** as defined at https://semver.org/, adapted for embedded firmware deployment.

## Version Format

```
MAJOR.MINOR.PATCH
```

Each component has a specific meaning in the context of ESP32 OTA firmware:

### MAJOR — Breaking Changes

Increment when the new firmware is **incompatible** with the previous version in any of these ways:

- Change to the HTTP API (endpoint paths, request/response formats)
- Change to the OTA protocol (handshake sequence, token mechanism)
- Change to hardware pin assignments or peripheral configuration
- Change to the partition table layout
- Removal of previously available endpoints or features

**Example**: `1.x.x → 2.0.0` when `/version` response format changes from `{version, hostname}` to `{firmware_version, device_name, uptime_s}`

### MINOR — New Features (Backwards-Compatible)

Increment when new functionality is added **without breaking existing behavior**:

- New HTTP endpoint (e.g., adding `/restart` or `/config`)
- New sensor or peripheral driver
- Performance improvement to existing endpoints
- New mDNS service attribute
- Wi-Fi configuration enhancement

**Example**: `1.0.x → 1.1.0` when adding a `/restart` endpoint

### PATCH — Bug Fixes Only

Increment for bug fixes that **do not change any external interface**:

- Fix a memory leak in the HTTP handler
- Fix watchdog timer not resetting on successful OTA
- Fix incorrect Content-Type header
- Improve error message wording

**Example**: `1.1.0 → 1.1.1` when fixing a watchdog timer reset bug

## Version Location

The firmware version is defined in **exactly one place**:

```cpp
// firmware/ota_config.h
#define FIRMWARE_VERSION     "1.0.0"
```

This string is:
- Returned by `GET /version` as the `version` field
- Compared against by the Flutter app's version gate
- Displayed in Serial logs on boot

## Version Update Workflow

1. **Before each build and OTA push**: Manually increment `FIRMWARE_VERSION` in `ota_config.h`
2. **Compile**: Arduino IDE → Sketch → Export Compiled Binary
3. **Push via Flutter**: The app reads the version string embedded in the `.bin` filename or prompts the user

### The Flutter Version Gate

The Flutter app enforces version progression:

- If the selected `.bin` file's version (parsed from filename) is **newer** than the device's current version → upload proceeds normally
- If the selected `.bin` file's version is **equal or older** → a warning badge appears: *"Already up to date"* 
- The user must explicitly toggle "Force update" to proceed with a same-version or downgrade OTA

This prevents accidental downgrade attacks and ensures field devices always run the intended version.

## CI/CD Integration Recommendation

For automated build pipelines, add a version check step:

```yaml
# .github/workflows/ota-build.yml
- name: Check version increment
  run: |
    NEW_VERSION=$(grep FIRMWARE_VERSION firmware/ota_config.h | cut -d'"' -f2)
    # Compare against the version currently on the target device
    # (fetched via GET /version)
    if [ "$NEW_VERSION" <= "$DEVICE_VERSION" ]; then
      echo "ERROR: New version must be greater than device version"
      exit 1
    fi
```

## Version History Template

Maintain a changelog in the project root:

```
## [1.1.0] - 2026-05-24
### Added
- /restart endpoint for remote reboot without OTA

## [1.0.1] - 2026-05-20
### Fixed
- Watchdog timer now correctly resets after successful OTA

## [1.0.0] - 2026-05-15
### Added
- Initial OTA firmware update system
- mDNS discovery, token authentication, binary validation
- Flutter companion app with version gating
```

## Branching Strategy

| Branch | Version | Purpose |
|---|---|---|
| `main` | `1.x.x` | Stable production releases |
| `develop` | `1.x.x-dev` | Integration branch |
| `feature/*` | `1.x.x-dev+feat` | Feature branches |
| `hotfix/*` | `1.x.x-patch` | Emergency production fixes |