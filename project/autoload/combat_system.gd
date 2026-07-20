extends Node
## Pure formulas are intentionally callable from headless tests.
func sword_damage(strength: int, weapon_damage: int, armor: int, rank: int = 0) -> int:
	return maxi(1, weapon_damage + maxi(0, strength - 5) + rank * 2 - armor)

func bow_damage(dexterity: int, weapon_damage: int, armor: int) -> int:
	return maxi(1, weapon_damage + maxi(0, dexterity - 5) - armor)

func spell_damage(base_damage: int, resistance: int) -> int:
	return maxi(1, base_damage - resistance)

func can_cast(mana: int, mana_cost: int) -> bool:
	return mana >= mana_cost
