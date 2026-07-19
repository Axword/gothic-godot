extends SceneTree
func _init() -> void:
	assert(CombatSystem.sword_damage(5, 10, 0) == 10)
	assert(CombatSystem.sword_damage(10, 10, 3) == 12)
	assert(CombatSystem.bow_damage(8, 9, 2) == 10)
	assert(CombatSystem.can_cast(5, 5))
	assert(not CombatSystem.can_cast(4, 5))
	print("RULE TESTS PASSED")
	quit()
