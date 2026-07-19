# Architektura

`project/` jest samodzielnym projektem Godot 4.3+.

- `autoload/game_state.gd`: stan runtime, sygnały, XP i inwentarz.
- `autoload/data_loader.gd`: typed gateway JSON i kontrola duplikatów ID.
- `autoload/save_system.gd`: wersjonowany zapis JSON tylko ze stabilnymi danymi.
- `scripts/game.gd`: scena wycinka, renderer proceduralny, input, interakcje i UI.
- `data/json/`: kanoniczne dane statyczne; runtime nie serializuje referencji Godot.

Sygnały `GameState.changed`, `GameState.quest_changed` i `SaveSystem.saved` oddzielają stan od widoku. Kolejny etap powinien przenieść aktorów z `game.gd` do osobnych scen `CharacterBody2D` i zasilić je tym samym ID z JSON.
