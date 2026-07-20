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

## Zrealizowane — animacje prototypowe
- [x] Widoczne stany gracza: idle, chód, atak i rzucanie czaru.
- [x] Widoczne stany wilka: idle, trafienie i śmierć.
- [x] Kołysanie idle/chodu populacji NPC.
- [x] Reużywalna scena `ProceduralActor` z sześcioma stanami animacji.

## Zrealizowane — intro i zachowania świata
- [x] Intro tłumaczące konflikt, list oraz Bezdech.
- [x] Kontekstowe rozmowy lore dla pełnej populacji NPC.
- [x] Bandyci inicjują wymuszenie, przechodzą w agresję po odmowie i mogą zostać ogłuszeni.
- [x] Cztery assety pancerzy z prawidłowymi referencjami JSON.

## Zrealizowane — wyposażenie i style walki
- [x] Ekwipunek pod `I` z aktywnym założeniem miecza, łuku i pancerza.
- [x] Łuk z wymaganym wyposażeniem, amunicją i trafieniem celu.
- [x] Lodowy Kolec z kosztem many i efektem pocisku.
- [x] Zapis wyposażenia i poznanych czarów.

## Zrealizowane — nauczyciele
- [x] Dialogowy ekran treningu oparty o `trainers.json`.
- [x] Wydawanie punktów nauki i Znaków przez `TrainerSystem`.
- [x] Ranga miecza wpływa na rzeczywiste obrażenia.

## Zrealizowane — kradzież i skórowanie
- [x] Kradzież pod `R` z lokalnymi świadkami i eskalacją CrimeSystem.
- [x] Świadkowie-ochroniarze przechodzą do agresji.
- [x] Skórowanie zwłok wilka po nauce u trenera Jelenia.
- [x] Trofeum nie jest już automatycznym łupem z zabicia.

## Zrealizowane — fauna świata
- [x] Wszystkie sześć gatunków stworów ma aktywną instancję na mapie w przypisanym biomie.
- [x] Miecz, łuk i oba czary mogą trafić dodatkowe gatunki.
- [x] Ciała dodatkowych stworów zostają w świecie i obsługują pozyskiwanie trofeów.

## Zrealizowane — wybór frakcji
- [x] Dwie grywalne próby kandydackie po głównym wycinku.
- [x] Możliwość wykonania obu prób przed ostatecznym wyborem.
- [x] Ostateczne dołączenie do Zakonu albo Wolnego Żaru, blokada drugiej strony i odrębny epilog.
- [x] Wybór frakcji jest zapisany w savegame.

## Zrealizowane — menu i zapis
- [x] Menu główne: nowa gra, trzy sloty wczytania, opcje głośności i wyjście.
- [x] Pauza z trzema slotami zapisu/wczytania oraz powrotem do menu.

## Zrealizowane — AI stworów
- [x] Wykrycie, pościg, atak i powrót do biomu dla aktywnych stworów.
- [x] Odmienne prędkości golema, upiora i komara.
- [x] Nocna aktywacja Upiora Bezdechu.
- [x] Pancerz gracza redukuje obrażenia stworów.

## Zrealizowane — karta postaci i dziennik
- [x] Karta postaci pod `C` z pełnymi statystykami runtime, pancerzem, rangami i frakcją.
- [x] Dziennik pokazuje również status aktywnych prób kandydackich.
