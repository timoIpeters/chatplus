# Chat Plus

A better chat for Farever: timestamps, chat history that survives a character switch, a resizable chat, and commands that find any player you have met by name.

## Features

- **Timestamps.** `[HH:MM]` in front of every player message, in the channel's color.
- **Chat kept on character switch.** Messages and whisper channels stay when you return to the character selection and log in with another character. An optional line `------ character switch ------` marks the switch.
- **Resizable chat.** Drag the chat's top edge (taller), right edge (wider) or top-right corner (both). Hovering an edge shows a red line and the drag cursor. The game's size is the smallest; your size is saved.
- **A closed chat stays closed.** Close the chat with its minimize button and it stays closed when you enter a dungeon, change map or switch character. Press Enter or click its button to open it as usual.
- **More chat commands** (see below): whisper, invite, ignore or befriend players by name, leave your group, clear the chat.
- **Address book.** Every player you meet (chat, whispers, group, map, friends) is remembered, also across game restarts, so `/w` and `/invite` work for players who are not around anymore.
- **Settings page** in Esc → Mod Settings (with Better Mod Settings).
- **English and German.** The mod's texts follow the game's language.

## Commands

The game's own commands keep working: `/all`, `/p`, `/s`, `/r`. Chat Plus adds:

| Command | What it does |
|---|---|
| `/w`, `/whisper`, `/tell <name> [message]` | Opens a whisper channel with the player and sends the message |
| `/invite`, `/inv <name>` | Invites the player to your group |
| `/leave` | Leaves your group |
| `/ignore <name>` | Ignores the player. `/ignore` alone lists the players you ignore |
| `/unignore <name>` | Stops ignoring the player |
| `/friend`, `/addfriend <name>` | Sends a friend request |
| `/clear` | Removes chat messages; they don't come back after a scene change or character switch. What it removes is set in the settings |
| `/help` | Lists all chat commands, also those of the game and other mods |
| `/chatplus` | Checks that the game still has everything the mod uses |

Tip: Tab and Shift+Tab switch the channel while you type. This is a game feature that the game's options don't list.

### Commands of other mods

`/help` also shows the commands of other mods that support it, each mod under its own heading.

If two mods use the same command, `/help` numbers them, e.g. `[/roll:1]` and `[/roll:2]`. A plain `/roll` uses the first one, `/roll:2` the second. Mods are numbered by folder name (A-Z), the game comes last.

To choose each time instead, turn off "Auto-pick a mod for shared commands". Then `/roll 100` shows:

```
[Chat Plus] 2 matches for /roll, pick one:
1) Some Mod
2) Other Mod
Pick: /roll:1 (keeps what you typed after /roll)
```

and `/roll:2` runs the second mod's `/roll 100`.

### Finding players by name

Names are matched without regard to case, among players on your map, in your group, your friends and the address book.

Character names in Farever are not unique: several players can have the same name. When a name matches several players, Chat Plus lists them with what it knows (class, level, where and when you saw them):

```
[Chat Plus] 2 players named Senix, using 1:
1) Senix - Rogue, level 28, on your map
2) Senix - whispered with you (21:14)
Pick another: /invite Senix:2, or right-click a line
```

Right-click a line for the game's player menu, or type the name with the number (`/invite Senix:2`). By default `/invite` invites the most likely player right away, while `/w`, `/ignore` and `/friend` wait for your pick. A held whisper keeps your message: `/w Senix:2` sends it.

## Settings

Esc → Mod Settings → Chat Plus. Changes apply right away.

| Section | Setting | Default |
|---|---|---|
| Chat | Timestamps | on |
| | Keep a closed chat closed | on |
| Character switch | Keep chat on character switch | on |
| | Character switch line | off |
| | Messages kept on character switch | 500 |
| Players & commands | Remember players across restarts | on |
| | Auto-pick shared names for /invite | on |
| | Auto-pick shared names for /w | off |
| | Auto-pick a mod for shared commands | on |
| | Group /help by mod | on |
| /clear | Clear All / Group / Local / whisper / system messages | on |
| | Clear whisper channels | off |
| | Show a note after /clear | off |
| Chat size | Chat width, Chat height | 480 × 250 (the game's size) |
| Troubleshooting | Show mod errors in the chat | on |

Without Better Mod Settings, the values can be edited in `hlx\config\chat-plus\config.json` (restart the game afterwards).

## Requirements

- [HLX Core](https://github.com/hlx-framework/hlx-core).
- Better Mod Settings by xWink, for the settings page (optional).

## Installation

Install with Vortex, or extract the archive into the Farever game folder so that the mod ends up in `<Farever folder>\hlx\mods\chat-plus\chat-plus.hl`. Start the game. If the Chat Plus page is missing in Mod Settings on the first start, restart the game once.

To remove the mod, delete `hlx\mods\chat-plus\` and, for its settings, `hlx\config\chat-plus\`.

## Good to know

- Timestamps show when your client received the message.
- `/w` and `/invite` can only find players the mod has seen: on your map, in your group, in your friend list, or in your chat. The game offers no name search.
- The address book is stored in `hlx\mods\chat-plus\players.json`. Turn off "Remember players across restarts" to keep it for the current session only.
- `/clear` cannot be undone.
- The mod changes only your own client. Nothing is sent that the game's own chat and player menu couldn't send.

## After a game update

At every start Chat Plus checks that the game still has the functions it uses. If something is missing, red `[Chat Plus]` lines in the chat name it and the feature that stops working; the rest of the mod keeps working. `/chatplus` runs the check at any time. Details are in `hlx\logs\hlx.log`.

## For mod authors

To show your commands in `/help`, add this to your mod's `main()`. Your mod doesn't need Chat Plus for it and works the same without it.

```haxe
hlx.runtime.Registry.register("chat-commands", "my-mod", {
    id: "my-mod",                 // your mod folder, the same as the key
    mod: "My Mod",                // heading in /help
    commands: [
        {names: ["roll"], usage: "/roll [max]", text: "roll a number", texts: {de: "eine Zahl würfeln"}},
    ],
    run: runCommand,              // optional
});
```

- `names`: the command names, without `/`.
- `usage` and `text`: shown as `/roll [max] - roll a number`. `texts` is optional and holds `text` in other languages, by the game's language code.
- `run`: lets Chat Plus run your command when a player picks your mod by number. It takes the same arguments as `ui.hud.ChatBox.handleCommand`, `(chat:Dynamic, command:String, args:Dynamic)`, and returns the text to send, or `""`.

Also put this line first in your own `ChatBox.handleCommand` hook. It leaves the command to Chat Plus while Chat Plus is installed:

```haxe
if (hlx.runtime.Registry.get("chat-commands", "chat-plus") != null) return Continue;
```

All of this is optional. Your command works without it, but:

- Without registering, it isn't in `/help`.
- Without `run`, it only gets a number if no other mod without `run` comes before yours (folder order).
- Without the line in your hook, `/roll:2` still works. But if your folder name comes before `chat-plus`, a plain `/roll` always goes to your mod.

## License

MIT License, © 2026 Timo Peters (see `LICENSE`). Contains code from [HLX Core](https://github.com/hlx-framework/hlx-core), MIT License, © 2026 hlx-framework.
