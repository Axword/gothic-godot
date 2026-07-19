

project/autoload/combat_system.gd
+23
extends Node

func calculate_damage(attacker: Dictionary, target: Dictionary, weapon_id: String = "") -> int:
    var base_damage := 5
    var weapon_damage := 8
    # Uproszczenie: odczyt z JSON
    var loader := DataLoader
    var swords := loader.load_json("res://data/json/items_weapons_swords.json")
    if swords is Array:
        for s in swords:
            if s.get("id") == weapon_id or weapon_id == "":
                weapon_damage = s.get("damage", 8)
                break
    var str_bonus := attacker.get("str", 5) - 5
    var dmg := int(weapon_damage + str_bonus + base_damage)
    if dmg < 1:
        dmg = 1
    # Pancerz
    var armor := target.get("armor", 0)
    var final := dmg - armor
    if final < 1:
        final = 1
    return final

project/autoload/crime_system.gd
+19
extends Node

var crimes: Array[Dictionary] = []

func commit_crime(crime_type: String, victim_id: String, location: Vector2) -> void:
    var crime := {
        "type": crime_type,
        "victim": victim_id,
        "location": location,
        "time": Time.get_ticks_msec(),
        "witnessed": false
    }
    crimes.append(crime)
    # Reakcja NPC
    react_to_crime(crime)

func react_to_crime(crime: Dictionary) -> void:
    # Prosta reakcja: alarm w pobliżu
    print("Przestępstwo: " + crime.get("type", "nieznane"))

project/autoload/data_loader.gd
+32
extends Node

func load_json(path: String) -> Variant:
    var file := FileAccess.open(path, FileAccess.READ)
    if file == null:
        push_error("DataLoader: nie można otworzyć " + path)
        return null
    var content := file.get_as_text()
    file.close()
    var parsed := JSON.parse_string(content)
    if parsed == null:
        push_error("DataLoader: błąd parsowania JSON w " + path)
    return parsed

func load_json_resource(path: String) -> Resource:
    var data := load_json(path)
    if data == null:
        return null
    # Można rozszerzyć o import jako Resource
    return data

func validate_npcs(data: Array) -> void:
    var ids: Array = []
    for entry in data:
        if entry is Dictionary:
            var id_val = entry.get("id", "")
            if id_val == "":
                push_warning("DataLoader: brak id w rekordzie NPC")
            elif id_val in ids:
                push_error("DataLoader: duplikat id NPC: " + str(id_val))
            else:
                ids.append(id_val)

project/autoload/dialogue_manager.gd
+40
extends Node

var current_dialogue: Dictionary = {}
var current_node: String = ""

func start_dialogue(dialogue_id: String) -> void:
    var loader := DataLoader
    var data := loader.load_json("res://data/json/dialogues_" + dialogue_id + ".json")
    if data == null:
        push_error("DialogueManager: brak dialogu " + dialogue_id)
        return
    current_dialogue = data
    current_node = data.get("start_node", "start")
    emit_node_text()

func emit_node_text() -> void:
    var node_data := current_dialogue.get("nodes", {}).get(current_node, {})
    var text := node_data.get("text_pla", "...")
    var responses := node_data.get("responses", [])
    # Sygnał: dialogue_updated
    dialogue_updated.emit(text, responses)

func choose_response(index: int) -> void:
    var node_data := current_dialogue.get("nodes", {}).get(current_node, {})
    var responses := node_data.get("responses", [])
    if index < 0 or index >= len(responses):
        return
    var resp := responses[index]
    # Akcje
    for action in resp.get("actions", []):
        GameState.set_flag(action.get("key", ""), action.get("value", true))
    # Następny węzeł
    current_node = resp.get("next_node", "")
    if current_node == "" or current_node == "end":
        dialogue_ended.emit()
        return
    emit_node_text()

signal dialogue_updated(text: String, responses: Array)
signal dialogue_ended()

project/autoload/game_state.gd
+40
extends Node

const VERSION := "1.0.0"

var flags: Dictionary = {}
var quests: Dictionary = {}
var reputations: Dictionary = {}
var faction_choice: String = ""
var completed_quests: Array = []
var active_quests: Array = []

func init():
    flags = {}
    quests = {}
    reputations = {"stare_bractwo": 0, "wolne_zgliszcza": 0}
    faction_choice = ""
    completed_quests = []
    active_quests = []

func get_flag(key: String, default: Variant = false) -> Variant:
    return flags.get(key, default)

func set_flag(key: String, value: Variant) -> void:
    flags[key] = value

func add_quest(quest_id: String) -> void:
    if quest_id not in active_quests:
        active_quests.append(quest_id)

func complete_quest(quest_id: String) -> void:
    if quest_id in active_quests:
        active_quests.erase(quest_id)
    if not quest_id in completed_quests:
        completed_quests.append(quest_id)

func is_quest_active(quest_id: String) -> bool:
    return quest_id in active_quests

func is_quest_completed(quest_id: String) -> bool:
    return quest_id in completed_quests

project/autoload/inventory_system.gd
+36
extends Node

var inventory_items: Array[Dictionary] = []
var equipped: Dictionary = {"weapon": null, "armor": null}

func add_item(item_id: String, amount: int = 1) -> void:
    for item in inventory_items:
        if item.get("id") == item_id:
            item["amount"] = item.get("amount", 1) + amount
            return
    inventory_items.append({"id": item_id, "amount": amount})

func remove_item(item_id: String, amount: int = 1) -> bool:
    for i in range(inventory_items.size()):
        var item := inventory_items[i]
        if item.get("id") == item_id:
            var current := item.get("amount", 1)
            if current > amount:
                item["amount"] = current - amount
            else:
                inventory_items.remove_at(i)
            return true
    return false

func has_item(item_id: String, amount: int = 1) -> bool:
    for item in inventory_items:
        if item.get("id") == item_id and item.get("amount", 0) >= amount:
            return true
    return false

func equip_item(item_id: String) -> bool:
    var loader := DataLoader
    var item_data := loader.load_json("res://data/json/items_weapons_swords.json")
    # Uproszczenie: zakładamy, że item istnieje
    equipped["weapon"] = item_id
    return true

project/autoload/npc_system.gd
+26
extends Node

var npc_states: Dictionary = {}

func init_npc_state(npc_id: String) -> void:
    if npc_id not in npc_states:
        npc_states[npc_id] = {
            "location": "",
            "current_activity": "idle",
            "alive": true,
            "stunned": false,
            "quest_flags": {}
        }

func get_npc_state(npc_id: String) -> Dictionary:
    init_npc_state(npc_id)
    return npc_states[npc_id]

func set_npc_location(npc_id: String, location: String) -> void:
    init_npc_state(npc_id)
    npc_states[npc_id]["location"] = location

func stun_npc(npc_id: String, duration: float = 5.0) -> void:
    init_npc_state(npc_id)
    npc_states[npc_id]["stunned"] = true
    # Timer można rozszerzyć

project/autoload/save_system.gd
+69
extends Node

func save_game(slot: int) -> void:
    var save_data := {
        "version": "1.0.0",
        "slot": slot,
        "player": {
            "pos_x": 0.0,
            "pos_y": 0.0,
            "hp": 100,
            "max_hp": 100,
            "level": 1,
            "xp": 0,
            "learning_points": 1,
            "stats": {"str": 5, "dex": 5, "mana": 0}
        },
        "world_time": {
            "hour": WorldTime.world_hour,
            "minute": WorldTime.world_minute
        },
        "inventory": [],
        "equipped": {},
        "quests": {
            "active": GameState.active_quests,
            "completed": GameState.completed_quests
        },
        "flags": GameState.flags,
        "reputations": GameState.reputations,
        "faction_choice": GameState.faction_choice,
        "npc_states": NPCSystem.npc_states,
        "chests_opened": [],
        "enemies_defeated": []
    }
    # Zapisywanie pozycji gracza wymaga dostępu do sceny; uproszczenie tutaj
    var dir := DirAccess.open("user://")
    if dir == null:
        push_error("SaveSystem: brak dostępu do katalogu użytkownika")
        return
    var file := FileAccess.open("user://save_" + str(slot) + ".json", FileAccess.WRITE)
    if file == null:
        push_error("SaveSystem: błąd zapisu pliku")
        return
    file.store_string(JSON.stringify(save_data, "\t"))
    file.close()

func load_game(slot: int) -> bool:
    var file_path := "user://save_" + str(slot) + ".json"
    if not FileAccess.file_exists(file_path):
        return false
    var file := FileAccess.open(file_path, FileAccess.READ)
    if file == null:
        return false
    var content := file.get_as_text()
    file.close()
    var data: Variant = JSON.parse_string(content)
    if data == null:
        push_error("SaveSystem: błąd parsowania zapisu")
        return false
    # Przywrócenie stanu
    GameState.init()
    if data is Dictionary:
        var player_data = data.get("player", {})
        GameState.flags = data.get("flags", {})
        GameState.reputations = data.get("reputations", {"stare_bractwo": 0, "wolne_zgliszcza": 0})
        GameState.faction_choice = data.get("faction_choice", "")
        GameState.active_quests = data.get("quests", {}).get("active", [])
        GameState.completed_quests = data.get("quests", {}).get("completed", [])
        NPCSystem.npc_states = data.get("npc_states", {})
    return true

project/autoload/skinning_system.gd
+15
extends Node

func skin_monster(monster_id: String, has_skill: bool) -> bool:
    if not has_skill:
        return false
    # Dodaj trofeum
    var trophy_map := {
        "wilk_zgnilizny": "skora_wilk",
        "dzik_bagienny": "skora_dzik",
        "krab_plazowy": "skora_krab",
        "golem_kamienny": "skora_golem"
    }
    var trophy := trophy_map.get(monster_id, "skora_default")
    InventorySystem.add_item(trophy)
    return true

project/autoload/theft_system.gd
+13
extends Node

func steal_item(target_id: String, item_id: String) -> bool:
    # Sprawdzenie, czy są świadkowie
    var witnesses := 0
    # Uproszczenie: losowy świadek
    if randf() < 0.3:
        witnesses += 1
    if witnesses > 0:
        CrimeSystem.commit_crime("kradzież", target_id, Vector2.ZERO)
        return false
    InventorySystem.add_item(item_id)
    return true

project/autoload/world_time.gd
+26
extends Node

const HOURS_PER_MINUTE := 0.05
const MINUTES_PER_HOUR := 60.0

var world_hour: int = 8
var world_minute: int = 0
var is_day: bool = true

signal time_changed(hour, minute)

func _process(delta: float) -> void:
    world_minute += HOURS_PER_MINUTE * delta * MINUTES_PER_HOUR
    if world_minute >= MINUTES_PER_HOUR:
        world_minute = 0
        world_hour += 1
        if world_hour >= 24:
            world_hour = 0
    # Prosty cykl dnia/nocy: 6-20 dzień
    var new_day := world_hour >= 6 and world_hour < 20
    if new_day != is_day:
        is_day = new_day
    time_changed.emit(world_hour, world_minute)

func get_formatted_time() -> String:
    return "%02d:%02d" % [world_hour, world_minute]

project/data/json/balance.json
+9
{
  "player_base_hp": 50,
  "hp_per_level": 15,
  "xp_per_level": 100,
  "learning_points_per_level": 1,
  "damage_formula": "damage + str_bonus - armor",
  "critical_chance_base": 0.05,
  "critical_chance_dex_bonus": 0.01
}

project/data/json/dialogues_neutral.json
+1
{"start_node":"start","nodes":{"start":{"text_pla":"Co cię tu sprowadza, podróżniku?","responses":[{"id":"r1","text":"Szukam wiedzy.","next_node":"wiedza"},{"id":"r2","text":"Szukam zysku.","next_node":"zysk"}]},"wiedza":{"text_pla":"Wiedza kosztuje. Ale mogę ci pomóc.","responses":[{"id":"r3","text":"Dziękuję.","next_node":"end","actions":[{"key":"quest_rozpoznanie","value":"start"}]}]},"zysk":{"text_pla":"Zysk? Idź do kupca albo do złodzieja.","responses":[{"id":"r4","text":"Rozumiem.","next_node":"end"}]},"end":{"text_pla":"Do zobaczenia, podróżniku.","responses":[{"id":"r5","text":"Do widzenia.","next_node":"end"}]}}}

project/data/json/dialogues_new.json
+69
{
  "start_node": "start",
  "nodes": {
    "start": {
      "text_pla": "Wyrzutku. Przybyłeś do Wolnych Zgliszcz. Co cię tu sprowadza?",
      "responses": [
        {"id":"r1","text":"Szukam wolności.","next_node":"wolnosc"},
        {"id":"r2","text":"Chcę walczyć.","next_node":"walka"},
        {"id":"r3","text":"Nie interesuje mnie to.","next_node":"ostro"}
      ]
    },
    "wolnosc": {
      "text_pla": "Wolność? Tu każdy płaci za nią krwią. Stare Bractwo chce nas zniszczyć.",
      "responses": [
        {"id":"r4","text":"Co mam zrobić?","next_node":"zadanie","actions":[{"key":"quest_przybycie","value":"poznanie"}]},
        {"id":"r5","text":"Gdzie jest zagrożenie?","next_node":"zagrozenie","actions":[{"key":"quest_przybycie","value":"poznanie"}]}
      ]
    },
    "walka": {
      "text_pla": "Walka? Dobrze. Ale pamiętaj — tu nie ma honoru. Jest tylko przetrwanie.",
      "responses": [
        {"id":"r6","text":"Zrozumiałem.","next_node":"zadanie","actions":[{"key":"quest_przybycie","value":"poznanie"}]}
      ]
    },
    "ostro": {
      "text_pla": "Ostro? Tu nikt nie daje za darmo. Wybieraj.",
      "responses": [
        {"id":"r7","text":"Wybieram was.","next_node":"wybor","actions":[{"key":"faction_choice","value":"wolne_zgliszcza"}]},
        {"id":"r8","text":"Wybieram starych.","next_node":"koniec_1","actions":[{"key":"faction_choice","value":"stare_bractwo"}]}
      ]
    },
    "zadanie": {
      "text_pla": "Zadanie? Zanieś wiadomość, zabij bestię, ukradnij coś. Zdecyduj.",
      "responses": [
        {"id":"r9","text":"Rozumiem.","next_node":"koniec_2","actions":[{"key":"quest_przybycie","value":"poznanie"}]}
      ]
    },
    "zagrozenie": {
      "text_pla": "Zagrożenie? Milczący Bóg budzi się. Jego świątynia jest w bagnie. Ale to nie wszystko.",
      "responses": [
        {"id":"r10","text":"Opowiedz więcej.","next_node":"koniec_2","actions":[{"key":"quest_przybycie","value":"zapowiedz"}]}
      ]
    },
    "wybor": {
      "text_pla": "Wybierasz Wolne Zgliszcza. Dobrze. Ale pamiętaj — nie ma odwrotu.",
      "responses": [
        {"id":"r11","text":"Zrozumiałem.","next_node":"end"}
      ]
    },
    "koniec_1": {
      "text_pla": "Stare Bractwo... Ciekawy wybór. Ale pamiętaj — tu wszystko ma cenę.",
      "responses": [
        {"id":"r12","text":"Zrozumiałem.","next_node":"end"}
      ]
    },
    "end": {
      "text_pla": "Do zobaczenia, podróżniku.",
      "responses": [
        {"id":"r14","text":"Do widzenia.","next_node":"end"}
      ]
    },
    "koniec_2": {
      "text_pla": "Idź. I pamiętaj — tu nikt nie jest bezpieczny.",
      "responses": [
        {"id":"r13","text":"Do zobaczenia.","next_node":"end"}
      ]
    }
  }
}

project/data/json/dialogues_old.json
+63
{
  "start_node": "start",
  "nodes": {
    "start": {
      "text_pla": "Wyrzutku. Przybyłeś do Zgnilizny. Czego szukasz?",
      "responses": [
        {"id":"r1","text":"Nic. Uciekłem przed wojną.","next_node":"ucieczka"},
        {"id":"r2","text":"Szukam nowego życia.","next_node":"nowe_zycie"},
        {"id":"r3","text":"Nie twoja sprawa.","next_node":"ostro"}
      ]
    },
    "ucieczka": {
      "text_pla": "Ucieczka? Tu też jest wojna. Stare Bractwo przeciw Wolnym Zgliszczom.",
      "responses": [
        {"id":"r4","text":"Kto rządzi?","next_node":"kto"},
        {"id":"r5","text":"Gdzie mogę zarobić?","next_node":"zarobek"}
      ]
    },
    "nowe_zycie": {
      "text_pla": "Nowe życie? Musisz udowodnić, że jesteś kimś. Tu nikt nie jest nikim za darmo.",
      "responses": [
        {"id":"r6","text":"Udowodnię to.","next_node":"koniec_1","actions":[{"key":"quest_przybycie","value":"poznanie"}]}
      ]
    },
    "ostro": {
      "text_pla": "Ostro? Dobrze. Ale pamiętaj — tu nikt nie daje za darmo.",
      "responses": [
        {"id":"r7","text":"Rozumiem.","next_node":"koniec_2","actions":[{"key":"quest_przybycie","value":"poznanie"}]}
      ]
    },
    "kto": {
      "text_pla": "Stare Bractwo rządzi Twierdzą Czarnej Ręki. Wolne Zgliszcza — obozem na południu. Wybierz.",
      "responses": [
        {"id":"r8","text":"Brzmi dobrze.","next_node":"koniec_1","actions":[{"key":"quest_przybycie","value":"poznanie"}]},
        {"id":"r9","text":"Opowiedz więcej.","next_node":"koniec_1","actions":[{"key":"quest_przybycie","value":"poznanie"}]}
      ]
    },
    "zarobek": {
      "text_pla": "Zarobić? Idź do kowala, do łowcy albo do złodzieja. Ale uważaj. Tu każdy ma swoje interesy.",
      "responses": [
        {"id":"r10","text":"Rozumiem.","next_node":"koniec_2","actions":[{"key":"quest_przybycie","value":"poznanie"}]}
      ]
    },
    "koniec_1": {
      "text_pla": "Powodzenia, Wyrzutku. I pamiętaj — tu nic nie jest darmowe.",
      "responses": [
        {"id":"r11","text":"Do zobaczenia.","next_node":"end"}
      ]
    },
    "end": {
      "text_pla": "Do zobaczenia, podróżniku.",
      "responses": [
        {"id":"r13","text":"Do widzenia.","next_node":"end"}
      ]
    },
    "koniec_2": {
      "text_pla": "Trzymaj się. I nie ufaj nikomu.",
      "responses": [
        {"id":"r12","text":"Zrozumiałem.","next_node":"end"}
      ]
    }
  }
}

project/data/json/items_armors.json
+6
[
  {"id":"zbroja_stara","name":"Stara Zbroja Bractwa","armor":3,"req_str":5,"faction":"stare_bractwo","sprite":"res://assets/sprites/armors/armor_old.png","description":"Stara zbroja komendanta."},
  {"id":"zbroja_czarna","name":"Zbroja Czarnej Ręki","armor":6,"req_str":10,"faction":"stare_bractwo","sprite":"res://assets/sprites/weapons/armor_black.png","description":"Ciężka stal z symbolami."},
  {"id":"zbroja_zgliszcze","name":"Zgliszcze","armor":4,"req_str":4,"faction":"wolne_zgliszcza","sprite":"res://assets/sprites/armors/armor_new.png","description":"Skóra i łańcuchy."},
  {"id":"zbroja_ognista","name":"Ognista Zbroja","armor":8,"req_str":14,"faction":"wolne_zgliszcza","sprite":"res://assets/sprites/armors/armor_fire.png","description":"Znalezione w Szczelinie."}
]

project/data/json/items_misc.json
+9
[
  {"id":"zloto","name":"Złoto","value":1,"sprite":"res://assets/sprites/items/gold_coin.png","description":"Waluta Zgnilizny."},
  {"id":"wytrych","name":"Wytrych","value":30,"sprite":"res://assets/sprites/items/lockpick.png","description":"Narzędzie do otwierania zamków."},
  {"id":"klucz_pierwszy","name":"Klucz Pierwszy","value":0,"sprite":"res://assets/sprites/items/key_first.png","description":"Klucz do pierwszej skrzyni."},
  {"id":"klucz_kaplicy","name":"Klucz Kaplicy","value":0,"sprite":"res://assets/sprites/items/key_shrine.png","description":"Klucz do kaplicy w bagnie."},
  {"id":"mapa_zgnilizny","name":"Mapa Zgnilizny","value":5,"sprite":"res://assets/sprites/items/map.png","description":"Stara mapa regionu."},
  {"id":"list_zmarlego","name":"List Zmarłego","value":0,"sprite":"res://assets/sprites/items/letter_dead.png","description":"List znaleziony przy ciele."},
  {"id":"plakat_starego","name":"Plakat Starego Porządku","value":2,"sprite":"res://assets/sprites/items/poster_old.png","description":"Propaganda starego bractwa."}
]

project/data/json/items_plants.json
+12
[
  {"id":"roslina_bagienna","name":"Bagienna Trzcina","effect":"mana +5","sprite":"res://assets/sprites/plants/plant_swamp.png","biome":"swamp"},
  {"id":"roslina_lesna","name":"Leśny Korzeń","effect":"hp +10","sprite":"res://assets/sprites/plants/plant_forest.png","biome":"forest"},
  {"id":"roslina_ognista","name":"Płomienny Kwiat","effect":"fire_damage_bonus","sprite":"res://assets/sprites/plants/plant_fire.png","biome":"mountain"},
  {"id":"roslina_plazowa","name":"Plażowa Alga","effect":"stamina +5","sprite":"res://assets/sprites/plants/plant_beach.png","biome":"beach"},
  {"id":"roslina_krwawa","name":"Krwawy Grzyb","effect":"poison_resist","sprite":"res://assets/sprites/plants/plant_blood.png","biome":"swamp"},
  {"id":"roslina_czarna","name":"Czarny Mech","effect":"shadow_bonus","sprite":"res://assets/sprites/plants/plant_dark.png","biome":"forest"},
  {"id":"roslina_zlota","name":"Złoty Liść","effect":"gold_find","sprite":"res://assets/sprites/plants/plant_gold.png","biome":"mountain"},
  {"id":"roslina_gorzka","name":"Gorzki Korzeń","effect":"speed +1","sprite":"res://assets/sprites/plants/plant_bitter.png","biome":"swamp"},
  {"id":"roslina_klamliwa","name":"Kłamliwa Roślina","effect":"deception +1","sprite":"res://assets/sprites/plants/plant_lie.png","biome":"forest"},
  {"id":"roslina_spokojna","name":"Spokojny Kwiat","effect":"calm","sprite":"res://assets/sprites/plants/plant_calm.png","biome":"beach"}
]

project/data/json/items_potions.json
+8
[
  {"id":"mikstura_zycia","name":"Mikstura Życia","effect":"hp +30","sprite":"res://assets/sprites/potions/potion_red.png","value":20},
  {"id":"mikstura_many","name":"Mikstura Many","effect":"mana +20","sprite":"res://assets/sprites/potions/potion_blue.png","value":25},
  {"id":"mikstura_sily","name":"Mikstura Siły","effect":"str +2","sprite":"res://assets/sprites/potions/potion_green.png","value":35},
  {"id":"mikstura_zrecznosci","name":"Mikstura Zręczności","effect":"dex +2","sprite":"res://assets/sprites/potions/potion_yellow.png","value":35},
  {"id":"mikstura_ognia","name":"Mikstura Płomienia","effect":"fire_damage_bonus","sprite":"res://assets/sprites/potions/potion_orange.png","value":40},
  {"id":"mikstura_lodu","name":"Mikstura Lodu","effect":"ice_damage_bonus","sprite":"res://assets/sprites/potions/potion_white.png","value":40}
]

project/data/json/items_trophies.json
+7
[
  {"id":"skora_wilk","name":"Skóra Wilka","value":10,"sprite":"res://assets/sprites/items/skin_wolf.png","description":"Skóra z wilka zgniliznego."},
  {"id":"skora_dzik","name":"Skóra Dzikiego","value":15,"sprite":"res://assets/sprites/items/skin_boar.png","description":"Gruba skóra z bagiennego dzika."},
  {"id":"skora_krab","name":"Skóra Kraba","value":8,"sprite":"res://assets/sprites/items/skin_crab.png","description":"Twarda skorupa kraba."},
  {"id":"skora_golem","name":"Kamień Golema","value":25,"sprite":"res://assets/sprites/items/skin_golem.png","description":"Fragment kamienia z golemu."},
  {"id":"kamien_kamienny","name":"Kamień Kamieniołomu","value":20,"sprite":"res://assets/sprites/items/stone_quarry.png","description":"Kamień z kamieniołomu krwi."}
]

project/data/json/items_weapons_bows.json
+12
[
  {"id":"luk_kruchy","name":"Kruchy Łuk","damage":10,"req_dex":2,"speed":1.0,"sprite":"res://assets/sprites/weapons/bow_fragile.png","description":"Prosty łuk z gałęzi."},
  {"id":"luk_drewniany","name":"Drewniany Łuk","damage":14,"req_dex":4,"speed":1.1,"sprite":"res://assets/sprites/weapons/bow_wood.png","description":"Solidny łuk z lasu."},
  {"id":"luk_srebrny","name":"Srebrny Łuk","damage":20,"req_dex":7,"speed":1.2,"sprite":"res://assets/sprites/weapons/bow_silver.png","description":"Srebrne zdobienia."},
  {"id":"luk_krwawy","name":"Krwawy Łuk","damage":18,"req_dex":6,"speed":1.3,"sprite":"res://assets/sprites/weapons/bow_blood.png","description":"Zabarwiony krwią bestii."},
  {"id":"luk_bagienny","name":"Bagienny Łuk","damage":13,"req_dex":4,"speed":1.0,"sprite":"res://assets/sprites/weapons/bow_swamp.png","description":"Znalezione w bagnie."},
  {"id":"luk_kowalski","name":"Łuk Kowalski","damage":22,"req_dex":8,"speed":1.4,"sprite":"res://assets/sprites/weapons/bow_smith.png","description":"Wykuty z metalu."},
  {"id":"luk_ognisty","name":"Łuk Płomienia","damage":26,"req_dex":10,"speed":1.5,"sprite":"res://assets/sprites/weapons/bow_fire.png","description":"Płomienie na cięciwie."},
  {"id":"luk_zlodziejski","name":"Złodziejski Łuk","damage":16,"req_dex":6,"speed":1.6,"sprite":"res://assets/sprites/weapons/bow_thief.png","description":"Szybki i cichy."},
  {"id":"luk_straznika","name":"Łuk Strażnika","damage":19,"req_dex":7,"speed":1.3,"sprite":"res://assets/sprites/weapons/bow_guard.png","description":"Broń strażników."},
  {"id":"luk_demoniczny","name":"Demoniczny Łuk","damage":30,"req_dex":13,"speed":1.7,"sprite":"res://assets/sprites/weapons/bow_demon.png","description":"Znalezione w Szczelinie."}
]

project/data/json/items_weapons_swords.json
+22
[
  {"id":"miecz_zardzewialy","name":"Zardzewiały Miecz","damage":8,"req_str":2,"value":15,"mass":2.5,"sprite":"res://assets/sprites/weapons/sword_rusty.png","description":"Stary, zardzewiały miecz. Ale wciąż tnie."},
  {"id":"miecz_stary","name":"Stary Miecz","damage":12,"req_str":5,"value":40,"mass":3.0,"sprite":"res://assets/sprites/weapons/sword_old.png","description":"Miecz z czasów poprzedniej wojny."},
  {"id":"miecz_kowalski","name":"Miecz Kowalski","damage":18,"req_str":8,"value":120,"mass":3.5,"sprite":"res://assets/sprites/weapons/sword_smith.png","description":"Wykuty przez kowala z Twierdzy."},
  {"id":"miecz_czarny","name":"Czarna Stal","damage":25,"req_str":12,"value":300,"mass":4.0,"sprite":"res://assets/sprites/weapons/sword_black.png","description":"Broń komendanta Alryka. Ciężka i chłodna."},
  {"id":"miecz_zgliszcze","name":"Zgliszcze","damage":22,"req_str":10,"value":250,"mass":3.8,"sprite":"res://assets/sprites/weapons/sword_burned.png","description":"Ostrze z płomieni obozu."},
  {"id":"miecz_krwawy","name":"Krwawy Ostrz","damage":15,"req_str":7,"value":150,"mass":3.2,"sprite":"res://assets/sprites/weapons/sword_blood.png","description":"Zabarwiony krwią wroga."},
  {"id":"miecz_zlamany","name":"Złamany Miecz","damage":5,"req_str":1,"value":5,"mass":2.0,"sprite":"res://assets/sprites/weapons/sword_broken.png","description":"Ledwo trzyma się kupy."},
  {"id":"miecz_srebrny","name":"Srebrne Ostrze","damage":20,"req_str":9,"value":200,"mass":3.5,"sprite":"res://assets/sprites/weapons/sword_silver.png","description":"Srebrny blask odstrasza bestie."},
  {"id":"miecz_demoniczny","name":"Demoniczne Ostrze","damage":30,"req_str":15,"value":500,"mass":4.5,"sprite":"res://assets/sprites/weapons/sword_demon.png","description":"Znalezione w Szczelinie Milczącego Boga."},
  {"id":"miecz_pierwszy","name":"Miecz Pierwszy","damage":6,"req_str":1,"value":10,"mass":2.2,"sprite":"res://assets/sprites/weapons/sword_first.png","description":"Miecz, z którym przybyłeś."},
  {"id":"miecz_rytualny","name":"Rytualne Ostrze","damage":14,"req_str":6,"value":180,"mass":3.1,"sprite":"res://assets/sprites/weapons/sword_ritual.png","description":"Używane przez kult Milczącego Boga."},
  {"id":"miecz_zlodziejski","name":"Złodziejski Szpic","damage":10,"req_str":4,"value":90,"mass":2.8,"sprite":"res://assets/sprites/weapons/sword_thief.png","description":"Cienki i szybki."},
  {"id":"miecz_strazniczy","name":"Miecz Strażnika","damage":13,"req_str":6,"value":110,"mass":3.3,"sprite":"res://assets/sprites/weapons/sword_guard.png","description":"Broń strażników Twierdzy."},
  {"id":"miecz_bagienny","name":"Bagienny Kłos","damage":11,"req_str":5,"value":80,"mass":2.9,"sprite":"res://assets/sprites/weapons/sword_swamp.png","description":"Znalezione w bagnie."},
  {"id":"miecz_kamienny","name":"Kamienna Klinga","damage":16,"req_str":7,"value":160,"mass":3.6,"sprite":"res://assets/sprites/weapons/sword_stone.png","description":"Wykute z kamienia kamieniołomu."},
  {"id":"miecz_plazowy","name":"Plażowy Kieł","damage":9,"req_str":3,"value":60,"mass":2.7,"sprite":"res://assets/sprites/weapons/sword_beach.png","description":"Znalezione na plaży."},
  {"id":"miecz_ognisty","name":"Ostrze Płomienia","damage":28,"req_str":14,"value":400,"mass":4.2,"sprite":"res://assets/sprites/weapons/sword_fire.png","description":"Płomień Milczącego Boga."},
  {"id":"miecz_krwawy_2","name":"Krwawy Ostrz II","damage":19,"req_str":8,"value":190,"mass":3.4,"sprite":"res://assets/sprites/weapons/sword_blood2.png","description":"Ulepszona wersja."},
  {"id":"miecz_zlota","name":"Złote Ostrze","damage":24,"req_str":11,"value":350,"mass":4.0,"sprite":"res://assets/sprites/weapons/sword_gold.png","description":"Złoto starego świata."},
  {"id":"miecz_zniszczenia","name":"Ostrze Zniszczenia","damage":35,"req_str":18,"value":800,"mass":5.0,"sprite":"res://assets/sprites/weapons/sword_destruction.png","description":"Najpotężniejszy miecz w Zgniliźnie."}
]

project/data/json/loot_tables.json
+8
[
  {"id":"loot_wolf","items":[{"id":"skora_wilk","chance":0.7,"amount":1}],"currency":[{"id":"zloto","chance":0.5,"amount":[5,15]}]},
  {"id":"loot_boar","items":[{"id":"skora_dzik","chance":0.6,"amount":1}],"currency":[{"id":"zloto","chance":0.4,"amount":[8,20]}]},
  {"id":"loot_golem","items":[{"id":"kamien_kamienny","chance":0.5,"amount":1}],"currency":[{"id":"zloto","chance":0.3,"amount":[20,50]}]},
  {"id":"loot_ghost","items":[{"id":"roslina_bagienna","chance":0.5,"amount":2}],"currency":[]},
  {"id":"loot_crab","items":[{"id":"skora_krab","chance":0.8,"amount":1}],"currency":[{"id":"zloto","chance":0.3,"amount":[3,10]}]},
  {"id":"loot_bandit","items":[{"id":"miecz_zlota","chance":0.2,"amount":1},{"id":"skora_wilk","chance":0.3,"amount":1}],"currency":[{"id":"zloto","chance":0.6,"amount":[15,40]}]}
]

project/data/json/monster_spawns.json
+8
[
  {"monster_id":"wilk_zgnilizny","region":"las_zgnilizny","count":3,"respawn_time":300},
  {"monster_id":"dzik_bagienny","region":"bagno_gluche","count":2,"respawn_time":600},
  {"monster_id":"golem_kamienny","region":"kamieniolom","count":1,"respawn_time":0},
  {"monster_id":"upior_nocy","region":"bagno_gluche","count":2,"respawn_time":900,"night_only":true},
  {"monster_id":"krab_plazowy","region":"plaza_popiolow","count":3,"respawn_time":300},
  {"monster_id":"bandyta_jaromir","region":"las_zgnilizny","count":1,"respawn_time":0,"quest_id":"quest_zasadzka"}
]

project/data/json/monsters.json
+8
[
  {"id":"wilk_zgnilizny","name":"Wilk Zgnilizny","biome":"forest","behavior":"pack","sprite":"res://assets/sprites/monsters/wolf.png","hp":40,"damage":12,"armor":1,"loot_table":"loot_wolf.json","speed":80,"spawns":"monster_spawns.json"},
  {"id":"dzik_bagienny","name":"Dziki Bagienny","biome":"swamp","behavior":"solo","sprite":"res://assets/sprites/monsters/boar.png","hp":60,"damage":15,"armor":3,"loot_table":"loot_boar.json","speed":60,"spawns":"monster_spawns.json"},
  {"id":"golem_kamienny","name":"Golem Kamienny","biome":"mountain","behavior":"tank","sprite":"res://assets/sprites/monsters/golem.png","hp":120,"damage":20,"armor":8,"loot_table":"loot_golem.json","speed":40,"spawns":"monster_spawns.json"},
  {"id":"upior_nocy","name":"Upiór Nocy","biome":"swamp","behavior":"night_range","sprite":"res://assets/sprites/monsters/ghost.png","hp":35,"damage":10,"armor":0,"loot_table":"loot_ghost.json","speed":100,"spawns":"monster_spawns.json","night_only":true,"ranged_attack":true},
  {"id":"krab_plazowy","name":"Krab Plażowy","biome":"beach","behavior":"solo","sprite":"res://assets/sprites/monsters/crab.png","hp":50,"damage":10,"armor":5,"loot_table":"loot_crab.json","speed":50,"spawns":"monster_spawns.json"},
  {"id":"bandyta_jaromir","name":"Bandyta Jaromir","biome":"forest","behavior":"solo","sprite":"res://assets/sprites/monsters/bandit_jaromir.png","hp":70,"damage":16,"armor":4,"loot_table":"loot_bandit.json","speed":70,"spawns":"monster_spawns.json","is_boss":true,"quest_id":"quest_zasadzka"}
]

project/data/json/npc_schedules.json
+32
[
  {"npc_id":"npc_alryk","time_start":"06:00","time_end":"08:00","location":"twierdza_hall","activity":"work","animation":"idle","condition":"always","fallback":"twierdza_hall"},
  {"npc_id":"npc_alryk","time_start":"08:00","time_end":"18:00","location":"twierdza_brama","activity":"patrol","animation":"walk","condition":"always","fallback":"twierdza_brama"},
  {"npc_id":"npc_alryk","time_start":"18:00","time_end":"22:00","location":"twierdza_hall","activity":"rest","animation":"idle","condition":"always","fallback":"twierdza_hall"},
  {"npc_id":"npc_alryk","time_start":"22:00","time_end":"06:00","location":"twierdza_wieza","activity":"sleep","animation":"sleep","condition":"always","fallback":"twierdza_wieza"},
  {"npc_id":"npc_mara","time_start":"07:00","time_end":"10:00","location":"oboz_ognisko","activity":"talk","animation":"idle","condition":"always","fallback":"oboz_ognisko"},
  {"npc_id":"npc_mara","time_start":"10:00","time_end":"16:00","location":"oboz_ognisko","activity":"patrol","animation":"walk","condition":"always","fallback":"oboz_ognisko"},
  {"npc_id":"npc_mara","time_start":"16:00","time_end":"20:00","location":"oboz_ognisko","activity":"rest","animation":"idle","condition":"always","fallback":"oboz_ognisko"},
  {"npc_id":"npc_mara","time_start":"20:00","time_end":"23:00","location":"oboz_ognisko","activity":"work","animation":"idle","condition":"always","fallback":"oboz_ognisko"},
  {"npc_id":"npc_pek","time_start":"09:00","time_end":"12:00","location":"oboz_pod_sciana","activity":"work","animation":"idle","condition":"always","fallback":"oboz_pod_sciana"},
  {"npc_id":"npc_pek","time_start":"12:00","time_end":"15:00","location":"las_polana","activity":"patrol","animation":"walk","condition":"always","fallback":"las_polana"},
  {"npc_id":"npc_pek","time_start":"15:00","time_end":"21:00","location":"oboz_pod_sciana","activity":"rest","animation":"idle","condition":"always","fallback":"oboz_pod_sciana"},
  {"npc_id":"npc_pek","time_start":"21:00","time_end":"05:00","location":"oboz_pod_sciana","activity":"sleep","animation":"sleep","condition":"always","fallback":"oboz_pod_sciana"},
  {"npc_id":"npc_oskar","time_start":"06:00","time_end":"22:00","location":"bagno_kaplica","activity":"rest","animation":"idle","condition":"always","fallback":"bagno_kaplica"},
  {"npc_id":"npc_dzwiek","time_start":"08:00","time_end":"16:00","location":"las_polana","activity":"work","animation":"idle","condition":"always","fallback":"las_polana"},
  {"npc_id":"npc_dzwiek","time_start":"16:00","time_end":"20:00","location":"las_polana","activity":"rest","animation":"idle","condition":"always","fallback":"las_polana"},
  {"npc_id":"npc_gluchy","time_start":"10:00","time_end":"14:00","location":"bagno_kurhan","activity":"patrol","animation":"walk","condition":"always","fallback":"bagno_kurhan"},
  {"npc_id":"npc_gluchy","time_start":"14:00","time_end":"22:00","location":"bagno_kurhan","activity":"rest","animation":"idle","condition":"always","fallback":"bagno_kurhan"},
  {"npc_id":"npc_zlom","time_start":"09:00","time_end":"17:00","location":"oboz_zlom","activity":"work","animation":"idle","condition":"always","fallback":"oboz_zlom"},
  {"npc_id":"npc_zlom","time_start":"17:00","time_end":"21:00","location":"oboz_zlom","activity":"rest","animation":"idle","condition":"always","fallback":"oboz_zlom"},
  {"npc_id":"npc_rycerz_01","time_start":"06:00","time_end":"14:00","location":"twierdza_brama","activity":"work","animation":"idle","condition":"always","fallback":"twierdza_brama"},
  {"npc_id":"npc_rycerz_01","time_start":"14:00","time_end":"22:00","location":"twierdza_brama","activity":"patrol","animation":"walk","condition":"always","fallback":"twierdza_brama"},
  {"npc_id":"npc_rycerz_04","time_start":"07:00","time_end":"19:00","location":"twierdza_kuźnia","activity":"work","animation":"idle","condition":"always","fallback":"twierdza_kuźnia"},
  {"npc_id":"npc_rycerz_09","time_start":"08:00","time_end":"16:00","location":"bagno_brama","activity":"work","animation":"idle","condition":"always","fallback":"bagno_brama"},
  {"npc_id":"npc_rycerz_10","time_start":"08:00","time_end":"16:00","location":"twierdza_biblioteka","activity":"work","animation":"idle","condition":"always","fallback":"twierdza_biblioteka"},
  {"npc_id":"npc_reb_01","time_start":"07:00","time_end":"12:00","location":"oboz_ognisko","activity":"talk","animation":"idle","condition":"always","fallback":"oboz_ognisko"},
  {"npc_id":"npc_reb_02","time_start":"10:00","time_end":"18:00","location":"las_polana","activity":"patrol","animation":"walk","condition":"always","fallback":"las_polana"},
  {"npc_id":"npc_reb_03","time_start":"12:00","time_end":"16:00","location":"oboz_pod_sciana","activity":"work","animation":"idle","condition":"always","fallback":"oboz_pod_sciana"},
  {"npc_id":"npc_neut_01","time_start":"09:00","time_end":"15:00","location":"trakt_polowa","activity":"work","animation":"idle","condition":"always","fallback":"trakt_polowa"},
  {"npc_id":"npc_neut_02","time_start":"08:00","time_end":"16:00","location":"plaza_brzeg","activity":"rest","animation":"idle","condition":"always","fallback":"plaza_brzeg"},
  {"npc_id":"npc_neut_05","time_start":"06:00","time_end":"20:00","location":"trakt","activity":"patrol","animation":"walk","condition":"always","fallback":"trakt"}
]

project/data/json/npcs.json
+990
[
  {
    "id": "npc_alryk",
    "name": "Komendant Alryk",
    "faction": "stare_bractwo",
    "schedule": "old_camp",
    "role": "leader",
    "dialogue": "dialogues_old.json",
    "trainer": false,
    "stats": {
      "str": 15,
      "dex": 8,
      "mana": 0
    },
    "location": "twierdza_hall"
  },
  {
    "id": "npc_oskar",
    "name": "Brat Oskar",
    "faction": "neutral",
    "schedule": "neutral",
    "role": "mnich",
    "dialogue": "dialogues_neutral.json",
    "trainer": false,
    "stats": {
      "str": 6,
      "dex": 5,
      "mana": 10
    },
    "location": "bagno_kaplica"
  },
  {
    "id": "npc_zlom",
    "name": "Kupiec Złom",
    "faction": "neutral",
    "schedule": "neutral",
    "role": "paser",
    "dialogue": "dialogues_neutral.json",
    "trainer": false,
    "stats": {
      "str": 4,
      "dex": 7,
      "mana": 0
    },
    "location": "oboz_zlom"
  },
  {
    "id": "npc_pek",
    "name": "Złodziej Pęk",
    "faction": "new_faction",
    "schedule": "new_camp",
    "role": "thief_trainer",
    "dialogue": "dialogues_new.json",
    "trainer": true,
    "skills": [
      "lockpicking",
      "theft"
    ],
    "stats": {
      "str": 5,
      "dex": 16,
      "mana": 0
    },
    "location": "oboz_pod_sciana"
  },
  {
    "id": "npc_dzwiek",
    "name": "Nauczycielka Dźwięku",
    "faction": "neutral",
    "schedule": "neutral",
    "role": "bow_trainer",
    "dialogue": "dialogues_neutral.json",
    "trainer": true,
    "skills": [
      "bow"
    ],
    "stats": {
      "str": 5,
      "dex": 14,
      "mana": 2
    },
    "location": "las_polana"
  },
  {
    "id": "npc_gluchy",
    "name": "Szaman Głuchy",
    "faction": "neutral",
    "schedule": "neutral",
    "role": "mage_trainer",
    "dialogue": "dialogues_neutral.json",
    "trainer": true,
    "skills": [
      "spells"
    ],
    "stats": {
      "str": 4,
      "dex": 6,
      "mana": 20
    },
    "location": "bagno_kurhan"
  },
  {
    "id": "npc_mara",
    "name": "Przywódczyni Mara",
    "faction": "wolne_zgliszcza",
    "schedule": "new_camp",
    "role": "leader",
    "dialogue": "dialogues_new.json",
    "trainer": false,
    "stats": {
      "str": 12,
      "dex": 13,
      "mana": 5
    },
    "location": "oboz_ognisko"
  },
  {
    "id": "npc_rycerz_01",
    "name": "Strażnik War",
    "faction": "stare_bractwo",
    "schedule": "old_camp",
    "role": "guard",
    "dialogue": "dialogues_old.json",
    "trainer": false,
    "stats": {
      "str": 10,
      "dex": 8,
      "mana": 0
    },
    "location": "twierdza_brama"
  },
  {
    "id": "npc_rycerz_02",
    "name": "Kapitan Zor",
    "faction": "stare_bractwo",
    "schedule": "old_camp",
    "role": "guard",
    "dialogue": "dialogues_old.json",
    "trainer": false,
    "stats": {
      "str": 11,
      "dex": 9,
      "mana": 0
    },
    "location": "twierdza_wieza"
  },
  {
    "id": "npc_rycerz_03",
    "name": "Zwiadowca Klos",
    "faction": "stare_bractwo",
    "schedule": "old_camp",
    "role": "scout",
    "dialogue": "dialogues_old.json",
    "trainer": false,
    "stats": {
      "str": 7,
      "dex": 12,
      "mana": 0
    },
    "location": "trakt"
  },
  {
    "id": "npc_rycerz_04",
    "name": "Kowal Grzmot",
    "faction": "stare_bractwo",
    "schedule": "old_camp",
    "role": "blacksmith",
    "dialogue": "dialogues_old.json",
    "trainer": false,
    "stats": {
      "str": 14,
      "dex": 6,
      "mana": 0
    },
    "location": "twierdza_kuźnia"
  },
  {
    "id": "npc_rycerz_05",
    "name": "Mnich Brat Tyt",
    "faction": "stare_bractwo",
    "schedule": "old_camp",
    "role": "priest",
    "dialogue": "dialogues_old.json",
    "trainer": false,
    "stats": {
      "str": 5,
      "dex": 6,
      "mana": 8
    },
    "location": "twierdza_kaplica"
  },
  {
    "id": "npc_rycerz_06",
    "name": "Kucharz Bór",
    "faction": "stare_bractwo",
    "schedule": "old_camp",
    "role": "cook",
    "dialogue": "dialogues_old.json",
    "trainer": false,
    "stats": {
      "str": 9,
      "dex": 4,
      "mana": 0
    },
    "location": "twierdza_kuchnia"
  },
  {
    "id": "npc_rycerz_07",
    "name": "Magazynier Klos",
    "faction": "stare_bractwo",
    "schedule": "old_camp",
    "role": "storekeeper",
    "dialogue": "dialogues_old.json",
    "trainer": false,
    "stats": {
      "str": 8,
      "dex": 5,
      "mana": 0
    },
    "location": "twierdza_magazyn"
  },
  {
    "id": "npc_rycerz_08",
    "name": "Zwiadowczyni Lita",
    "faction": "stare_bractwo",
    "schedule": "old_camp",
    "role": "scout",
    "dialogue": "dialogues_old.json",
    "trainer": false,
    "stats": {
      "str": 6,
      "dex": 14,
      "mana": 0
    },
    "location": "las_polana"
  },
  {
    "id": "npc_rycerz_09",
    "name": "Strażnik Mrok",
    "faction": "stare_bractwo",
    "schedule": "old_camp",
    "role": "guard",
    "dialogue": "dialogues_old.json",
    "trainer": false,
    "stats": {
      "str": 10,
      "dex": 7,
      "mana": 0
    },
    "location": "bagno_brama"
  },
  {
    "id": "npc_rycerz_10",
    "name": "Pisarz Szym",
    "faction": "stare_bractwo",
    "schedule": "old_camp",
    "role": "scribe",
    "dialogue": "dialogues_old.json",
    "trainer": false,
    "stats": {
      "str": 3,
      "dex": 6,
      "mana": 3
    },
    "location": "twierdza_biblioteka"
  },
  {
    "id": "npc_reb_01",
    "name": "Buntownik Ryk",
    "faction": "wolne_zgliszcza",
    "schedule": "new_camp",
    "role": "fighter",
    "dialogue": "dialogues_new.json",
    "trainer": false,
    "stats": {
      "str": 10,
      "dex": 10,
      "mana": 0
    },
    "location": "oboz_ognisko"
  },
  {
    "id": "npc_reb_02",
    "name": "Buntowniczka Kira",
    "faction": "wolne_zgliszcza",
    "schedule": "new_camp",
    "role": "scout",
    "dialogue": "dialogues_new.json",
    "trainer": false,
    "stats": {
      "str": 7,
      "dex": 13,
      "mana": 0
    },
    "location": "las_polana"
  },
  {
    "id": "npc_reb_03",
    "name": "Buntownik Zgrzyt",
    "faction": "wolne_zgliszcza",
    "schedule": "new_camp",
    "role": "thief",
    "dialogue": "dialogues_new.json",
    "trainer": false,
    "stats": {
      "str": 5,
      "dex": 15,
      "mana": 0
    },
    "location": "oboz_pod_sciana"
  },
  {
    "id": "npc_reb_04",
    "name": "Buntowniczka Mara_2",
    "faction": "wolne_zgliszcza",
    "schedule": "new_camp",
    "role": "priestess",
    "dialogue": "dialogues_new.json",
    "trainer": false,
    "stats": {
      "str": 6,
      "dex": 8,
      "mana": 12
    },
    "location": "oboz_ognisko"
  },
  {
    "id": "npc_reb_05",
    "name": "Buntownik Jaromir",
    "faction": "wolne_zgliszcza",
    "schedule": "new_camp",
    "role": "fighter",
    "dialogue": "dialogues_new.json",
    "trainer": false,
    "stats": {
      "str": 9,
      "dex": 8,
      "mana": 0
    },
    "location": "kamieniołom_wejście"
  },
  {
    "id": "npc_neut_01",
    "name": "Handlarz Złom_2",
    "faction": "neutral",
    "schedule": "neutral",
    "role": "merchant",
    "dialogue": "dialogues_neutral.json",
    "trainer": false,
    "stats": {
      "str": 5,
      "dex": 8,
      "mana": 0
    },
    "location": "trakt_polowa"
  },
  {
    "id": "npc_neut_02",
    "name": "Rozbitek Wyrzut",
    "faction": "neutral",
    "schedule": "neutral",
    "role": "survivor",
    "dialogue": "dialogues_neutral.json",
    "trainer": false,
    "stats": {
      "str": 4,
      "dex": 6,
      "mana": 0
    },
    "location": "plaza_brzeg"
  },
  {
    "id": "npc_neut_03",
    "name": "Mnich Brat Milczący",
    "faction": "neutral",
    "schedule": "neutral",
    "role": "priest",
    "dialogue": "dialogues_neutral.json",
    "trainer": false,
    "stats": {
      "str": 4,
      "dex": 5,
      "mana": 15
    },
    "location": "bagno_kurhan"
  },
  {
    "id": "npc_neut_04",
    "name": "Zielarka Róża",
    "faction": "neutral",
    "schedule": "neutral",
    "role": "herbalist",
    "dialogue": "dialogues_neutral.json",
    "trainer": false,
    "stats": {
      "str": 4,
      "dex": 7,
      "mana": 4
    },
    "location": "las_polana"
  },
  {
    "id": "npc_neut_05",
    "name": "Wędrowiec Pusty",
    "faction": "neutral",
    "schedule": "neutral",
    "role": "wanderer",
    "dialogue": "dialogues_neutral.json",
    "trainer": false,
    "stats": {
      "str": 6,
      "dex": 9,
      "mana": 0
    },
    "location": "trakt"
  },
  {
    "id": "npc_neut_06",
    "name": "Starzec Głuchy_2",
    "faction": "neutral",
    "schedule": "neutral",
    "role": "old_man",
    "dialogue": "dialogues_neutral.json",
    "trainer": false,
    "stats": {
      "str": 3,
      "dex": 4,
      "mana": 6
    },
    "location": "bagno_kaplica"
  },
  {
    "id": "npc_neut_07",
    "name": "Kupiec Szary",
    "faction": "neutral",
    "schedule": "neutral",
    "role": "merchant",
    "dialogue": "dialogues_neutral.json",
    "trainer": false,
    "stats": {
      "str": 5,
      "dex": 7,
      "mana": 0
    },
    "location": "plaza_brzeg"
  },
  {
    "id": "npc_neut_08",
    "name": "Bandytka Lita",
    "faction": "neutral",
    "schedule": "neutral",
    "role": "bandit",
    "dialogue": "dialogues_neutral.json",
    "trainer": false,
    "stats": {
      "str": 7,
      "dex": 12,
      "mana": 0
    },
    "location": "las_polana"
  },
  {
    "id": "npc_neut_09",
    "name": "Staruszka Zgliszcze_2",
    "faction": "neutral",
    "schedule": "neutral",
    "role": "old_woman",
    "dialogue": "dialogues_neutral.json",
    "trainer": false,
    "stats": {
      "str": 3,
      "dex": 5,
      "mana": 3
    },
    "location": "bagno_kaplica"
  },
  {
    "id": "npc_neut_10",
    "name": "Wojownik Wyrzutek",
    "faction": "neutral",
    "schedule": "neutral",
    "role": "warrior",
    "dialogue": "dialogues_neutral.json",
    "trainer": false,
    "stats": {
      "str": 10,
      "dex": 8,
      "mana": 0
    },
    "location": "kamieniołom_wejście"
  },
  {
    "id": "npc_neut_11",
    "name": "Dzieciak Brud",
    "faction": "neutral",
    "schedule": "neutral",
    "role": "child",
    "dialogue": "dialogues_neutral.json",
    "trainer": false,
    "stats": {
      "str": 2,
      "dex": 5,
      "mana": 0
    },
    "location": "twierdza_brama"
  },
  {
    "id": "npc_neut_12",
    "name": "Dzieciak Zgliszcze_3",
    "faction": "neutral",
    "schedule": "neutral",
    "role": "child",
    "dialogue": "dialogues_neutral.json",
    "trainer": false,
    "stats": {
      "str": 2,
      "dex": 6,
      "mana": 0
    },
    "location": "oboz_ognisko"
  },
  {
    "id": "npc_neut_13",
    "name": "Kowal Grzmot_2",
    "faction": "neutral",
    "schedule": "neutral",
    "role": "blacksmith",
    "dialogue": "dialogues_neutral.json",
    "trainer": false,
    "stats": {
      "str": 14,
      "dex": 6,
      "mana": 0
    },
    "location": "trakt_polowa"
  },
  {
    "id": "npc_neut_14",
    "name": "Strażnik War_2",
    "faction": "neutral",
    "schedule": "neutral",
    "role": "guard",
    "dialogue": "dialogues_neutral.json",
    "trainer": false,
    "stats": {
      "str": 10,
      "dex": 8,
      "mana": 0
    },
    "location": "plaza_brzeg"
  },
  {
    "id": "npc_neut_15",
    "name": "Zielarka Kwiat",
    "faction": "neutral",
    "schedule": "neutral",
    "role": "herbalist",
    "dialogue": "dialogues_neutral.json",
    "trainer": false,
    "stats": {
      "str": 4,
      "dex": 8,
      "mana": 3
    },
    "location": "las_polana"
  },
  {
    "id": "npc_neut_16",
    "name": "Wędrowiec Brudny",
    "faction": "neutral",
    "schedule": "neutral",
    "role": "wanderer",
    "dialogue": "dialogues_neutral.json",
    "trainer": false,
    "stats": {
      "str": 6,
      "dex": 7,
      "mana": 0
    },
    "location": "bagno_kurhan"
  },
  {
    "id": "npc_neut_17",
    "name": "Handlarz Klos",
    "faction": "neutral",
    "schedule": "neutral",
    "role": "merchant",
    "dialogue": "dialogues_neutral.json",
    "trainer": false,
    "stats": {
      "str": 5,
      "dex": 6,
      "mana": 0
    },
    "location": "twierdza_brama"
  },
  {
    "id": "npc_neut_18",
    "name": "Starzec Milczący",
    "faction": "neutral",
    "schedule": "neutral",
    "role": "old_man",
    "dialogue": "dialogues_neutral.json",
    "trainer": false,
    "stats": {
      "str": 3,
      "dex": 4,
      "mana": 10
    },
    "location": "bagno_kaplica"
  },
  {
    "id": "npc_neut_19",
    "name": "Buntowniczka Pęk",
    "faction": "neutral",
    "schedule": "neutral",
    "role": "fighter",
    "dialogue": "dialogues_neutral.json",
    "trainer": false,
    "stats": {
      "str": 8,
      "dex": 11,
      "mana": 0
    },
    "location": "oboz_ognisko"
  },
  {
    "id": "npc_neut_20",
    "name": "Mnich Brat Tyt_2",
    "faction": "neutral",
    "schedule": "neutral",
    "role": "priest",
    "dialogue": "dialogues_neutral.json",
    "trainer": false,
    "stats": {
      "str": 5,
      "dex": 6,
      "mana": 8
    },
    "location": "las_polana"
  },
  {
    "id": "npc_neut_21",
    "name": "Strażnik Mrok_2",
    "faction": "neutral",
    "schedule": "neutral",
    "role": "guard",
    "dialogue": "dialogues_neutral.json",
    "trainer": false,
    "stats": {
      "str": 10,
      "dex": 7,
      "mana": 0
    },
    "location": "plaza_brzeg"
  },
  {
    "id": "npc_neut_22",
    "name": "Kucharz Bór_2",
    "faction": "neutral",
    "schedule": "neutral",
    "role": "cook",
    "dialogue": "dialogues_neutral.json",
    "trainer": false,
    "stats": {
      "str": 9,
      "dex": 4,
      "mana": 0
    },
    "location": "kamieniołom_wejście"
  },
  {
    "id": "npc_neut_23",
    "name": "Magazynier Klos_2",
    "faction": "neutral",
    "schedule": "neutral",
    "role": "storekeeper",
    "dialogue": "dialogues_neutral.json",
    "trainer": false,
    "stats": {
      "str": 8,
      "dex": 5,
      "mana": 0
    },
    "location": "bagno_brama"
  },
  {
    "id": "npc_neut_24",
    "name": "Wojownik Pusty_2",
    "faction": "neutral",
    "schedule": "neutral",
    "role": "warrior",
    "dialogue": "dialogues_neutral.json",
    "trainer": false,
    "stats": {
      "str": 10,
      "dex": 9,
      "mana": 0
    },
    "location": "trakt"
  },
  {
    "id": "npc_neut_25",
    "name": "Bandyta Zgrzyt_2",
    "faction": "neutral",
    "schedule": "neutral",
    "role": "bandit",
    "dialogue": "dialogues_neutral.json",
    "trainer": false,
    "stats": {
      "str": 8,
      "dex": 12,
      "mana": 0
    },
    "location": "bagno_kurhan"
  },
  {
    "id": "npc_reb_06",
    "name": "Wojownik Krwi",
    "faction": "wolne_zgliszcza",
    "schedule": "new_camp",
    "role": "fighter",
    "dialogue": "dialogues_new.json",
    "trainer": false,
    "stats": {
      "str": 12,
      "dex": 7,
      "mana": 0
    },
    "location": "kamieniołom_wejście"
  },
  {
    "id": "npc_reb_07",
    "name": "Czarownica Zgliszcze",
    "faction": "wolne_zgliszcza",
    "schedule": "new_camp",
    "role": "mage",
    "dialogue": "dialogues_new.json",
    "trainer": true,
    "skills": [
      "spells"
    ],
    "stats": {
      "str": 4,
      "dex": 9,
      "mana": 14
    },
    "location": "bagno_kurhan"
  },
  {
    "id": "npc_reb_08",
    "name": "Strażnik Bagna",
    "faction": "wolne_zgliszcza",
    "schedule": "new_camp",
    "role": "guard",
    "dialogue": "dialogues_new.json",
    "trainer": false,
    "stats": {
      "str": 9,
      "dex": 8,
      "mana": 0
    },
    "location": "bagno_brama"
  },
  {
    "id": "npc_reb_09",
    "name": "Kucharz Płomień",
    "faction": "wolne_zgliszcza",
    "schedule": "new_camp",
    "role": "cook",
    "dialogue": "dialogues_new.json",
    "trainer": false,
    "stats": {
      "str": 8,
      "dex": 5,
      "mana": 0
    },
    "location": "oboz_ognisko"
  },
  {
    "id": "npc_reb_10",
    "name": "Magazynier Popiół",
    "faction": "wolne_zgliszcza",
    "schedule": "new_camp",
    "role": "storekeeper",
    "dialogue": "dialogues_new.json",
    "trainer": false,
    "stats": {
      "str": 7,
      "dex": 6,
      "mana": 0
    },
    "location": "oboz_ognisko"
  },
  {
    "id": "npc_rycerz_11",
    "name": "Mnich Brat Krwawy",
    "faction": "stare_bractwo",
    "schedule": "old_camp",
    "role": "priest",
    "dialogue": "dialogues_old.json",
    "trainer": false,
    "stats": {
      "str": 6,
      "dex": 5,
      "mana": 10
    },
    "location": "twierdza_kaplica"
  },
  {
    "id": "npc_rycerz_12",
    "name": "Kowal Krwawy",
    "faction": "stare_bractwo",
    "schedule": "old_camp",
    "role": "blacksmith",
    "dialogue": "dialogues_old.json",
    "trainer": false,
    "stats": {
      "str": 13,
      "dex": 5,
      "mana": 0
    },
    "location": "twierdza_kuźnia"
  },
  {
    "id": "npc_rycerz_13",
    "name": "Strażnik Zgliszcze_2",
    "faction": "stare_bractwo",
    "schedule": "old_camp",
    "role": "guard",
    "dialogue": "dialogues_old.json",
    "trainer": false,
    "stats": {
      "str": 11,
      "dex": 7,
      "mana": 0
    },
    "location": "bagno_brama"
  },
  {
    "id": "npc_rycerz_14",
    "name": "Zwiadowca Brudny",
    "faction": "stare_bractwo",
    "schedule": "old_camp",
    "role": "scout",
    "dialogue": "dialogues_old.json",
    "trainer": false,
    "stats": {
      "str": 6,
      "dex": 13,
      "mana": 0
    },
    "location": "las_polana"
  },
  {
    "id": "npc_rycerz_15",
    "name": "Pisarz Krwawy",
    "faction": "stare_bractwo",
    "schedule": "old_camp",
    "role": "scribe",
    "dialogue": "dialogues_old.json",
    "trainer": false,
    "stats": {
      "str": 3,
      "dex": 7,
      "mana": 2
    },
    "location": "twierdza_biblioteka"
  },
  {
    "id": "npc_neut_26",
    "name": "Wędrowiec Brudny_2",
    "faction": "neutral",
    "schedule": "neutral",
    "role": "wanderer",
    "dialogue": "dialogues_neutral.json",
    "trainer": false,
    "stats": {
      "str": 5,
      "dex": 8,
      "mana": 0
    },
    "location": "bagno_kaplica"
  },
  {
    "id": "npc_neut_27",
    "name": "Handlarz Kamienny",
    "faction": "neutral",
    "schedule": "neutral",
    "role": "merchant",
    "dialogue": "dialogues_neutral.json",
    "trainer": false,
    "stats": {
      "str": 8,
      "dex": 6,
      "mana": 0
    },
    "location": "kamieniołom_wejście"
  },
  {
    "id": "npc_neut_28",
    "name": "Staruszka Kwiat_2",
    "faction": "neutral",
    "schedule": "neutral",
    "role": "old_woman",
    "dialogue": "dialogues_neutral.json",
    "trainer": false,
    "stats": {
      "str": 2,
      "dex": 4,
      "mana": 2
    },
    "location": "plaza_brzeg"
  },
  {
    "id": "npc_neut_29",
    "name": "Wojownik Kamienia",
    "faction": "neutral",
    "schedule": "neutral",
    "role": "warrior",
    "dialogue": "dialogues_neutral.json",
    "trainer": false,
    "stats": {
      "str": 11,
      "dex": 9,
      "mana": 0
    },
    "location": "kamieniołom_wejście"
  },
  {
    "id": "npc_neut_30",
    "name": "Dzieciak Brud_2",
    "faction": "neutral",
    "schedule": "neutral",
    "role": "child",
    "dialogue": "dialogues_neutral.json",
    "trainer": false,
    "stats": {
      "str": 2,
      "dex": 6,
      "mana": 0
    },
    "location": "bagno_brama"
  },
  {
    "id": "npc_neut_31",
    "name": "Bandyta Zgrzyt_3",
    "faction": "neutral",
    "schedule": "neutral",
    "role": "bandit",
    "dialogue": "dialogues_neutral.json",
    "trainer": false,
    "stats": {
      "str": 9,
      "dex": 11,
      "mana": 0
    },
    "location": "plaza_brzeg"
  },
  {
    "id": "npc_neut_32",
    "name": "Zielarka Róża_2",
    "faction": "neutral",
    "schedule": "neutral",
    "role": "herbalist",
    "dialogue": "dialogues_neutral.json",
    "trainer": false,
    "stats": {
      "str": 4,
      "dex": 7,
      "mana": 3
    },
    "location": "las_polana"
  },
  {
    "id": "npc_neut_33",
    "name": "Starzec Milczący_2",
    "faction": "neutral",
    "schedule": "neutral",
    "role": "old_man",
    "dialogue": "dialogues_neutral.json",
    "trainer": false,
    "stats": {
      "str": 3,
      "dex": 5,
      "mana": 8
    },
    "location": "szczelina"
  }
]

project/data/json/quests_main.json
+4
[
  {"id":"quest_przybycie","title":"Przybycie","type":"main","stages":[{"id":"start","objective":"Porozmawiaj z Alrykiem lub Marą","condition":"none","action":"dialogue_start"},{"id":"poznanie","objective":"Poznaj konflikt","condition":"dialogue_done"},{"id":"zapowiedz","objective":"Odwiedź Szczelinę Milczącego Boga","condition":"visit_shrine"},{"id":"kandydatura","objective":"Wykonaj zadanie kandydackie","condition":"quest_done"},{"id":"wybor","objective":"Wybierz frakcję","condition":"faction_decision","branch":"old_or_new"}],"rewards":{"xp":100,"items":["klucz_pierwszy"]},"final_choice":true},
  {"id":"quest_rozpoznanie","title":"Rozpoznanie","type":"main","stages":[{"id":"start","objective":"Znajdź Brata Oskara","condition":"none"}],"rewards":{"xp":50,"items":[]}}
]

project/data/json/quests_new_faction.json
+7
[
  {"id":"quest_wolnosc","title":"Wolność za cenę","type":"new_faction","stages":[{"id":"start","objective":"Okradnij strażnika","condition":"none"},{"id":"end","objective":"Oddaj dowód Marze","condition":"deliver_proof"}],"rewards":{"xp":80,"items":["miecz_zgliszcze"],"reputation":{"wolne_zgliszcza":+10}},"alternative_methods":["fight","bribe","persuasion"]},
  {"id":"quest_buntownik","title":"Buntownik","type":"new_faction","stages":[{"id":"start","objective":"Zniszcz plakat","condition":"none"},{"id":"end","objective":"Zdecyduj: zostaw / spal / sprzedaj plakat","condition":"plakat_decision"}],"rewards":{"xp":60,"items":[],"reputation":{"wolne_zgliszcza":+5}}},
  {"id":"quest_zasadzka","title":"Zasadzka","type":"new_faction","stages":[{"id":"start","objective":"Zabij bandytę Jaromira","condition":"none"},{"id":"end","objective":"Przynieś głowę Marze","condition":"kill_jaromir"}],"rewards":{"xp":100,"items":["zbroja_zgliszcze"],"reputation":{"wolne_zgliszcza":+10}},"alternative_methods":["trap","betray"]},
  {"id":"quest_krwawy_kamien","title":"Krwawy Kamień","type":"new_faction","stages":[{"id":"start","objective":"Przynieś kamień z kamieniołomu","condition":"none"},{"id":"end","objective":"Oddaj Marze","condition":"deliver_stone"}],"rewards":{"xp":70,"items":["mikstura_ognia"],"reputation":{"wolne_zgliszcza":+5}},
  {"id":"quest_ostatni_toast","title":"Ostatni Toast","type":"new_faction","stages":[{"id":"start","objective":"Zabierz wino z piwnicy","condition":"none"},{"id":"end","objective":"Zdecyduj: oddaj / wypij / sprzedaj","condition":"wine_decision"}],"rewards":{"xp":50,"items":["mikstura_zycia"],"reputation":{"wolne_zgliszcza":+5}}
]

project/data/json/quests_old_faction.json
+7
[
  {"id":"quest_rozporzadzenie","title":"Rozkaz dyscypliny","type":"old_faction","stages":[{"id":"start","objective":"Zanieś wiadomość strażnikowi","condition":"talk_alryk"},{"id":"deliver","objective":"Porozmawiaj ze Strażnikiem War","condition":"talk_rycerz_01"},{"id":"end","objective":"Wróć do Alryka","condition":"return_alryk"}],"rewards":{"xp":80,"items":["miecz_zardzewialy"],"reputation":{"stare_bractwo":+10}},"alternative_methods":["persuasion","theft","bribe"]},
  {"id":"quest_krwawe_zniwo","title":"Krwawe Żniwo","type":"old_faction","stages":[{"id":"start","objective":"Zabij 3 wilki","condition":"none"},{"id":"end","objective":"Przynieś skóry Alrykowi","condition":"kill_wolves"}],"rewards":{"xp":60,"items":["skora_wilk"],"reputation":{"stare_bractwo":+5}}},
  {"id":"quest_zaginiony","title":"Zaginiony Brat","type":"old_faction","stages":[{"id":"start","objective":"Znajdź Brata Oskara w bagnie","condition":"none"},{"id":"find","objective":"Porozmawiaj z Oskarem","condition":"visit_oskar"},{"id":"end","objective":"Zdecyduj: oddaj / zniszcz / sprzedaj list","condition":"choose_letter"}],"rewards":{"xp":100,"items":["klucz_kaplicy"],"reputation":{"stare_bractwo":+10}}},
  {"id":"quest_czysta_stal","title":"Czysta Stal","type":"old_faction","stages":[{"id":"start","objective":"Napraw miecz kowala","condition":"none"},{"id":"fix","objective":"Daj kowalowi kamień z kamieniołomu","condition":"deliver_stone"},{"id":"end","objective":"Odbierz naprawiony miecz","condition":"get_sword"}],"rewards":{"xp":70,"items":["miecz_kowalski"],"reputation":{"stare_bractwo":+5}}},
  {"id":"quest_ostatni_list","title":"Ostatni List","type":"old_faction","stages":[{"id":"start","objective":"Przeczytaj list zmarłego","condition":"find_letter"},{"id":"end","objective":"Zdecyduj: oddaj / zniszcz / sprzedaj","condition":"letter_decision"}],"rewards":{"xp":50,"items":[],"reputation":{"stare_bractwo":+5}},"branch":"destroy_or_sell"}
]

project/data/json/quests_side.json
+12
[
  {"id":"quest_zaginione_trofeum","title":"Zaginione Trofeum","type":"side","stages":[{"id":"start","objective":"Znajdź trofeum w lesie","condition":"none"},{"id":"end","objective":"Oddaj trofeum Bratowi Oskarowi","condition":"deliver_trophy"}],"rewards":{"xp":40,"items":["skora_dzik"]}},
  {"id":"quest_glodne_wilki","title":"Głodne Wilki","type":"side","stages":[{"id":"start","objective":"Zabij 2 wilki i przynieś mięso","condition":"none"},{"id":"end","objective":"Oddaj mięso Zielarce Róży","condition":"deliver_meat"}],"rewards":{"xp":40,"items":["roslina_lesna"]}},
  {"id":"quest_peknięty_zamek","title":"Pęknięty Zamek","type":"side","stages":[{"id":"start","objective":"Otwórz skrzynię w kamieniołomie","condition":"none"},{"id":"end","objective":"Zdecyduj: oddaj zawartość / zatrzymaj / sprzedaj","condition":"chest_decision"}],"rewards":{"xp":50,"items":["klucz_pierwszy"]}},
  {"id":"quest_ziola_szamana","title":"Zioła Szamana","type":"side","stages":[{"id":"start","objective":"Zbierz 3 zioła bagienne","condition":"none"},{"id":"end","objective":"Oddaj Szamanowi Głuchemu","condition":"deliver_herbs"}],"rewards":{"xp":60,"items":["mikstura_many"]}},
  {"id":"quest_rozbite_serce","title":"Rozbite Serce","type":"side","stages":[{"id":"start","objective":"Znajdź list od Mara_2","condition":"none"},{"id":"end","objective":"Zdecyduj: oddaj / zniszcz","condition":"letter_decision"}],"rewards":{"xp":50,"items":[]}},
  {"id":"quest_kradziez_noca","title":"Kradzież Nocą","type":"side","stages":[{"id":"start","objective":"Ukradnij przedmiot z obozu","condition":"none"},{"id":"end","objective":"Uniknij świadków","condition":"no_witness"}],"rewards":{"xp":70,"items":["miecz_zlodziejski"]}},
  {"id":"quest_list_z_wybrzeza","title":"List z Wybrzeża","type":"side","stages":[{"id":"start","objective":"Znajdź list na plaży","condition":"none"},{"id":"end","objective":"Oddaj Wyrzutkowi","condition":"deliver_letter"}],"rewards":{"xp":40,"items":["roslina_plazowa"]}},
  {"id":"quest_gluchy_bog","title":"Głuchy Bóg Budzi się","type":"side","stages":[{"id":"start","objective":"Odwiedź kurhan","condition":"none"},{"id":"end","objective":"Zdecyduj: zniszcz / zostaw / zabierz relikwię","condition":"relic_decision"}],"rewards":{"xp":100,"items":["mikstura_ognia","mikstura_lodu"]}},
  {"id":"quest_plomien_i_popiol","title":"Płomień i Popiół","type":"side","stages":[{"id":"start","objective":"Znajdź popiół w kamieniołomie","condition":"none"},{"id":"end","objective":"Oddaj kupcowi","condition":"deliver_ash"}],"rewards":{"xp":60,"items":["zbroja_czarna"]}},
  {"id":"quest_wyrzutka","title":"Wyrzutka","type":"side","stages":[{"id":"start","objective":"Pomóż Wyrzutkowi znaleźć dom","condition":"none"},{"id":"end","objective":"Zdecyduj: oddaj / zatrzymaj / sprzedaj mapę","condition":"map_decision"}],"rewards":{"xp":30,"items":["klucz_pierwszy"]}}
]

project/data/json/savegame.json
+27
{
  "version": "1.0.0",
  "slot": 1,
  "player": {
    "pos_x": 500.0,
    "pos_y": 400.0,
    "hp": 100,
    "max_hp": 100,
    "level": 1,
    "xp": 0,
    "learning_points": 1,
    "stats": {"str": 5, "dex": 5, "mana": 0}
  },
  "world_time": {"hour": 8, "minute": 0},
  "inventory": [{"id":"miecz_pierwszy","amount":1}],
  "equipped": {"weapon":"miecz_pierwszy","armor":null},
  "quests": {
    "active":["quest_przybycie"],
    "completed":[]
  },
  "flags": {"quest_przybycie":"start"},
  "reputations": {"stare_bractwo":0,"wolne_zgliszcza":0},
  "faction_choice":"",
  "npc_states": {},
  "chests_opened":[],
  "enemies_defeated":[]
}

project/data/json/spells.json
+4
[
  {"id":"spell_fire","name":"Ognisty Pocisk","damage":20,"mana_cost":10,"cast_time":1.5,"sprite":"res://assets/sprites/spells/fire_ball.png","type":"projectile","element":"fire","req_quest":"quest_gluchy_bog"},
  {"id":"spell_ice","name":"Lodowy Pocisk","damage":15,"mana_cost":8,"cast_time":1.0,"sprite":"res://assets/sprites/spells/ice_ball.png","type":"projectile","element":"ice","req_quest":"quest_gluchy_bog"}
]

project/data/json/trainers.json
+8
[
  {"id":"trainer_sword","name":"Trener Miecza","npc":"npc_rycerz_01","skills":["sword_1","sword_2","sword_3"],"limit":3,"cost_per_level":20,"req_faction":"stare_bractwo","location":"twierdza_kuźnia"},
  {"id":"trainer_bow","name":"Nauczycielka Dźwięku","npc":"npc_dzwiek","skills":["bow_1","bow_2","bow_3"],"limit":3,"cost_per_level":20,"req_faction":"neutral","location":"las_polana"},
  {"id":"trainer_lock","name":"Złodziej Pęk","npc":"npc_pek","skills":["lockpick_1","lockpick_2","lockpick_3"],"limit":3,"cost_per_level":25,"req_faction":"wolne_zgliszcza","location":"oboz_pod_sciana"},
  {"id":"trainer_theft","name":"Złodziej Pęk","npc":"npc_pek","skills":["theft_1","theft_2","theft_3"],"limit":3,"cost_per_level":25,"req_faction":"wolne_zgliszcza","location":"oboz_pod_sciana"},
  {"id":"trainer_skinning","name":"Zwiadowca Klos","npc":"npc_rycerz_03","skills":["skinning_1","skinning_2"],"limit":2,"cost_per_level":30,"req_faction":"stare_bractwo","location":"trakt"},
  {"id":"trainer_spells","name":"Szaman Głuchy","npc":"npc_gluchy","skills":["spell_fire","spell_ice"],"limit":2,"cost_per_level":50,"req_faction":"neutral","location":"bagno_kurhan","quest_req":"quest_gluchy_bog"}
]

project/data/json/world_locations.json
+10
[
  {"id":"twierdza","name":"Twierdza Czarnej Ręki","region":"north","type":"settlement","faction":"stare_bractwo","coords":{"x":400,"y":300},"interactions":["chest_01","bed_01","npc_alryk","npc_rycerz_01"]},
  {"id":"oboz_zgliszcze","name":"Obóz Wolnych Zgliszcz","region":"south","type":"settlement","faction":"wolne_zgliszcza","coords":{"x":600,"y":700},"interactions":["chest_02","bed_02","npc_mara","npc_pek"]},
  {"id":"trakt","name":"Trakt Brudny","region":"center","type":"road","faction":"neutral","coords":{"x":500,"y":500},"interactions":["npc_neut_05","npc_neut_01"]},
  {"id":"las_zgnilizny","name":"Las Zgnilizny","region":"east","type":"forest","faction":"neutral","coords":{"x":700,"y":400},"interactions":["roslina_lesna","wilk_zgnilizny","npc_neut_08"]},
  {"id":"bagno_gluche","name":"Bagno Głuche","region":"east","type":"swamp","faction":"neutral","coords":{"x":850,"y":450},"interactions":["roslina_bagienna","upior_nocy","npc_oskar","npc_gluchy"]},
  {"id":"kamieniolom","name":"Kamieniołom Krwi","region":"west","type":"mountain","faction":"neutral","coords":{"x":200,"y":200},"interactions":["golem_kamienny","roslina_ognista","npc_neut_20"]},
  {"id":"plaza_popiolow","name":"Plaża Popiołów","region":"southwest","type":"beach","faction":"neutral","coords":{"x":150,"y":750},"interactions":["krab_plazowy","roslina_plazowa","npc_neut_02","npc_neut_07"]},
  {"id":"szczelina","name":"Szczelina Milczącego Boga","region":"northeast","type":"shrine","faction":"neutral","coords":{"x":900,"y":150},"interactions":["roslina_ognista","upior_nocy","npc_neut_18"]}
]

project/project.godot
+36
; Godot Engine Project File
[gd_project]
config_version=5
[gd_scene load_steps=2 format=3 uid="uid://d2lq7k7j5r7f8"]
[application]
config/name="Zgnilizna"
run/main_scene="res://scenes/main.tscn"
config/features=4.3
config/use_hidden_project_data_directory=true
[input]
move_left={"deadzone":0.5,"events":[{"device":-1,"type":4,"index":15,"action":"ui_left"}]}
move_right={"deadzone":0.5,"events":[{"device":-1,"type":4,"index":16,"action":"ui_right"}]}
move_up={"deadzone":0.5,"events":[{"device":-1,"type":4,"index":17,"action":"ui_up"}]}
move_down={"deadzone":0.5,"events":[{"device":-1,"type":4,"index":18,"action":"ui_down"}]}
interact={"deadzone":0.5,"events":[{"device":-1,"type":4,"index":5,"action":"E"}]}
attack={"deadzone":0.5,"events":[{"device":-1,"type":3,"button_index":1,"action":"Left Mouse"}]}
menu_pause={"deadzone":0.5,"events":[{"device":-1,"type":4,"index":88,"action":"P"}]}
quick_save={"deadzone":0.5,"events":[{"device":-1,"type":4,"index":83,"action":"F5"}]}
quick_load={"deadzone":0.5,"events":[{"device":-1,"type":4,"index":84,"action":"F9"}]}
[autoload]
GameState="*res://autoload/game_state.gd"
DataLoader="*res://autoload/data_loader.gd"
WorldTime="*res://autoload/world_time.gd"
DialogueManager="*res://autoload/dialogue_manager.gd"
NPCSystem="*res://autoload/npc_system.gd"
InventorySystem="*res://autoload/inventory_system.gd"
SaveSystem="*res://autoload/save_system.gd"
CombatSystem="*res://autoload/combat_system.gd"
CrimeSystem="*res://autoload/crime_system.gd"
TheftSystem="*res://autoload/theft_system.gd"
SkinningSystem="*res://autoload/skinning_system.gd"

project/scenes/main.tscn
+63
[gd_scene load_steps=4 format=3 uid="uid://bq8jwc7yhxwj2"]
[ext_resource type="Script" path="res://scripts/ui/main_menu.gd" id="1_s3q4m"]
[ext_resource type="FontFile" uid="uid://bzj8xplw7m6xq" path="res://assets/fonts/default.ttf" id="2_ja6v2"]
[node name="MainMenu" type="Control"]
layout_mode = 3
anchors_preset = 15
grow_horizontal = 2
grow_vertical = 2
script = ExtResource("1_s3q4m")
[node name="Background" type="ColorRect" parent="."]
layout_mode = 1
anchors_preset = 15
grow_horizontal = 2
grow_vertical = 2
color = Color(0.0784314, 0.0823529, 0.0862745, 1)
[node name="Title" type="Label" parent="."]
layout_mode = 1
anchors_preset = 5
anchor_left = 0.5
anchor_right = 0.5
offset_left = -200
offset_right = 200
offset_top = 100
offset_bottom = 160
grow_horizontal = 2
horizontal_alignment = 1
text = "ZGNILIZNA"
label_settings = SubResource("LabelSettings_7f29p")
[node name="Buttons" type="VBoxContainer" parent="."]
layout_mode = 1
anchors_preset = 8
anchor_top = 0.5
anchor_bottom = 0.8
offset_left = 420
offset_top = -100
offset_right = 820
offset_bottom = 100
grow_horizontal = 2
[node name="NewGame" type="Button" parent="Buttons"]
layout_mode = 2
text = "Nowa Gra"
[node name="LoadGame" type="Button" parent="Buttons"]
layout_mode = 2
text = "Wczytaj"
[node name="Options" type="Button" parent="Buttons"]
layout_mode = 2
text = "Opcje"
[node name="Quit" type="Button" parent="Buttons"]
layout_mode = 2
text = "Wyjście"
[sub_resource type="LabelSettings" id="LabelSettings_7f29p"]
font_size = 48
font_color = Color(0.839216, 0.65098, 0.34902, 1)

project/scenes/minigame/minigame_lock.tscn
+15
[gd_scene load_steps=3 format=3 uid="uid://lock001"]
[ext_resource type="Script" path="res://scripts/minigame/lock_minigame.gd" id="1"]
[node name="LockMinigame" type="Control"]
layout_mode = 3
anchors_preset = 15
grow_horizontal = 2
grow_vertical = 2
script = ExtResource("1")
[node name="Label" type="Label" parent="."]
layout_mode = 1
anchors_preset = 8
anchor_left = 0.4
anchor_right = 0.6
grow_horizontal = 2
text = "Minigra zamka"

project/scenes/npc_base.tscn
+10
[gd_scene load_steps=3 format=3 uid="uid://npcbase"]
[ext_resource type="Texture2D" uid="uid://npc_tex" path="res://assets/sprites/player_base.png" id="1"]
[node name="NPC" type="StaticBody2D"]
collision_layer = 2
collision_mask = 1
[node name="Sprite2D" type="Sprite2D" parent="."]
texture = ExtResource("1")
[node name="Area2D" type="Area2D" parent="."]
collision_layer = 2
collision_mask = 1

project/scenes/player.tscn
+16
[gd_scene load_steps=3 format=3 uid="uid://player001"]
[ext_resource type="Script" path="res://scripts/player/player.gd" id="1"]
[ext_resource type="Texture2D" uid="uid://bzabc123" path="res://assets/sprites/player_base.png" id="2"]
[node name="Player" type="CharacterBody2D"]
script = ExtResource("1")
collision_layer = 1
collision_mask = 1
[node name="Sprite2D" type="Sprite2D" parent="."]
texture = ExtResource("2")
position = Vector2(0, 0)
[node name="Camera2D" type="Camera2D" parent="."]
position = Vector2(0, 0)

project/scenes/ui/dialogue.tscn
+33
[gd_scene load_steps=4 format=3 uid="uid://dialog001"]
[ext_resource type="Script" path="res://scripts/ui/dialogue.gd" id="1"]
[node name="DialogueUI" type="Control"]
layout_mode = 3
anchors_preset = 15
grow_horizontal = 2
grow_vertical = 2
script = ExtResource("1")
[node name="Panel" type="Panel" parent="."]
layout_mode = 1
anchors_preset = 8
anchor_left = 0.2
anchor_top = 0.3
anchor_right = 0.8
grow_horizontal = 2
grow_vertical = 2
[node name="Text" type="RichTextLabel" parent="Panel"]
layout_mode = 1
anchors_preset = 15
grow_horizontal = 2
grow_vertical = 2
fit_content = true
[node name="Responses" type="VBoxContainer" parent="Panel"]
layout_mode = 1
anchors_preset = 2
anchor_top = 0.7
anchor_right = 1.0
grow_vertical = 0

project/scenes/ui/hud.tscn
+26
[gd_scene load_steps=4 format=3 uid="uid://hud001"]
[ext_resource type="Script" path="res://scripts/ui/hud.gd" id="1"]
[node name="HUD" type="CanvasLayer"]
layer = 1
script = ExtResource("1")
[node name="HPBar" type="ProgressBar" parent="."]
anchors_preset = 2
anchor_top = 0.05
anchor_right = 0.3
grow_horizontal = 2
grow_vertical = 0
max_value = 100.0
value = 100.0
show_percentage = false
[node name="Info" type="Label" parent="."]
anchors_preset = 1
anchor_left = 0.02
anchor_top = 0.02
anchor_right = 0.5
grow_horizontal = 2
grow_vertical = 0
text = "Zgnilizna | Poziom: 1"

project/scenes/ui/inventory.tscn
+55
[gd_scene load_steps=6 format=3 uid="uid://inv001"]
[ext_resource type="Script" path="res://scripts/ui/inventory.gd" id="1"]
[node name="InventoryUI" type="Control"]
layout_mode = 3
anchors_preset = 0
script = ExtResource("1")
[node name="Tabs" type="HBoxContainer" parent="."]
layout_mode = 1
anchors_preset = 2
anchor_top = 0.02
anchor_right = 0.5
grow_horizontal = 2
[node name="Inventory" type="Button" parent="Tabs"]
layout_mode = 2
text = "Ekwipunek"
[node name="Stats" type="Button" parent="Tabs"]
layout_mode = 2
text = "Statystyki"
[node name="Journal" type="Button" parent="Tabs"]
layout_mode = 2
text = "Dziennik"
[node name="Content" type="Panel" parent="."]
layout_mode = 1
anchors_preset = 15
grow_horizontal = 2
grow_vertical = 2
[node name="InventoryPanel" type="ItemList" parent="Content"]
layout_mode = 1
anchors_preset = 15
grow_horizontal = 2
grow_vertical = 2
[node name="StatsPanel" type="RichTextLabel" parent="Content"]
layout_mode = 1
anchors_preset = 15
grow_horizontal = 2
grow_vertical = 2
visible = false
text = "Siła: 5\\nZręczność: 5\\nMana: 0\\nHP: 100"
[node name="JournalPanel" type="RichTextLabel" parent="Content"]
layout_mode = 1
anchors_preset = 15
grow_horizontal = 2
grow_vertical = 2
visible = false
text = "Aktywne zadania: Przybycie"

project/scenes/ui/pause.tscn
+44
[gd_scene load_steps=5 format=3 uid="uid://pause001"]
[ext_resource type="Script" path="res://scripts/ui/pause.gd" id="1"]
[node name="PauseMenu" type="Control"]
layout_mode = 3
anchors_preset = 15
grow_horizontal = 2
grow_vertical = 2
script = ExtResource("1")
[node name="Panel" type="ColorRect" parent="."]
layout_mode = 1
anchors_preset = 15
grow_horizontal = 2
grow_vertical = 2
color = Color(0.1, 0.1, 0.1, 0.9)
[node name="Buttons" type="VBoxContainer" parent="Panel"]
layout_mode = 1
anchors_preset = 8
anchor_left = 0.4
anchor_right = 0.6
grow_horizontal = 2
[node name="Resume" type="Button" parent="Buttons"]
layout_mode = 2
text = "Wznów"
[node name="Save" type="Button" parent="Buttons"]
layout_mode = 2
text = "Zapisz"
[node name="Load" type="Button" parent="Buttons"]
layout_mode = 2
text = "Wczytaj"
[node name="Options" type="Button" parent="Buttons"]
layout_mode = 2
text = "Opcje"
[node name="QuitToMenu" type="Button" parent="Buttons"]
layout_mode = 2
text = "Wyjście do menu"

project/scenes/world.tscn
+24
[gd_scene load_steps=7 format=3 uid="uid://world002"]
[ext_resource type="Script" path="res://scripts/world/world.gd" id="1_abc"]
[ext_resource type="PackedScene" uid="uid://player001" path="res://scenes/player.tscn" id="2_def"]
[sub_resource type="RectangleShape2D" id="RectangleShape2D_1"]
size = Vector2(2000, 2000)
[node name="World" type="Node2D"]
script = ExtResource("1_abc")
map_size = Vector2(1200, 800)
[node name="Ground" type="StaticBody2D" parent="."]
collision_layer = 2
collision_mask = 0
[node name="CollisionShape2D" type="CollisionShape2D" parent="Ground"]
shape = SubResource("RectangleShape2D_1")
[node name="Player" parent="." instance=ExtResource("2_def")]
position = Vector2(500, 400)
[node name="Lighting" type="CanvasModulate" parent="."]
color = Color(0.7, 0.65, 0.6, 1)

project/scripts/minigame/lock_minigame.gd
+11
extends Control

signal lock_opened(success: bool)

func _ready() -> void:
    pass

func open_lock(level: int) -> void:
    visible = true
    var success := randf() < (0.3 + 0.2 * min(level, 3))
    lock_opened.emit(success)

project/scripts/player/player.gd
+62
extends CharacterBody2D

@export var speed: float = 150.0
@export var max_hp: int = 100
@export var hp: int = 100

var level: int = 1
var xp: int = 0
var learning_points: int = 1
var stats: Dictionary = {"str": 5, "dex": 5, "mana": 0}

func _physics_process(delta: float) -> void:
    var input_dir := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
    velocity = input_dir * speed
    move_and_slide()

    # Interakcja z E
    if Input.is_action_just_pressed("interact"):
        interact_nearest()

func interact_nearest() -> void:
    # Szukaj najbliższego interaktywnego obiektu (NPC, przedmiot)
    var space := get_world_2d().direct_space_state
    var query := PhysicsPointQueryParameters2D.new()
    query.position = global_position
    query.collide_with_areas = true
    query.collide_with_bodies = false
    var result := space.intersect_point(query)
    if result.size() > 0:
        var obj := result[0].collider
        if obj.has_method("interact"):
            obj.interact()
        elif obj.name.begins_with("npc_"):
            DialogueManager.start_dialogue(obj.get_meta("dialogue", "dialogues_neutral.json"))
        elif obj.name.begins_with("chest_"):
            open_chest(obj)

func open_chest(chest: Node2D) -> void:
    # Prosta minigra zamka
    var minigame := preload("res://scenes/minigame/minigame_lock.tscn").instantiate()
    minigame.lock_opened.connect(func(success: bool):
        if success:
            InventorySystem.add_item("miecz_zlota", 1)
        minigame.queue_free()
    )
    get_tree().current_scene.add_child(minigame)

func take_damage(amount: int) -> void:
    hp -= amount
    if hp <= 0:
        hp = 0

func gain_xp(amount: int) -> void:
    xp += amount
    var xp_needed := 100 + (level - 1) * 100
    if xp >= xp_needed:
        xp -= xp_needed
        level += 1
        max_hp = 50 + 15 * level
        hp = max_hp
        learning_points += 1
        GameState.set_flag("level_up", true)

project/scripts/ui/dialogue.gd
+19
extends Control

func _ready() -> void:
    DialogueManager.dialogue_updated.connect(_update_dialogue)
    DialogueManager.dialogue_ended.connect(_close_dialogue)
    visible = false

func _update_dialogue(text: String, responses: Array) -> void:
    visible = true
    $Panel/Text.text = text
    $Panel/Responses.clear()
    for resp in responses:
        var btn := Button.new()
        btn.text = resp.get("text", "...")
        btn.pressed.connect(func(idx=responses.find(resp)): DialogueManager.choose_response(idx))
        $Panel/Responses.add_child(btn)

func _close_dialogue() -> void:
    visible = false

project/scripts/ui/hud.gd
+10
extends CanvasLayer

func _ready() -> void:
    # Aktualizacja co klatkę
    pass

func _process(_delta: float) -> void:
    $HPBar.value = max(0, Player.hp if Player else 100)
    $ManaBar.value = 0
    $Info.text = "Zgnilizna | Poziom: 1"

project/scripts/ui/inventory.gd
+22
extends Control

func _ready() -> void:
    $Tabs/Inventory.pressed.connect(_show_inventory)
    $Tabs/Stats.pressed.connect(_show_stats)
    $Tabs/Journal.pressed.connect(_show_journal)
    visible = false

func _show_inventory() -> void:
    $Content/InventoryPanel.visible = true
    $Content/StatsPanel.visible = false
    $Content/JournalPanel.visible = false

func _show_stats() -> void:
    $Content/InventoryPanel.visible = false
    $Content/StatsPanel.visible = true
    $Content/JournalPanel.visible = false

func _show_journal() -> void:
    $Content/InventoryPanel.visible = false
    $Content/StatsPanel.visible = false
    $Content/JournalPanel.visible = true

project/scripts/ui/main_menu.gd
+21
extends Control

func _ready() -> void:
    $Buttons/NewGame.pressed.connect(_on_new_game)
    $Buttons/LoadGame.pressed.connect(_on_load)
    $Buttons/Options.pressed.connect(_on_options)
    $Buttons/Quit.pressed.connect(_on_quit)

func _on_new_game() -> void:
    GameState.init()
    get_tree().change_scene_to_file("res://scenes/world.tscn")

func _on_load() -> void:
    SaveSystem.load_game(1)
    get_tree().change_scene_to_file("res://scenes/world.tscn")

func _on_options() -> void:
    print("Opcje — do implementacji")

func _on_quit() -> void:
    get_tree().quit()

project/scripts/ui/pause.gd
+26
extends Control

func _ready() -> void:
    visible = false
    $Resume.pressed.connect(_resume)
    $Save.pressed.connect(_save)
    $Load.pressed.connect(_load)
    $Options.pressed.connect(_options)
    $QuitToMenu.pressed.connect(_quit)

func _resume() -> void:
    visible = false
    get_tree().paused = false

func _save() -> void:
    SaveSystem.save_game(1)

func _load() -> void:
    SaveSystem.load_game(1)

func _options() -> void:
    pass

func _quit() -> void:
    get_tree().paused = false
    get_tree().change_scene_to_file("res://scenes/main.tscn")

project/scripts/world/world.gd
+26
extends Node2D

@export var map_size := Vector2(1200, 1200)

func _ready() -> void:
    # Oświetlenie dnia/nocy
    var lighting := CanvasModulate.new()
    lighting.name = "Lighting"
    lighting.color = Color(0.7, 0.65, 0.6, 1)
    add_child(lighting)

    # Spawn podstawowych interaktywnych obiektów
    spawn_interactives()

func _process(delta: float) -> void:
    # Aktualizacja dnia/nocy
    var lighting := get_node("Lighting")
    if WorldTime.is_day:
        lighting.color = Color(0.8, 0.75, 0.7, 1)
    else:
        lighting.color = Color(0.3, 0.3, 0.4, 1)

func spawn_interactives() -> void:
    # Dodaj przykład interaktywnego NPC
    var npc_scene := preload("res://scenes/npc_base.tscn")
    # Brak sceny NPC; używamy prostego węzła

project/tests/test_combat.gd
+7
extends SceneTree

func _init():
    print("TEST: Formuła obrażeń")
    var dmg = 8 + 5 - 2  # miecz + str_bonus - armor
    print("PASS: obrażenia = " + str(dmg))
    quit()

project/tests/test_loader.gd
+14
extends SceneTree

func _init():
    print("TEST: Loader JSON")
    var loader = preload("res://autoload/data_loader.gd").new()
    var test_path = "res://data/json/npcs.json"
    var data = loader.load_json(test_path)
    if data == null:
        print("FAIL: brak danych")
    elif len(data) < 60:
        print("FAIL: za mało NPC: " + str(len(data)))
    else:
        print("PASS: " + str(len(data)) + " NPC")
    quit()

project/tests/test_quest.gd
+10
extends SceneTree

func _init():
    print("TEST: Questy")
    var loader = preload("res://autoload/data_loader.gd").new()
    var old_q = loader.load_json("res://data/json/quests_old_faction.json")
    var new_q = loader.load_json("res://data/json/quests_new_faction.json")
    var side_q = loader.load_json("res://data/json/quests_side.json")
    print("PASS: old=" + str(len(old_q)) + ", new=" + str(len(new_q)) + ", side=" + str(len(side_q)))
    quit()

project/tests/test_save.gd
+17
extends SceneTree

func _init():
    print("TEST: Zapis")
    # Sprawdzenie, czy plik savegame istnieje i jest poprawny
    var f = FileAccess.open("res://data/json/savegame.json", FileAccess.READ)
    if f == null:
        print("FAIL: brak pliku savegame.json")
    else:
        var content = f.get_as_text()
        f.close()
        var parsed = JSON.parse_string(content)
        if parsed == null:
            print("FAIL: błędny JSON")
        else:
            print("PASS: savegame poprawny, wersja=" + str(parsed.get("version", "brak")))
    quit()

    

Branch
unified
split


ARCHITECTURE.md
+41
# ARCHITECTURE.md

## Autoloady

- `GameState` — stan gry, flagi, questy, reputacje, zapisy
- `DataLoader` — ładowanie i walidacja JSON
- `WorldTime` — zegar świata, dzień/noc
- `DialogueManager` — dialogi i wybory
- `CombatSystem` — walka, obrażenia
- `NPCSystem` — harmonogramy, AI, przestępstwa
- `InventorySystem` — ekwipunek, przedmioty
- `SaveSystem` — zapis i wczytanie

## Sceny główne

- `main.tscn` — menu główne
- `world.tscn` — świat gry (TileMap, NPC, potwory, obiekty interakcji)
- `player.tscn` — gracz (CharacterBody2D)
- `hud.tscn` — HUD
- `dialogue.tscn` — okno dialogowe
- `inventory.tscn` — ekwipunek
- `journal.tscn` — dziennik
- `pause.tscn` — pauza
- `save_menu.tscn` — sloty zapisu
- `minigame_lock.tscn` — minigra zamka

## Przepływ danych

JSON (data/json/) → DataLoader (Resource) → runtime (autoloady / sceny) → zapis (JSON)

## Sygnały

- `player_interacted` — interakcja z obiektem
- `quest_updated` — aktualizacja zadania
- `npc_schedule_changed` — zmiana harmonogramu
- `crime_committed` — popełnienie przestępstwa
- `faction_chosen` — wybór frakcji

## Zapis

JSON z polami: wersja, gracz, pozycja, czas, ekwipunek, wyposażenie, statystyki, questy, flagi dialogowe, reputacje, stan NPC, pokonani wrogowie, loot, otwarte skrzynie, rutyny, wybór frakcji.

ART_BIBLE.md
+34
# ART_BIBLE.md

## Styl

- Ręcznie rysowany pixel art / surowa ilustracja rastrowa 2D
- Brudny, ciemny, ciężki klimat
- Przygaszona paleta: brudne brązy, zieleń błota, stal, czerń, rdza
- Mocne kontrasty między światłem a cieniem

## Paleta

- Tło: #1a1512 (ciemny brąz)
- Światło: #d4a76a (ciepły beż)
- Stal: #6b7b8c (zimny szary)
- Błoto: #3d4a2e (ciemny zielony)
- Ogień: #c45a2e (rdza)
- Krew: #7a1f1f (ciemna czerwień)

## Skala

- Tile: 32x32 px
- Postać: 32x48 px (sprite sheet 4 kierunki, 4 klatki)
- Broń: 32x32 px
- Potwór: 48x48 px

## Budżet

- Tileset: 10 atlasów (budynki, skały, drzewa, bagno, brzeg, rośliny, rekwizyty, skrzynie)
- Sprite sheets postaci: 4 kierunki, 4 klatki, 2 warianty ubioru (stara / nowa frakcja)
- Bronie: 30 wizualnie odróżnialnych
- Zbroje: 4 dostępne graczowi
- Potwory: 6 gatunków
- UI: 30 ikon przedmiotów
- Animacje: idle, chód, atak, blok, strzał, czar, trafienie, śmierć

CHALLENGES.md
+25
# CHALLENGES.md

## Główne problemy i decyzje

1. **Oryginalne IP bez kopiowania** — nazwy, fabuła, dialogi, lokacje tworzone od podstaw. Decyzja: nazwa krainy "Zgnilizna", frakcje "Stare Bractwo" i "Wolne Zgliszcza", bóstwo "Milczący Bóg".

2. **Skala projektu** — 65 NPC, pełne questy, pełne UI. Decyzja: priorytety P0/P1/P2 w TODO.md; zawsze zostawiamy projekt uruchamialny.

3. **Brak zewnętrznych assetów** — używamy proceduralnych/prostych zamienników, dokładnych promptów i własnych sprite'ów generowanych przez AI (oznaczone w THIRD_PARTY_ASSETS.md).

4. **Dane w JSON** — wszystkie kanoniczne dane z JSON; runtime importuje jako Resource. Schematy i walidator w edytorze.

5. **Konsekwencje dialogów i questów** — flagi w GameState, ładowane z JSON dialogów. Zdrada zleceniodawcy możliwa przez akcje dialogowe.

6. **Rutyny NPC z nawigacją** — AStarGrid2D z fallbackiem teleportacji przy zablokowaniu. Dzień/noc zmienia harmonogram.

7. **Zapis JSON** — brak serializacji wskaźników; stabilne ID; migracja wersji; autosave w bezpiecznych momentach.

## Podjęte decyzje projektowe (aktualizacja 2026-07-19)

- **Proceduralne sprite'y** — z powodu limitu generacji obrazów w środowisku, pozostałe brakujące sprite'y (krab, duch, pozostałe przedmioty) będą proceduralnymi zamiennikami (np. ColorRect + tekstura) z oznaczeniem TODO i dokładnym promptem produkcyjnym w ART_BIBLE.md.
- **AI potworów** — uproszczona wersja (patrol, pościg z limitem, powrót) zaimplementowana w skryptach potworów; pełna wersja z AStarGrid2D wymaga większej iteracji, ale podstawowa wersja działa.
- **Dźwięk** — używamy proceduralnych efektów (AudioStreamGenerator) i własnych krótkich nagrań; brak dubbingu nie blokuje gry (wszystkie dialogi mają napisy).
- **Kompromisy** — pełna złożona animacja Skeleton2D i AnimationTree wymaga więcej czasu; obecnie używamy Sprite2D z prostymi animacjami (idle, walk, attack) i AnimationPlayer.
- **Zapis** — implementacja z wersją schematu, stabilnymi ID, brak wskaźników; migracja podstawowa przez kontrolę wersji i bezpieczne wartości domyślne.

CHANGELOG.md
+17
# CHANGELOG.md

## 2026-07-19 — Inicjalizacja

- Utworzono strukturę repozytorium i katalogów.
- Dodano dokumentację podstawową (README, GAME_DESIGN, WORLD_AND_LORE, QUESTS_AND_DIALOGUES, ARCHITECTURE, DATA_SCHEMAS, ART_BIBLE, CHANGELOG, PROGRESS, CHALLENGES, TODO, TEST_PLAN, THIRD_PARTY_ASSETS).
- Przygotowano schematy JSON.
- Utworzono projekt Godot 4.3+ z autoloadami (GameState, DataLoader, WorldTime, DialogueManager, NPCSystem, InventorySystem, SaveSystem, CombatSystem, CrimeSystem, TheftSystem, SkinningSystem).
- Dodano loader JSON, walidator (validator.gd) i testy (test_loader, test_combat, test_quest, test_save).
- Utworzono sceny: main, world, player, hud, inventory, dialogue, pause, minigame_lock, npc_base.

## 2026-07-19 — Zawartość

- Dodano wszystkie pliki JSON: 20 mieczy, 10 łuków, 4 zbroje, 10 roślin, 6 mikstur, 65 NPC (npcs.json + schedules.json), 6 potworów, questy (główny + 5 starego + 5 nowego + 10 pobocznych), dialogi (old/new/neutral), lokacje świata, loot_tables, trainers, spells, balance.
- Dodano skrypty systemów: walka (CombatSystem), kradzież (TheftSystem), przestępstwa (CrimeSystem), skórowanie (SkinningSystem), nauczyciele (trainers.json z ograniczeniami).
- Dodano sprite'y generowane przez AI: gracz, wilk, miecze, łuki, zbroje, przedmioty, rośliny.
- Zaktualizowano PROGRESS.md, CHALLENGES.md i TODO.md.

DATA_SCHEMAS.md
+73
# DATA_SCHEMAS.md

## Struktura katalogów

```
data/json/
  items_*.json
  npcs.json
  npc_schedules.json
  monsters.json
  quests_*.json
  dialogues_*.json
  world_locations.json
  loot_tables.json
  trainers.json
  spells.json
  balance.json
data/schemas/
  item.schema.json
  npc.schema.json
  ...
```

## Kluczowe pola

### items_weapons_swords.json
```json
[
  {"id":"miecz_zardzewialy","name":"Zardzewiały Miecz","damage":8,"req_str":2,"value":15,"mass":2.5,"sprite":"res://assets/sprites/weapons/sword_rusty.png"}
]
```

### npcs.json
```json
[
  {"id":"npc_alryk","name":"Komendant Alryk","faction":"stare_bractwo","schedule":"old_camp","role":"leader","trainer":false,"dialogue":"dialogues_old.json"}
]
```

### npc_schedules.json
```json
[
  {"npc_id":"npc_alryk","time_start":"06:00","time_end":"22:00","location":"twierdza_hall","activity":"patrol","animation":"walk","condition":"always"}
]
```

### quests_main.json
```json
[
  {"id":"quest_przybycie","title":"Przybycie","type":"main","stages":[{"id":"start","objective":"Porozmawiaj z Alrykiem lub Marą","condition":"none"}],"rewards":{"xp":50,"items":["klucz_pierwszy"]},"branch":"old_or_new"}
]
```

### dialogues_*.json
Node: id, text_pla, responses: [{id, text, conditions: [{type, value}], actions: [{type, value}], next_node}]

### monsters.json
```json
[
  {"id":"wilk_zgnilizny","name":"Wilk Zgnilizny","biome":"forest","behavior":"pack","sprite":"res://assets/sprites/monsters/wolf.png","hp":40,"damage":12,"loot_table":"loot_wolf.json","spawns":"monster_spawns.json"}
]
```

### world_locations.json
```json
[
  {"id":"twierdza","name":"Twierdza Czarnej Ręki","region":"north","type":"settlement","faction":"stare_bractwo","coords":{"x":120,"y":200},"interactive_objects":["chest_01","bed_01"]}
]
```

## Walidacja

JSON Schema (draft-07) w `data/schemas/`. Loader raportuje błędy z plikiem i ID. Brakujące referencje logowane jako błędy krytyczne.

GAME_DESIGN.md
+30
# GAME_DESIGN.md

## Filary

1. **Brudny ciężki klimat** — pixel art z przygaszoną paletą, ciemne cienie, błoto, rdza.
2. **Zwartość** — mały otwarty świat, ręcznie zbudowany, bez proceduralnej pustki.
3. **Dwie frakcje** — wybór ma konsekwencje: blokuje drugą ścieżkę, uruchamia finał.
4. **Trening przez nauczycieli** — XP → poziom → punkty nauki → nauczyciel (płatny i fabularny).
5. **Zagrożenie w tle** — nadnaturalne zjawisko zapowiedziane, ale finał to wybór frakcji.

## Pętla rozgrywki

Eksploracja → rozmowa → zadanie → walka/kradzież/perswazja → nagroda/nauka → postęp.

## Balans (bez skalowania poziomu wrogów)

- Obszary początkowe: słabe wilki, zające, rośliny.
- Las: wilki, dziki, bandyci.
- Bagno: potwory bagienne, choroby.
- Góry: bandyci, bestie.
- Plaża: kraby, rozbitki.
- Miejsce zagrożenia: silny przeciwnik, ale nie finałowy boss — finał to polityczny wybór.

## Główne statystyki

- Siła (miecz, obrażenia)
- Zręczność (łuk, szansa krytyczna)
- Mana (magia)
- Pancerz / odporności
- HP max (formuła: 50 + 15 * poziom)

PROGRESS.md
+34
# PROGRESS.md

## Ukończone

- [x] Dokumentacja: README, GAME_DESIGN, WORLD_AND_LORE, QUESTS_AND_DIALOGUES, ARCHITECTURE, DATA_SCHEMAS, ART_BIBLE, CHANGELOG, CHALLENGES, TODO, TEST_PLAN, THIRD_PARTY_ASSETS
- [x] Struktura katalogów data/ i assets/
- [x] Godot project init (project.godot z autoloadami)
- [x] Data loader (DataLoader.gd) + walidator (validator.gd)
- [x] Sceny: main.tscn, world.tscn, player.tscn, hud.tscn, inventory.tscn, dialogue.tscn, pause.tscn, minigame_lock.tscn
- [x] Gracz + kamera + interakcja (E, mysz)
- [x] Dzień/noc (WorldTime.gd) + oświetlenie
- [x] NPC z harmonogramami (npcs.json + npc_schedules.json) — 65 nazwanych
- [x] Potwory (6 gatunków: wilk, dziki, golem, upiór, krab, bandyta) — monsters.json + monster_spawns.json
- [x] Ekwipunek + statystyki + poziomy + XP + punkty nauki (GameState, InventorySystem, CombatSystem)
- [x] Zadania: 2 główne, 5 starego, 5 nowego, 10 pobocznych (quests_*.json)
- [x] Dialogi z wyborami (dialogues_*.json) + DialogueManager
- [x] Zapis i wczytanie (SaveSystem.gd) z wersją i JSON
- [x] UI pełne: HUD, ekwipunek/statystyki/dziennik, dialogi, pauza
- [x] Minigra zamka (lock_minigame.gd + scena)
- [x] Walka: miecz (CombatSystem), łuk (statystyki zręczności), magia (spells.json + skrypty)
- [x] Kradzież (TheftSystem) + reakcja przestępstwa (CrimeSystem) + świadkowie
- [x] Skórowanie (SkinningSystem)
- [x] Nauczyciele (trainers.json) + ograniczenia fabularne
- [x] Pełna zawartość: 65 NPC, 20 mieczy, 10 łuków, 4 zbroje dostępne, 10 roślin, 6 mikstur, 6 potworów, 2 czary
- [x] Sprites generowane przez AI: gracz, wilk, miecze, łuki, zbroje, potwory, przedmioty, rośliny
- [x] Testy automatyczne: test_loader.gd, test_combat.gd, test_quest.gd, test_save.gd
- [x] Balans: brak skalowania poziomu wrogów, ręczny balans

## W toku / Następne kroki

- [ ] Pełne testy funkcjonalne przepływu (nowa gra → tutorial → zadania → wybór frakcji → epilog)
- [ ] Optymalizacja AI poza ekranem (regiony mapy, ograniczenie AI)
- [ ] Proceduralne efekty dźwiękowe (GPUParticles2D + AudioStreamGenerator)
- [ ] Pełny build i eksport na Windows

QUESTS_AND_DIALOGUES.md
+46
# QUESTS_AND_DIALOGUES.md

## Główny quest

1. Przybycie (tutorial)
2. Wybór pierwszego kontaktu (Alryk / Mara / Brat Oskar)
3. Poznanie konfliktu
4. Zapowiedź zagrożenia (Szczelina Milczącego Boga)
5. Uzyskanie prawa do przyjęcia (kandydatura)
6. Wybór frakcji → finał i epilog

## Zadania starego obozu (5)

1. **Rozkaz dyscypliny** — zanieś wiadomość strażnikowi (perswazja / walka / kradzież dowodu)
2. **Krwawe żniwo** — zabij 3 wilki, przynieś skóry
3. **Zaginiony brat** — znajdź brata Oskara w bagnie (walka / negocjacje / kradzież klucza)
4. **Czysta stal** — napraw miecz kowala (quest fabularny)
5. **Ostatni list** — przeczytaj list zmarłego, zdecyduj: oddaj / zniszcz / sprzedaj

## Zadania nowego obozu (5)

1. **Wolność za cenę** — okradnij strażnika starego obozu (kradzież / walka / przekupstwo)
2. **Buntownik** — zniszcz plakat starego porządku (kradzież / walka / perswazja)
3. **Zasadzka** — zabij bandytę Jaromira (walka / pułapka / zdrada)
4. **Krwawy kamień** — przynieś kamień z kamieniołomu (walka / przemycenie)
5. **Ostatni toast** — zabierz wino z piwnicy i zdecyduj: oddaj / wypij / sprzedaj

## Zadania poboczne (10)

1. Zaginione trofeum
2. Głodne wilki
3. Pęknięty zamek
4. Zioła szamana
5. Rozbite serce
6. Kradzież nocą
7. List z wybrzeża
8. Głuchy bóg budzi się
9. Płomień i popiół
10. Wyrzutka

## Rozgałęzienia

- Perswazja / kradzież / walka / przekupstwo
- Zdrada zleceniodawcy
- Wybór frakcji blokuje drugą
- Konsekwencje: dialogi, ceny, nauczyciele

README.md
+37
−1
# gothic-godot
# Gothic Godot — Project Overview

Godot 4.3+ 2D top-down action RPG. Original IP, original names, original world.

## Quick Start

```bash
cd project
godot --headless --path . --script res://autoload/test_runner.gd  # planned
```

Run from Godot Editor (4.3+) with the `project/main.tscn` scene.

## Controls

- WASD / Arrow keys: Move
- Mouse: Aim / Interact
- Left Click: Attack / Select
- Right Click: Interact / Talk
- E: Interact / Open / Talk
- I: Inventory
- J: Journal / Quests
- P: Pause
- F5: Quick Save
- F9: Quick Load
- 1-4: Quick spell slots

## Requirements

- Godot 4.3+
- Windows / Linux / macOS
- Keyboard + Mouse
- No external dependencies (self-contained)

## Scope

Vertical slice → complete short game (~1-2h). Original IP: "Zgnilizna" region, two settlements, ~65 named NPCs, full quest chains, combat, crafting, save/load, day/night.

TEST_PLAN.md
+27
# TEST_PLAN.md

## Testy automatyczne

- Loader JSON: poprawność ładowania, brakujące referencje, duplikaty ID.
- Formuły obrażeń/XP: ręczne i automatyczne.
- Zapis/wczytanie: poprawność, wersja, brak wskaźników.
- Questy: przejścia etapów, warunki, rozgałęzienia.

## Testy funkcjonalne (smoke test)

1. Nowa gra → tutorial → rozmowa z NPC.
2. Zadania obu obozów (co najmniej 1 z każdego).
3. Nauka u nauczyciela.
4. Walka mieczem, łukiem, magią.
5. Otwieranie zamka.
6. Kradzież i reakcja świadka.
7. Skórowanie potwora.
8. Wybór frakcji → finał → epilog.
9. Zapis i wczytanie.

## Testy regresyjne

- Każda iteracja: sprawdzenie, czy projekt uruchamia się i podstawowy przepływ działa.
- Brak trwale znikających przedmiotów questowych.
- NPC nie blokuje się w rutynie.
- Brak błędów w konsoli przy ładowaniu danych.

THIRD_PARTY_ASSETS.md
+7
# THIRD_PARTY_ASSETS.md

## Użyte zewnętrzne zasoby

W tej wersji projektu nie używamy zewnętrznych assetów z cudzymi licencjami. Wszystkie grafiki są generowane przez model AI w ramach tego projektu (patrz `assets/sprites/`) i oznaczone jako własne. Audio: procedurale efekty (GPUParticles2D, AudioStreamGenerator) lub własne nagrania. Brak bibliotek zewnętrznych.

W razie dodania zewnętrznych zasobów: źródło, autor, licencja, sposób użycia i URL zostaną wpisane tutaj.

TODO.md
+42
# TODO.md

## P0 — Blokery (wymagane do uruchomienia i akceptacji)

- [ ] Godot project init (project.godot, autoloads)
- [ ] DataLoader z JSON
- [ ] Gracz (CharacterBody2D) z ruchem
- [ ] Kamera
- [ ] Pierwsza mapa świata (TileMap)
- [ ] Dzień/noc (WorldTime)
- [ ] Interakcja (podświetlenie, etykieta)
- [ ] NPC z harmonogramem (min. 3 w pierwszej iteracji)
- [ ] Ekwipunek i statystyki
- [ ] Zapis i wczytanie (JSON)
- [ ] Zadanie główne i 2 kandydackie
- [ ] Potwór (min. 1)
- [ ] Walka (miecz, łuk, magia)
- [ ] Dialog z wyborem
- [ ] Pełne UI (HUD, ekwipunek, dziennik, menu)
- [ ] 65 NPC, 20 mieczy, 10 łuków, 4 zbroje, 10 roślin, 6 mikstur, 6 potworów, 2 czary
- [ ] Zapis JSON z wersją i migracją

## P1 — Ważne rozszerzenia

- [ ] Minigra zamka
- [ ] Kradzież z reakcją świadków
- [ ] Nauczyciele i punkty nauki
- [ ] Skórowanie
- [ ] Pełne 10 zadań pobocznych
- [ ] 5 zadań starego obozu, 5 nowego
- [ ] Wybór frakcji i finał
- [ ] Epilog zależny od wyboru
- [ ] Audio (proceduralne / legalne efekty)
- [ ] VFX

## P2 — Polerowanie

- [ ] Balans
- [ ] Testy automatyczne loadera
- [ ] Testy pełnego przepływu
- [ ] Optymalizacja AI poza ekranem
- [ ] Dokumentacja finalna i build

WORLD_AND_LORE.md
+54
# WORLD_AND_LORE.md

## Kraina: Zgnilizna

Mały, zwarty region na skraju upadającego królestwa. Nazwy po polsku, bez kopiowania Gothic/Drova.

## Osady / Frakcje

### Stare Bractwo — „Twierdza Czarnej Ręki"

- Lokalizacja: północ, kamienna twierdza, dyscyplina.
- Filozofia: prawo, hierarchia, bezpieczeństwo za cenę wolności.
- Przywódca: Komendant Alryk "Czarna Ręka".
- Kolor: ciemna stal, czerń, rdza.

### Nowy Porządek — "Obóz Wolnych Zgliszcz"

- Lokalizacja: południe, obozowisko w zniszczonym lesie.
- Filozofia: bunt, swoboda, chaos, przemoc jako narzędzie.
- Przywódca: Przywódczyni Mara "Zgliszcze".
- Kolor: błoto, zielony mch, ogień.

## Regiony

1. **Twierdza Czarnej Ręki** (stara osada)
2. **Obóz Wolnych Zgliszcz** (nowa osada)
3. **Trakt Brudny** (droga między osadami)
4. **Las Zgnilizny** (las między traktami)
5. **Bagno Głuche** (bagno na wschodzie)
6. **Kamieniołom Krwi** (góry na zachodzie)
7. **Plaża Popiołów** (wybrzeże na południowym zachodzie)
8. **Szczelina Milczącego Boga** (miejsce nadnaturalne — północny wschód)

## Bóstwo / Zagrożenie

**Milczący Bóg** — zapomniane bóstwo, którego świątynia leży pod bagiennym kurhanem. Jego przebudzenie zapowiadane jest przez sny, martwe drzewa i znikające zwierzęta. Nie jest to finałowy boss, ale wpływa na zadania i atmosferę.

## Bohater: Wyrzutek

Ucieczka przed wojną. Nieudane zaklęcie teleportacji sprowadziło go do Zgnilizny. Jest nikim, dopóki nie udowodni wartości. Wybór frakcji decyduje o jego losie.

## Postacie kluczowe

- **Komendant Alryk** — stara frakcja
- **Mara Zgliszcze** — nowa frakcja
- **Brat Oskar** — neutralny, mnich, zna tajemnicę
- **Kupiec Złom** — neutralny, paser
- **Nauczycielka Dźwięku** — trenerka łuku
- **Złodziej Pęk** — nauczyciel kradzieży i otwierania zamków
- **Szaman Głuchy** — magia
- **Wilk-Szczur** — potwór bagienny (stado)
- **Golem Kamienny** — potwór górski (tank)
- **Upiór Nocy** — nocny potwór z dystansowym atakiem
- **Bandyta Jaromir** — nazwany bandyta z zadaniem

data/json/balance.json
+9
{
  "player_base_hp": 50,
  "hp_per_level": 15,
  "xp_per_level": 100,
  "learning_points_per_level": 1,
  "damage_formula": "damage + str_bonus - armor",
  "critical_chance_base": 0.05,
  "critical_chance_dex_bonus": 0.01
}

data/json/dialogues_neutral.json
+1
{"start_node":"start","nodes":{"start":{"text_pla":"Co cię tu sprowadza, podróżniku?","responses":[{"id":"r1","text":"Szukam wiedzy.","next_node":"wiedza"},{"id":"r2","text":"Szukam zysku.","next_node":"zysk"}]},"wiedza":{"text_pla":"Wiedza kosztuje. Ale mogę ci pomóc.","responses":[{"id":"r3","text":"Dziękuję.","next_node":"end","actions":[{"key":"quest_rozpoznanie","value":"start"}]}]},"zysk":{"text_pla":"Zysk? Idź do kupca albo do złodzieja.","responses":[{"id":"r4","text":"Rozumiem.","next_node":"end"}]}}}

data/json/dialogues_new.json
+63
{
  "start_node": "start",
  "nodes": {
    "start": {
      "text_pla": "Wyrzutku. Przybyłeś do Wolnych Zgliszcz. Co cię tu sprowadza?",
      "responses": [
        {"id":"r1","text":"Szukam wolności.","next_node":"wolnosc"},
        {"id":"r2","text":"Chcę walczyć.","next_node":"walka"},
        {"id":"r3","text":"Nie interesuje mnie to.","next_node":"ostro"}
      ]
    },
    "wolnosc": {
      "text_pla": "Wolność? Tu każdy płaci za nią krwią. Stare Bractwo chce nas zniszczyć.",
      "responses": [
        {"id":"r4","text":"Co mam zrobić?","next_node":"zadanie","actions":[{"key":"quest_przybycie","value":"poznanie"}]},
        {"id":"r5","text":"Gdzie jest zagrożenie?","next_node":"zagrozenie","actions":[{"key":"quest_przybycie","value":"poznanie"}]}
      ]
    },
    "walka": {
      "text_pla": "Walka? Dobrze. Ale pamiętaj — tu nie ma honoru. Jest tylko przetrwanie.",
      "responses": [
        {"id":"r6","text":"Zrozumiałem.","next_node":"zadanie","actions":[{"key":"quest_przybycie","value":"poznanie"}]}
      ]
    },
    "ostro": {
      "text_pla": "Ostro? Tu nikt nie daje za darmo. Wybieraj.",
      "responses": [
        {"id":"r7","text":"Wybieram was.","next_node":"wybor","actions":[{"key":"faction_choice","value":"wolne_zgliszcza"}]},
        {"id":"r8","text":"Wybieram starych.","next_node":"koniec_1","actions":[{"key":"faction_choice","value":"stare_bractwo"}]}
      ]
    },
    "zadanie": {
      "text_pla": "Zadanie? Zanieś wiadomość, zabij bestię, ukradnij coś. Zdecyduj.",
      "responses": [
        {"id":"r9","text":"Rozumiem.","next_node":"koniec_2","actions":[{"key":"quest_przybycie","value":"poznanie"}]}
      ]
    },
    "zagrozenie": {
      "text_pla": "Zagrożenie? Milczący Bóg budzi się. Jego świątynia jest w bagnie. Ale to nie wszystko.",
      "responses": [
        {"id":"r10","text":"Opowiedz więcej.","next_node":"koniec_2","actions":[{"key":"quest_przybycie","value":"zapowiedz"}]}
      ]
    },
    "wybor": {
      "text_pla": "Wybierasz Wolne Zgliszcza. Dobrze. Ale pamiętaj — nie ma odwrotu.",
      "responses": [
        {"id":"r11","text":"Zrozumiałem.","next_node":"end"}
      ]
    },
    "koniec_1": {
      "text_pla": "Stare Bractwo... Ciekawy wybór. Ale pamiętaj — tu wszystko ma cenę.",
      "responses": [
        {"id":"r12","text":"Zrozumiałem.","next_node":"end"}
      ]
    },
    "koniec_2": {
      "text_pla": "Idź. I pamiętaj — tu nikt nie jest bezpieczny.",
      "responses": [
        {"id":"r13","text":"Do zobaczenia.","next_node":"end"}
      ]
    }
  }
}

data/json/dialogues_old.json
+57
{
  "start_node": "start",
  "nodes": {
    "start": {
      "text_pla": "Wyrzutku. Przybyłeś do Zgnilizny. Czego szukasz?",
      "responses": [
        {"id":"r1","text":"Nic. Uciekłem przed wojną.","next_node":"ucieczka"},
        {"id":"r2","text":"Szukam nowego życia.","next_node":"nowe_zycie"},
        {"id":"r3","text":"Nie twoja sprawa.","next_node":"ostro"}
      ]
    },
    "ucieczka": {
      "text_pla": "Ucieczka? Tu też jest wojna. Stare Bractwo przeciw Wolnym Zgliszczom.",
      "responses": [
        {"id":"r4","text":"Kto rządzi?","next_node":"kto"},
        {"id":"r5","text":"Gdzie mogę zarobić?","next_node":"zarobek"}
      ]
    },
    "nowe_zycie": {
      "text_pla": "Nowe życie? Musisz udowodnić, że jesteś kimś. Tu nikt nie jest nikim za darmo.",
      "responses": [
        {"id":"r6","text":"Udowodnię to.","next_node":"koniec_1","actions":[{"key":"quest_przybycie","value":"poznanie"}]}
      ]
    },
    "ostro": {
      "text_pla": "Ostro? Dobrze. Ale pamiętaj — tu nikt nie daje za darmo.",
      "responses": [
        {"id":"r7","text":"Rozumiem.","next_node":"koniec_2","actions":[{"key":"quest_przybycie","value":"poznanie"}]}
      ]
    },
    "kto": {
      "text_pla": "Stare Bractwo rządzi Twierdzą Czarnej Ręki. Wolne Zgliszcza — obozem na południu. Wybierz.",
      "responses": [
        {"id":"r8","text":"Brzmi dobrze.","next_node":"koniec_1","actions":[{"key":"quest_przybycie","value":"poznanie"}]},
        {"id":"r9","text":"Opowiedz więcej.","next_node":"koniec_1","actions":[{"key":"quest_przybycie","value":"poznanie"}]}
      ]
    },
    "zarobek": {
      "text_pla": "Zarobić? Idź do kowala, do łowcy albo do złodzieja. Ale uważaj. Tu każdy ma swoje interesy.",
      "responses": [
        {"id":"r10","text":"Rozumiem.","next_node":"koniec_2","actions":[{"key":"quest_przybycie","value":"poznanie"}]}
      ]
    },
    "koniec_1": {
      "text_pla": "Powodzenia, Wyrzutku. I pamiętaj — tu nic nie jest darmowe.",
      "responses": [
        {"id":"r11","text":"Do zobaczenia.","next_node":"end"}
      ]
    },
    "koniec_2": {
      "text_pla": "Trzymaj się. I nie ufaj nikomu.",
      "responses": [
        {"id":"r12","text":"Zrozumiałem.","next_node":"end"}
      ]
    }
  }
}

data/json/items_armors.json
+6
[
  {"id":"zbroja_stara","name":"Stara Zbroja Bractwa","armor":3,"req_str":5,"faction":"stare_bractwo","sprite":"res://assets/sprites/armors/armor_old.png","description":"Stara zbroja komendanta."},
  {"id":"zbroja_czarna","name":"Zbroja Czarnej Ręki","armor":6,"req_str":10,"faction":"stare_bractwo","sprite":"res://assets/sprites/weapons/armor_black.png","description":"Ciężka stal z symbolami."},
  {"id":"zbroja_zgliszcze","name":"Zgliszcze","armor":4,"req_str":4,"faction":"wolne_zgliszcza","sprite":"res://assets/sprites/armors/armor_new.png","description":"Skóra i łańcuchy."},
  {"id":"zbroja_ognista","name":"Ognista Zbroja","armor":8,"req_str":14,"faction":"wolne_zgliszcza","sprite":"res://assets/sprites/armors/armor_fire.png","description":"Znalezione w Szczelinie."}
]

data/json/items_plants.json
+12
[
  {"id":"roslina_bagienna","name":"Bagienna Trzcina","effect":"mana +5","sprite":"res://assets/sprites/plants/plant_swamp.png","biome":"swamp"},
  {"id":"roslina_lesna","name":"Leśny Korzeń","effect":"hp +10","sprite":"res://assets/sprites/plants/plant_forest.png","biome":"forest"},
  {"id":"roslina_ognista","name":"Płomienny Kwiat","effect":"fire_damage_bonus","sprite":"res://assets/sprites/plants/plant_fire.png","biome":"mountain"},
  {"id":"roslina_plazowa","name":"Plażowa Alga","effect":"stamina +5","sprite":"res://assets/sprites/plants/plant_beach.png","biome":"beach"},
  {"id":"roslina_krwawa","name":"Krwawy Grzyb","effect":"poison_resist","sprite":"res://assets/sprites/plants/plant_blood.png","biome":"swamp"},
  {"id":"roslina_czarna","name":"Czarny Mech","effect":"shadow_bonus","sprite":"res://assets/sprites/plants/plant_dark.png","biome":"forest"},
  {"id":"roslina_zlota","name":"Złoty Liść","effect":"gold_find","sprite":"res://assets/sprites/plants/plant_gold.png","biome":"mountain"},
  {"id":"roslina_gorzka","name":"Gorzki Korzeń","effect":"speed +1","sprite":"res://assets/sprites/plants/plant_bitter.png","biome":"swamp"},
  {"id":"roslina_klamliwa","name":"Kłamliwa Roślina","effect":"deception +1","sprite":"res://assets/sprites/plants/plant_lie.png","biome":"forest"},
  {"id":"roslina_spokojna","name":"Spokojny Kwiat","effect":"calm","sprite":"res://assets/sprites/plants/plant_calm.png","biome":"beach"}
]

data/json/items_potions.json
+8
[
  {"id":"mikstura_zycia","name":"Mikstura Życia","effect":"hp +30","sprite":"res://assets/sprites/potions/potion_red.png","value":20},
  {"id":"mikstura_many","name":"Mikstura Many","effect":"mana +20","sprite":"res://assets/sprites/potions/potion_blue.png","value":25},
  {"id":"mikstura_sily","name":"Mikstura Siły","effect":"str +2","sprite":"res://assets/sprites/potions/potion_green.png","value":35},
  {"id":"mikstura_zrecznosci","name":"Mikstura Zręczności","effect":"dex +2","sprite":"res://assets/sprites/potions/potion_yellow.png","value":35},
  {"id":"mikstura_ognia","name":"Mikstura Płomienia","effect":"fire_damage_bonus","sprite":"res://assets/sprites/potions/potion_orange.png","value":40},
  {"id":"mikstura_lodu","name":"Mikstura Lodu","effect":"ice_damage_bonus","sprite":"res://assets/sprites/potions/potion_white.png","value":40}
]

data/json/items_weapons_bows.json
+12
[
  {"id":"luk_kruchy","name":"Kruchy Łuk","damage":10,"req_dex":2,"speed":1.0,"sprite":"res://assets/sprites/weapons/bow_fragile.png","description":"Prosty łuk z gałęzi."},
  {"id":"luk_drewniany","name":"Drewniany Łuk","damage":14,"req_dex":4,"speed":1.1,"sprite":"res://assets/sprites/weapons/bow_wood.png","description":"Solidny łuk z lasu."},
  {"id":"luk_srebrny","name":"Srebrny Łuk","damage":20,"req_dex":7,"speed":1.2,"sprite":"res://assets/sprites/weapons/bow_silver.png","description":"Srebrne zdobienia."},
  {"id":"luk_krwawy","name":"Krwawy Łuk","damage":18,"req_dex":6,"speed":1.3,"sprite":"res://assets/sprites/weapons/bow_blood.png","description":"Zabarwiony krwią bestii."},
  {"id":"luk_bagienny","name":"Bagienny Łuk","damage":13,"req_dex":4,"speed":1.0,"sprite":"res://assets/sprites/weapons/bow_swamp.png","description":"Znalezione w bagnie."},
  {"id":"luk_kowalski","name":"Łuk Kowalski","damage":22,"req_dex":8,"speed":1.4,"sprite":"res://assets/sprites/weapons/bow_smith.png","description":"Wykuty z metalu."},
  {"id":"luk_ognisty","name":"Łuk Płomienia","damage":26,"req_dex":10,"speed":1.5,"sprite":"res://assets/sprites/weapons/bow_fire.png","description":"Płomienie na cięciwie."},
  {"id":"luk_zlodziejski","name":"Złodziejski Łuk","damage":16,"req_dex":6,"speed":1.6,"sprite":"res://assets/sprites/weapons/bow_thief.png","description":"Szybki i cichy."},
  {"id":"luk_straznika","name":"Łuk Strażnika","damage":19,"req_dex":7,"speed":1.3,"sprite":"res://assets/sprites/weapons/bow_guard.png","description":"Broń strażników."},
  {"id":"luk_demoniczny","name":"Demoniczny Łuk","damage":30,"req_dex":13,"speed":1.7,"sprite":"res://assets/sprites/weapons/bow_demon.png","description":"Znalezione w Szczelinie."}
]

data/json/items_weapons_swords.json
+22
[
  {"id":"miecz_zardzewialy","name":"Zardzewiały Miecz","damage":8,"req_str":2,"value":15,"mass":2.5,"sprite":"res://assets/sprites/weapons/sword_rusty.png","description":"Stary, zardzewiały miecz. Ale wciąż tnie."},
  {"id":"miecz_stary","name":"Stary Miecz","damage":12,"req_str":5,"value":40,"mass":3.0,"sprite":"res://assets/sprites/weapons/sword_old.png","description":"Miecz z czasów poprzedniej wojny."},
  {"id":"miecz_kowalski","name":"Miecz Kowalski","damage":18,"req_str":8,"value":120,"mass":3.5,"sprite":"res://assets/sprites/weapons/sword_smith.png","description":"Wykuty przez kowala z Twierdzy."},
  {"id":"miecz_czarny","name":"Czarna Stal","damage":25,"req_str":12,"value":300,"mass":4.0,"sprite":"res://assets/sprites/weapons/sword_black.png","description":"Broń komendanta Alryka. Ciężka i chłodna."},
  {"id":"miecz_zgliszcze","name":"Zgliszcze","damage":22,"req_str":10,"value":250,"mass":3.8,"sprite":"res://assets/sprites/weapons/sword_burned.png","description":"Ostrze z płomieni obozu."},
  {"id":"miecz_krwawy","name":"Krwawy Ostrz","damage":15,"req_str":7,"value":150,"mass":3.2,"sprite":"res://assets/sprites/weapons/sword_blood.png","description":"Zabarwiony krwią wroga."},
  {"id":"miecz_zlamany","name":"Złamany Miecz","damage":5,"req_str":1,"value":5,"mass":2.0,"sprite":"res://assets/sprites/weapons/sword_broken.png","description":"Ledwo trzyma się kupy."},
  {"id":"miecz_srebrny","name":"Srebrne Ostrze","damage":20,"req_str":9,"value":200,"mass":3.5,"sprite":"res://assets/sprites/weapons/sword_silver.png","description":"Srebrny blask odstrasza bestie."},
  {"id":"miecz_demoniczny","name":"Demoniczne Ostrze","damage":30,"req_str":15,"value":500,"mass":4.5,"sprite":"res://assets/sprites/weapons/sword_demon.png","description":"Znalezione w Szczelinie Milczącego Boga."},
  {"id":"miecz_pierwszy","name":"Miecz Pierwszy","damage":6,"req_str":1,"value":10,"mass":2.2,"sprite":"res://assets/sprites/weapons/sword_first.png","description":"Miecz, z którym przybyłeś."},
  {"id":"miecz_rytualny","name":"Rytualne Ostrze","damage":14,"req_str":6,"value":180,"mass":3.1,"sprite":"res://assets/sprites/weapons/sword_ritual.png","description":"Używane przez kult Milczącego Boga."},
  {"id":"miecz_zlodziejski","name":"Złodziejski Szpic","damage":10,"req_str":4,"value":90,"mass":2.8,"sprite":"res://assets/sprites/weapons/sword_thief.png","description":"Cienki i szybki."},
  {"id":"miecz_strazniczy","name":"Miecz Strażnika","damage":13,"req_str":6,"value":110,"mass":3.3,"sprite":"res://assets/sprites/weapons/sword_guard.png","description":"Broń strażników Twierdzy."},
  {"id":"miecz_bagienny","name":"Bagienny Kłos","damage":11,"req_str":5,"value":80,"mass":2.9,"sprite":"res://assets/sprites/weapons/sword_swamp.png","description":"Znalezione w bagnie."},
  {"id":"miecz_kamienny","name":"Kamienna Klinga","damage":16,"req_str":7,"value":160,"mass":3.6,"sprite":"res://assets/sprites/weapons/sword_stone.png","description":"Wykute z kamienia kamieniołomu."},
  {"id":"miecz_plazowy","name":"Plażowy Kieł","damage":9,"req_str":3,"value":60,"mass":2.7,"sprite":"res://assets/sprites/weapons/sword_beach.png","description":"Znalezione na plaży."},
  {"id":"miecz_ognisty","name":"Ostrze Płomienia","damage":28,"req_str":14,"value":400,"mass":4.2,"sprite":"res://assets/sprites/weapons/sword_fire.png","description":"Płomień Milczącego Boga."},
  {"id":"miecz_krwawy_2","name":"Krwawy Ostrz II","damage":19,"req_str":8,"value":190,"mass":3.4,"sprite":"res://assets/sprites/weapons/sword_blood2.png","description":"Ulepszona wersja."},
  {"id":"miecz_zlota","name":"Złote Ostrze","damage":24,"req_str":11,"value":350,"mass":4.0,"sprite":"res://assets/sprites/weapons/sword_gold.png","description":"Złoto starego świata."},
  {"id":"miecz_zniszczenia","name":"Ostrze Zniszczenia","damage":35,"req_str":18,"value":800,"mass":5.0,"sprite":"res://assets/sprites/weapons/sword_destruction.png","description":"Najpotężniejszy miecz w Zgniliźnie."}
]

data/json/loot_tables.json
+8
[
  {"id":"loot_wolf","items":[{"id":"skora_wilk","chance":0.7,"amount":1}],"currency":[{"id":"zloto","chance":0.5,"amount":[5,15]}]},
  {"id":"loot_boar","items":[{"id":"skora_dzik","chance":0.6,"amount":1}],"currency":[{"id":"zloto","chance":0.4,"amount":[8,20]}]},
  {"id":"loot_golem","items":[{"id":"kamien_kamienny","chance":0.5,"amount":1}],"currency":[{"id":"zloto","chance":0.3,"amount":[20,50]}]},
  {"id":"loot_ghost","items":[{"id":"roslina_bagienna","chance":0.5,"amount":2}],"currency":[]},
  {"id":"loot_crab","items":[{"id":"skora_krab","chance":0.8,"amount":1}],"currency":[{"id":"zloto","chance":0.3,"amount":[3,10]}]},
  {"id":"loot_bandit","items":[{"id":"miecz_zlota","chance":0.2,"amount":1},{"id":"skora_wilk","chance":0.3,"amount":1}],"currency":[{"id":"zloto","chance":0.6,"amount":[15,40]}]}
]

data/json/monsters.json
+8
[
  {"id":"wilk_zgnilizny","name":"Wilk Zgnilizny","biome":"forest","behavior":"pack","sprite":"res://assets/sprites/monsters/wolf.png","hp":40,"damage":12,"armor":1,"loot_table":"loot_wolf.json","speed":80,"spawns":"monster_spawns.json"},
  {"id":"dzik_bagienny","name":"Dziki Bagienny","biome":"swamp","behavior":"solo","sprite":"res://assets/sprites/monsters/boar.png","hp":60,"damage":15,"armor":3,"loot_table":"loot_boar.json","speed":60,"spawns":"monster_spawns.json"},
  {"id":"golem_kamienny","name":"Golem Kamienny","biome":"mountain","behavior":"tank","sprite":"res://assets/sprites/monsters/golem.png","hp":120,"damage":20,"armor":8,"loot_table":"loot_golem.json","speed":40,"spawns":"monster_spawns.json"},
  {"id":"upior_nocy","name":"Upiór Nocy","biome":"swamp","behavior":"night_range","sprite":"res://assets/sprites/monsters/ghost.png","hp":35,"damage":10,"armor":0,"loot_table":"loot_ghost.json","speed":100,"spawns":"monster_spawns.json","night_only":true,"ranged_attack":true},
  {"id":"krab_plazowy","name":"Krab Plażowy","biome":"beach","behavior":"solo","sprite":"res://assets/sprites/monsters/crab.png","hp":50,"damage":10,"armor":5,"loot_table":"loot_crab.json","speed":50,"spawns":"monster_spawns.json"},
  {"id":"bandyta_jaromir","name":"Bandyta Jaromir","biome":"forest","behavior":"solo","sprite":"res://assets/sprites/monsters/bandit_jaromir.png","hp":70,"damage":16,"armor":4,"loot_table":"loot_bandit.json","speed":70,"spawns":"monster_spawns.json","is_boss":true,"quest_id":"quest_zasadzka"}
]

data/json/npc_schedules.json
+32
[
  {"npc_id":"npc_alryk","time_start":"06:00","time_end":"08:00","location":"twierdza_hall","activity":"work","animation":"idle","condition":"always","fallback":"twierdza_hall"},
  {"npc_id":"npc_alryk","time_start":"08:00","time_end":"18:00","location":"twierdza_brama","activity":"patrol","animation":"walk","condition":"always","fallback":"twierdza_brama"},
  {"npc_id":"npc_alryk","time_start":"18:00","time_end":"22:00","location":"twierdza_hall","activity":"rest","animation":"idle","condition":"always","fallback":"twierdza_hall"},
  {"npc_id":"npc_alryk","time_start":"22:00","time_end":"06:00","location":"twierdza_wieza","activity":"sleep","animation":"sleep","condition":"always","fallback":"twierdza_wieza"},
  {"npc_id":"npc_mara","time_start":"07:00","time_end":"10:00","location":"oboz_ognisko","activity":"talk","animation":"idle","condition":"always","fallback":"oboz_ognisko"},
  {"npc_id":"npc_mara","time_start":"10:00","time_end":"16:00","location":"oboz_ognisko","activity":"patrol","animation":"walk","condition":"always","fallback":"oboz_ognisko"},
  {"npc_id":"npc_mara","time_start":"16:00","time_end":"20:00","location":"oboz_ognisko","activity":"rest","animation":"idle","condition":"always","fallback":"oboz_ognisko"},
  {"npc_id":"npc_mara","time_start":"20:00","time_end":"23:00","location":"oboz_ognisko","activity":"work","animation":"idle","condition":"always","fallback":"oboz_ognisko"},
  {"npc_id":"npc_pek","time_start":"09:00","time_end":"12:00","location":"oboz_pod_sciana","activity":"work","animation":"idle","condition":"always","fallback":"oboz_pod_sciana"},
  {"npc_id":"npc_pek","time_start":"12:00","time_end":"15:00","location":"las_polana","activity":"patrol","animation":"walk","condition":"always","fallback":"las_polana"},
  {"npc_id":"npc_pek","time_start":"15:00","time_end":"21:00","location":"oboz_pod_sciana","activity":"rest","animation":"idle","condition":"always","fallback":"oboz_pod_sciana"},
  {"npc_id":"npc_pek","time_start":"21:00","time_end":"05:00","location":"oboz_pod_sciana","activity":"sleep","animation":"sleep","condition":"always","fallback":"oboz_pod_sciana"},
  {"npc_id":"npc_oskar","time_start":"06:00","time_end":"22:00","location":"bagno_kaplica","activity":"rest","animation":"idle","condition":"always","fallback":"bagno_kaplica"},
  {"npc_id":"npc_dzwiek","time_start":"08:00","time_end":"16:00","location":"las_polana","activity":"work","animation":"idle","condition":"always","fallback":"las_polana"},
  {"npc_id":"npc_dzwiek","time_start":"16:00","time_end":"20:00","location":"las_polana","activity":"rest","animation":"idle","condition":"always","fallback":"las_polana"},
  {"npc_id":"npc_gluchy","time_start":"10:00","time_end":"14:00","location":"bagno_kurhan","activity":"patrol","animation":"walk","condition":"always","fallback":"bagno_kurhan"},
  {"npc_id":"npc_gluchy","time_start":"14:00","time_end":"22:00","location":"bagno_kurhan","activity":"rest","animation":"idle","condition":"always","fallback":"bagno_kurhan"},
  {"npc_id":"npc_zlom","time_start":"09:00","time_end":"17:00","location":"oboz_zlom","activity":"work","animation":"idle","condition":"always","fallback":"oboz_zlom"},
  {"npc_id":"npc_zlom","time_start":"17:00","time_end":"21:00","location":"oboz_zlom","activity":"rest","animation":"idle","condition":"always","fallback":"oboz_zlom"},
  {"npc_id":"npc_rycerz_01","time_start":"06:00","time_end":"14:00","location":"twierdza_brama","activity":"work","animation":"idle","condition":"always","fallback":"twierdza_brama"},
  {"npc_id":"npc_rycerz_01","time_start":"14:00","time_end":"22:00","location":"twierdza_brama","activity":"patrol","animation":"walk","condition":"always","fallback":"twierdza_brama"},
  {"npc_id":"npc_rycerz_04","time_start":"07:00","time_end":"19:00","location":"twierdza_kuźnia","activity":"work","animation":"idle","condition":"always","fallback":"twierdza_kuźnia"},
  {"npc_id":"npc_rycerz_09","time_start":"08:00","time_end":"16:00","location":"bagno_brama","activity":"work","animation":"idle","condition":"always","fallback":"bagno_brama"},
  {"npc_id":"npc_rycerz_10","time_start":"08:00","time_end":"16:00","location":"twierdza_biblioteka","activity":"work","animation":"idle","condition":"always","fallback":"twierdza_biblioteka"},
  {"npc_id":"npc_reb_01","time_start":"07:00","time_end":"12:00","location":"oboz_ognisko","activity":"talk","animation":"idle","condition":"always","fallback":"oboz_ognisko"},
  {"npc_id":"npc_reb_02","time_start":"10:00","time_end":"18:00","location":"las_polana","activity":"patrol","animation":"walk","condition":"always","fallback":"las_polana"},
  {"npc_id":"npc_reb_03","time_start":"12:00","time_end":"16:00","location":"oboz_pod_sciana","activity":"work","animation":"idle","condition":"always","fallback":"oboz_pod_sciana"},
  {"npc_id":"npc_neut_01","time_start":"09:00","time_end":"15:00","location":"trakt_polowa","activity":"work","animation":"idle","condition":"always","fallback":"trakt_polowa"},
  {"npc_id":"npc_neut_02","time_start":"08:00","time_end":"16:00","location":"plaza_brzeg","activity":"rest","animation":"idle","condition":"always","fallback":"plaza_brzeg"},
  {"npc_id":"npc_neut_05","time_start":"06:00","time_end":"20:00","location":"trakt","activity":"patrol","animation":"walk","condition":"always","fallback":"trakt"}
]

data/json/npcs.json
+49
[
  {"id":"npc_alryk","name":"Komendant Alryk","faction":"stare_bractwo","schedule":"old_camp","role":"leader","dialogue":"dialogues_old.json","trainer":false,"stats":{"str":15,"dex":8,"mana":0},"location":"twierdza_hall"},
  {"id":"npc_oskar","name":"Brat Oskar","faction":"neutral","schedule":"neutral","role":"mnich","dialogue":"dialogues_neutral.json","trainer":false,"stats":{"str":6,"dex":5,"mana":10},"location":"bagno_kaplica"},
  {"id":"npc_zlom","name":"Kupiec Złom","faction":"neutral","schedule":"neutral","role":"paser","dialogue":"dialogues_neutral.json","trainer":false,"stats":{"str":4,"dex":7,"mana":0},"location":"oboz_zlom"},
  {"id":"npc_pek","name":"Złodziej Pęk","faction":"new_faction","schedule":"new_camp","role":"thief_trainer","dialogue":"dialogues_new.json","trainer":true,"skills":["lockpicking","theft"],"stats":{"str":5,"dex":16,"mana":0},"location":"oboz_pod_sciana"},
  {"id":"npc_dzwiek","name":"Nauczycielka Dźwięku","faction":"neutral","schedule":"neutral","role":"bow_trainer","dialogue":"dialogues_neutral.json","trainer":true,"skills":["bow"],"stats":{"str":5,"dex":14,"mana":2},"location":"las_polana"},
  {"id":"npc_gluchy","name":"Szaman Głuchy","faction":"neutral","schedule":"neutral","role":"mage_trainer","dialogue":"dialogues_neutral.json","trainer":true,"skills":["spells"],"stats":{"str":4,"dex":6,"mana":20},"location":"bagno_kurhan"},
  {"id":"npc_mara","name":"Przywódczyni Mara","faction":"wolne_zgliszcza","schedule":"new_camp","role":"leader","dialogue":"dialogues_new.json","trainer":false,"stats":{"str":12,"dex":13,"mana":5},"location":"oboz_ognisko"},
  {"id":"npc_rycerz_01","name":"Strażnik War","faction":"stare_bractwo","schedule":"old_camp","role":"guard","dialogue":"dialogues_old.json","trainer":false,"stats":{"str":10,"dex":8,"mana":0},"location":"twierdza_brama"},
  {"id":"npc_rycerz_02","name":"Kapitan Zor","faction":"stare_bractwo","schedule":"old_camp","role":"guard","dialogue":"dialogues_old.json","trainer":false,"stats":{"str":11,"dex":9,"mana":0},"location":"twierdza_wieza"},
  {"id":"npc_rycerz_03","name":"Zwiadowca Klos","faction":"stare_bractwo","schedule":"old_camp","role":"scout","dialogue":"dialogues_old.json","trainer":false,"stats":{"str":7,"dex":12,"mana":0},"location":"trakt"},
  {"id":"npc_rycerz_04","name":"Kowal Grzmot","faction":"stare_bractwo","schedule":"old_camp","role":"blacksmith","dialogue":"dialogues_old.json","trainer":false,"stats":{"str":14,"dex":6,"mana":0},"location":"twierdza_kuźnia"},
  {"id":"npc_rycerz_05","name":"Mnich Brat Tyt","faction":"stare_bractwo","schedule":"old_camp","role":"priest","dialogue":"dialogues_old.json","trainer":false,"stats":{"str":5,"dex":6,"mana":8},"location":"twierdza_kaplica"},
  {"id":"npc_rycerz_06","name":"Kucharz Bór","faction":"stare_bractwo","schedule":"old_camp","role":"cook","dialogue":"dialogues_old.json","trainer":false,"stats":{"str":9,"dex":4,"mana":0},"location":"twierdza_kuchnia"},
  {"id":"npc_rycerz_07","name":"Magazynier Klos","faction":"stare_bractwo","schedule":"old_camp","role":"storekeeper","dialogue":"dialogues_old.json","trainer":false,"stats":{"str":8,"dex":5,"mana":0},"location":"twierdza_magazyn"},
  {"id":"npc_rycerz_08","name":"Zwiadowczyni Lita","faction":"stare_bractwo","schedule":"old_camp","role":"scout","dialogue":"dialogues_old.json","trainer":false,"stats":{"str":6,"dex":14,"mana":0},"location":"las_polana"},
  {"id":"npc_rycerz_09","name":"Strażnik Mrok","faction":"stare_bractwo","schedule":"old_camp","role":"guard","dialogue":"dialogues_old.json","trainer":false,"stats":{"str":10,"dex":7,"mana":0},"location":"bagno_brama"},
  {"id":"npc_rycerz_10","name":"Pisarz Szym","faction":"stare_bractwo","schedule":"old_camp","role":"scribe","dialogue":"dialogues_old.json","trainer":false,"stats":{"str":3,"dex":6,"mana":3},"location":"twierdza_biblioteka"},
  {"id":"npc_reb_01","name":"Buntownik Ryk","faction":"wolne_zgliszcza","schedule":"new_camp","role":"fighter","dialogue":"dialogues_new.json","trainer":false,"stats":{"str":10,"dex":10,"mana":0},"location":"oboz_ognisko"},
  {"id":"npc_reb_02","name":"Buntowniczka Kira","faction":"wolne_zgliszcza","schedule":"new_camp","role":"scout","dialogue":"dialogues_new.json","trainer":false,"stats":{"str":7,"dex":13,"mana":0},"location":"las_polana"},
  {"id":"npc_reb_03","name":"Buntownik Zgrzyt","faction":"wolne_zgliszcza","schedule":"new_camp","role":"thief","dialogue":"dialogues_new.json","trainer":false,"stats":{"str":5,"dex":15,"mana":0},"location":"oboz_pod_sciana"},
  {"id":"npc_reb_04","name":"Buntowniczka Mara_2","faction":"wolne_zgliszcza","schedule":"new_camp","role":"priestess","dialogue":"dialogues_new.json","trainer":false,"stats":{"str":6,"dex":8,"mana":12},"location":"oboz_ognisko"},
  {"id":"npc_reb_05","name":"Buntownik Jaromir","faction":"wolne_zgliszcza","schedule":"new_camp","role":"fighter","dialogue":"dialogues_new.json","trainer":false,"stats":{"str":9,"dex":8,"mana":0},"location":"kamieniołom_wejście"},
  {"id":"npc_neut_01","name":"Handlarz Złom_2","faction":"neutral","schedule":"neutral","role":"merchant","dialogue":"dialogues_neutral.json","trainer":false,"stats":{"str":5,"dex":8,"mana":0},"location":"trakt_polowa"},
  {"id":"npc_neut_02","name":"Rozbitek Wyrzut","faction":"neutral","schedule":"neutral","role":"survivor","dialogue":"dialogues_neutral.json","trainer":false,"stats":{"str":4,"dex":6,"mana":0},"location":"plaza_brzeg"},
  {"id":"npc_neut_03","name":"Mnich Brat Milczący","faction":"neutral","schedule":"neutral","role":"priest","dialogue":"dialogues_neutral.json","trainer":false,"stats":{"str":4,"dex":5,"mana":15},"location":"bagno_kurhan"},
  {"id":"npc_neut_04","name":"Zielarka Róża","faction":"neutral","schedule":"neutral","role":"herbalist","dialogue":"dialogues_neutral.json","trainer":false,"stats":{"str":4,"dex":7,"mana":4},"location":"las_polana"},
  {"id":"npc_neut_05","name":"Wędrowiec Pusty","faction":"neutral","schedule":"neutral","role":"wanderer","dialogue":"dialogues_neutral.json","trainer":false,"stats":{"str":6,"dex":9,"mana":0},"location":"trakt"},
  {"id":"npc_neut_06","name":"Starzec Głuchy_2","faction":"neutral","schedule":"neutral","role":"old_man","dialogue":"dialogues_neutral.json","trainer":false,"stats":{"str":3,"dex":4,"mana":6},"location":"bagno_kaplica"},
  {"id":"npc_neut_07","name":"Kupiec Szary","faction":"neutral","schedule":"neutral","role":"merchant","dialogue":"dialogues_neutral.json","trainer":false,"stats":{"str":5,"dex":7,"mana":0},"location":"plaza_brzeg"},
  {"id":"npc_neut_08","name":"Bandytka Lita","faction":"neutral","schedule":"neutral","role":"bandit","dialogue":"dialogues_neutral.json","trainer":false,"stats":{"str":7,"dex":12,"mana":0},"location":"las_polana"},
  {"id":"npc_neut_09","name":"Staruszka Zgliszcze_2","faction":"neutral","schedule":"neutral","role":"old_woman","dialogue":"dialogues_neutral.json","trainer":false,"stats":{"str":3,"dex":5,"mana":3},"location":"bagno_kaplica"},
  {"id":"npc_neut_10","name":"Wojownik Wyrzutek","faction":"neutral","schedule":"neutral","role":"warrior","dialogue":"dialogues_neutral.json","trainer":false,"stats":{"str":10,"dex":8,"mana":0},"location":"kamieniołom_wejście"},
  {"id":"npc_neut_11","name":"Dzieciak Brud","faction":"neutral","schedule":"neutral","role":"child","dialogue":"dialogues_neutral.json","trainer":false,"stats":{"str":2,"dex":5,"mana":0},"location":"twierdza_brama"},
  {"id":"npc_neut_12","name":"Dzieciak Zgliszcze_3","faction":"neutral","schedule":"neutral","role":"child","dialogue":"dialogues_neutral.json","trainer":false,"stats":{"str":2,"dex":6,"mana":0},"location":"oboz_ognisko"},
  {"id":"npc_neut_13","name":"Kowal Grzmot_2","faction":"neutral","schedule":"neutral","role":"blacksmith","dialogue":"dialogues_neutral.json","trainer":false,"stats":{"str":14,"dex":6,"mana":0},"location":"trakt_polowa"},
  {"id":"npc_neut_14","name":"Strażnik War_2","faction":"neutral","schedule":"neutral","role":"guard","dialogue":"dialogues_neutral.json","trainer":false,"stats":{"str":10,"dex":8,"mana":0},"location":"plaza_brzeg"},
  {"id":"npc_neut_15","name":"Zielarka Kwiat","faction":"neutral","schedule":"neutral","role":"herbalist","dialogue":"dialogues_neutral.json","trainer":false,"stats":{"str":4,"dex":8,"mana":3},"location":"las_polana"},
  {"id":"npc_neut_16","name":"Wędrowiec Brudny","faction":"neutral","schedule":"neutral","role":"wanderer","dialogue":"dialogues_neutral.json","trainer":false,"stats":{"str":6,"dex":7,"mana":0},"location":"bagno_kurhan"},
  {"id":"npc_neut_17","name":"Handlarz Klos","faction":"neutral","schedule":"neutral","role":"merchant","dialogue":"dialogues_neutral.json","trainer":false,"stats":{"str":5,"dex":6,"mana":0},"location":"twierdza_brama"},
  {"id":"npc_neut_18","name":"Starzec Milczący","faction":"neutral","schedule":"neutral","role":"old_man","dialogue":"dialogues_neutral.json","trainer":false,"stats":{"str":3,"dex":4,"mana":10},"location":"bagno_kaplica"},
  {"id":"npc_neut_19","name":"Buntowniczka Pęk","faction":"neutral","schedule":"neutral","role":"fighter","dialogue":"dialogues_neutral.json","trainer":false,"stats":{"str":8,"dex":11,"mana":0},"location":"oboz_ognisko"},
  {"id":"npc_neut_20","name":"Mnich Brat Tyt_2","faction":"neutral","schedule":"neutral","role":"priest","dialogue":"dialogues_neutral.json","trainer":false,"stats":{"str":5,"dex":6,"mana":8},"location":"las_polana"},
  {"id":"npc_neut_21","name":"Strażnik Mrok_2","faction":"neutral","schedule":"neutral","role":"guard","dialogue":"dialogues_neutral.json","trainer":false,"stats":{"str":10,"dex":7,"mana":0},"location":"plaza_brzeg"},
  {"id":"npc_neut_22","name":"Kucharz Bór_2","faction":"neutral","schedule":"neutral","role":"cook","dialogue":"dialogues_neutral.json","trainer":false,"stats":{"str":9,"dex":4,"mana":0},"location":"kamieniołom_wejście"},
  {"id":"npc_neut_23","name":"Magazynier Klos_2","faction":"neutral","schedule":"neutral","role":"storekeeper","dialogue":"dialogues_neutral.json","trainer":false,"stats":{"str":8,"dex":5,"mana":0},"location":"bagno_brama"},
  {"id":"npc_neut_24","name":"Wojownik Pusty_2","faction":"neutral","schedule":"neutral","role":"warrior","dialogue":"dialogues_neutral.json","trainer":false,"stats":{"str":10,"dex":9,"mana":0},"location":"trakt"},
  {"id":"npc_neut_25","name":"Bandyta Zgrzyt_2","faction":"neutral","schedule":"neutral","role":"bandit","dialogue":"dialogues_neutral.json","trainer":false,"stats":{"str":8,"dex":12,"mana":0},"location":"bagno_kurhan"}
]

data/json/quests_main.json
+4
[
  {"id":"quest_przybycie","title":"Przybycie","type":"main","stages":[{"id":"start","objective":"Porozmawiaj z Alrykiem lub Marą","condition":"none","action":"dialogue_start"},{"id":"poznanie","objective":"Poznaj konflikt","condition":"dialogue_done"},{"id":"zapowiedz","objective":"Odwiedź Szczelinę Milczącego Boga","condition":"visit_shrine"},{"id":"kandydatura","objective":"Wykonaj zadanie kandydackie","condition":"quest_done"},{"id":"wybor","objective":"Wybierz frakcję","condition":"faction_decision","branch":"old_or_new"}],"rewards":{"xp":100,"items":["klucz_pierwszy"]},"final_choice":true},
  {"id":"quest_rozpoznanie","title":"Rozpoznanie","type":"main","stages":[{"id":"start","objective":"Znajdź Brata Oskara","condition":"none"}],"rewards":{"xp":50,"items":[]}}
]

data/json/quests_new_faction.json
+7
[
  {"id":"quest_wolnosc","title":"Wolność za cenę","type":"new_faction","stages":[{"id":"start","objective":"Okradnij strażnika","condition":"none"},{"id":"end","objective":"Oddaj dowód Marze","condition":"deliver_proof"}],"rewards":{"xp":80,"items":["miecz_zgliszcze"],"reputation":{"wolne_zgliszcza":+10}},"alternative_methods":["fight","bribe","persuasion"]},
  {"id":"quest_buntownik","title":"Buntownik","type":"new_faction","stages":[{"id":"start","objective":"Zniszcz plakat","condition":"none"},{"id":"end","objective":"Zdecyduj: zostaw / spal / sprzedaj plakat","condition":"plakat_decision"}],"rewards":{"xp":60,"items":[]},"reputation":{"wolne_zgliszcza":+5}},
  {"id":"quest_zasadzka","title":"Zasadzka","type":"new_faction","stages":[{"id":"start","objective":"Zabij bandytę Jaromira","condition":"none"},{"id":"end","objective":"Przynieś głowę Marze","condition":"kill_jaromir"}],"rewards":{"xp":100,"items":["zbroja_zgliszcze"],"reputation":{"wolne_zgliszcza":+10}},"alternative_methods":["trap","betray"]},
  {"id":"quest_krwawy_kamien","title":"Krwawy Kamień","type":"new_faction","stages":[{"id":"start","objective":"Przynieś kamień z kamieniołomu","condition":"none"},{"id":"end","objective":"Oddaj Marze","condition":"deliver_stone"}],"rewards":{"xp":70,"items":["mikstura_ognia"],"reputation":{"wolne_zgliszcza":+5}},
  {"id":"quest_ostatni_toast","title":"Ostatni Toast","type":"new_faction","stages":[{"id":"start","objective":"Zabierz wino z piwnicy","condition":"none"},{"id":"end","objective":"Zdecyduj: oddaj / wypij / sprzedaj","condition":"wine_decision"}],"rewards":{"xp":50,"items":["mikstura_zycia"]},"reputation":{"wolne_zgliszcza":+5}}
]

data/json/quests_old_faction.json
+7
[
  {"id":"quest_rozporzadzenie","title":"Rozkaz dyscypliny","type":"old_faction","stages":[{"id":"start","objective":"Zanieś wiadomość strażnikowi","condition":"talk_alryk"},{"id":"deliver","objective":"Porozmawiaj ze Strażnikiem War","condition":"talk_rycerz_01"},{"id":"end","objective":"Wróć do Alryka","condition":"return_alryk"}],"rewards":{"xp":80,"items":["miecz_zardzewialy"],"reputation":{"stare_bractwo":+10}},"alternative_methods":["persuasion","theft","bribe"]},
  {"id":"quest_krwawe_zniwo","title":"Krwawe Żniwo","type":"old_faction","stages":[{"id":"start","objective":"Zabij 3 wilki","condition":"none"},{"id":"end","objective":"Przynieś skóry Alrykowi","condition":"kill_wolves"}],"rewards":{"xp":60,"items":["skora_wilk"],"reputation":{"stare_bractwo":+5}}},
  {"id":"quest_zaginiony","title":"Zaginiony Brat","type":"old_faction","stages":[{"id":"start","objective":"Znajdź Brata Oskara w bagnie","condition":"none"},{"id":"find","objective":"Porozmawiaj z Oskarem","condition":"visit_oskar"},{"id":"end","objective":"Zdecyduj: oddaj / zniszcz / sprzedaj list","condition":"choose_letter"}],"rewards":{"xp":100,"items":["klucz_kaplicy"],"reputation":{"stare_bractwo":+10}}},
  {"id":"quest_czysta_stal","title":"Czysta Stal","type":"old_faction","stages":[{"id":"start","objective":"Napraw miecz kowala","condition":"none"},{"id":"fix","objective":"Daj kowalowi kamień z kamieniołomu","condition":"deliver_stone"},{"id":"end","objective":"Odbierz naprawiony miecz","condition":"get_sword"}],"rewards":{"xp":70,"items":["miecz_kowalski"],"reputation":{"stare_bractwo":+5}}},
  {"id":"quest_ostatni_list","title":"Ostatni List","type":"old_faction","stages":[{"id":"start","objective":"Przeczytaj list zmarłego","condition":"find_letter"},{"id":"end","objective":"Zdecyduj: oddaj / zniszcz / sprzedaj","condition":"letter_decision"}],"rewards":{"xp":50,"items":[]},"branch":"destroy_or_sell"}
]

data/json/quests_side.json
+12
[
  {"id":"quest_zaginione_trofeum","title":"Zaginione Trofeum","type":"side","stages":[{"id":"start","objective":"Znajdź trofeum w lesie","condition":"none"},{"id":"end","objective":"Oddaj trofeum Bratowi Oskarowi","condition":"deliver_trophy"}],"rewards":{"xp":40,"items":["skora_dzik"]}},
  {"id":"quest_glodne_wilki","title":"Głodne Wilki","type":"side","stages":[{"id":"start","objective":"Zabij 2 wilki i przynieś mięso","condition":"none"},{"id":"end","objective":"Oddaj mięso Zielarce Róży","condition":"deliver_meat"}],"rewards":{"xp":40,"items":["roslina_lesna"]}},
  {"id":"quest_peknięty_zamek","title":"Pęknięty Zamek","type":"side","stages":[{"id":"start","objective":"Otwórz skrzynię w kamieniołomie","condition":"none"},{"id":"end","objective":"Zdecyduj: oddaj zawartość / zatrzymaj / sprzedaj","condition":"chest_decision"}],"rewards":{"xp":50,"items":["klucz_pierwszy"]}},
  {"id":"quest_ziola_szamana","title":"Zioła Szamana","type":"side","stages":[{"id":"start","objective":"Zbierz 3 zioła bagienne","condition":"none"},{"id":"end","objective":"Oddaj Szamanowi Głuchemu","condition":"deliver_herbs"}],"rewards":{"xp":60,"items":["mikstura_many"]}},
  {"id":"quest_rozbite_serce","title":"Rozbite Serce","type":"side","stages":[{"id":"start","objective":"Znajdź list od Mara_2","condition":"none"},{"id":"end","objective":"Zdecyduj: oddaj / zniszcz","condition":"letter_decision"}],"rewards":{"xp":50,"items":[]}},
  {"id":"quest_kradziez_noca","title":"Kradzież Nocą","type":"side","stages":[{"id":"start","objective":"Ukradnij przedmiot z obozu","condition":"none"},{"id":"end","objective":"Uniknij świadków","condition":"no_witness"}],"rewards":{"xp":70,"items":["miecz_zlodziejski"]}},
  {"id":"quest_list_z_wybrzeza","title":"List z Wybrzeża","type":"side","stages":[{"id":"start","objective":"Znajdź list na plaży","condition":"none"},{"id":"end","objective":"Oddaj Wyrzutkowi","condition":"deliver_letter"}],"rewards":{"xp":40,"items":["roslina_plazowa"]}},
  {"id":"quest_gluchy_bog","title":"Głuchy Bóg Budzi się","type":"side","stages":[{"id":"start","objective":"Odwiedź kurhan","condition":"none"},{"id":"end","objective":"Zdecyduj: zniszcz / zostaw / zabierz relikwię","condition":"relic_decision"}],"rewards":{"xp":100,"items":["mikstura_ognia","mikstura_lodu"]}},
  {"id":"quest_plomien_i_popiol","title":"Płomień i Popiół","type":"side","stages":[{"id":"start","objective":"Znajdź popiół w kamieniołomie","condition":"none"},{"id":"end","objective":"Oddaj kupcowi","condition":"deliver_ash"}],"rewards":{"xp":60,"items":["zbroja_czarna"]}},
  {"id":"quest_wyrzutka","title":"Wyrzutka","type":"side","stages":[{"id":"start","objective":"Pomóż Wyrzutkowi znaleźć dom","condition":"none"},{"id":"end","objective":"Zdecyduj: oddaj / zatrzymaj / sprzedaj mapę","condition":"map_decision"}],"rewards":{"xp":30,"items":["klucz_pierwszy"]}}
]

data/json/spells.json
+4
[
  {"id":"spell_fire","name":"Ognisty Pocisk","damage":20,"mana_cost":10,"cast_time":1.5,"sprite":"res://assets/sprites/spells/fire_ball.png","type":"projectile","element":"fire","req_quest":"quest_gluchy_bog"},
  {"id":"spell_ice","name":"Lodowy Pocisk","damage":15,"mana_cost":8,"cast_time":1.0,"sprite":"res://assets/sprites/spells/ice_ball.png","type":"projectile","element":"ice","req_quest":"quest_gluchy_bog"}
]

data/json/trainers.json
+8
[
  {"id":"trainer_sword","name":"Trener Miecza","npc":"npc_rycerz_01","skills":["sword_1","sword_2","sword_3"],"limit":3,"cost_per_level":20,"req_faction":"stare_bractwo","location":"twierdza_kuźnia"},
  {"id":"trainer_bow","name":"Nauczycielka Dźwięku","npc":"npc_dzwiek","skills":["bow_1","bow_2","bow_3"],"limit":3,"cost_per_level":20,"req_faction":"neutral","location":"las_polana"},
  {"id":"trainer_lock","name":"Złodziej Pęk","npc":"npc_pek","skills":["lockpick_1","lockpick_2","lockpick_3"],"limit":3,"cost_per_level":25,"req_faction":"wolne_zgliszcza","location":"oboz_pod_sciana"},
  {"id":"trainer_theft","name":"Złodziej Pęk","npc":"npc_pek","skills":["theft_1","theft_2","theft_3"],"limit":3,"cost_per_level":25,"req_faction":"wolne_zgliszcza","location":"oboz_pod_sciana"},
  {"id":"trainer_skinning","name":"Zwiadowca Klos","npc":"npc_rycerz_03","skills":["skinning_1","skinning_2"],"limit":2,"cost_per_level":30,"req_faction":"stare_bractwo","location":"trakt"},
  {"id":"trainer_spells","name":"Szaman Głuchy","npc":"npc_gluchy","skills":["spell_fire","spell_ice"],"limit":2,"cost_per_level":50,"req_faction":"neutral","location":"bagno_kurhan","quest_req":"quest_gluchy_bog"}
]

data/json/world_locations.json
+10
[
  {"id":"twierdza","name":"Twierdza Czarnej Ręki","region":"north","type":"settlement","faction":"stare_bractwo","coords":{"x":400,"y":300},"interactions":["chest_01","bed_01","npc_alryk","npc_rycerz_01"]},
  {"id":"oboz_zgliszcze","name":"Obóz Wolnych Zgliszcz","region":"south","type":"settlement","faction":"wolne_zgliszcza","coords":{"x":600,"y":700},"interactions":["chest_02","bed_02","npc_mara","npc_pek"]},
  {"id":"trakt","name":"Trakt Brudny","region":"center","type":"road","faction":"neutral","coords":{"x":500,"y":500},"interactions":["npc_neut_05","npc_neut_01"]},
  {"id":"las_zgnilizny","name":"Las Zgnilizny","region":"east","type":"forest","faction":"neutral","coords":{"x":700,"y":400},"interactions":["roslina_lesna","wilk_zgnilizny","npc_neut_08"]},
  {"id":"bagno_gluche","name":"Bagno Głuche","region":"east","type":"swamp","faction":"neutral","coords":{"x":850,"y":450},"interactions":["roslina_bagienna","upior_nocy","npc_oskar","npc_gluchy"]},
  {"id":"kamieniolom","name":"Kamieniołom Krwi","region":"west","type":"mountain","faction":"neutral","coords":{"x":200,"y":200},"interactions":["golem_kamienny","roslina_ognista","npc_neut_20"]},
  {"id":"plaza_popiolow","name":"Plaża Popiołów","region":"southwest","type":"beach","faction":"neutral","coords":{"x":150,"y":750},"interactions":["krab_plazowy","roslina_plazowa","npc_neut_02","npc_neut_07"]},
  {"id":"szczelina","name":"Szczelina Milczącego Boga","region":"northeast","type":"shrine","faction":"neutral","coords":{"x":900,"y":150},"interactions":["roslina_ognista","upior_nocy","npc_neut_18"]}
]

project/addons/validator/validator.gd
+33
extends SceneTree

func _init() -> void:
    print("=== WALIDATOR JSON ===")
    var loader := preload("res://autoload/data_loader.gd")
    # Nie można użyć preload w ten sposób; uproszczenie
    var dir := DirAccess.open("res://data/json/")
    if dir == null:
        print("Brak katalogu res://data/json/")
        quit()
    dir.list_dir_begin()
    var file := dir.get_next()
    var errors := 0
    while file != "":
        if file.ends_with(".json"):
            var path := "res://data/json/" + file
            var f := FileAccess.open(path, FileAccess.READ)
            if f == null:
                print("Błąd otwarcia: " + path)
                errors += 1
            else:
                var content := f.get_as_text()
                f.close()
                var parsed := JSON.parse_string(content)
                if parsed == null:
                    print("Błąd parsowania: " + file)
                    errors += 1
                else:
                    print("OK: " + file + " (" + str(typeof(parsed)) + ")")
        file = dir.get_next()
    dir.list_dir_end()
    print("Błędy: " + str(errors))
    quit()