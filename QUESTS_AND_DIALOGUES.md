# Quest i dialogi

`quest_iskra` jest zapisany kanonicznie w `project/data/json/quests_main.json`.

```text
Boruta (list) → wilk z mielizny → skrzynia Miry (← → ←) → Wrona (Pieczęć) → koniec wycinka
```

Dialogi są oszczędne i rozgałęziają się warunkiem stanu: Mira daje dalszą wskazówkę dopiero po śmierci wilka, Wrona dopiero po otrzymaniu Pieczęci. Każde okno ma bezpieczną odpowiedź „Odejdź”/„Zamknij”.

## Intro i rozmowy świata

Intro „Iskra pod Mułem” uruchamia się przed przekazaniem kontroli: wyjaśnia pochodzenie listu, konflikt Wału Miary z Wolnym Żarem oraz zagrożenie Bezdechu. Każdy NPC ma w `npcs.json` pole `lore`; zwykła rozmowa istnieje wyłącznie dlatego, że postać może przekazać konkretną informację o regionie, frakcji lub zagrożeniu. Bandyci mają `aggression: robbery`: w promieniu wykrywania uruchamiają rozmowę wymuszającą haracz albo walkę. Po odmowie atakują, a ich pokonanie to ogłuszenie, nie trwałe usunięcie postaci questowej.
