# Claude Shadow

Get push notifications on your phone when Claude Code needs your input. Approve, deny, or reply directly from the ShadowAI app.

## Features

- **Permission Notifications**: Get notified when Claude Code needs to run a command, edit a file, or perform any action requiring approval
- **Session Updates**: Know when Claude finishes working on your request
- **Mobile Approval**: Approve or deny actions directly from your phone
- **Reply from Phone**: Send messages back to Claude Code via clipboard sync

## Requirements

- [ShadowAI](https://play.google.com/store/apps/details?id=com.shadowai.release) installed on your Android device
- [ShadowBridge](https://github.com/alrightryanx/shadow-bridge) running on your PC
- Phone and PC on the same network (or connected via Tailscale)

## Installation

### Option 1: Install from Marketplace (Recommended)
1. Add the ShadowAI plugin marketplace:
```
/plugin marketplace add alrightryanx/claude-shadow
```

2. Install the plugin:
```
/plugin install claude-shadow@shadowai-plugins
```

### Option 2: Install from Local Directory
1. Clone this repository
2. Run Claude Code with the plugin directory:
```bash
claude --plugin-dir /path/to/claude-shadow
```

## Setup

1. **Install ShadowAI** on your Android device from the Play Store
2. **Run ShadowBridge** on your PC
3. **Quick Connect** from ShadowAI to your PC (scan QR code or use network discovery)
4. **Enable Companion** in ShadowAI settings
5. Start using Claude Code - notifications will appear on your phone!

## How It Works

```
Claude Code (hooks) -> ShadowBridge (relay) -> ShadowAI (notifications)
                                            <- approval/reply
```

The plugin hooks into Claude Code's permission system and sends events to ShadowBridge, which relays them to the ShadowAI app on your phone. When you approve or reply, the response goes back through the same path.

## Configuration

Create `~/.claude-shadow-config.json` to customize settings:

```json
{
  "bridgeHost": "127.0.0.1",
  "bridgePort": 19286,
  "enabled": true
}
```

## Privacy

- All communication stays on your local network (or Tailscale VPN)
- No data is sent to external servers
- Messages are transmitted directly between your PC and phone

## License

MIT License - See [LICENSE](LICENSE) for details.

## Support

- [ShadowAI Website](https://ryancartwright.com/shadowai)
- [GitHub Issues](https://github.com/alrightryanx/claude-shadow/issues)
