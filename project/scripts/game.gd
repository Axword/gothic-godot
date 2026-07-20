extends Node2D
## Self-contained, original vertical slice. Art is deliberately procedural while production sprites are pending.

const WORLD: Rect2 = Rect2(0, 0, 26000, 14000)
const WALK_SPEED: float = 180.0
const INTERACT_DISTANCE: float = 58.0
const MAP_TEXTURE: Texture2D = preload("res://assets/generated/world_map_painted.png")
const ACTORS_TEXTURE: Texture2D = preload("res://assets/generated/actors_sheet.png")
const PROPS_TEXTURE: Texture2D = preload("res://assets/generated/combat_props.png")
const PLAYER_TEXTURE: Texture2D = preload("res://assets/sprites/player.svg")
const ORDER_TEXTURE: Texture2D = preload("res://assets/sprites/order_guard.svg")
const REBEL_TEXTURE: Texture2D = preload("res://assets/sprites/rebel.svg")
const NEUTRAL_TEXTURE: Texture2D = preload("res://assets/sprites/neutral.svg")
const WOLF_TEXTURE: Texture2D = preload("res://assets/sprites/wolf.svg")
const ARMOR_ORDER_TEXTURE: Texture2D = preload("res://assets/sprites/armor/plaszcz_miernika.svg")
const ARMOR_WALL_TEXTURE: Texture2D = preload("res://assets/sprites/armor/kolczuga_walu.svg")
const ARMOR_REBEL_TEXTURE: Texture2D = preload("res://assets/sprites/armor/skora_zaru.svg")
const ARMOR_ASH_TEXTURE: Texture2D = preload("res://assets/sprites/armor/pancerz_popiolu.svg")
const TOAD_TEXTURE: Texture2D = preload("res://assets/sprites/monsters/toad.svg")
const CRAB_TEXTURE: Texture2D = preload("res://assets/sprites/monsters/crab.svg")
const GOLEM_TEXTURE: Texture2D = preload("res://assets/sprites/monsters/golem.svg")
const WRAITH_TEXTURE: Texture2D = preload("res://assets/sprites/monsters/wraith.svg")
const MOSQUITO_TEXTURE: Texture2D = preload("res://assets/sprites/monsters/mosquito.svg")
var player: Vector2
var message := "Przybyłeś z listem, którego nie pisałeś."
var message_timer := 7.0
var selected: String = ""
var attack_timer := 0.0
var cast_timer := 0.0
var player_facing := Vector2.DOWN
var player_is_walking := false
var wolf_death_timer := 0.0
var wolf_hit_timer := 0.0
var hostile_npcs: Dictionary = {}
var npc_combat_hp: Dictionary = {}
var robbery_cooldowns: Dictionary = {}
var bandit_attack_timer := 0.0
var current_trainer_id: String = ""
var wolf_hp := 32
var wolf_position := Vector2(17200, 7200)
var npc_positions: Dictionary = {}
var npc_names: Dictionary = {}
var npc_data: Dictionary = {}
var location_positions: Dictionary = {}
var npc_home: Dictionary = {}
var creatures: Dictionary = {}
var dialogue: Dictionary = {}
var dialogue_open := false
var lock_open := false
var journal_open := false
var inventory_open := false
var projectile_flash_timer := 0.0
var projectile_flash_position := Vector2.ZERO
var ui: CanvasLayer
var hud: Label
var prompt: Label
var panel: PanelContainer
var panel_text: RichTextLabel
var choices: VBoxContainer

func _ready() -> void:
	_ensure_input_map()
	player = GameState.player_position
	_load_world_population()
	_load_creatures()
	_create_camera()
	_build_ui()
	_show_intro()
	SaveSystem.saved.connect(_notice)
	GameState.changed.connect(queue_redraw)
	queue_redraw()


func _create_camera() -> void:
	var camera := Camera2D.new()
	camera.name = "WorldCamera"
	camera.position = player
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 6.0
	camera.make_current()
	add_child(camera)

func _ensure_input_map() -> void:
	var bindings := {"move_left": KEY_A, "move_right": KEY_D, "move_up": KEY_W, "move_down": KEY_S, "interact": KEY_E, "cast_fire": KEY_1, "cast_ice": KEY_3, "use_bow": KEY_2, "open_inventory": KEY_I, "steal": KEY_R, "open_journal": KEY_J, "save_game": KEY_F5, "load_game": KEY_F9}
	for action: String in bindings:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		var key_event := InputEventKey.new()
		key_event.keycode = int(bindings[action])
		InputMap.action_add_event(action, key_event)
	if not InputMap.has_action("attack"):
		InputMap.add_action("attack")
		var mouse_event := InputEventMouseButton.new()
		mouse_event.button_index = MOUSE_BUTTON_LEFT
		InputMap.action_add_event("attack", mouse_event)

func _load_world_population() -> void:
	for location: Dictionary in DataLoader.load_array("res://data/json/world_locations.json"):
		var marker: Dictionary = location.get("marker", {})
		location_positions[str(location.get("id", ""))] = Vector2(float(marker.get("x", 500)), float(marker.get("y", 330)))
	var faction_homes := {"Zakon Żelaznej Miary": "wal_miary", "Wolny Żar": "oboz_zaru", "neutralna": "trakt_mulu"}
	var index := 0
	for npc: Dictionary in DataLoader.load_array("res://data/json/npcs.json"):
		var id := str(npc.get("id", "")); var faction := str(npc.get("faction", "neutralna"))
		var home_id := str(faction_homes.get(faction, "trakt_mulu"))
		# Neutralni są rozrzuceni po terenie, obozy mają zwarte, czytelne skupiska.
		if faction == "neutralna":
			var neutral_regions := ["trakt_mulu", "las_trzcin", "bagno_bezdechu", "kamieniolom_tamy", "wydmy_popiolu", "szczelina_glosu"]
			home_id = neutral_regions[index % neutral_regions.size()]
		var home: Vector2 = location_positions.get(home_id, Vector2(500, 330))
		var offset := Vector2(float((index * 1731) % 15000 - 7500), float((index * 947) % 8000 - 4000))
		npc_positions[id] = home + offset; npc_home[id] = home + offset
		npc_names[id] = "%s, %s" % [str(npc.get("name", "Nieznany")), str(npc.get("role", "mieszkaniec"))]
		npc_data[id] = npc
		if str(npc.get("role", "")) == "bandit": npc_combat_hp[id] = 45
		index += 1

func _load_creatures() -> void:
	# Stałe spawny reprezentują wszystkie gatunki danych, bez skalowania poziomu.
	var positions := {"ropucha_mulowa": Vector2(21100, 10800), "krab_wydmowy": Vector2(3100, 11900), "golem_tamy": Vector2(3600, 6200), "upior_bezdechu": Vector2(22400, 3000), "komar_krwawy": Vector2(20200, 10100)}
	for monster: Dictionary in DataLoader.load_array("res://data/json/monsters.json"):
		var monster_id := str(monster.get("id", ""))
		if positions.has(monster_id):
			creatures[monster_id] = {"data": monster, "position": positions[monster_id], "hp": int(monster.get("hp", 30)), "dead": false, "harvested": false}

func _build_ui() -> void:
	ui = CanvasLayer.new(); add_child(ui)
	hud = Label.new(); hud.position = Vector2(18, 12); hud.add_theme_font_size_override("font_size", 17); ui.add_child(hud)
	prompt = Label.new(); prompt.position = Vector2(18, 615); prompt.add_theme_font_size_override("font_size", 16); ui.add_child(prompt)
	panel = PanelContainer.new(); panel.position = Vector2(170, 365); panel.size = Vector2(810, 245); panel.visible = false; ui.add_child(panel)
	var margin := MarginContainer.new(); margin.add_theme_constant_override("margin_left", 18); margin.add_theme_constant_override("margin_right", 18); margin.add_theme_constant_override("margin_top", 12); margin.add_theme_constant_override("margin_bottom", 12); panel.add_child(margin)
	var column := VBoxContainer.new(); margin.add_child(column)
	panel_text = RichTextLabel.new(); panel_text.bbcode_enabled = true; panel_text.custom_minimum_size = Vector2(0, 115); panel_text.fit_content = true; panel_text.add_theme_font_size_override("normal_font_size", 17); column.add_child(panel_text)
	choices = VBoxContainer.new(); column.add_child(choices)

func _process(delta: float) -> void:
	if not dialogue_open and not lock_open and not journal_open and not inventory_open:
		_move_player(delta)
		_handle_world_input()
	attack_timer = maxf(0.0, attack_timer - delta)
	cast_timer = maxf(0.0, cast_timer - delta)
	projectile_flash_timer = maxf(0.0, projectile_flash_timer - delta)
	wolf_hit_timer = maxf(0.0, wolf_hit_timer - delta)
	wolf_death_timer = maxf(0.0, wolf_death_timer - delta)
	message_timer = maxf(0.0, message_timer - delta)
	_update_npc_routines()
	_update_bandit_aggression(delta)
	_update_ui()
	queue_redraw()

func _move_player(delta: float) -> void:
	var direction := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	player_is_walking = direction.length_squared() > 0.01
	if player_is_walking:
		player_facing = direction.normalized()
	player += direction * WALK_SPEED * delta
	player.x = clampf(player.x, WORLD.position.x + 48, WORLD.end.x - 48)
	player.y = clampf(player.y, WORLD.position.y + 48, WORLD.end.y - 48)
	var camera := get_node_or_null("WorldCamera") as Camera2D
	if camera != null: camera.position = player
	GameState.player_position = player

func _handle_world_input() -> void:
	if Input.is_action_just_pressed("save_game"):
		SaveSystem.save_slot()
	if Input.is_action_just_pressed("load_game") and SaveSystem.load_slot():
		player = GameState.player_position
	if Input.is_action_just_pressed("open_inventory"):
		_show_inventory()
	if Input.is_action_just_pressed("steal"):
		_attempt_theft()
	if Input.is_action_just_pressed("open_journal"):
		_show_journal()
	if Input.is_action_just_pressed("use_bow"):
		fire_bow()
	if Input.is_action_just_pressed("cast_ice"):
		cast_ice()
	if Input.is_action_just_pressed("interact"):
		interact()
	if Input.is_action_just_pressed("attack"):
		attack()
	if Input.is_action_just_pressed("cast_fire"):
		cast_fire()

func _update_npc_routines() -> void:
	var hour: int = int(GameState.world_minutes / 60.0) % 24
	for id: String in npc_positions:
		var home: Vector2 = npc_home.get(id, npc_positions[id])
		var npc: Dictionary = npc_data.get(id, {})
		var role := str(npc.get("role", ""))
		# Patrolujący krążą w dzień; pracownicy wykonują krótkie ruchy, śpiący wracają do fallbacku.
		if hour >= 22 or hour < 6:
			npc_positions[id] = home
		elif role in ["guard", "captain", "fighter", "bandit"]:
			npc_positions[id] = home + Vector2(sin(GameState.world_minutes * 0.035 + home.x) * 24.0, cos(GameState.world_minutes * 0.035 + home.y) * 16.0)
		else:
			npc_positions[id] = home + Vector2(sin(GameState.world_minutes * 0.07 + home.y) * 6.0, 0.0)

func _update_bandit_aggression(delta: float) -> void:
	bandit_attack_timer = maxf(0.0, bandit_attack_timer - delta)
	for id: String in npc_data:
		var npc: Dictionary = npc_data[id]
		if str(npc.get("aggression", "")) != "robbery" or GameState.defeated.has(id): continue
		var pos: Vector2 = npc_positions.get(id, Vector2.ZERO)
		if hostile_npcs.has(id):
			if player.distance_to(pos) < 260.0 and bandit_attack_timer <= 0.0:
				GameState.hp = maxi(0, GameState.hp - 4); bandit_attack_timer = 1.5
				_notice(false, "%s tnie cię po kieszeni i przy okazji po żebrach." % str(npc.get("name", "Bandyta")))
		elif not dialogue_open and not lock_open and not journal_open and player.distance_to(pos) < 330.0 and not robbery_cooldowns.has(id):
			robbery_cooldowns[id] = true
			_start_robbery(id)

func _start_robbery(id: String) -> void:
	var npc: Dictionary = npc_data.get(id, {})
	dialogue_open = true; panel.visible = true
	GameState.flags["robbery_id"] = id
	_show_choices("[b]%s:[/b] Stój. Trakt ma opłatę. Pięć Znaków albo trochę twojej krwi na błocie." % str(npc.get("name", "Bandyta")), [["Zapłać 5 Znaków.", "pay_bandit"], ["Nie płacę. Spróbuj.", "fight_bandit"]])

func nearest_target() -> String:
	var best := ""; var distance := INTERACT_DISTANCE
	for id: String in npc_positions:
		var d := player.distance_to(npc_positions[id])
		if d < distance: best = id; distance = d
	if player.distance_to(Vector2(15100, 9600)) < distance and not GameState.opened_chests.has("skrzynia_popiolu"):
		best = "chest"
	if player.distance_to(wolf_position) < distance and wolf_hp > 0:
		best = "wolf"
	return best

func interact() -> void:
	selected = nearest_target()
	if wolf_hp <= 0 and wolf_death_timer <= 0.0 and player.distance_to(wolf_position) < 180.0:
		_harvest_wolf()
		return
	var corpse_id := _near_creature_corpse()
	if not corpse_id.is_empty():
		_harvest_creature(corpse_id)
		return
	match selected:
		"chest": _open_lock()
		"wolf": _notice(true, "Wilk nie prowadzi rozmów. Zwykle.")
		_:
			if npc_data.has(selected): _start_dialogue(selected)
			else: _notice(true, "Tu nic nie odpowiada.")

func _near_creature_corpse() -> String:
	for creature_id: String in creatures:
		var creature: Dictionary = creatures[creature_id]
		var creature_pos: Vector2 = creature.get("position", Vector2.ZERO)
		if bool(creature.get("dead", false)) and player.distance_to(creature_pos) < 180.0: return creature_id
	return ""

func _harvest_creature(creature_id: String) -> void:
	var creature: Dictionary = creatures[creature_id]
	var trophy := SkinningSystem.harvest(creature_id, int(TrainerSystem.ranks.get("skinning", 0)))
	if trophy.is_empty():
		_notice(false, "Potrzebujesz nauki skórowania albo ciało jest już opróżnione.")
	else:
		creature["harvested"] = true; creatures[creature_id] = creature
		_notice(true, "Pozyskujesz: " + trophy.replace("_", " ") + ".")

func _harvest_wolf() -> void:
	var rank := int(TrainerSystem.ranks.get("skinning", 0))
	var trophy := SkinningSystem.harvest("wilk_z_mielizny", rank)
	if trophy.is_empty():
		_notice(false, "Bez nauki skórowania zostawisz z wilka tylko bałagan. Znajdź łowcę Jelenia.")
	else:
		_notice(true, "Pozyskujesz: " + trophy.replace("_", " ") + ".")

func _attempt_theft() -> void:
	var owner_id := nearest_target()
	if owner_id.is_empty() or not npc_data.has(owner_id):
		_notice(false, "Nie ma tu nikogo, kogo da się okraść."); return
	var witnesses: Array[String] = []
	for id: String in npc_positions:
		if id != owner_id and player.distance_to(npc_positions.get(id, Vector2.ZERO)) < 350.0: witnesses.append(id)
	var outcome := TheftSystem.attempt(owner_id, "zlote_znaki", witnesses)
	if outcome == "success":
		if bool(GameState.flags.get("new_candidate_started", false)): GameState.flags["new_candidate_ready"] = true
		_notice(true, "Znak znika z cudzej kieszeni. Nikt nie krzyczy.")
	else:
		_notice(false, "Ktoś widział twoją rękę. Reakcja: " + outcome + ".")
		for witness_id: String in witnesses:
			var npc: Dictionary = npc_data.get(witness_id, {})
			if str(npc.get("role", "")) in ["guard", "captain", "fighter"]: hostile_npcs[witness_id] = true

func _nearest_hostile() -> String:
	var nearest := ""; var distance := INF
	for id: String in hostile_npcs:
		if GameState.defeated.has(id): continue
		var pos: Vector2 = npc_positions.get(id, Vector2.ZERO)
		var candidate_distance := player.distance_to(pos)
		if candidate_distance < distance: nearest = id; distance = candidate_distance
	return nearest

func _damage_creature(creature_id: String, damage: int) -> void:
	var creature: Dictionary = creatures[creature_id]
	creature["hp"] = int(creature.get("hp", 1)) - damage
	if int(creature["hp"]) <= 0:
		creature["dead"] = true; GameState.gain_xp(25)
		if creature_id == "golem_tamy" and bool(GameState.flags.get("old_candidate_started", false)):
			GameState.flags["old_candidate_ready"] = true
		_notice(true, str(creature.get("data", {}).get("name", "Stworzenie")) + " pada. Możesz pozyskać trofeum.")
	else:
		_notice(true, "Trafiasz bestię.")
	creatures[creature_id] = creature

func attack() -> void:
	attack_timer = 0.30
	var creature_target := _nearest_combat_target(150.0)
	var hostile_id := _nearest_hostile()
	if not creature_target.is_empty() and creature_target != "wolf" and creatures.has(creature_target):
		_damage_creature(creature_target, CombatSystem.sword_damage(GameState.strength, 10, 0, int(TrainerSystem.ranks.get("sword", 0))))
	elif not hostile_id.is_empty() and player.distance_to(npc_positions.get(hostile_id, Vector2.ZERO)) < 130.0:
		npc_combat_hp[hostile_id] = int(npc_combat_hp.get(hostile_id, 45)) - CombatSystem.sword_damage(GameState.strength, 10, 0, int(TrainerSystem.ranks.get("sword", 0)))
		if int(npc_combat_hp[hostile_id]) <= 0:
			GameState.defeated.append(hostile_id); hostile_npcs.erase(hostile_id); GameState.gain_xp(30); _notice(true, "Bandyta pada ogłuszony. Żyje, ale ma gorszy dzień.")
		else: _notice(true, "Trafiasz bandytę.")
	elif player.distance_to(wolf_position) < 130 and wolf_hp > 0:
		wolf_hp -= CombatSystem.sword_damage(GameState.strength, 10, 0, int(TrainerSystem.ranks.get("sword", 0)))
		wolf_hit_timer = 0.18
		if wolf_hp <= 0:
			wolf_death_timer = 0.9
			GameState.defeated.append("wilk_z_mielizny")
			GameState.gain_xp(35)
			if GameState.quest_stage == "speak": GameState.advance_quest("wolf")
			_notice(true, "Wilk pada. Zostawia skórę i ciszę.")
		else: _notice(true, "Stal trafia: wilk warczy.")

func fire_bow() -> void:
	if str(GameState.equipped.get("weapon", "")) != "luk_1":
		_notice(false, "Najpierw załóż Łuk Wiklinowy w ekwipunku [I]."); return
	if not GameState.remove_item("strzala_trzcinowa", 1):
		_notice(false, "Nie masz strzał."); return
	var target := _nearest_combat_target(900.0)
	projectile_flash_position = player + player_facing * 240.0; projectile_flash_timer = 0.20
	if not target.is_empty() and target != "wolf" and creatures.has(target):
		_damage_creature(target, CombatSystem.bow_damage(GameState.dexterity, 7, 0))
	elif target == "wolf":
		wolf_hp -= CombatSystem.bow_damage(GameState.dexterity, 7, 0)
		wolf_hit_timer = 0.18
		if wolf_hp <= 0: attack()
	elif not target.is_empty():
		npc_combat_hp[target] = int(npc_combat_hp.get(target, 45)) - CombatSystem.bow_damage(GameState.dexterity, 7, 0)
		if int(npc_combat_hp[target]) <= 0: GameState.defeated.append(target); hostile_npcs.erase(target)
	_notice(true, "Strzała trzcinowa świszczy w ciemności.")

func cast_ice() -> void:
	if not GameState.learned_spells.has("lodowy_kolec") or GameState.mana < 7:
		_notice(false, "Nie znasz Lodowego Kolca albo brakuje many."); return
	GameState.mana -= 7; cast_timer = 0.42
	var target := _nearest_combat_target(650.0)
	projectile_flash_position = player + player_facing * 180.0; projectile_flash_timer = 0.26
	if not target.is_empty() and target != "wolf" and creatures.has(target): _damage_creature(target, CombatSystem.spell_damage(11, 0))
	elif target == "wolf": wolf_hp -= CombatSystem.spell_damage(11, 0); wolf_hit_timer = 0.25
	elif not target.is_empty(): npc_combat_hp[target] = int(npc_combat_hp.get(target, 45)) - CombatSystem.spell_damage(11, 0)
	_notice(true, "Lodowy Kolec pęka na wilgotnym powietrzu.")

func _nearest_combat_target(maximum_distance: float) -> String:
	for creature_id: String in creatures:
		var creature: Dictionary = creatures[creature_id]
		var creature_pos: Vector2 = creature.get("position", Vector2.ZERO)
		if not bool(creature.get("dead", false)) and player.distance_to(creature_pos) <= maximum_distance: return creature_id
	if wolf_hp > 0 and player.distance_to(wolf_position) <= maximum_distance: return "wolf"
	var id := _nearest_hostile()
	if not id.is_empty() and player.distance_to(npc_positions.get(id, Vector2.ZERO)) <= maximum_distance: return id
	return ""

func cast_fire() -> void:
	cast_timer = 0.42
	if GameState.mana < 5: _notice(false, "Za mało many."); return
	GameState.mana -= 5
	if player.distance_to(wolf_position) < 240 and wolf_hp > 0:
		wolf_hp -= 14
		if wolf_hp <= 0: attack()
	_notice(true, "Iskra przecina wilgotne powietrze.")

func _start_dialogue(id: String) -> void:
	dialogue_open = true; panel.visible = true
	match id:
		"npc_boruta":
			if GameState.quest_stage == "complete" and GameState.faction_choice.is_empty():
				if bool(GameState.flags.get("old_candidate_ready", false)):
					_show_choices("[b]Boruta:[/b] Golem już nie pilnuje kamieniołomu. Wykonałeś rozkaz bez pieczęci. To rzadkie.", [["Dołączam do Zakonu Żelaznej Miary.", "join_old"], ["Jeszcze nie.", "close"]])
				elif bool(GameState.flags.get("old_candidate_started", false)):
					_show_choices("[b]Boruta:[/b] Golem Tamy wciąż stoi. Nie wracaj z pustymi rękami.", [["Odejdź.", "close"]])
				else:
					_show_choices("[b]Boruta:[/b] Chcesz porządku? Udowodnij, że potrafisz go wykuć. Golem Tamy blokuje kamieniołom.", [["Podejmuję próbę Zakonu.", "start_old_candidate"], ["Nie teraz.", "close"]])
			else:
				_show_choices("[b]Boruta:[/b] List pachnie mokrym prochem. Tak pachną rzeczy, które nie chcą żyć.\n\n„Jeżeli dotarłeś, znajdź Iskrę pod Mułem. Nie ufaj ani wałowi, ani ogniowi.”", [["Pokaż list.", "boruta_list"], ["Odejdź.", "close"]])
		"npc_mira":
			if GameState.quest_stage == "complete" and GameState.faction_choice.is_empty():
				if bool(GameState.flags.get("new_candidate_ready", false)):
					_show_choices("[b]Mira:[/b] Ukradłeś pod nosem ludzi, którzy myślą, że pilnują świata. To wystarczy na początek.", [["Dołączam do Wolnego Żaru.", "join_new"], ["Jeszcze nie.", "close"]])
				elif bool(GameState.flags.get("new_candidate_started", false)):
					_show_choices("[b]Mira:[/b] Wróć, kiedy ukradniesz coś komuś, kto tego nie oddał dobrowolnie.", [["Odejdź.", "close"]])
				else:
					_show_choices("[b]Mira:[/b] Wolność nie jest hasłem. Jest ręką w cudzej kieszeni, kiedy trzeba przeżyć.", [["Podejmuję próbę Żaru.", "start_new_candidate"], ["Nie teraz.", "close"]])
			else:
				_show_choices("[b]Mira:[/b] Wrona mierzy szczelinę, Boruta mierzy ludzi. Oboje wychodzą na oszustów, tylko jeden nosi hełm.", [["Zapytaj o Iskrę.", "mira_quest"], ["Odejdź.", "close"]])
		"npc_wrona":
			_show_choices("[b]Wrona:[/b] Szczelina nie jest dziurą. Jest ustami. A coś pod bagnem uczy się mówić.", [["Oddaj pieczęć z kufra.", "wrona_end"], ["Odejdź.", "close"]])
		_:
			var npc: Dictionary = npc_data.get(id, {})
			var name := str(npc.get("name", "Mieszkaniec"))
			var faction := str(npc.get("faction", "neutralna"))
			var trainer := ""
			if npc.has("trainer_skills"):
				trainer = " Potrafię uczyć: " + ", ".join(npc.get("trainer_skills", [])) + "."
			var options: Array = [["Zapytaj o pogłoski.", "rumor"]]
			var trainer_id := _trainer_for_npc(id)
			if not trainer_id.is_empty(): options.append(["Pokaż, czego uczysz.", "open_trainer"])
			options.append(["Odejdź.", "close"])
			_show_choices("[b]%s:[/b] Na tym trakcie nawet błoto ma stronę. Ja należę do: %s.%s" % [name, faction, trainer], options)

func _trainer_for_npc(npc_id: String) -> String:
	for trainer_id: String in TrainerSystem.trainers:
		var definition: Dictionary = TrainerSystem.trainers[trainer_id]
		if str(definition.get("npc_id", "")) == npc_id:
			current_trainer_id = trainer_id
			return trainer_id
	return ""

func _show_trainer() -> void:
	if current_trainer_id.is_empty(): return
	var definition: Dictionary = TrainerSystem.trainers.get(current_trainer_id, {})
	var skill := str(definition.get("skill", ""))
	var rank := int(TrainerSystem.ranks.get(skill, 0))
	_show_choices("[b]Trening: %s[/b]\nRanga: %d / %d\nKoszt: %d punkt nauki i %d Znaków.\n\nWiedza boli mniej niż rana, ale kupuje się ją tak samo." % [skill, rank, int(definition.get("rank_limit", 0)), int(definition.get("learning_cost", 1)), int(definition.get("currency_cost", 0))], [["Zapłać za trening.", "buy_training"], ["Wróć.", "close"]])

func _show_intro() -> void:
	if bool(GameState.flags.get("intro_seen", false)): return
	dialogue_open = true; panel.visible = true
	_show_choices("[b]ZGNILIZNA: ISKRA POD MUŁEM[/b]\n\nPrzyszedłeś z wojny, niosąc list bez podpisu. Kanały za tobą płoną, a przed tobą Wał Miary i Obóz Żaru wyrywają sobie ostatni suchy grunt. Pod bagnem budzi się Bezdech.\n\nNie jesteś wybrańcem. Jesteś człowiekiem z listem i pustymi kieszeniami.", [["Przeczytaj list i ruszaj.", "intro_start"], ["Kim jest Bezdech?", "intro_lore"]])

func _show_choices(text: String, entries: Array) -> void:
	panel_text.text = text
	for child: Node in choices.get_children(): child.queue_free()
	for entry: Array in entries:
		var button := Button.new(); button.text = str(entry[0]); button.pressed.connect(_choose.bind(str(entry[1]))); choices.add_child(button)

func _choose(choice: String) -> void:
	if choice == "lock_l":
		_lock_input("L")
		return
	if choice == "lock_r":
		_lock_input("R")
		return
	match choice:
		"intro_start":
			GameState.flags["intro_seen"] = true
			_show_choices("[b]List:[/b] „Jeżeli to czytasz, znajdź Iskrę pod Mułem. Nie ufaj ani wałowi, ani ogniowi.”", [["Zaczynajmy.", "close"]])
		"intro_lore":
			_show_choices("[b]Głos z pamięci:[/b] Bezdech był bogiem ludzi, którzy bali się mówić prawdę. Pogrzebali go żywcem. Teraz ziemia oddaje mu głos.", [["Wróć do listu.", "intro_start"]])
		"pay_bandit":
			var bandit_id := str(GameState.flags.get("robbery_id", ""))
			if GameState.remove_item("zlote_znaki", 5):
				_show_choices("[b]Bandyta:[/b] Rozsądnie. Rozsądek boli krócej niż stal.", [["Odejdź.", "close"]])
			else:
				hostile_npcs[bandit_id] = true
				_show_choices("[b]Bandyta:[/b] Nie masz czym zapłacić. To zapłacisz uwagą.", [["Walcz.", "fight_bandit"]])
		"fight_bandit":
			var fight_id := str(GameState.flags.get("robbery_id", "")); hostile_npcs[fight_id] = true
			_close_panel(); _notice(false, "Bandyta rusza do ataku!")
		"equip_sword":
			GameState.equip("miecz_iskrowy", "weapon"); _show_inventory()
		"equip_bow":
			GameState.equip("luk_1", "weapon"); _show_inventory()
		"equip_armor":
			GameState.equip("plaszcz_miernika", "armor"); _show_inventory()
		"open_trainer":
			_show_trainer()
		"buy_training":
			if TrainerSystem.train(current_trainer_id):
				_notice(true, "Nauka zostaje w rękach, nie w słowach."); _show_trainer()
			else:
				_notice(false, "Brakuje ci punktów nauki, Znaków albo osiągnąłeś limit."); _show_trainer()
		"start_old_candidate":
			GameState.flags["old_candidate_started"] = true
			GameState.add_quest("q_miara_rozkazu")
			_show_choices("[b]Boruta:[/b] Golem jest na zachodzie, w Kamieniołomie Tamy. Wróć, jeśli przeżyjesz.", [["Przyjąłem.", "close"]])
		"start_new_candidate":
			GameState.flags["new_candidate_started"] = true
			GameState.add_quest("q_iskra_buntu")
			_show_choices("[b]Mira:[/b] Ukradnij cokolwiek przy świadkach albo bez. Wolny Żar oceni wynik, nie metodę.", [["Przyjęłam.", "close"]])
		"join_old":
			GameState.faction_choice = "Zakon Żelaznej Miary"; GameState.flags["new_path_locked"] = true
			_show_choices("[b]Epilog — Zakon Żelaznej Miary[/b]\nZałożyłeś stalowy płaszcz i nauczyłeś się, że bezpieczeństwo zawsze ma cenę. Wał trwał dłużej, ale ludzie pod nim milczeli głębiej.", [["Koniec gry.", "close"]])
		"join_new":
			GameState.faction_choice = "Wolny Żar"; GameState.flags["old_path_locked"] = true
			_show_choices("[b]Epilog — Wolny Żar[/b]\nWybrałeś ogień zamiast wału. Obóz żył głośno i krótko, lecz przez jedną zimę nikt nie pytał o pozwolenie na oddech.", [["Koniec gry.", "close"]])
		"rumor":
			_show_choices("[b]Pogłoska:[/b] Bezdech nie lubi imion. Dlatego wszyscy tutaj mają po dwa.", [["Wystarczy.", "close"]])
		"boruta_list":
			GameState.advance_quest("speak")
			_show_choices("[b]Boruta:[/b] Pieczęć jest prawdziwa. To gorzej. Zabij wilka przy kamieniu i sprawdź kufer Miry. Ona ma klucz albo kłamstwo.", [["Rozumiem.", "close"]])
		"mira_quest":
			if GameState.quest_stage == "wolf": _show_choices("[b]Mira:[/b] Wilk przestał oddychać, a Boruta nadal. Kufer jest mój. Zamek nie. Jeśli go otworzysz, podzielimy winę po równo.", [["Otworzę kufer.", "close"]])
			else: _show_choices("[b]Mira:[/b] Najpierw wilk. Bez jego kłów nawet prawda brzmi jak plotka.", [["Odejdź.", "close"]])
		"wrona_end":
			if GameState.inventory.has("pieczec_iskry"):
				GameState.advance_quest("complete"); GameState.gain_xp(60)
				_show_choices("[b]Wrona:[/b] Więc list wybrał nogi, nie adresata. Zatrzymaj nagrodę. Kiedy bagno przemówi, wybierzesz wał albo ogień.", [["Koniec wycinka.", "close"]])
			else: _show_choices("[b]Wrona:[/b] Nie przynoś mi pustych rąk. Puste ręce już tu rządzą.", [["Odejdź.", "close"]])
		"close": _close_panel()

func _open_lock() -> void:
	lock_open = true; panel.visible = true
	_show_choices("[b]Skrzynia z popiołu — zamek I[/b]\nSekwencja zapadek: [b]LEWO, PRAWO, LEWO[/b]. Błąd zużywa wytrych.\n\nUżyj przycisków w poprawnej kolejności.", [["←", "lock_l"], ["→", "lock_r"], ["Anuluj", "close"]])
	GameState.flags["lock_input"] = ""

func _lock_input(value: String) -> void:
	var sequence: String = str(GameState.flags.get("lock_input", "")) + value
	GameState.flags["lock_input"] = sequence
	if not "LRL".begins_with(sequence):
		GameState.remove_item("wytrych"); GameState.flags["lock_input"] = ""
		_notice(false, "Zgrzyt. Wytrych pękł.")
	elif sequence == "LRL":
		GameState.opened_chests.append("skrzynia_popiolu"); GameState.add_item("pieczec_iskry"); GameState.gain_xp(25)
		if GameState.quest_stage == "wolf": GameState.advance_quest("chest")
		lock_open = false; _close_panel(); _notice(true, "Zamek puszcza. W środku: Pieczęć Iskry.")

func _input(event: InputEvent) -> void:
	if lock_open and event is InputEventKey and event.pressed:
		if event.keycode == KEY_LEFT: _lock_input("L")
		elif event.keycode == KEY_RIGHT: _lock_input("R")

func _show_inventory() -> void:
	inventory_open = not inventory_open; panel.visible = inventory_open
	if not inventory_open: return
	var inventory_lines: Array[String] = []
	for item_id: String in GameState.inventory:
		inventory_lines.append("• %s × %d" % [item_id.replace("_", " ").capitalize(), int(GameState.inventory[item_id])])
	_show_choices("[b]Ekwipunek[/b]\nBroń: %s | Pancerz: %s\n\n%s" % [str(GameState.equipped.get("weapon", "brak")), str(GameState.equipped.get("armor", "brak")), "\n".join(inventory_lines)], [["Załóż Miecz Iskrowy", "equip_sword"], ["Załóż Łuk Wiklinowy", "equip_bow"], ["Załóż Płaszcz Miernika", "equip_armor"], ["Zamknij", "close"]])

func _show_journal() -> void:
	journal_open = not journal_open; panel.visible = journal_open
	if journal_open:
		_show_choices("[b]Dziennik — Iskra pod Mułem[/b]\n" + _objective() + "\n\nSterowanie: WASD ruch · E interakcja · LPM miecz · 1 Iskra · 2 łuk · 3 Lód · I ekwipunek · R kradzież · F5/F9 zapis/wczytanie · J dziennik.", [["Zamknij", "close"]])

func _objective() -> String:
	match GameState.quest_stage:
		"start": return "Cel: Porozmawiaj z Borutą przy północnym wale."
		"speak": return "Cel: Zabij wilka z mielizny (LPM lub czar 1)."
		"wolf": return "Cel: Otwórz skrzynię Miry sekwencją ← → ←."
		"chest": return "Cel: Zanieś Pieczęć Iskry Wronie przy szczelinie."
		"complete": return "Ukończono: prawda o liście zostaje w twojej kieszeni."
	return "Cel nieznany. To też rodzaj prawdy."

func _close_panel() -> void:
	dialogue_open = false; lock_open = false; journal_open = false; inventory_open = false; panel.visible = false

func _notice(ok: bool, text: String) -> void:
	message = text; message_timer = 4.0

func _update_ui() -> void:
	var target := nearest_target()
	var context := ""
	if not dialogue_open and not lock_open and not journal_open:
		if target == "chest": context = "[E] Otwórz skrzynię z popiołu"
		elif target == "wolf": context = "[LPM] Atakuj wilka"
		elif not target.is_empty(): context = "[E] Rozmawiaj: " + str(npc_names[target]) + "  |  [R] Spróbuj okraść"
	prompt.text = context + ("\n" + message if message_timer > 0.0 else "")
	hud.text = "ZGNILIZNA  |  HP %d/%d  Mana %d/%d  |  Poz. %d  XP %d  |  %s\n%s" % [GameState.hp, GameState.max_hp, GameState.mana, GameState.max_mana, GameState.level, GameState.xp, GameState.time_text(), _objective()]

func _draw() -> void:
	var day: float = sin((GameState.world_minutes / 1440.0) * TAU - PI / 2.0) * 0.25 + 0.75
	draw_rect(Rect2(Vector2.ZERO, Vector2(1152, 648)), Color("101412"))
	draw_rect(WORLD, Color(0.12 * day, 0.19 * day, 0.14 * day))
	# Nie skalujemy rastrowego obrazu przez cały świat: przy mapie tej skali rozmywałby się i maskował interakcje.
	# Każdy biom ma ostre, proceduralne warstwy, a ilustracja pozostaje materiałem do ekranu mapy.
	# Wielka mapa: czytelne warstwy nawigacyjne renderowane w skali świata.
	draw_line(Vector2(3800, 2600), Vector2(13000, 7000), Color("5a4932"), 420.0)
	draw_line(Vector2(13000, 7000), Vector2(14500, 10300), Color("5a4932"), 420.0)
	var regions: Array[Dictionary] = [
		{"p":Vector2(3800,2600),"n":"Wał Miary","c":Color("4f5961")}, {"p":Vector2(14500,10300),"n":"Obóz Żaru","c":Color("6b382c")},
		{"p":Vector2(13000,7000),"n":"Trakt Mułu","c":Color("5a4b35")}, {"p":Vector2(19000,6000),"n":"Las Trzcin","c":Color("29452f")},
		{"p":Vector2(21800,11000),"n":"Bagno Bezdechu","c":Color("335548")}, {"p":Vector2(3500,6000),"n":"Kamieniołom Tamy","c":Color("56504b")},
		{"p":Vector2(2500,12500),"n":"Wydmy Popiołu","c":Color("756347")}, {"p":Vector2(22500,2500),"n":"Szczelina Głosu","c":Color("4b3155")}
	]
	for region: Dictionary in regions:
		var pos: Vector2 = region["p"]
		var region_color: Color = region["c"]
		draw_circle(pos, 2200.0, region_color)
		draw_arc(pos, 2230.0, 0.0, TAU, 24, Color("171b19"), 42.0)
		draw_string(ThemeDB.fallback_font, pos + Vector2(-650, -2300), str(region["n"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 260, Color("f1ead8"))
	# Wał Miary — ostre deski, budynki i stalowe bramy.
	draw_rect(Rect2(1500, 700, 5000, 3800), Color("303b40"))
	for x: float in range(1600, 6400, 180):
		draw_rect(Rect2(x, 850, 80, 3000), Color("55656a")); draw_line(Vector2(x, 850), Vector2(x, 3850), Color("1a2427"), 20.0)
	for house: Vector2 in [Vector2(2400,1600),Vector2(3800,1700),Vector2(5000,1500),Vector2(3300,3000)]:
		draw_rect(Rect2(house, Vector2(720, 520)), Color("6c6254")); draw_colored_polygon(PackedVector2Array([house + Vector2(-80,0),house + Vector2(360,-380),house + Vector2(800,0)]), Color("282e30"))
	# Trakt Mułu — szeroka droga o wyraźnej krawędzi i kamieniach.
	draw_line(Vector2(5400, 4200), Vector2(15500, 9200), Color("2d261d"), 650.0)
	draw_line(Vector2(5400, 4200), Vector2(15500, 9200), Color("786343"), 480.0)
	for stone_index: int in range(22):
		var stone_pos: Vector2 = Vector2(5700 + stone_index * 430, 4350 + stone_index * 214)
		draw_circle(stone_pos, 38.0, Color("a08c69"))
	# Las Trzcin — pojedyncze czytelne drzewa, cień i ścieżki.
	for tree_index: int in range(55):
		var tree_pos: Vector2 = Vector2(16800 + float((tree_index * 487) % 4400), 4100 + float((tree_index * 941) % 3900))
		draw_circle(tree_pos + Vector2(35,55), 180.0, Color("162a20")); draw_circle(tree_pos, 160.0, Color("31533a")); draw_rect(Rect2(tree_pos + Vector2(-28, 100), Vector2(56, 170)), Color("4c3b2b"))
	# Bagno Bezdechu — czarna woda, trzcinowiska i zielona poświata.
	draw_rect(Rect2(19000, 9000, 6000, 4300), Color("233d37"))
	for pool_index: int in range(26):
		var pool: Vector2 = Vector2(19400 + float((pool_index * 719) % 5100), 9400 + float((pool_index * 359) % 3000))
		draw_circle(pool, 180.0, Color("112725"))
		for reed_x: float in range(-140, 160, 70): draw_line(pool + Vector2(reed_x,80), pool + Vector2(reed_x+20,-120), Color("719152"), 18.0)
	# Kamieniołom — tarasy skalne i głęboki szyb.
	draw_rect(Rect2(900, 4200, 5200, 3800), Color("46433e"))
	for terrace: int in range(6):
		draw_line(Vector2(1300, 4600 + terrace * 500), Vector2(5600, 4600 + terrace * 500), Color("82765f"), 180.0)
	draw_circle(Vector2(3500, 6100), 720.0, Color("1f2424"))
	# Wydmy — brzeg, popiół i fale, wszystko ostre w skali kamery.
	draw_rect(Rect2(500, 10400, 5200, 3300), Color("9a815b")); draw_rect(Rect2(300, 12200, 5500, 1700), Color("315866"))
	for wave: int in range(12): draw_line(Vector2(500, 12300 + wave * 125), Vector2(5700, 12300 + wave * 125), Color("9fc1bd"), 20.0)
	# Szczelina Głosu — kamienny krąg i kontrastowe światło.
	draw_rect(Rect2(19800, 650, 4900, 4000), Color("30273c"))
	for ring: int in range(4): draw_arc(Vector2(22500,2500), 350.0 + ring * 210.0, 0.0, TAU, 32, Color("9b6cb3"), 55.0)
	draw_circle(Vector2(22500,2500), 270.0, Color("e2a1ed"))
	# Obóz jest fizycznie rozległy: palisady i ogniska są punktami orientacyjnymi na wielkiej przestrzeni.
	for camp_x: float in range(7000, 22000, 1200):
		draw_line(Vector2(camp_x, 8800), Vector2(camp_x + 300, 9100), Color("573728"), 90.0)
	draw_circle(Vector2(14500, 10300), 260.0, Color("d06b35")); draw_circle(Vector2(14500, 10300), 110.0, Color("f6c56d"))
	# actors
	for id: String in npc_positions:
		var faction := str(npc_data.get(id, {}).get("faction", "neutralna"))
		var color := Color("7890a0") if faction == "Zakon Żelaznej Miary" else (Color("c06d4f") if faction == "Wolny Żar" else Color("ad9a62"))
		var npc_position: Vector2 = npc_positions.get(id, Vector2.ZERO)
		var npc_bob: float = sin(Time.get_ticks_msec() * 0.005 + npc_position.x) * 8.0
		var visual_npc: Vector2 = npc_position + Vector2(0.0, npc_bob)
		var actor_texture: Texture2D = ORDER_TEXTURE if faction == "Zakon Żelaznej Miary" else (REBEL_TEXTURE if faction == "Wolny Żar" else NEUTRAL_TEXTURE)
		var actor_modulate := Color("e35c4f") if hostile_npcs.has(id) else color
		draw_texture_rect(actor_texture, Rect2(visual_npc - Vector2(46, 62), Vector2(92, 124)), false, actor_modulate)
		if hostile_npcs.has(id): draw_line(visual_npc + Vector2(-55, -10), visual_npc + Vector2(65, -10), Color("e7c486"), 14.0)
		if player.distance_to(visual_npc) < 260.0:
			draw_string(ThemeDB.fallback_font, visual_npc + Vector2(-100, -82), str(npc_names[id]).split(",")[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 36, Color.WHITE)
	# Pozostałe gatunki są realnie rozmieszczone w swoich biomach i zostawiają ciała/trofea.
	for creature_id: String in creatures:
		var creature: Dictionary = creatures[creature_id]
		var creature_pos: Vector2 = creature.get("position", Vector2.ZERO)
		var texture: Texture2D = TOAD_TEXTURE
		match creature_id:
			"krab_wydmowy": texture = CRAB_TEXTURE
			"golem_tamy": texture = GOLEM_TEXTURE
			"upior_bezdechu": texture = WRAITH_TEXTURE
			"komar_krwawy": texture = MOSQUITO_TEXTURE
		var alpha := 0.42 if bool(creature.get("dead", false)) else 1.0
		draw_texture_rect(texture, Rect2(creature_pos - Vector2(90, 75), Vector2(180, 150)), false, Color(1.0, 1.0, 1.0, alpha))
		if player.distance_to(creature_pos) < 330.0:
			draw_string(ThemeDB.fallback_font, creature_pos + Vector2(-120, -100), str(creature.get("data", {}).get("name", "Bestia")), HORIZONTAL_ALIGNMENT_LEFT, -1, 32, Color.WHITE)
	# Wilk ma czytelne stany: idle, trafienie z błyskiem i śmierć z zanikiem.
	if wolf_hp > 0 or wolf_death_timer > 0.0:
		var wolf_alpha := 1.0 if wolf_hp > 0 else wolf_death_timer / 0.9
		var recoil := Vector2(-wolf_hit_timer * 70.0, 0.0)
		draw_texture_rect(WOLF_TEXTURE, Rect2(wolf_position + recoil - Vector2(92, 62), Vector2(184, 124)), false, Color(1.0, 1.0, 1.0, wolf_alpha))
		if wolf_hit_timer > 0.0: draw_arc(wolf_position + recoil, 128, 0.0, TAU, 16, Color("f2d27d"), 12.0)
		draw_string(ThemeDB.fallback_font, wolf_position + Vector2(-180, -105), "Wilk z mielizny", HORIZONTAL_ALIGNMENT_LEFT, -1, 36, Color("e6d8c2"))
	# Gracz: idle (oddech), chód (bujanie), atak (łuk miecza), rzucanie (krąg Iskry).
	var bob: float = sin(Time.get_ticks_msec() * 0.006) * (2.0 if player_is_walking else 0.8)
	var visual_player: Vector2 = player + Vector2(0.0, bob)
	draw_texture_rect(PLAYER_TEXTURE, Rect2(visual_player - Vector2(46, 62), Vector2(92, 124)), false)
	var armor_id := str(GameState.equipped.get("armor", ""))
	var armor_texture: Texture2D = ARMOR_ORDER_TEXTURE
	if armor_id == "kolczuga_walu": armor_texture = ARMOR_WALL_TEXTURE
	elif armor_id == "skora_zaru": armor_texture = ARMOR_REBEL_TEXTURE
	elif armor_id == "pancerz_popiolu": armor_texture = ARMOR_ASH_TEXTURE
	draw_texture_rect(armor_texture, Rect2(visual_player - Vector2(38, 42), Vector2(76, 76)), false)
	var sword_direction: Vector2 = player_facing
	if attack_timer > 0.0:
		sword_direction = player_facing.rotated((0.30 - attack_timer) * 8.0)
		draw_arc(visual_player + sword_direction * 70.0, 80, sword_direction.angle() - 1.0, sword_direction.angle() + 1.0, 10, Color("e8bb68"), 12.0)
	if projectile_flash_timer > 0.0:
		draw_circle(projectile_flash_position, 34.0, Color(0.55, 0.82, 1.0, projectile_flash_timer * 4.0))
	if cast_timer > 0.0:
		var pulse := 60.0 + sin(cast_timer * 28.0) * 4.0
		draw_circle(visual_player + player_facing * 100.0, pulse, Color(0.92, 0.38, 0.12, cast_timer * 1.4))
		draw_arc(visual_player, 115, 0.0, TAU, 18, Color("f5b85d"), 8.0)
