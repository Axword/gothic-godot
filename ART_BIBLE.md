# Art bible

Wycinek stosuje procedurally rysowaną surową ilustrację jako **tymczasowy, własny placeholder**: muł `#1f3024`, droga `#4b4030`, żar `#d06b35`, stal Zakonu `#7890a0`, czerwienie Wolnego Żaru `#c06d4f` i żółta pieczęć `#ad9a62`. To nie są cudze assety.

Docelowy asset pack: pixel-art 32 px/tile, postacie 24×32 px, cztery kierunki, czytelne sylwetki i przygaszona paleta. Żadnych zewnętrznych assetów nie dodano.

## Reprezentatywne grafiki w projekcie

W `project/assets/generated/` znajdują się trzy autorskie grafiki rastrowe, wygenerowane dla tego projektu i wykorzystujące tę samą przygaszoną paletę:

- `world_map_painted.png` — tło przechodniej mapy ośmiu regionów; jest bezpośrednio renderowane w scenie.
- `actors_sheet.png` — zestaw czytelnych sylwetek mieszkańców Zakonu, Wolnego Żaru i neutralnych ról; przygotowany do pocięcia na atlas po finalizacji kierunków/klatek.
- `combat_props.png` — zestaw rekwizytów dla broni, skrzyń, roślin, mikstur oraz sześciu archetypów stworów; przygotowany do pocięcia na ikony i SpriteFrames.

Są to grafiki własne projektu, nie import cudzych plików ani elementów z istniejących gier. Wciąż wymagają fazy technicznego atlasowania przed finalną animacją.

## Animacja prototypowa

`ProceduralActor` ma sześć stanów animacji renderowanych przez Godot: `IDLE`, `WALK`, `ATTACK`, `CAST`, `HIT`, `DEATH`. Pozwala to zachować czytelność prototypu nawet przed pocięciem arkusza aktorów na finalne SpriteFrames. W działającej scenie mapa stosuje te same zasady wizualne: oddech/idle, kołysanie chodu, łuk miecza, puls Iskry, błysk trafienia i zanik śmierci wilka.

## Aktywne sprite’y świata

`project/assets/sprites/` zawiera własne grafiki SVG gracza, strażnika Zakonu, członka Wolnego Żaru, postaci neutralnej i wilka. Są one obecnie faktycznie renderowane na mapie jako `Texture2D`, w skali 92×124 jednostek (wilk 184×124), a nie zastępowane kropkami.

## Pancerze

Dodano cztery aktywa pancerzy SVG: `plaszcz_miernika.svg`, `kolczuga_walu.svg`, `skora_zaru.svg`, `pancerz_popiolu.svg`. Każdy ma odrębną sylwetkę i kolory frakcyjne, a dane pancerzy wskazują na prawdziwe ścieżki tych assetów.
