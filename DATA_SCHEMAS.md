# Dane JSON

Każdy rekord ma stabilne tekstowe `id` w formacie `a-z`, cyfry i `_`. `data/schemas/record.schema.json` definiuje wspólne minimum. `tests/validate_data.gd` sprawdza parsowanie i duplikaty ID bez zależności zewnętrznych.

- `npcs.json`: NPC, rola, frakcja, dialog i ID rutyny.
- `npc_schedules.json`: przedział czasu, marker, aktywność i fallback.
- `items_*.json`: dane stałe przedmiotów.
- `monsters.json`, `spells.json`, `balance.json`: parametry rozgrywki.
- `quests_main.json`: kolejne etapy, cele i nagroda.

Zapis w `user://` ma pole `version`; `SaveSystem` odrzuca zapis z nowszego schematu i stosuje wartości domyślne przy brakujących polach.
