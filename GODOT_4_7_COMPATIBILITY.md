# Zgodność z Godot 4.7

Projekt został ustawiony na feature flag `4.7` i renderer **GL Compatibility** w `project/project.godot`.

## Korekty dla statycznego GDScript w 4.7

Godot 4.7 traktuje niejednoznaczne typy pochodzące z `Dictionary` bardziej rygorystycznie. Renderer NPC nie używa już `:=` dla wyniku `npc_positions[id]`, ponieważ indeks słownika ma typ `Variant`. Zamiast tego stosuje jawne typy:

```gdscript
var npc_position: Vector2 = npc_positions.get(id, Vector2.ZERO)
var npc_bob: float = ...
var visual_npc: Vector2 = npc_position + Vector2(0.0, npc_bob)
```

Ten wzorzec należy zachować przy każdym dostępie do dynamicznych danych JSON lub słowników runtime.
