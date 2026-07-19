# Mapa gry — Iskra pod Mułem

Aktualna scena renderuje proceduralną, przechodnią mapę o rozmiarze 1070×530 jednostek i ładuje jej markery z `world_locations.json`.

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
