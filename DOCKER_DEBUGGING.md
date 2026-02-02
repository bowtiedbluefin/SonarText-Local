# Docker Integration Debugging Guide

## Changes Made to Fix Installation Issues

### Critical Fixes

1. **Fixed Broken Symlink Detection** (DockerClient.swift)
   - Previous: Used `FileManager.fileExists()` which returns true for broken symlinks
   - Now: Resolves symlinks and verifies executability with `isExecutableFile()`
   - Impact: Fixes cases where `/usr/local/bin/docker` points to non-existent `/Volumes/Docker/...`

2. **Moved `docker pull` Off Main Thread** (DockerClient.swift)
   - Previous: `Task { @MainActor in ...waitUntilExit() }` blocked UI
   - Now: `Task.detached { ... }` runs on background thread
   - Impact: Prevents UI freezes during download

3. **Added 10-Minute Timeout** (DockerClient.swift)
   - Previous: Could hang indefinitely on network issues
   - Now: Terminates process after 600 seconds
   - Impact: Prevents indefinite hangs

4. **Separated stdout/stderr in pullImage** (DockerClient.swift)
   - Previous: Mixed output made error detection impossible
   - Now: Captures stderr separately for specific error detection
   - Impact: Shows meaningful errors (rate limits, disk space, permissions)

5. **Added Stale Container Cleanup** (LocalHostingManager.swift)
   - Previous: Failed if container existed from previous failed install
   - Now: Removes existing container before installation
   - Impact: Fixes "container name already exists" errors

6. **Added Port Conflict Detection** (LocalHostingManager.swift)
   - Previous: Container started but silently failed if port in use
   - Now: Checks port 17394 availability before starting
   - Impact: Clear error message instead of mysterious health check failure

7. **Enhanced Error Messages** (DockerClient.swift)
   - Rate limiting: "Rate limited by Docker Hub. Try again later."
   - Disk space: "Insufficient disk space"
   - Permissions: "Permission denied - check Docker access"
   - Impact: Users know exactly what went wrong

8. **Comprehensive Diagnostic Logging** (LocalHostingManager.swift + DockerClient.swift)
   - Every step now logs to Console.app
   - Pull progress logged at each update
   - All errors logged with context
   - Impact: You can ask users to check Console.app for specific failures

## How to Debug User Issues

### Step 1: Ask User to Check Console.app

1. Open Console.app
2. Select their Mac in sidebar
3. Search for "LocalHostingManager" or "DockerClient"
4. Share logs starting from "Starting installation"

### Step 2: Common Failure Patterns

#### "Docker not found"
- **Cause**: Docker Desktop not installed or at unexpected location
- **Log**: "DockerClient: Docker executable not found"
- **Fix**: Install Docker Desktop

#### "Docker is not running"
- **Cause**: Docker Desktop installed but not launched
- **Log**: "DockerClient: Docker daemon not running" or "Cannot connect to the Docker daemon"
- **Fix**: Launch Docker Desktop.app

#### "Permission denied"
- **Cause**: User doesn't have Docker socket access
- **Log**: "DockerClient: Docker permission denied"
- **Fix**: User needs admin rights or to be in `docker` group

#### "Rate limited by Docker Hub"
- **Cause**: Too many pulls from same IP (Docker Hub free tier limit)
- **Log**: stderr contains "429" or "rate limit"
- **Fix**: Wait 6 hours or authenticate with Docker Hub account

#### "Insufficient disk space"
- **Cause**: Not enough space to extract 680MB image
- **Log**: stderr contains "no space left" or "insufficient space"
- **Fix**: Free up disk space (need ~2GB for extraction)

#### "Port 17394 is already in use"
- **Cause**: Another process bound to that port
- **Log**: "LocalHostingManager: Port 17394 is already in use"
- **Fix**: `lsof -i :17394` to find process, then kill it

#### Pull hangs/times out
- **Cause**: Network issues, VPN blocking Docker Hub
- **Log**: Process terminates after 10 minutes
- **Fix**: Check network, disable VPN, try different network

#### "Container name already exists"
- **Cause**: Previous failed install left container
- **Log**: Should not happen anymore (cleanup added)
- **Fix**: Run `docker rm -f sonartext-whisperx` manually

## Testing Checklist Before Release

### Local Testing
- [ ] Fresh install on clean machine
- [ ] Install with Docker not running (should show error)
- [ ] Install without Docker Desktop (should show error)
- [ ] Install with image already pulled (should succeed)
- [ ] Install with stale container present (should auto-cleanup)
- [ ] Install with port 17394 in use (should show error)
- [ ] Cancel mid-download (should handle gracefully)
- [ ] Retry failed install (should work)

### Docker Configuration Testing
- [ ] Docker Desktop in `/Applications/Docker.app`
- [ ] Docker symlink in `/usr/local/bin`
- [ ] Docker installed via Homebrew (`/opt/homebrew/bin`)
- [ ] Broken symlink at `/usr/local/bin/docker`

### Network Testing
- [ ] Slow connection (progress updates work)
- [ ] No internet (clear error message)
- [ ] Behind corporate proxy (may need docker config)
- [ ] VPN enabled (some VPNs block Docker Hub)

### Error Recovery Testing
- [ ] Kill Docker Desktop mid-pull (recoverable?)
- [ ] Fill disk during extraction (error message clear?)
- [ ] Rate limit scenario (message shows)

## Console.app Search Queries for Users

Ask users experiencing issues to:

1. Open Console.app
2. Click their Mac name in sidebar
3. Click "Start" button to begin streaming
4. Try the installation again
5. Use these search filters:
   - `LocalHostingManager` - shows all manager activity
   - `DockerClient` - shows all Docker interaction
   - `Pull progress` - shows download progress
   - `failed` - shows any failures

## Known Limitations

1. **ARM64 Only**: Docker image is Apple Silicon only (not Intel)
2. **Docker Desktop Required**: Won't work with Colima or other Docker alternatives
3. **10-Minute Timeout**: Very slow connections may timeout (can increase if needed)
4. **No Progress Bar**: Progress increments don't match actual download % (cosmetic)

## Code Locations

- Docker path detection: `DockerClient.findDockerExecutable()`
- Image pull logic: `DockerClient.pullImage()`
- Installation flow: `LocalHostingManager.downloadAndInstall()`
- Error types: `LocalHostingError` enum
- Container cleanup: `LocalHostingManager.cleanupStaleContainer()`
- Port checking: `LocalHostingManager.isPortInUse()`
