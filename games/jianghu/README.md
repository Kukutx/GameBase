# Pocket Jianghu (掌中江湖)

A wuxia desktop pet and idle game. A little swordsman lives on the taskbar of your desktop: they sit and cultivate, practise the sword, stroll along the taskbar and sleep at night by your clock, while their cultivation climbs and they roam the jianghu on their own. Everything here is original: the hero and the landscape are drawn from shapes in code, and the sounds and the music were synthesised for the game (`source/synth_audio.py`). The game uses no gameplay module of Tiamat; its state is its own (`Cultivation`, `game/idle/`) and keeps in `WorldState`.

## Run

From the repository root, link the foundation once, then open `games/jianghu/project.godot` in Godot:

```text
node tools/link.js --game jianghu
```

The main scene (`game/ui/boot.tscn`) has no title: the hero has one life, so it continues the first slot's save, or starts a new game. `node tools/validate.js --game jianghu` runs this game's checks; the runtime smoke ends with `Pocket Jianghu smoke passed.`.

## Where the hero lives

- **On the desktop** (Windows, macOS and Linux with a compositor): a borderless, see-through window that stays on top, standing on the taskbar at the bottom right. Clicks pass through everywhere except the hero and the open scroll. Drag the hero to carry them anywhere; strolls move the window along the taskbar. The window's place is remembered (`user://jianghu_window.json`, a device setting, not the save).
- **In a window** (the web, a phone, or with the option off): an ink-wash landscape whose colours follow the region the hero roams, with the scroll beside or above the hero.

Click the hero to pat them (cultivation ×2 for a minute, once every five minutes) and to open or close the scroll.

## Play

- **Cultivation** fills the nine layers of each of eight realms (初窥门径 to 破碎虚空) on its own. The step into the next realm is the player's (冲击境界), once the last layer is full and the realm's gate region is beaten.
- **Roaming**: the hero fights a foe every few seconds in the region they roam; ten foes, then the region's boss. Wins pay silver; a loss means a short rest. Beating a boss opens the next of eight regions, from Bluestone Town to the Martial Assembly, whose last boss crowns the hero first under heaven.
- **Martial arts**: nine arts bought with silver, each raising cultivation, attack, health, fight pace, silver or the chance of a double blow; later arts open with later realms.
- **Time away**: closing the game is a save point; the next start plays out up to twelve hours away and tells what happened.

The numbers live in `game/idle/rules.gd`. A simulation of a player who always studies the cheapest art reaches the first boss in about four minutes, the fourth realm in under an hour and the crown after about forty hours of play and time away.
