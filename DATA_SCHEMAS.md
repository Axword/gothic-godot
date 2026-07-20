# Dane JSON

Każdy rekord ma stabilne tekstowe `id` w formacie `a-z`, cyfry i `_`. `data/schemas/record.schema.json` definiuje wspólne minimum. `tests/validate_data.gd` sprawdza parsowanie i duplikaty ID bez zależności zewnętrznych.

- `npcs.json`: NPC, rola, frakcja, dialog i ID rutyny.
- `npc_schedules.json`: przedział czasu, marker, aktywność i fallback.
- `items_*.json`: dane stałe przedmiotów.
- `monsters.json`, `spells.json`, `balance.json`: parametry rozgrywki.
- `quests_main.json`: kolejne etapy, cele i nagroda.

Zapis w `user://` ma pole `version`; `SaveSystem` odrzuca zapis z nowszego schematu i stosuje wartości domyślne przy brakujących polach.

## Rozbudowana zawartość

W tej iteracji wszystkie wymagane katalogi danych są obecne: 20 mieczy, 10 łuków, 4 pancerze gracza, 10 roślin, 6 mikstur, trofea, 65 NPC (20 Zakon, 20 Wolny Żar, 25 neutralnych), 260 wpisów rutyn, 6 potworów i spawnów, lokacje, loot, trenerzy, czary, questy oraz trzy pliki dialogowe. Referencje są ID, nigdy ścieżkami do instancji runtime.

### NPC: informacje świata i agresja

`npcs.json` ma pola `lore` (konkretna kwestia o świecie), `can_talk` oraz opcjonalne `aggression: "robbery"`. Dzięki temu interakcja nie tworzy pustego dialogu: każdy rozmówca ma określony temat, a bandyta ma osobną inicjację konfliktu.

### Runtime skrzyń

Skrzynie świata wykorzystują stabilne ID, poziom `1–3`, sekwencję i ID nagrody. Stan otwarcia trafia do `GameState.opened_chests`, a następnie do slotu zapisu.

### world_chests.json

Kanoniczna lista skrzyń świata. Rekord zawiera stabilne `id`, `position` (`x`, `y`), `level` 1–3, sekwencję zamka oraz `reward` odwołujący się do istniejącego ID przedmiotu. Walidator kontroluje unikalność oraz referencję nagrody.
