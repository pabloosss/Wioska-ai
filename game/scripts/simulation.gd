extends RefCounted
# Only plans supplied by AI select work. This executor completes finite jobs.
signal event_logged(message: String)
const ACTIONS := ["gather_food", "gather_wood", "deliver", "eat", "rest", "warm", "build", "wait"]
const SPOTS := {"food": Vector2(185, 235), "wood": Vector2(650, 210), "storage": Vector2(445, 370), "home": Vector2(315, 440), "fire": Vector2(575, 435)}
const SAVE_PATH := "user://wioska_ai_save.json"
var people: Array[Dictionary] = []
var stock := {"food": 16, "wood": 18}
var houses := 1
var build_progress := 0
var elapsed := 0.0
var logs: Array[String] = []
var completed := 0
var delivered := {"food": 0, "wood": 0}
var last_save := "Jeszcze nie zapisano"
var dirty := false

func _init() -> void:
	var names := ["Mira", "Olek", "Lena", "Tomasz", "Iga"]
	var jobs := ["Zbieracz", "Zbieracz", "Drwal", "Drwal", "Budowniczy"]
	var traits := ["Ciekawska", "Spokojny", "Pracowita", "Ostrożny", "Pomysłowa"]
	var colors := ["e8a45b", "d47a6a", "84b878", "7799c9", "c38bd1"]
	for i in range(names.size()):
		people.append({"name": names[i], "job": jobs[i], "trait": traits[i], "color": Color(colors[i]),
			"position": Vector2(345 + i * 40, 315), "target": Vector2(345 + i * 40, 315),
			"hunger": 82.0, "rest": 88.0, "warmth": 76.0, "cargo_food": 0, "cargo_wood": 0,
			"inventory": {"food": 1, "keepsake": "osobista pamiątka", "equipment": ["kosz" if i < 2 else "topór" if i < 4 else "młotek"]},
			"skill_level": 1, "skill_xp": 0, "memory": [], "revision": 0, "queue": [],
			"action": "", "phase": "idle", "task": "Czeka na plan AI", "progress": 0.0,
			"reason": "Jeszcze nie otrzymał planu.", "last_result": "", "jobs_done": 0})

func log_event(message: String) -> void:
	logs.push_front("%s  %s" % [clock_text(), message])
	if logs.size() > 160:
		logs.resize(160)
	event_logged.emit(message)

func clock_text() -> String:
	var minutes := 480 + int(elapsed / 2.0)
	return "Dzień %d • %02d:%02d" % [1 + minutes / 1440, minutes / 60 % 24, minutes % 60]

func idle_snapshot() -> Array:
	var result: Array = []
	for p in people:
		if p["phase"] == "idle" and p["queue"].is_empty():
			result.append({"name": p["name"], "revision": p["revision"], "job": p["job"], "personality": p["trait"],
				"needs": {"satiety": roundi(p["hunger"]), "rest": roundi(p["rest"]), "warmth": roundi(p["warmth"])},
				"inventory": {"food": p["inventory"]["food"], "cargo_food": p["cargo_food"], "cargo_wood": p["cargo_wood"]},
				"last_result": p["last_result"], "memory": p["memory"].slice(-3)})
	return result

func world_snapshot() -> Dictionary:
	var busy: Array = []
	for p in people:
		if p["phase"] != "idle":
			busy.append({"name": p["name"], "action": p["action"], "phase": p["phase"]})
	return {"shared_food": stock["food"], "shared_wood": stock["wood"], "houses": houses,
		"build_progress": build_progress, "busy_residents_do_not_reassign": busy, "time": clock_text()}

func apply_decisions(decisions: Array, revisions: Dictionary) -> int:
	var accepted := 0
	var seen: Array = []
	for decision in decisions:
		if not decision is Dictionary:
			continue
		var name_text := str(decision.get("name", ""))
		if seen.has(name_text):
			continue
		seen.append(name_text)
		for p in people:
			if p["name"] != name_text or p["phase"] != "idle" or not p["queue"].is_empty() or int(revisions.get(name_text, -1)) != p["revision"]:
				continue
			var action := str(decision.get("action", ""))
			if not ACTIONS.has(action):
				continue
			var reason := str(decision.get("reason", "Plan AI")).left(240)
			p["queue"].append({"action": action, "reason": reason})
			var following: Variant = decision.get("next_actions", [])
			if following is Array:
				for next in following.slice(0, 2):
					if ACTIONS.has(str(next)):
						p["queue"].append({"action": str(next), "reason": "Kolejny krok planu AI: " + reason})
			p["revision"] += 1
			accepted += 1
			log_event("%s otrzymuje plan AI: %s." % [name_text, action])
			_start_next(p)
	return accepted

func _spot(p: Dictionary, key: String) -> Vector2:
	var index := people.find(p)
	return SPOTS[key] + Vector2((index % 3 - 1) * 16, int(index / 3) * 16)

func _go(p: Dictionary, phase: String, location: String, label: String) -> void:
	p["phase"] = phase
	p["target"] = _spot(p, location)
	p["task"] = label

func _start_next(p: Dictionary) -> void:
	if p["queue"].is_empty():
		p["phase"] = "idle"
		p["action"] = ""
		p["task"] = "Czeka na plan AI"
		return
	var item: Dictionary = p["queue"].pop_front()
	p["action"] = item["action"]
	p["reason"] = item["reason"]
	p["progress"] = 0.0
	match str(p["action"]):
		"gather_food", "gather_wood":
			if p["cargo_food"] + p["cargo_wood"] >= 4:
				_go(p, "to_storage", "storage", "Niesie pełny ładunek do magazynu")
			else:
				_go(p, "to_resource", "food" if p["action"] == "gather_food" else "wood", "Idzie zbierać jedzenie" if p["action"] == "gather_food" else "Idzie po drewno")
		"deliver":
			if p["cargo_food"] + p["cargo_wood"] == 0:
				_finish(p, "Nie ma ładunku do oddania.", false)
			else:
				_go(p, "to_storage", "storage", "Niesie ładunek do magazynu")
		"eat":
			if p["inventory"]["food"] > 0 or p["cargo_food"] > 0:
				p["phase"] = "eating"
				p["task"] = "Je własną porcję"
			elif stock["food"] > 0:
				_go(p, "to_food", "storage", "Idzie po porcję do magazynu")
			else:
				_finish(p, "Brak jedzenia. AI musi zaplanować zbiór.", false)
		"rest":
			_go(p, "to_rest", "home", "Idzie odpocząć")
		"warm":
			_go(p, "to_warm", "fire", "Idzie do ogniska")
		"build":
			_go(p, "to_build", "home", "Idzie na budowę")
		"wait":
			p["phase"] = "waiting"
			p["task"] = "Czeka zgodnie z planem AI"

func step(delta: float) -> void:
	elapsed += delta
	dirty = true
	for p in people:
		# Needs use simulated seconds, not frame count or network round trips.
		p["hunger"] = maxf(0.0, p["hunger"] - delta * 0.09)
		p["rest"] = maxf(0.0, p["rest"] - delta * 0.035)
		p["warmth"] = maxf(0.0, p["warmth"] - delta * 0.02)
		var phase: String = p["phase"]
		if phase == "idle":
			_start_next(p)
			continue
		if phase.begins_with("to_"):
			var position: Vector2 = p["position"]
			var target: Vector2 = p["target"]
			p["position"] = position.move_toward(target, 65.0 * delta)
			if p["position"].distance_to(target) > 1.0:
				continue
			p["progress"] = 0.0
			match phase:
				"to_resource":
					p["phase"] = "gathering"
					p["task"] = "Zbiera jedzenie" if p["action"] == "gather_food" else "Ścina drewno"
				"to_storage":
					var food: int = p["cargo_food"]
					var wood: int = p["cargo_wood"]
					stock["food"] += food
					stock["wood"] += wood
					delivered["food"] += food
					delivered["wood"] += wood
					p["cargo_food"] = 0
					p["cargo_wood"] = 0
					_finish(p, "Dostarcza jedzenie %d, drewno %d." % [food, wood])
				"to_food":
					p["phase"] = "eating"
					p["task"] = "Je w magazynie"
				"to_rest":
					p["phase"] = "resting"
					p["task"] = "Odpoczywa"
				"to_warm":
					p["phase"] = "warming"
					p["task"] = "Grzeje się"
				"to_build":
					p["phase"] = "building"
					p["task"] = "Buduje"
			continue
		p["progress"] += delta
		match phase:
			"gathering":
				if p["progress"] >= 2.0:
					p["progress"] = 0.0
					var cargo_key := "cargo_food" if p["action"] == "gather_food" else "cargo_wood"
					p[cargo_key] += mini(2, 4 - int(p["cargo_food"]) - int(p["cargo_wood"]))
					if p["cargo_food"] + p["cargo_wood"] >= 4:
						_go(p, "to_storage", "storage", "Niesie pełny ładunek do magazynu")
			"eating":
				if p["progress"] >= 2.0:
					if p["inventory"]["food"] > 0:
						p["inventory"]["food"] -= 1
					elif p["cargo_food"] > 0:
						p["cargo_food"] -= 1
					elif p["position"].distance_to(_spot(p, "storage")) <= 2.0 and stock["food"] > 0:
						stock["food"] -= 1
					else:
						_finish(p, "Nie ma dostępnej porcji jedzenia.", false)
						continue
					p["hunger"] = minf(100.0, p["hunger"] + 42.0)
					_finish(p, "Zjada jedną porcję jedzenia.")
			"resting":
				p["rest"] = minf(100.0, p["rest"] + delta * 3.0)
				if p["rest"] >= 90.0:
					_finish(p, "Kończy odpoczynek.")
			"warming":
				p["warmth"] = minf(100.0, p["warmth"] + delta * 4.0)
				if p["warmth"] >= 90.0:
					_finish(p, "Ogrzewa się przy ognisku.")
			"building":
				if p["progress"] >= 6.0:
					if stock["wood"] < 4:
						_finish(p, "Brak 4 sztuk drewna na budowę.", false)
					else:
						stock["wood"] -= 4
						build_progress += 1
						if build_progress == 5:
							build_progress = 0
							houses += 1
						_finish(p, "Kończy etap budowy domu.")
			"waiting":
				if p["progress"] >= 5.0:
					_finish(p, "Kończy zaplanowane oczekiwanie.")

func _finish(p: Dictionary, result: String, success: bool = true) -> void:
	p["last_result"] = result
	p["memory"].append(clock_text() + " " + result)
	while p["memory"].size() > 12:
		p["memory"].pop_front()
	log_event("%s: %s" % [p["name"], result])
	if success:
		completed += 1
		p["jobs_done"] += 1
		p["skill_xp"] += 1
		if p["skill_xp"] >= 5:
			p["skill_xp"] = 0
			p["skill_level"] += 1
	p["revision"] += 1
	p["phase"] = "idle"
	p["action"] = ""
	p["task"] = "Czeka na kolejny krok planu" if not p["queue"].is_empty() else "Czeka na plan AI"
	p["progress"] = 0.0
	dirty = true

func save_game(path: String = SAVE_PATH) -> bool:
	var data_people: Array = []
	for p in people:
		var copy: Dictionary = p.duplicate(true)
		copy.erase("color")
		copy["position"] = [p["position"].x, p["position"].y]
		copy["target"] = [p["target"].x, p["target"].y]
		data_people.append(copy)
	var data := {"version": 2, "residents": data_people, "stock": stock, "houses": houses,
		"build_progress": build_progress, "elapsed": elapsed, "completed": completed, "delivered": delivered}
	var file := FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if file == null:
		last_save = "Błąd zapisu: " + error_string(FileAccess.get_open_error())
		return false
	file.store_string(JSON.stringify(data))
	file.close()
	if FileAccess.file_exists(path):
		DirAccess.copy_absolute(ProjectSettings.globalize_path(path), ProjectSettings.globalize_path(path + ".bak"))
	var error := DirAccess.rename_absolute(ProjectSettings.globalize_path(path + ".tmp"), ProjectSettings.globalize_path(path))
	last_save = "Zapisano " + Time.get_time_string_from_system() if error == OK else "Błąd zapisu: " + error_string(error)
	if error == OK:
		dirty = false
	return error == OK

func load_game(path: String = SAVE_PATH) -> void:
	if not FileAccess.file_exists(path):
		return
	var parser := JSON.new()
	if parser.parse(FileAccess.get_file_as_string(path)) != OK or not parser.data is Dictionary:
		log_event("Nieczytelny zapis. Zachowano plik, uruchomiono nowy świat.")
		return
	var data: Dictionary = parser.data
	var saved_stock: Dictionary = data.get("stock", {})
	for key in stock:
		stock[key] = maxi(0, int(saved_stock.get(key, stock[key])))
	houses = maxi(1, int(data.get("houses", 1)))
	build_progress = clampi(int(data.get("build_progress", 0)), 0, 4)
	elapsed = maxf(0.0, float(data.get("elapsed", 0)))
	completed = maxi(0, int(data.get("completed", 0)))
	var saved_deliveries: Dictionary = data.get("delivered", {})
	for key in delivered:
		delivered[key] = maxi(0, int(saved_deliveries.get(key, 0)))
	for saved in data.get("residents", []):
		if not saved is Dictionary:
			continue
		for p in people:
			if p["name"] != saved.get("name", ""):
				continue
			for key in ["hunger", "rest", "warmth"]:
				p[key] = clampf(float(saved.get(key, p[key])), 0, 100)
			for key in ["skill_level", "skill_xp", "cargo_food", "cargo_wood", "jobs_done", "revision"]:
				p[key] = maxi(0, int(saved.get(key, p[key])))
			p["cargo_food"] = mini(4, p["cargo_food"])
			p["cargo_wood"] = mini(4 - int(p["cargo_food"]), p["cargo_wood"])
			var inv: Variant = saved.get("inventory", {})
			if inv is Dictionary:
				p["inventory"]["food"] = maxi(0, int(inv.get("food", 1)))
				p["inventory"]["keepsake"] = str(inv.get("keepsake", "pamiątka"))
				if inv.get("equipment") is Array:
					p["inventory"]["equipment"] = inv["equipment"]
			if saved.get("memory") is Array:
				p["memory"] = saved["memory"].slice(-12)
			var pos: Variant = saved.get("position", [])
			if pos is Array and pos.size() == 2:
				p["position"] = Vector2(clampf(float(pos[0]), 40, 750), clampf(float(pos[1]), 60, 500))
			p["target"] = p["position"]
			# Rebuild navigation from the saved AI command. Preserve cargo, never invent a job.
			if int(data.get("version", 1)) >= 2:
				var action := str(saved.get("action", ""))
				if ACTIONS.has(action):
					p["queue"].append({"action": action, "reason": str(saved.get("reason", "Wznowienie planu AI"))})
				for item in saved.get("queue", []):
					if item is Dictionary and ACTIONS.has(str(item.get("action", ""))) and p["queue"].size() < 3:
						p["queue"].append(item)
	log_event("Wczytano świat. Ładunki i rzeczy mieszkańców zostały zachowane.")
