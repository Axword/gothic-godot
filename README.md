# Zgnilizna: Iskra pod Mułem

Grywalny, autorski vertical slice action RPG 2D dla **Godot 4.7+**. Projekt nie używa nazw, świata, dialogów ani zasobów z istniejących gier. Jest to fundament do rozbudowy pełnej krótkiej gry opisanej w `what_to_do.md`.

## Uruchomienie

1. Otwórz katalog `project/` w Godot Engine 4.7 lub nowszym.
2. Uruchom `scenes/game.tscn` (`F6`) albo projekt (`F5`).
3. Opcjonalna kontrola danych: `godot --headless --path project --script res://tests/validate_data.gd`.

## Sterowanie

- **WASD / strzałki** — ruch
- **E** — rozmowa / interakcja
- **LPM** — miecz
- **1** — czar „Iskra”
- **J** — dziennik
- **F5 / F9** — zapis / wczytanie slotu 1
- W zamku: **← → ←** (błąd niszczy wytrych)

## Co działa w wycinku

Jedna ręcznie narysowana proceduralnie lokacja, cykl dnia/nocy, 3 NPC z innymi rutynami, dialogi z wyborem, wilk z walką mieczem i czarem, skrzynia z sekwencyjnym zamkiem, quest rozgałęziony etapami oraz zapis w czytelnym JSON `user://save_1.json`.

## Status

Pełne minima z pierwotnego briefu (65 NPC, wszystkie frakcje i zawartość) **nie są jeszcze implementowane**. Aktualny PR świadomie dostarcza uruchamialny vertical slice i modularny punkt startowy zamiast udawać ukończoną produkcję.

## Rozszerzona baza danych

Druga iteracja zawiera również pełną projektową bazę danych wymaganej skali (65 NPC, 260 wpisów rutyn, 20 mieczy, 10 łuków, 4 pancerze, 10 roślin, 6 mikstur, 6 stworów, 2 czary i 21 questów). Aktualnie grywalna scena nadal jest pionowym wycinkiem z trzema NPC; pozostałe rekordy są przygotowanym kanonicznym contentem do podpięcia pod kolejne sceny.

## Menu i sloty

Projekt startuje teraz w menu głównym. Dostępne są nowa gra, wczytanie trzech slotów, wyjście oraz prosta regulacja głośności master. W grze klawisz `Esc` otwiera pauzę z zapisem/wczytaniem slotów 1–3 i powrotem do menu.
