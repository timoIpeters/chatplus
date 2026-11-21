# Chat Plus

An HLX mod for Farever that improves the chat.

- `[HH:MM]` in front of every player message (the time your client received it).
- Chat messages and whisper channels stay when you switch character. A line `──── character switch ────` marks the switch. The oldest messages are dropped above 500.

Planned: `/w`, `/invite` and more commands, the chat remembering that it was closed, channel buttons and a channel hotkey, a settings panel next to the chat's close button.

## Settings

`<Farever folder>\hlx\mods\chat-plus\settings.json`, written with the defaults on the first start. Restart the game after editing it.

| Key | Default | Meaning |
|---|---|---|
| `timestamps` | `true` | Time in front of player messages |
| `keepHistory` | `true` | Keep messages and whisper channels across a character switch |
| `historyLimit` | `500` | Most messages kept at a character switch |

## Build

Needs `haxe` (see `../workbench/WORKSPACE.md`) and the HLX runtime sources:

```sh
git clone --depth 1 https://github.com/hlx-framework/hlx-core.git vendor/hlx-core
haxe test.hxml      # All checks passed
haxe compile.hxml   # build/chat-plus/chat-plus.hl
```

## Install

HLX Core must be installed in the game. Copy `build/chat-plus/chat-plus.hl` to `<Farever folder>\hlx\mods\chat-plus\`, or from WSL: `../workbench/tools/game_pc.sh push-mod .`
