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
- **Local Storage** - All recordings and transcripts stored locally with SQLite (GRDB)
- **Folder Organization** - Organize recordings into folders with drag-and-drop support
- **Speaker Mapping** - Assign custom names to detected speakers
- **Transcript Formatting** - Toggle timestamps and speaker labels
- **Copy to Clipboard** - One-click copy for transcripts and analysis

## Requirements

- macOS 13.0 (Ventura) or later
- Microphone permission
- Screen Recording permission (for system audio capture)

## Setup

1. Clone the repository
2. Open `SonarText Local.xcodeproj` in Xcode
3. Build and run

### API Configuration

In the app's Settings, configure:

- **Transcription API URL** - WhisperX-compatible endpoint
- **Transcription API Key** - (optional, depending on your endpoint)
- **Morpheus API URL** - OpenAI-compatible chat completions endpoint
- **Morpheus API Key** - Your API key for analysis

## Architecture

```
SonarText Local/
├── App/
│   └── AudioRecorderApp.swift       # Main app entry, AppState
├── Views/
│   ├── MenuBarView.swift            # Menu bar dropdown UI
│   ├── ContentView.swift            # Library list with folders
│   ├── RecordingDetailView.swift    # Recording detail, player, transcribe/analyze
│   └── SettingsView.swift           # API configuration
└── Core/
    ├── Audio/
    │   ├── MicCapture.swift         # AVAudioRecorder wrapper
    │   ├── SystemAudioCapture.swift # ScreenCaptureKit capture
    │   ├── AudioMerger.swift        # Merges mic + system audio
    │   └── AudioDeviceManager.swift # CoreAudio device enumeration
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

## License

MIT
