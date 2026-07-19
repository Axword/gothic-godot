extends Node2D
## Self-contained, original vertical slice. Art is deliberately procedural while production sprites are pending.

const WORLD := Rect2(40, 70, 1070, 530)
const INTERACT_DISTANCE := 58.0
const MAP_TEXTURE: Texture2D = preload("res://assets/generated/world_map_painted.png")
const ACTORS_TEXTURE: Texture2D = preload("res://assets/generated/actors_sheet.png")
const PROPS_TEXTURE: Texture2D = preload("res://assets/generated/combat_props.png")
var player: Vector2
var message := "Przybyłeś z listem, którego nie pisałeś."
var message_timer := 7.0
var selected: String = ""
var attack_timer := 0.0
var wolf_hp := 32
var wolf_position := Vector2(725, 315)
var npc_positions: Dictionary = {}
var npc_names: Dictionary = {}
var npc_data: Dictionary = {}
var location_positions: Dictionary = {}
var npc_home: Dictionary = {}
var dialogue: Dictionary = {}
var dialogue_open := false
var lock_open := false
var journal_open := false
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
	_build_ui()
	SaveSystem.saved.connect(_notice)
	GameState.changed.connect(queue_redraw)
	queue_redraw()


func _ensure_input_map() -> void:
	var bindings := {"move_left": KEY_A, "move_right": KEY_D, "move_up": KEY_W, "move_down": KEY_S, "interact": KEY_E, "cast_fire": KEY_1, "open_journal": KEY_J, "save_game": KEY_F5, "load_game": KEY_F9}
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
		var offset := Vector2(float((index * 31) % 92 - 46), float((index * 47) % 64 - 32))
		npc_positions[id] = home + offset; npc_home[id] = home + offset
		npc_names[id] = "%s, %s" % [str(npc.get("name", "Nieznany")), str(npc.get("role", "mieszkaniec"))]
		npc_data[id] = npc; index += 1

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
	if not dialogue_open and not lock_open and not journal_open:
		_move_player(delta)
		_handle_world_input()
	attack_timer = maxf(0.0, attack_timer - delta)
	message_timer = maxf(0.0, message_timer - delta)
	_update_npc_routines()
	_update_ui()
	queue_redraw()

func _move_player(delta: float) -> void:
	var direction := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	player += direction * 180.0 * delta
	player.x = clampf(player.x, WORLD.position.x + 12, WORLD.end.x - 12)
	player.y = clampf(player.y, WORLD.position.y + 12, WORLD.end.y - 12)
	GameState.player_position = player

func _handle_world_input() -> void:
	if Input.is_action_just_pressed("save_game"):
		SaveSystem.save_slot()
	if Input.is_action_just_pressed("load_game") and SaveSystem.load_slot():
		player = GameState.player_position
	if Input.is_action_just_pressed("open_journal"):
		_show_journal()
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

func nearest_target() -> String:
	var best := ""; var distance := INTERACT_DISTANCE
	for id: String in npc_positions:
		var d := player.distance_to(npc_positions[id])
		if d < distance: best = id; distance = d
	if player.distance_to(Vector2(640, 455)) < distance and not GameState.opened_chests.has("skrzynia_popiolu"):
		best = "chest"
	if player.distance_to(wolf_position) < distance and wolf_hp > 0:
		best = "wolf"
	return best

func interact() -> void:
	selected = nearest_target()
	match selected:
		"chest": _open_lock()
		"wolf": _notice(true, "Wilk nie prowadzi rozmów. Zwykle.")
		_:
			if npc_data.has(selected): _start_dialogue(selected)
			else: _notice(true, "Tu nic nie odpowiada.")

func attack() -> void:
	attack_timer = 0.18
	if player.distance_to(wolf_position) < 70 and wolf_hp > 0:
		wolf_hp -= 10 + GameState.strength
		if wolf_hp <= 0:
			GameState.defeated.append("wilk_z_mielizny")
			GameState.add_item("skora_wilka", 1); GameState.gain_xp(35)
			if GameState.quest_stage == "speak": GameState.advance_quest("wolf")
			_notice(true, "Wilk pada. Zostawia skórę i ciszę.")
		else: _notice(true, "Stal trafia: wilk warczy.")

func cast_fire() -> void:
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
			_show_choices("[b]Boruta:[/b] List pachnie mokrym prochem. Tak pachną rzeczy, które nie chcą żyć.\n\n„Jeżeli dotarłeś, znajdź Iskrę pod Mułem. Nie ufaj ani wałowi, ani ogniowi.”", [["Pokaż list.", "boruta_list"], ["Odejdź.", "close"]])
		"npc_mira":
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
			_show_choices("[b]%s:[/b] Na tym trakcie nawet błoto ma stronę. Ja należę do: %s.%s" % [name, faction, trainer], [["Zapytaj o pogłoski.", "rumor"], ["Odejdź.", "close"]])

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

func _show_journal() -> void:
	journal_open = not journal_open; panel.visible = journal_open
	if journal_open:
		_show_choices("[b]Dziennik — Iskra pod Mułem[/b]\n" + _objective() + "\n\nSterowanie: WASD ruch · E interakcja · LPM miecz · 1 Iskra · F5/F9 zapis/wczytanie · J dziennik.", [["Zamknij", "close"]])

func _objective() -> String:
	match GameState.quest_stage:
		"start": return "Cel: Porozmawiaj z Borutą przy północnym wale."
		"speak": return "Cel: Zabij wilka z mielizny (LPM lub czar 1)."
		"wolf": return "Cel: Otwórz skrzynię Miry sekwencją ← → ←."
		"chest": return "Cel: Zanieś Pieczęć Iskry Wronie przy szczelinie."
		"complete": return "Ukończono: prawda o liście zostaje w twojej kieszeni."
	return "Cel nieznany. To też rodzaj prawdy."

func _close_panel() -> void:
	dialogue_open = false; lock_open = false; journal_open = false; panel.visible = false

func _notice(ok: bool, text: String) -> void:
	message = text; message_timer = 4.0

func _update_ui() -> void:
	var target := nearest_target()
	var context := ""
	if not dialogue_open and not lock_open and not journal_open:
		if target == "chest": context = "[E] Otwórz skrzynię z popiołu"
		elif target == "wolf": context = "[LPM] Atakuj wilka"
		elif not target.is_empty(): context = "[E] Rozmawiaj: " + str(npc_names[target])
	prompt.text = context + ("\n" + message if message_timer > 0.0 else "")
	hud.text = "ZGNILIZNA  |  HP %d/%d  Mana %d/%d  |  Poz. %d  XP %d  |  %s\n%s" % [GameState.hp, GameState.max_hp, GameState.mana, GameState.max_mana, GameState.level, GameState.xp, GameState.time_text(), _objective()]

func _draw() -> void:
	var day: float = sin((GameState.world_minutes / 1440.0) * TAU - PI / 2.0) * 0.25 + 0.75
	draw_rect(Rect2(Vector2.ZERO, Vector2(1152, 648)), Color("101412"))
	draw_rect(WORLD, Color(0.12 * day, 0.19 * day, 0.14 * day))
	# Własna, wygenerowana ilustracja stanowi podstawę mapy; kod dodaje interaktywne warstwy ponad nią.
	draw_texture_rect(MAP_TEXTURE, WORLD, false, Color(1.0, 1.0, 1.0, day))
	# road, marsh, old palisade and rebel fire: procedural original placeholders.
	draw_rect(Rect2(50, 340, 1050, 75), Color("4b4030")); draw_circle(Vector2(870, 210), 84, Color("273a33")); draw_rect(Rect2(190, 120, 225, 145), Color("34383a")); draw_rect(Rect2(430, 420, 205, 120), Color("3a2922"))
	for x: float in range(55, 1100, 38): draw_line(Vector2(x, 120), Vector2(x + 14, 145), Color("745841"), 3.0)
	draw_circle(Vector2(520, 475), 16, Color("d06b35")); draw_circle(Vector2(520, 475), 7, Color("f6c56d"))
	draw_rect(Rect2(625, 440, 30, 24), Color("754a28")); draw_rect(Rect2(628, 435, 24, 8), Color("bf9655"))
	# Czytelna mapa całej krainy: osady, trakt, las, bagno, kamieniołom, plaża i Szczelina.
	var regions := [{"p":Vector2(195,155),"n":"Wał Miary","c":Color("4f5961")},{"p":Vector2(440,480),"n":"Obóz Żaru","c":Color("6b382c")},{"p":Vector2(500,340),"n":"Trakt Mułu","c":Color("5a4b35")},{"p":Vector2(765,305),"n":"Las Trzcin","c":Color("29452f")},{"p":Vector2(865,445),"n":"Bagno Bezdechu","c":Color("335548")},{"p":Vector2(190,270),"n":"Kamieniołom","c":Color("56504b")},{"p":Vector2(155,515),"n":"Wydmy Popiołu","c":Color("756347")},{"p":Vector2(925,170),"n":"Szczelina Głosu","c":Color("4b3155")}]
	for region: Dictionary in regions:
		var pos: Vector2 = region["p"]; draw_circle(pos, 60, region["c"]); draw_string(ThemeDB.fallback_font, pos + Vector2(-48, -67), str(region["n"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("ddd2bd"))
	for tree_pos: Vector2 in [Vector2(700,250),Vector2(740,360),Vector2(800,330),Vector2(775,240)]: draw_circle(tree_pos, 18, Color("1e3527"))
	# actors
	for id: String in npc_positions:
		var faction := str(npc_data.get(id, {}).get("faction", "neutralna"))
		var color := Color("7890a0") if faction == "Zakon Żelaznej Miary" else (Color("c06d4f") if faction == "Wolny Żar" else Color("ad9a62"))
		var radius := 9.0 if id.begins_with("npc_") else 13.0
		draw_circle(npc_positions[id], radius, color)
		if player.distance_to(npc_positions[id]) < 95.0:
			draw_string(ThemeDB.fallback_font, npc_positions[id] + Vector2(-30, -18), str(npc_names[id]).split(",")[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color.WHITE)
	if wolf_hp > 0:
		draw_circle(wolf_position, 16, Color("6c6555")); draw_circle(wolf_position + Vector2(10, -3), 3, Color("d84535")); draw_string(ThemeDB.fallback_font, wolf_position + Vector2(-38, -24), "Wilk z mielizny", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("e6d8c2"))
	# Arkusze aktorów i rekwizytów pozostają źródłem grafik dla następnego kroku animacji.
	draw_circle(player, 13 + attack_timer * 20, Color("e6d3a4")); draw_line(player, get_global_mouse_position(), Color("e8bb68"), 2.0)
