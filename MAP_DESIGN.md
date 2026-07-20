# Mapa gry — Iskra pod Mułem

Aktualna scena renderuje proceduralną, przechodnią mapę o rozmiarze 26 000×14 000 jednostek i ładuje jej markery z `world_locations.json`.

| Region | Położenie | Rola |
|---|---:|---|
| Wał Miary | północny zachód | osada Zakonu Żelaznej Miary |
| Obóz Żaru | południowy środek | osada Wolnego Żaru |
| Trakt Mułu | środek | bezpieczniejszy łącznik |
| Las Trzcin | wschód | teren przejściowy i stada |
| Bagno Bezdechu | południowy wschód | nocne zagrożenia |
| Kamieniołom Tamy | zachód | twardsi wrogowie |
| Wydmy Popiołu | południowy zachód | wybrzeże |
| Szczelina Głosu | północny wschód | nadnaturalne zagrożenie |

Wszyscy 65 NPC są pozycjonowani deterministycznie na podstawie frakcji i markerów. Neutralni są rozłożeni między sześć terenów zewnętrznych, a członkowie obozów skupieni przy swoich osadach. Ruch zależy od pory: w nocy NPC wraca do fallbacku, za dnia patrolujący wykonują obchód, a inni pracują w promieniu markera.

Renderer mapy jest celowo własnym proceduralnym rozwiązaniem bez cudzych assetów. Następny etap artystyczny zastępuje poszczególne warstwy `TileMapLayer` ręcznie rysowanym atlasem, bez zmiany danych o markerach.

## Skala po korekcie przestrzeni

Mapa ma teraz **26 000 × 14 000 jednostek świata**, a kamera śledzi gracza zamiast pokazywać całą planszę naraz. Przy bazowej prędkości 180 jednostek/s przejście od jednego skraju do drugiego trwa około 144 s; skupiska mieszkańców obozów mają rozrzut do 15 000 jednostek, więc przejście przez pełny obóz może zająć około 80–120 s. To jest celowy rytm eksploracji, a nie ekranowa makieta.

## Assety aktorów

Do działania sceny podpięto prawdziwe, własne assety SVG: `player.svg`, `order_guard.svg`, `rebel.svg`, `neutral.svg` i `wolf.svg`. Są renderowane jako tekstury postaci w świecie zamiast wcześniejszych kropek. Arkusz rasterowy pozostaje materiałem referencyjnym do późniejszego atlasu animacji.

## Korekta czytelności

Rastrowa ilustracja `world_map_painted.png` nie jest już rozciągana przez 26 000 jednostek świata — to powodowało nieakceptowalne rozmycie. Mapa rozgrywki korzysta teraz z ostrych, kontrastowych warstw renderowanych w przestrzeni świata: palisady i domy Wału, kamienny trakt, osobne drzewa Lasu Trzcin, woda/trzciny Bagna, tarasy kamieniołomu, fale wybrzeża i kamienny krąg Szczeliny. Ilustracja pozostaje zasobem dla przyszłego ekranu mapy, gdzie jej rozdzielczość jest właściwa.

## Kolizje i sen

Mapa ma teraz ręcznie ustawione kolizje najważniejszych struktur: domów Wału, szybu kamieniołomu, oczek bagiennych, kamiennego kręgu Szczeliny i namiotu obozowego. Ruch rozwiązuje osie osobno, więc gracz ślizga się po przeszkodach zamiast zatrzymywać się całkowicie. Dwa posłania przy Wałach i Obozie pozwalają przespać czas do 06:00 albo 18:00, co zmienia nocne zachowania świata.
