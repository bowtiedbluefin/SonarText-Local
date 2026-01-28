# Building SonarText Local from Source

## Prerequisites

- macOS 13.0 (Ventura) or later
- Xcode 15.0 or later
- Apple Developer account (free tier works for local development)
- Docker Desktop (optional, for local transcription)

## Quick Start

```bash
# Clone the repository
git clone https://github.com/bowtiedbluefin/SonarText-Local.git
cd SonarText-Local

# Open in Xcode
open "SonarText Local.xcodeproj"
```

## Build Configurations

The project has two build configurations:

| Configuration | Sandbox | Use Case |
|---------------|---------|----------|
| **Debug** | OFF | Development with local transcription |
| **Release** | ON | App Store distribution |

### For Development (with Local Transcription)

1. Open the project in Xcode
2. Select the **SonarText Local** scheme
3. Ensure **Debug** configuration is selected
4. Press `Cmd+R` to build and run

The Debug configuration uses `SonarText_Local_Direct.entitlements` which has sandbox disabled, allowing Docker communication.

### For App Store Distribution

1. Select **Release** configuration
2. Archive and submit to App Store Connect

The Release configuration uses `SonarText_Local.entitlements` with sandbox enabled.

## Setting Up Build Configurations

### Step 1: Create the Direct Scheme (if not present)

1. In Xcode, go to **Product → Scheme → Manage Schemes**
2. Duplicate the existing scheme
3. Name it "SonarText Local (Direct)"
4. Edit the new scheme:
   - Set Build Configuration to use Direct entitlements

### Step 2: Configure Entitlements per Build

In **Build Settings** for the target:

1. Search for "Code Signing Entitlements"
2. Set per-configuration:
   - **Debug**: `SonarText Local/SonarText_Local_Direct.entitlements`
   - **Release**: `SonarText Local/SonarText_Local.entitlements`

Or use Xcode's conditional settings:
```
CODE_SIGN_ENTITLEMENTS[config=Debug] = SonarText Local/SonarText_Local_Direct.entitlements
CODE_SIGN_ENTITLEMENTS[config=Release] = SonarText Local/SonarText_Local.entitlements
```

### Step 3: Add DIRECT_DISTRIBUTION Flag (Optional)

For explicit control, add a preprocessor flag:

1. Go to **Build Settings → Swift Compiler - Custom Flags**
2. Add to **Debug** configuration:
   ```
   -D DIRECT_DISTRIBUTION
   ```

This allows code to check distribution method at compile time:
```swift
#if DIRECT_DISTRIBUTION
    // Direct-only code
#endif
```

## Signing

### For Local Development

1. In Xcode, select the target
2. Go to **Signing & Capabilities**
3. Select your Team (Personal Team works)
4. Xcode will create a development certificate

### For Distribution

You'll need:
- **App Store**: App Store distribution certificate
- **Direct**: Developer ID certificate (for notarization)

## Testing Local Transcription

1. Install [Docker Desktop](https://www.docker.com/products/docker-desktop/)
2. Start Docker Desktop
3. Build and run the app (Debug configuration)
4. Go to Settings → Local Server
5. Click "Download & Setup Local Server"

## Troubleshooting

### "Docker Desktop is not running"

- Ensure Docker Desktop is installed and running
- Check the Docker icon in the menu bar shows "Running"
- The app needs the non-sandboxed (Debug) build to communicate with Docker

### Build Errors

If you see errors about missing types (NetworkError, DatabaseManager, etc.), these are LSP analysis issues. The project should still build successfully in Xcode since all files are part of the target.

### Sandbox Errors

If you get sandbox-related errors when trying to use Docker:
- Verify you're running the Debug configuration
- Check that `SonarText_Local_Direct.entitlements` has `com.apple.security.app-sandbox` set to `false`

## Project Structure

```
SonarText Local/
├── SonarText_Local.entitlements        # App Store (sandbox ON)
├── SonarText_Local_Direct.entitlements # Direct (sandbox OFF)
├── Core/
│   ├── Config/
│   │   ├── AppConfiguration.swift
│   │   └── AppDistribution.swift       # Detects App Store vs Direct
│   └── LocalHosting/
│       ├── LocalHostingManager.swift   # Docker orchestration
│       └── DockerClient.swift          # Docker CLI wrapper
└── Views/
    └── Components/
        └── LocalHostingTabView.swift   # Shows different UI per distribution
```

## Dependencies

The project uses Swift Package Manager:

- **GRDB** - SQLite database wrapper

Dependencies are resolved automatically when you open the project.
