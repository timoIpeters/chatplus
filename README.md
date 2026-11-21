# Chat Plus

An HLX mod for Farever that improves the chat.

- `[HH:MM]` in front of every player message (the time your client received it).
- Chat messages and whisper channels stay when you switch character. Optionally a system line `------ character switch ------` marks the switch (`switchMessage`). The oldest messages are dropped above 500.
- More chat commands, next to the game's own `/all`, `/p`, `/s`, `/r`:

  | Command | Does |
  |---|---|
  | `/w`, `/whisper`, `/tell <name> [message]` | Opens a whisper channel with the player and sends the message |
  | `/invite`, `/inv <name>` | Group invite, like the player menu |
  | `/leave` | Leaves your group |
  | `/help` | Lists all chat commands |

  Names are found, ignoring case, among players on your map, in your group, your friends, and an address book of every player the mod has seen (chat senders, whisper partners, group members, players on your map), kept across restarts in `hlx\mods\chat-plus\players.json`.

  Character names are not unique. When several accounts match, the mod uses the best match (map, then group, then friends, then the most recently seen) and lists all of them: right-click a line for the game's player menu, or type `/invite Senix:2`.

Planned: the chat remembering that it was closed, channel buttons and a channel hotkey, a settings panel next to the chat's close button.

## Settings

`<Farever folder>\hlx\mods\chat-plus\settings.json`, written with the defaults on the first start. Restart the game after editing it.

| Key | Default | Meaning |
|---|---|---|
| `timestamps` | `true` | Time in front of player messages |
| `keepHistory` | `true` | Keep messages and whisper channels across a character switch |
| `switchMessage` | `false` | System line at each character switch (needs `keepHistory`) |
| `rememberPlayers` | `true` | Keep the address book of seen players across game restarts |
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
