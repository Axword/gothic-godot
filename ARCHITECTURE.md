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

## Gameplay batch: wyposażenie i style walki

`GameState.equipped` oraz `GameState.learned_spells` są zapisywane przez `SaveSystem`. Scena gry ma dostępny przez `I` panel ekwipunku, który rzeczywiście zmienia aktywną broń/pancerz. Klawisz `2` odpala łuk po założeniu go i zużywa amunicję, a `3` rzuca Lodowy Kolec; oba style korzystają z czystych formuł `CombatSystem`.

### Trening w scenie

`TrainerSystem` jest teraz wywoływany z realnego dialogu NPC. Prowadzący szkolenie pokazuje rangę, limit, punkty nauki i koszt, a zakup bezpośrednio zmienia rankę; ranga miecza wpływa na formułę obrażeń w scenie.

### Kradzież i trofea

`TheftSystem` otrzymuje listę świadków policzoną przez scenę w promieniu czynu i deleguje eskalację do `CrimeSystem`; strażnicy oraz wojownicy-świadkowie przechodzą do agresji. `SkinningSystem` blokuje pobranie trofeum z ciała bez rangi `skinning`, zapamiętuje zebrane zwłoki i wydaje stałe ID przedmiotu.

## Menu i save slots

`main_menu.tscn` jest sceną startową; przyciski wywołują `GameState.reset()` lub wersjonowane `SaveSystem.load_slot(slot)`. Pauza w `game.gd` używa tych samych trzech slotów, więc logika serializacji pozostaje w jednym autoloadzie.

### AI stworów

`game.gd` ma aktywną pętlę AI dla instancji stworów: stan `idle/return`, wykrycie, pościg, atak oraz powrót do markera domowego. Prędkości i zasięg wykrycia zależą od gatunku; Upiór Bezdechu jest aktywny wyłącznie nocą. Obrażenia odejmują pancerz aktualnie założony przez gracza.

### SettingsSystem

`SettingsSystem` zarządza ustawieniami silnika niezależnie od savegame: master volume, rozdzielczością, fullscreenem, czułością i napisami. Serializuje wyłącznie preferencje do `user://settings.json`, a menu główne aplikuje je przez `AudioServer` i `DisplayServer`.

### AI ludzi

Wrogi ludzie mają aktywny limitowany pościg, atak w zasięgu, lokalny alarm dla sojuszników i powrót do markera rutyny po utracie celu. Iteracja odbywa się po kopii kluczy wrogów, dlatego alarm może bezpiecznie dołączać kolejne NPC bez mutacji kolekcji podczas iteracji.

### Bezpieczne momenty i porażka

`last_safe_position` jest stanem serializowanym. Sen oraz ostateczny wybór frakcji wywołują `SaveSystem.autosave()` do slotu 0. Po HP ≤ 0 scena oferuje odrodzenie w bezpiecznym miejscu, wczytanie autosave albo powrót do menu.

### Nawigacja A*

`NavigationSystem` tworzy gruboziarnisty `AStarGrid2D` 130×70, o komórkach 200 jednostek. Kolizje landmarków oznaczają komórki solidne. Ludzie i stworzenia pobierają kolejny waypoint A* zarówno dla pościgu, jak i powrotu do rutyny, zamiast przechodzić przez domy, szyb lub Szczelinę.
