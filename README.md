# SonarText Local

A macOS menu bar app for recording, transcribing, and analyzing audio with AI.

## Features

- **Menu Bar Recording** - Start/stop recording from the menu bar with mic and system audio capture
- **Dual Audio Capture** - Records microphone (AVFoundation) and system audio (ScreenCaptureKit) simultaneously
- **Audio Merging** - Automatically merges mic and system audio into a single file
- **AI Transcription** - Sends recordings to WhisperX API for accurate transcription with speaker diarization
- **AI Analysis** - Analyzes transcripts using Morpheus API (OpenAI-compatible) with two modes:
  - **Meeting Mode** - Extracts action items, decisions, participants, and key points
  - **Speech Mode** - Identifies themes, arguments, and calls to action
- **Local Transcription** - Run WhisperX locally via Docker (Direct download only)
- **Local Storage** - All recordings and transcripts stored locally with SQLite (GRDB)
- **Folder Organization** - Organize recordings into folders with drag-and-drop support
- **Speaker Mapping** - Assign custom names to detected speakers
- **Transcript Formatting** - Toggle timestamps and speaker labels
- **Copy to Clipboard** - One-click copy for transcripts and analysis

## Installation

### Option 1: Mac App Store (Recommended for most users)

[![Download on the Mac App Store](https://developer.apple.com/assets/elements/badges/download-on-the-mac-app-store.svg)](https://apps.apple.com/app/sonartext-local)

- Automatic updates
- Sandboxed for security
- Requires API key for transcription (no local hosting)

### Option 2: Direct Download (For local transcription)

**[Download Latest Release](https://github.com/bowtiedbluefin/SonarText-Local/releases)**

- Includes local transcription via Docker
- No API key required for transcription
- Run everything on your machine

### Option 3: Build from Source

See [BUILDING.md](BUILDING.md) for detailed instructions.

```bash
git clone https://github.com/bowtiedbluefin/SonarText-Local.git
cd SonarText-Local
open "SonarText Local.xcodeproj"
```

## Requirements

- macOS 13.0 (Ventura) or later
- Microphone permission
- Screen Recording permission (for system audio capture)
- Docker Desktop (for local transcription, direct download only)

## Transcription Options

| Method | Requirement | Speed | Privacy |
|--------|-------------|-------|---------|
| **Cloud API** | API key | Fast | Audio sent to server |
| **Local (Docker)** | Docker Desktop + Direct download | Slower | 100% local |

### Cloud Transcription (Both versions)

Configure in Settings → API:
- **Transcription API URL** - WhisperX-compatible endpoint
- **Transcription API Key** - Your API key

### Local Transcription (Direct download only)

1. Install [Docker Desktop](https://www.docker.com/products/docker-desktop/)
2. Open Settings → Local Server
3. Select model:
   - **Whisper Small** (~1GB) - Faster, good accuracy
   - **Distil Large v3** (~3GB) - Slower, excellent accuracy
4. Click "Download & Setup Local Server"
5. Server auto-starts and configures the app

## Architecture

```
SonarText Local/
├── App/
│   └── AudioRecorderApp.swift       # Main app entry, AppState
├── Views/
│   ├── MenuBarView.swift            # Menu bar dropdown UI
│   ├── ContentView.swift            # Library list with folders
│   ├── RecordingDetailView.swift    # Recording detail, player, transcribe/analyze
│   ├── SettingsView.swift           # API configuration
│   └── Components/
│       └── LocalHostingTabView.swift # Local server management
└── Core/
    ├── Audio/
    │   ├── MicCapture.swift         # AVAudioRecorder wrapper
    │   ├── SystemAudioCapture.swift # ScreenCaptureKit capture
    │   ├── AudioMerger.swift        # Merges mic + system audio
    │   └── AudioDeviceManager.swift # CoreAudio device enumeration
    ├── Config/
    │   ├── AppConfiguration.swift   # User settings
    │   └── AppDistribution.swift    # App Store vs Direct detection
    ├── LocalHosting/
    │   ├── LocalHostingManager.swift # Docker container management
    │   └── DockerClient.swift        # Docker CLI wrapper
    ├── Recording/
    │   ├── RecordingController.swift # Recording state machine
    │   └── RecordingState.swift      # State definitions
    ├── Storage/
    │   ├── DatabaseManager.swift    # GRDB SQLite wrapper
    │   ├── Models.swift             # Recording, Transcript, Analysis, Job, Folder
    │   ├── FileStorage.swift        # File management
    │   └── KeychainManager.swift    # Secure API key storage
    ├── Network/
    │   ├── TranscriptionClient.swift # WhisperX API client
    │   ├── MorpheusClient.swift      # Morpheus/OpenAI chat API
    │   └── NetworkError.swift        # Error types
    ├── Jobs/
    │   └── JobQueue.swift           # Async job queue with retry
    └── Permissions/
        └── PermissionsManager.swift # Permission handling
```

## Tech Stack

- Swift 6
- SwiftUI
- AVFoundation
- ScreenCaptureKit
- CoreAudio
- GRDB (SQLite)
- Combine
- Docker (for local transcription)

## App Store vs Direct Download

| Feature | App Store | Direct Download |
|---------|-----------|-----------------|
| Automatic updates | Yes | Manual |
| Sandbox security | Yes | No |
| Local transcription | No | Yes |
| Docker support | No | Yes |
| API-based transcription | Yes | Yes |

The app automatically detects how it was installed and shows the appropriate options.

## License

MIT
