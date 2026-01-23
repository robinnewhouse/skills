---
name: jetbrains-plugin-dev
description: Build and test the Cline JetBrains plugin. Use when asked to run, build, or test the IntelliJ/JetBrains plugin, or when setting up the intellij-plugin repository for development.
---

# JetBrains Plugin Development

Build and test the Cline JetBrains plugin from the `intellij-plugin` repository.

## Prerequisites

- JDK 21 installed
- The `intellij-plugin` repository should be a sibling of the `cline` repository (e.g., `~/dev/cline` and `~/dev/intellij-plugin`)

## Setting Up for Development (Idempotent)

If you're in the `cline` repository and want to test changes in the JetBrains plugin, ensure the symlink is set up:

```bash
cd ../intellij-plugin

# Only create symlink if it doesn't already exist
if [ ! -L "./cline" ]; then
    # Back up existing cline directory if it's a real directory (not a symlink)
    if [ -d "./cline" ]; then
        mv ./cline ./cline_BAK
    fi
    # Create symlink to the cline repo
    ln -s ../cline ./cline
    echo "Symlink created: ./cline -> ../cline"
else
    echo "Symlink already exists, skipping setup"
fi
```

## Running the Plugin

### Run in sandbox IntelliJ IDEA:
```bash
cd ../intellij-plugin
./gradlew runIde
```

### Run with other JetBrains IDEs:
```bash
./gradlew runWebStormIde      # WebStorm
./gradlew runPyCharmIde       # PyCharm
./gradlew runRiderIde         # Rider
./gradlew runAndroidStudioIde # Android Studio
```

## Testing

### Unit Tests:
```bash
cd ../intellij-plugin
./gradlew test
```

Unit tests are in `src/test/kotlin/` and cover:
- Plugin functionality
- Actions (AddToClineAction)
- Host bridge services (Window, Env)
- Diagnostics and utilities

### Integration Tests:
```bash
cd ../intellij-plugin
./gradlew integrationTest
```

Integration tests are in `src/integrationTest/kotlin/` and test:
- ClineToolWindowTest
- ClineBrowserPanelSearchSessionTest

## Building Distributable Packages

```bash
cd ../intellij-plugin
./gradlew buildPlugin       # Production build
./gradlew buildDebugPlugin  # Debug build with source maps
```

Output: `build/distributions/cline-{version}.zip`

## Useful Development Commands

```bash
# Clean build artifacts
./gradlew clean

# Kill running cline-core processes
./gradlew cleanupClineCoreProcesses

# Clear logs
./gradlew clearLogs

# Run cline-core standalone for debugging
./gradlew runClineCore
```

## Skip Building cline-core

If you're running cline-core externally (for debugging):
```bash
EXTERNAL_CLINECORE=true ./gradlew runIde
```

## Build Configuration

Environment variables can be set in:
- `build.env.properties` - Default settings
- `build.env.local.properties` - Local overrides (gitignored)
