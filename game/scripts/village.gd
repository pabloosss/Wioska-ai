extends Node2D

const SIDEBAR_X := 850.0
const HOME := Vector2(500, 390)
const FOOD_SPOT := Vector2(230, 270)
const WOOD_SPOT := Vector2(665, 230)
const FIRE_SPOT := Vector2(500, 430)

var residents: Array[Dictionary] = []
var stock := {"food": 16, "wood": 18}
var logs: Array[String] = []
var selected := 0
var paused := false
var day_minute := 8 * 60
var build_progress := 0
var houses := 1
var clock: Timer


func _ready() -> void:
	_create_residents()
	_add_log("Wioska zaczyna dzień. Pięciu mieszkańców rusza do pracy.")
	clock = Timer.new()
	clock.wait_time = 1.0
	clock.timeout.connect(_on_tick)
	add_child(clock)
	clock.start()


func _process(delta: float) -> void:
	if not paused:
		for person in residents:
			var position: Vector2 = person["position"]
			var target: Vector2 = person["target"]
			person["position"] = position.move_toward(target, 48.0 * delta)
	queue_redraw()


func _create_residents() -> void:
	residents = [
		_make_person("Mira", "Zbieracz", Vector2(400, 350), Color("#e8a45b"), "Ciekawska", "Zielarstwo", "sznurkowa bransoletka", ["kosz"]),
		_make_person("Olek", "Zbieracz", Vector2(440, 380), Color("#d47a6a"), "Spokojny", "Zielarstwo", "gładki kamień", ["kosz"]),
		_make_person("Lena", "Drwal", Vector2(545, 350), Color("#84b878"), "Pracowita", "Drwalstwo", "drewniany gwizdek", ["topór"]),
		_make_person("Tomasz", "Drwal", Vector2(575, 390), Color("#7799c9"), "Ostrożny", "Drwalstwo", "stary guzik", ["topór"]),
		_make_person("Iga", "Budowniczy", Vector2(505, 355), Color("#c38bd1"), "Pomysłowa", "Budowanie", "notes z rysunkami", ["młotek"])
	]


func _make_person(person_name: String, job: String, start: Vector2, tint: Color, trait: String, skill: String, keepsake: String, equipment: Array) -> Dictionary:
	return {
		"name": person_name,
		"job": job,
		"position": start,
		"target": start,
		"color": tint,
		"trait": trait,
		"skill": skill,
		"skill_level": 1,
		"hunger": 82.0,
		"rest": 88.0,
		"warmth": 76.0,
		"work_ticks": 0,
		"inventory": {"food": 1, "keepsake": keepsake, "equipment": equipment}
	}


func _on_tick() -> void:
	if paused:
		return
	day_minute = (day_minute + 10) % 1440
	for person in residents:
		person["hunger"] = maxf(0.0, person["hunger"] - 1.2)
		person["rest"] = maxf(0.0, person["rest"] - 0.55)
		person["warmth"] = maxf(0.0, person["warmth"] - (0.8 if _is_night() else 0.12))
		_choose_task(person)
		_do_task(person)
	queue_redraw()


func _choose_task(person: Dictionary) -> void:
	var position: Vector2 = person["position"]
	if person["hunger"] < 28.0:
		person["task"] = "Je"
		person["target"] = position
	elif person["rest"] < 18.0:
		person["task"] = "Odpoczywa"
		person["target"] = HOME
	elif person["warmth"] < 24.0:
		person["task"] = "Grzeje się"
		person["target"] = FIRE_SPOT
	elif person["job"] == "Zbieracz":
		person["task"] = "Zbiera jedzenie"
		person["target"] = FOOD_SPOT
	elif person["job"] == "Drwal":
		person["task"] = "Ścina drewno"
		person["target"] = WOOD_SPOT
	else:
		person["task"] = "Buduje dom"
		person["target"] = HOME


func _do_task(person: Dictionary) -> void:
	var task: String = person.get("task", "")
	if task == "Je":
		var inventory: Dictionary = person["inventory"]
		if inventory["food"] > 0:
			inventory["food"] -= 1
			person["hunger"] = minf(100.0, person["hunger"] + 42.0)
			_add_log("%s zjada swoje jedzenie." % person["name"])
		elif stock["food"] > 0:
			stock["food"] -= 1
			person["hunger"] = minf(100.0, person["hunger"] + 42.0)
			_add_log("%s bierze jedzenie ze wspólnego magazynu." % person["name"])
		else:
			_add_log("%s jest głodny — w magazynie nie ma jedzenia." % person["name"])
		return

	var position: Vector2 = person["position"]
	var target: Vector2 = person["target"]
	if position.distance_to(target) > 18.0:
		return

	if task == "Odpoczywa":
		person["rest"] = minf(100.0, person["rest"] + 7.0)
		return
	if task == "Grzeje się":
		person["warmth"] = minf(100.0, person["warmth"] + 8.0)
		return

	person["work_ticks"] += 1
	if person["work_ticks"] < 3:
		return
	person["work_ticks"] = 0

	if task == "Zbiera jedzenie":
		stock["food"] += 2
		_add_log("%s dostarcza 2 jedzenia do magazynu." % person["name"])
	elif task == "Ścina drewno":
		stock["wood"] += 2
		_add_log("%s dostarcza 2 drewna do magazynu." % person["name"])
	elif task == "Buduje dom":
		if stock["wood"] < 4:
			return
		stock["wood"] -= 4
		build_progress += 1
		if build_progress >= 5:
			build_progress = 0
			houses += 1
			_add_log("%s kończy nowy dom. Wioska ma %d domy." % [person["name"], houses])
		else:
			_add_log("%s pracuje przy domu (%d/5)." % [person["name"], build_progress])


func _is_night() -> bool:
	var hour := int(day_minute / 60)
	return hour >= 20 or hour < 6


func _add_log(message: String) -> void:
	logs.push_front("%02d:%02d  %s" % [int(day_minute / 60), day_minute % 60, message])
	while logs.size() > 6:
		logs.pop_back()


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_SPACE:
			paused = not paused
		elif event.keycode >= KEY_1 and event.keycode <= KEY_5:
			selected = event.keycode - KEY_1
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var mouse_position := event.position
		for index in range(residents.size()):
			var person_position: Vector2 = residents[index]["position"]
			if mouse_position.distance_to(person_position) < 24.0:
				selected = index
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(0, 0, SIDEBAR_X, 720), Color("#78945f"))
	_draw_world()
	draw_rect(Rect2(SIDEBAR_X, 0, 430, 720), Color("#1d2928"))
	_draw_sidebar()


func _draw_world() -> void:
	# Placeholder scenery until the selected licensed pack is connected.
	draw_rect(Rect2(70, 90, 700, 540), Color("#87a96b"))
	for x in range(90, 770, 48):
		draw_line(Vector2(x, 90), Vector2(x, 630), Color("#90b174", 0.35), 1.0)
	for y in range(110, 630, 48):
		draw_line(Vector2(70, y), Vector2(770, y), Color("#90b174", 0.35), 1.0)

	draw_rect(Rect2(430, 330, 140, 95), Color("#a77c55"))
	draw_rect(Rect2(450, 300, 100, 70), Color("#d5bf91"))
	draw_rect(Rect2(488, 350, 24, 42), Color("#6a4836"))
	_draw_text("wspólny magazyn", 430, 445, 13, Color("#fff4d6"))

	draw_circle(FIRE_SPOT, 13.0, Color("#ed8b43"))
	draw_circle(FIRE_SPOT, 6.0, Color("#ffd36e"))
	_draw_text("ognisko", 474, 458, 13, Color("#fff4d6"))

	draw_circle(FOOD_SPOT, 24.0, Color("#496f43"))
	draw_circle(FOOD_SPOT + Vector2(-9, -4), 5.0, Color("#db5f54"))
	draw_circle(FOOD_SPOT + Vector2(8, -8), 5.0, Color("#db5f54"))
	_draw_text("jagody", 202, 310, 13, Color.WHITE)

	for tree in [Vector2(625, 205), Vector2(690, 265), Vector2(710, 185)]:
		draw_rect(Rect2(tree.x - 4, tree.y + 12, 8, 18), Color("#72503a"))
		draw_circle(tree, 20.0, Color("#365c3b"))
	_draw_text("las", 650, 305, 13, Color.WHITE)

	for index in range(residents.size()):
		var person: Dictionary = residents[index]
		var position: Vector2 = person["position"]
		var tint: Color = person["color"]
		if index == selected:
			draw_circle(position, 20.0, Color("#fff1a8"))
		draw_circle(position, 15.0, tint)
		draw_circle(position + Vector2(0, -17), 7.0, Color("#f1d1ae"))
		_draw_text(person["name"], position.x - 22, position.y + 34, 12, Color.WHITE)

	_draw_text("WIOSKA AI  •  %02d:%02d" % [int(day_minute / 60), day_minute % 60], 82, 65, 20, Color.WHITE)
	_draw_text("SPACJA — pauza  |  kliknij mieszkańca albo użyj 1–5", 82, 610, 14, Color.WHITE)


func _draw_sidebar() -> void:
	_draw_text("WIOSKA AI", 885, 42, 24, Color("#f4d99b"))
	_draw_text("Dzień 1   •   %s" % ("noc" if _is_night() else "dzień"), 885, 70, 15, Color("#d5dfd5"))
	_draw_text("MAGAZYN WSPÓLNY", 885, 112, 15, Color("#f4d99b"))
	_draw_text("Jedzenie: %d     Drewno: %d" % [stock["food"], stock["wood"]], 885, 138, 16, Color.WHITE)
	_draw_text("Domy: %d     Budowa: %d/5" % [houses, build_progress], 885, 162, 14, Color("#d5dfd5"))

	_draw_text("MIESZKAŃCY", 885, 207, 15, Color("#f4d99b"))
	for index in range(residents.size()):
		var person: Dictionary = residents[index]
		var color: Color = Color("#fff1a8") if index == selected else Color("#d5dfd5")
		_draw_text("%d. %s — %s" % [index + 1, person["name"], person.get("task", "wybiera pracę")], 885, 235 + index * 25, 13, color)

	var chosen: Dictionary = residents[selected]
	_draw_text("WYBRANY MIESZKANIEC", 885, 383, 15, Color("#f4d99b"))
	_draw_text("%s  •  %s  •  %s" % [chosen["name"], chosen["job"], chosen["trait"]], 885, 409, 13, Color.WHITE)
	_draw_text("Głód", 885, 438, 12, Color("#d5dfd5"))
	_draw_bar(940, 427, 205, chosen["hunger"], Color("#e5a45b"))
	_draw_text("Odpoczynek", 885, 465, 12, Color("#d5dfd5"))
	_draw_bar(970, 454, 175, chosen["rest"], Color("#79b8d2"))
	_draw_text("Ciepło", 885, 492, 12, Color("#d5dfd5"))
	_draw_bar(940, 481, 205, chosen["warmth"], Color("#e77c58"))
	var inventory: Dictionary = chosen["inventory"]
	_draw_text("Umiejętność: %s  •  poziom %d" % [chosen["skill"], chosen["skill_level"]], 885, 522, 12, Color.WHITE)
	_draw_text("Ekwipunek: %s, jedzenie %d" % [", ".join(inventory["equipment"]), inventory["food"]], 885, 544, 12, Color.WHITE)
	_draw_text("Prywatna rzecz: %s" % inventory["keepsake"], 885, 566, 12, Color.WHITE)

	_draw_text("OSTATNIE ZDARZENIA", 885, 603, 14, Color("#f4d99b"))
	for index in range(logs.size()):
		_draw_text(logs[index], 885, 628 + index * 16, 11, Color("#d5dfd5"))


func _draw_bar(x: float, y: float, width: float, value: float, color: Color) -> void:
	draw_rect(Rect2(x, y, width, 10), Color("#3c4a46"))
	draw_rect(Rect2(x, y, width * clampf(value / 100.0, 0.0, 1.0), 10), color)


func _draw_text(text: String, x: float, y: float, size: int, color: Color) -> void:
	draw_string(ThemeDB.fallback_font, Vector2(x, y), text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size, color)
