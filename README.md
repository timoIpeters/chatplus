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
  | `/chatplus` | Checks that the game still has everything the mod uses (after a game update) |

  Names are found, ignoring case, among players on your map, in your group, your friends, and an address book of every player the mod has seen (chat senders, whisper partners, group members, players on your map), kept across restarts in `hlx\mods\chat-plus\players.json`.

  Character names are not unique. When several accounts match, the mod uses the best match (map, then group, then friends, then the most recently seen) and lists all of them: right-click a line for the game's player menu, or type `/invite Senix:2`. By default `/invite` invites the best match right away, while `/w` only lists the players and keeps your message until you pick one (`/w Senix:2` sends it); both can be changed (`inviteFirstMatch`, `whisperFirstMatch`).

- A chat you closed with its minimize button stays closed when you change scene (dungeon, map, character switch). Pressing Enter or clicking it opens it as before.

- `/help` also shows the game's channel keys: Tab and Shift+Tab while typing cycle All, Group, Local and whispers. The game's options don't list them.


## Chat size

Drag the chat's top edge (taller), right edge (wider) or top-right corner (both). Hovering an edge shows a red line and the drag cursor. The game's size is the smallest. The size is saved and also has sliders on the settings page.

## After a game update

At every start the mod checks that the game still has the functions it uses. Missing ones are listed in the chat as red `[Chat Plus]` lines with the feature that stops working; other errors appear the same way, each kind once per session. Type `/chatplus` to run the check yourself. Everything is also written to `hlx\logs\hlx.log`.

## Settings

Esc → Mod Settings → Chat Plus. The page needs the Better Mod Settings mod; the mod writes its page description (`hlx\mods\chat-plus\configFormats.json`) at start, so after the first install restart the game once if the page is missing. Changes apply at once to new messages, the next command and the next scene.

The values are stored in `<Farever folder>\hlx\config\chat-plus\config.json` (HLX's config folder; taken over once from the old `hlx\mods\chat-plus\settings.json`).

| Key | Default | Meaning |
|---|---|---|
| `timestamps` | `true` | Time in front of player messages |
| `keepHistory` | `true` | Keep messages and whisper channels across a character switch |
| `switchMessage` | `false` | System line at each character switch (needs `keepHistory`) |
| `rememberClosed` | `true` | A closed chat stays closed in the next scene |
| `rememberPlayers` | `true` | Keep the address book of seen players across game restarts |
| `inviteFirstMatch` | `true` | `/invite` with a shared name invites the best match right away |
| `whisperFirstMatch` | `false` | `/w` with a shared name whispers the best match right away; off: list first, message kept until you pick |
| `showErrors` | `true` | Red `[Chat Plus]` lines in the chat for missing game elements and errors (always in `hlx\logs\hlx.log`) |
| `historyLimit` | `500` | Most messages kept at a character switch (100–2000) |
| `chatWidth` | `480` | Chat width (480–1920), also set by dragging the right edge |
| `chatHeight` | `250` | Chat height (250–1080), also set by dragging the top edge |

## Build

Needs `haxe` (see `../workbench/WORKSPACE.md`) and the HLX runtime sources:

```sh
git clone --depth 1 https://github.com/hlx-framework/hlx-core.git vendor/hlx-core
haxe test.hxml      # All checks passed
haxe compile.hxml   # build/chat-plus/chat-plus.hl
```

## Install

HLX Core must be installed in the game. Copy `build/chat-plus/chat-plus.hl` to `<Farever folder>\hlx\mods\chat-plus\`, or from WSL: `../workbench/tools/game_pc.sh push-mod .`
