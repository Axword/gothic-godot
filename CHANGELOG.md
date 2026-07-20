# Changelog

## 2026-07-19
- Dodano działający projekt Godot 4.3+ `project/`.
- Dodano oryginalny vertical slice „Iskra pod Mułem”, proceduralny renderer, interakcję, walkę, dialog, zamek oraz zapis.
- Dodano rozdzielone JSON-y, wspólny schema record i skrypt walidacji.

## 2026-07-19 — iteracja danych i reguł
- Uzupełniono katalogi JSON o pełne minima danych wskazane w briefie.
- Dodano niezależne autoloady QuestSystem, CombatSystem, CrimeSystem, TrainerSystem i WorldTime.
- Usunięto podwójne naliczanie czasu w scenie vertical slice.

## 2026-07-19 — mapa danych świata
- Scena gry ładuje pełną populację i markery regionów z JSON.
- Dodano proceduralny renderer ośmiu regionów oraz uniwersalną interakcję z NPC.

## 2026-07-19 — grafiki reprezentatywne
- Dodano własną ilustrowaną mapę świata, arkusz aktorów i arkusz rekwizytów/walki.
- Mapa została podpięta jako tło renderowane przez scenę Godot.

## 2026-07-19 — animacje
- Dodano proceduralne animacje postaci i potwora w grywalnej scenie.
- Dodano reużywalną scenę ProceduralActor dla przyszłych NPC i potworów.

## 2026-07-19 — zgodność Godot 4.7
- Zmieniono feature flag projektu na Godot 4.7 i usunięto niejednoznaczne wnioskowanie typu `Variant` w rendererze NPC.

## 2026-07-19 — naprawa Godot 4.7.1
- Naprawiono błąd parsera `visual_npc`: wynik słownika jest teraz jawnie konwertowany do `Vector2`.
- Ustawiono feature flag projektu na 4.7 / GL Compatibility.

## 2026-07-19 — duża mapa i prawdziwe sprite’y
- Rozszerzono świat do 26 000×14 000 jednostek i dodano kamerę śledzącą gracza.
- Podpięto własne sprite’y SVG dla gracza, frakcji, postaci neutralnych i wilka zamiast punktowych placeholderów.

## 2026-07-19 — korekta czytelności mapy
- Usunięto rozciąganie rastrowego tła przez cały świat.
- Dodano ostre, kontrastowe warstwy środowiskowe i charakterystyczne landmarki wszystkich regionów.

## 2026-07-19 — intro, dialogi świata i bandyci
- Dodano intro fabularne przed sterowaniem graczem.
- Dodano informacje lore dla wszystkich NPC oraz rozmowy kontekstowe.
- Dodano automatyczne wymuszenie haraczu przez bandytów, wybór zapłaty/walki oraz walkę i ogłuszenie bandyty.
- Dodano cztery własne assety pancerzy SVG i poprawiono ich referencje danych.

## 2026-07-19 — wyposażenie oraz łuk/lód
- Dodano panel ekwipunku i zapis aktywnego wyposażenia.
- Podłączono łuk, strzały oraz Lodowy Kolec do grywalnej sceny.

## 2026-07-19 — trenerzy w gameplayu
- Podłączono nauczycieli do rozmów oraz realnego zakupu treningu.
- Podłączono rangę miecza do obrażeń.

## 2026-07-19 — kradzież i skórowanie
- Dodano TheftSystem i SkinningSystem jako autoloady.
- Podłączono kradzież, świadków, reakcję ochrony i trofeum z wilka do sceny.

## 2026-07-19 — fauna i trofea na mapie
- Dodano aktywne spawny ropuchy, kraba, golema, upiora i komara wraz z własnymi sprite’ami SVG.
- Podłączono ich obrażenia, śmierć, XP i pozyskanie trofeum.

## 2026-07-19 — kandydatura i epilog
- Dodano grywalne próby Boruty i Miry, zapis decyzji frakcyjnej oraz dwa epilogi.

## 2026-07-19 — menu i sloty
- Dodano scenę menu głównego i trzy dostępne sloty zapisu/wczytania.
- Dodano menu pauzy oraz podstawową regulację master volume.

## 2026-07-19 — AI stworów i pancerz
- Dodano stanowe AI pościgu/ataku/powrotu dla stworów na mapie.
- Podłączono wartości czterech pancerzy do redukcji obrażeń.

## 2026-07-19 — karta postaci
- Dodano ekran statystyk pod klawiszem C i rozszerzono dziennik o kandydatury frakcyjne.

## 2026-07-19 — system opcji
- Dodano SettingsSystem oraz ekran opcji w menu głównym.

## 2026-07-19 — przeszkody i sen
- Dodano kolizje struktur świata oraz łóżka z przyspieszeniem czasu.

## 2026-07-19 — pickupy roślin i mikstur
- Dodano punkty zbioru wszystkich roślin/mikstur, trwałe zapamiętywanie ich stanu i użycie podstawowych mikstur.

## 2026-07-19 — używanie przedmiotów i nagrody frakcyjne
- Rozszerzono ekwipunek o konsumpcję wszystkich mikstur/wywarów oraz podstawowych ziół.
- Dodano pancerze jako nagrody za dołączenie do obu frakcji.

## 2026-07-19 — zamki I–III
- Rozszerzono minigrę o trzy skrzynie, rangi zamków i różne sekwencje.

## 2026-07-19 — czterdzieści skrzyń świata
- Zastąpiono trzy skrzynie 40 skrzyniami danych, z nagrodami walidowanymi względem katalogu przedmiotów.

## 2026-07-19 — handel
- Dodano shops.json, walidację ofert i dialogowe zakupy u kowala/przemytników.

## 2026-07-19 — sprzedaż i zniżki
- Dodano sprzedaż trofeów oraz 15% zniżkę frakcyjną w sklepach.

## 2026-07-19 — pościg i alarm NPC
- Dodano AI pościgu/ataku/powrotu dla agresywnych ludzi oraz lokalną reakcję grupy.

## 2026-07-20 — proceduralne SFX
- Dodano AudioSystem i własne proceduralne WAV-y dla kluczowych akcji.
