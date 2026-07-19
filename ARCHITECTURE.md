# Architektura

`project/` jest samodzielnym projektem Godot 4.7+.

- `autoload/game_state.gd`: stan runtime, sygnały, XP i inwentarz.
- `autoload/data_loader.gd`: typed gateway JSON i kontrola duplikatów ID.
- `autoload/save_system.gd`: wersjonowany zapis JSON tylko ze stabilnymi danymi.
- `scripts/game.gd`: scena wycinka, renderer proceduralny, input, interakcje i UI.
- `data/json/`: kanoniczne dane statyczne; runtime nie serializuje referencji Godot.

Sygnały `GameState.changed`, `GameState.quest_changed` i `SaveSystem.saved` oddzielają stan od widoku. Kolejny etap powinien przenieść aktorów z `game.gd` do osobnych scen `CharacterBody2D` i zasilić je tym samym ID z JSON.

## Systemy domenowe (iteracja 2)

- `QuestSystem` przechowuje definicje questów osobno od ich stanu i emituje przejścia.
- `CombatSystem` zawiera czyste formuły miecza, łuku i czarów.
- `CrimeSystem` przyjmuje już wykrytych przez scenę świadków, więc nie tworzy wszechwiedzącego przestępstwa.
- `TrainerSystem` egzekwuje punkty nauki, walutę i limit rangi.
- `WorldTime` jest jedynym źródłem upływu czasu; `GameState` przechowuje go na potrzeby zapisu.
