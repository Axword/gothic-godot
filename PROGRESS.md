# Progress

## Zrealizowane — 2026-07-19
- [x] Godot 4.3 project, Input Map i autoloady.
- [x] Uruchamialny vertical slice z UI budowanym z `Control`/`Container`.
- [x] Ruch, dzień/noc, trzy odmienne rutyny NPC.
- [x] Miecz, czar, wróg, XP, przedmioty i quest.
- [x] Zamek z deterministyczną sekwencją i kosztem błędu.
- [x] Wersjonowany zapis/wczytanie JSON oraz walidacja danych.

## Następny P0
- [ ] Przenieść świat do scen TileMapLayer i aktorów `CharacterBody2D`.
- [ ] Dodać dwa obozy, pełną bazę danych i system questów zamiast wycinka.
- [ ] Zautomatyzować smoke test na binarce Godot w CI.

## Zrealizowane — iteracja danych i systemów
- [x] Pełne minima katalogu danych: 65 NPC i harmonogramy, 20 mieczy, 10 łuków, 4 pancerze, 10 roślin, 6 mikstur, 6 stworów, dwa czary.
- [x] 5 questów Zakonu, 5 Wolnego Żaru i 10 pobocznych jako dane JSON.
- [x] Modułowe systemy questów, treningu, przestępstw, czasu i formuł walki.
- [x] Test reguł walki do uruchomienia headless.

## Zrealizowane — mapa świata
- [x] Proceduralna mapa całego regionu z ośmioma wymaganymi biomami/regionami.
- [x] Rozmieszczenie 65 NPC ładowane z JSON oraz zachowania dobowe dla populacji.
- [x] Interakcja i widoczne etykiety dla każdego NPC w zasięgu gracza; specjalne dialogi Boruty, Miry i Wrony pozostają osią wycinka.
