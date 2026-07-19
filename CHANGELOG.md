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
