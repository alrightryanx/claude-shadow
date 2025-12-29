# Claude Code Instructions

When working on this codebase:

## Project Overview

ShadowAI is an ecosystem of tools for voice-first AI assistance:
- **Android app** with Android Auto, Wear OS, and Google TV support
- **PC bridge** for SSH key exchange, clipboard sync, and Claude Code relay
- **Claude Code plugin** for mobile notifications and approvals

## Project Tree

```
C:\shadow\
├── shadow-android/          # Main Android app
│   ├── app/                 # Phone + Android Auto app
│   ├── shared/              # Shared library (backends, LLM)
│   │   └── src/main/cpp/
│   │       ├── llama.cpp/   # On-device LLM (git submodule)
│   │       └── whisper.cpp/ # On-device speech (git submodule)
│   └── wear/                # Wear OS app
│
├── shadow-bridge/           # PC companion app (Python)
│   └── shadow_bridge_gui.py # Main entry point
│
└── claude-shadow/           # Claude Code plugin
    ├── .claude-plugin/
    │   ├── plugin.json      # Plugin manifest
    │   └── marketplace.json # Self-hosted marketplace
    ├── hooks/               # Claude Code hooks
    └── scripts/             # PowerShell notification scripts
```

## Component Descriptions

### shadow-android (ShadowAI App)
Voice-first AI assistant for Android with multiple backends:
- **SSH backends**: Claude Code, Gemini CLI, Codex
- **Cloud APIs**: Anthropic, OpenAI, Gemini
- **On-device**: llama.cpp for offline LLM inference
- **Features**: Projects, Notes, Automations, DevOps integrations (Slack, Jira, PagerDuty)

### shadow-bridge (ShadowBridge)
Windows PC companion that runs in system tray:
- **Port 19284**: Data receiver (clipboard, SSH keys)
- **Port 19285**: Network discovery broadcast
- **Port 19286**: Claude Code Companion relay

### claude-shadow (Claude Code Plugin)
Plugin that sends notifications to ShadowAI when Claude Code needs input:
- Permission request notifications
- Session start/stop events
- Mobile approval/denial responses
- Reply via clipboard sync

## Build Commands

### Android App
```bash
cd shadow-android
./gradlew assembleDebug    # Debug build
./gradlew assembleRelease  # Release build
./gradlew test             # Run tests
```

### ShadowBridge
```bash
cd shadow-bridge
pip install -r requirements.txt
python shadow_bridge_gui.py
```

### Claude Shadow Plugin
Install via Claude Code:
```
/plugin marketplace add alrightryanx/claude-shadow
/plugin install claude-shadow@shadowai-plugins
```

Or load locally:
```bash
claude --plugin-dir C:\shadow\claude-shadow
```

## Pre-Build Version Increment Rule (MANDATORY)

**BEFORE every `./gradlew assembleRelease` command**, you MUST increment both version numbers in `shadow-android/app/build.gradle.kts`:
- `versionCode`: increment by EXACTLY 1 (e.g., 362 → 363, NOT 362 → 370)
- `versionName`: increment the decimal part by EXACTLY 0.01 (e.g., "3.62" → "3.63", NOT "3.62" → "3.70")

**CRITICAL: Only increment by 1 per build. NEVER jump multiple versions.**

## Post-Build Rule

After every successful `./gradlew assembleRelease`, push the APK to connected adb devices:
```bash
C:\android\platform-tools\adb.exe install shadow-android/app/build/outputs/apk/release/app-release.apk
```

**IMPORTANT:** Do NOT use `-r` flag. Let install fail on signature conflicts rather than force-installing mismatched APKs.

## ADB Safety Rules

- **NEVER uninstall any APK** from adb devices. Only the user may uninstall apps.
- **NEVER use `adb uninstall`** command under any circumstances.
- If an install fails, inform the user and let them decide.

## Commit Discipline (MANDATORY)

**Commit frequently to maintain backups and track changes.**

### Timing Rules
- **Immediately after changes (MANDATORY)**: Commit AND PUSH as soon as a change is complete - do NOT wait for user prompts or batch commits
- **Session Start**: Check for uncommitted changes and commit if valid
- **Session End**: Always commit before ending a session

### Commit Quality Gates
Before committing, verify:
1. **No broken code** - Changes should not introduce errors or break builds
2. **No incomplete features** - Partial implementations should be marked WIP
3. **No secrets or credentials** - Never commit .env, API keys, passwords
4. **Meaningful descriptions** - Commit messages must describe WHAT and WHY

### Commit Message Format
```
<type>: <short description>

[optional body with details]
```

Types: `feat`, `fix`, `refactor`, `style`, `docs`, `chore`, `wip`

### Multi-Repo Awareness
This project spans multiple repos. Commit to the appropriate repo:
- `shadow-android/` - Android app changes
- `shadow-bridge/` - ShadowBridge Python/web changes
- `claude-shadow/` - Claude Code plugin changes

### Version Increment Rules
When committing changes to a component, increment its version using `X.YYY` format (e.g., 1.000 → 1.001 → 1.002):

**shadow-android** (`app/build.gradle.kts`):
- `versionCode`: increment by 1
- `versionName`: increment by 0.001 (e.g., "3.620" → "3.621")

**shadow-bridge** (`shadow_bridge_gui.py` or `version.py`):
- Update `VERSION` string (e.g., "1.000" → "1.001")

**claude-shadow** (`.claude-plugin/plugin.json`):
- Update `version` field (e.g., "1.000" → "1.001")

### Recovery Purpose
Frequent commits enable:
- Easy rollback if something breaks
- Clear history of what changed and when
- Protection against lost work
- Collaboration visibility

## Dual App ID Setup (MANDATORY)

- **`com.shadowai.release`** - Play Store stable build ONLY. Do NOT use for development.
- **`com.shadowai.release6`** - **ALWAYS use this for development/testing builds.**

**CRITICAL: Before ANY `./gradlew assembleRelease`, verify `applicationId = "com.shadowai.release6"` in `app/build.gradle.kts`. NEVER build with `.release` unless explicitly preparing a Play Store submission.**

Each app ID has separate SSH keys. Run Quick Connect with ShadowBridge when switching builds.

## Tool Paths

- ADB: `C:\android\platform-tools\adb.exe`

## Architecture Notes

- **Android**: MVVM pattern with ViewModels and Room database
- **Backend abstraction**: `IConnectionBackend` interface
- **Safety system**: Gates voice interactions based on driving speed
- **Android Auto**: Car App Library with voice-first screens

## Network Architecture

```
┌─────────────────┐     Local Network/Tailscale     ┌──────────────────┐
│   ShadowAI      │◄──────────────────────────────►│   ShadowBridge   │
│   (Android)     │         Ports 19284-19286       │   (Windows PC)   │
└─────────────────┘                                 └────────┬─────────┘
                                                             │
                                                             ▼
                                                    ┌──────────────────┐
                                                    │   Claude Code    │
                                                    │   (claude-shadow │
                                                    │    plugin)       │
                                                    └──────────────────┘
```

## Reconnection with Tailscale

Phone and PC can connect via:
1. **Same local network** - Automatic discovery on port 19285
2. **Tailscale VPN** - Use Tailscale IP in ShadowBridge settings

For persistent connections across networks, install Tailscale on both devices and use the Tailscale IP address.

## Contact

- Email: contact@ryancartwright.com
- Website: https://ryancartwright.com/shadowai

## Autonomous Mode (SHADOW System) v4.0

When you receive a prompt containing `[AUTONOMOUS MODE]` or `[SHADOW AUTONOMOUS]`, you are being invoked by ShadowAI's autonomous execution engine. In this mode:

### Behavioral Changes
1. **ACT PROACTIVELY** - Do not wait for confirmation. Execute tasks immediately.
2. **COMPLETE FULLY** - Continue working until the task is done.
3. **USE YOUR TOOLS** - Full access to Read, Write, Edit, Bash, Grep, Glob, Task, WebFetch, WebSearch.
4. **NO PERMISSION NEEDED** - The `--dangerously-skip-permissions` flag is active.
5. **REPORT PROGRESS** - Output status updates as you work.

### Phase Announcements
- `[PHASE: RECONNAISSANCE]` - Gathering information
- `[PHASE: ANALYSIS]` - Understanding the problem
- `[PHASE: PLANNING]` - Deciding what to do
- `[PHASE: EXECUTION]` - Making changes
- `[PHASE: REPORTING]` - Summarizing results

### Goal Tracking
```
[GOAL IDENTIFIED: <id>] <description>
[GOAL COMPLETE: <id>] <notes>
[GOAL FAILED: <id>] <reason>
[GOAL PROGRESS] 3/5 goals complete
```

### Voice Announcements
```
[ANNOUNCE: <short message under 15 words>]
```

### Session Checkpoints
```
[CHECKPOINT: <phase>|<goals_done>/<goals_total>|<summary>]
```
