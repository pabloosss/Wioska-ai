extends RefCounted
# Only plans supplied by AI select work. This executor completes finite jobs.
signal event_logged(message: String)
const ACTIONS := ["gather_food", "gather_wood", "deliver", "eat", "rest", "warm", "build", "wait"]
const SPOTS := {"food": Vector2(185, 235), "wood": Vector2(650, 210), "storage": Vector2(445, 370), "home": Vector2(315, 440), "fire": Vector2(575, 435)}
const SKILL_NAMES := {"foraging": "Zbieractwo", "woodcutting": "Drwalstwo", "building": "Budowanie"}
const SKILL_ACTIONS := {"gather_food": "foraging", "gather_wood": "woodcutting", "build": "building"}
const ACTION_NAMES := {"gather_food": "Zbieranie jedzenia", "gather_wood": "Zbieranie drewna", "deliver": "Dostawa", "eat": "Posiłek", "rest": "Odpoczynek", "warm": "Ogrzanie", "build": "Budowa", "wait": "Oczekiwanie"}
const MAX_SKILL_LEVEL := 10
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
			"skill_level": 1, "skill_xp": 0, "memory": [],
			"skills": _new_skills(), "episodes": [], "knowledge": {}, "milestones": [],
			"experience": {"actions": {}, "delivered_food": 0, "delivered_wood": 0}, "revision": 0, "queue": [],
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
				"last_result": p["last_result"], "skills": skill_snapshot(p), "memory": memory_for_ai(p)})
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
			log_event("%s otrzymuje plan AI: %s." % [name_text, ACTION_NAMES.get(action, action)])
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
					p["experience"]["delivered_food"] += food
					p["experience"]["delivered_wood"] += wood
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
				if p["progress"] >= work_duration(p, str(p["action"])):
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
				if p["progress"] >= work_duration(p, "build"):
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
	_record_experience(p, result, success)
	log_event("%s: %s" % [p["name"], result])
	if success:
		completed += 1
		p["jobs_done"] += 1
		if SKILL_ACTIONS.has(str(p["action"])):
			_award_xp(p, SKILL_ACTIONS[p["action"]], 12 if p["action"] == "build" else 10)
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
	var data := {"version": 3, "residents": data_people, "stock": stock, "houses": houses,
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
			_load_progress(p, saved)
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


func _new_skills() -> Dictionary:
	return {"foraging": {"level": 1, "xp": 0}, "woodcutting": {"level": 1, "xp": 0}, "building": {"level": 1, "xp": 0}}

func xp_needed(level: int) -> int:
	return 30 + (level - 1) * 20

func work_multiplier(p: Dictionary, action: String) -> float:
	var skill_key := str(SKILL_ACTIONS.get(action, ""))
	if skill_key.is_empty():
		return 1.0
	var level := int(p["skills"][skill_key]["level"])
	return 1.0 + 0.08 * float(level - 1)

func work_duration(p: Dictionary, action: String) -> float:
	return (6.0 if action == "build" else 2.0) / work_multiplier(p, action)

func skill_snapshot(p: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for key in SKILL_NAMES:
		result[key] = int(p["skills"][key]["level"])
	return result

func _award_xp(p: Dictionary, key: String, amount: int) -> void:
	var skill: Dictionary = p["skills"][key]
	if skill["level"] >= MAX_SKILL_LEVEL:
		return
	skill["xp"] += amount
	while skill["level"] < MAX_SKILL_LEVEL and skill["xp"] >= xp_needed(skill["level"]):
		skill["xp"] -= xp_needed(skill["level"])
		skill["level"] += 1
		var milestone := "%s: poziom %d. Szybkość pracy +%d%%." % [SKILL_NAMES[key], skill["level"], (int(skill["level"]) - 1) * 8]
		p["milestones"].append({"at": clock_text(), "text": milestone})
		if p["milestones"].size() > 27:
			p["milestones"].pop_front()
		log_event("%s rozwija umiejętność — %s" % [p["name"], milestone])
	if skill["level"] == MAX_SKILL_LEVEL:
		skill["xp"] = 0
	# Preserve compatibility with legacy summary fields; progress is now per skill.
	var primary := "foraging" if p["job"] == "Zbieracz" else "woodcutting" if p["job"] == "Drwal" else "building"
	p["skill_level"] = p["skills"][primary]["level"]
	p["skill_xp"] = p["skills"][primary]["xp"]

func _record_experience(p: Dictionary, result: String, success: bool) -> void:
	var action := str(p["action"])
	p["memory"].append(clock_text() + " " + result)
	while p["memory"].size() > 12:
		p["memory"].pop_front()
	var stats: Dictionary = p["experience"]["actions"]
	if not stats.has(action):
		stats[action] = {"successes": 0, "failures": 0}
	stats[action]["successes" if success else "failures"] += 1
	p["episodes"].append({"at": clock_text(), "seconds": elapsed, "action": action,
		"text": result.left(240), "outcome": "success" if success else "failure"})
	while p["episodes"].size() > 40:
		p["episodes"].pop_front()
	var knowledge: Dictionary = p["knowledge"]
	if success:
		match action:
			"gather_food":
				knowledge["food_source"] = "Znam jagody: zbieram 4 porcje i odnoszę je do magazynu."
				knowledge["delivery"] = "Zapasy wioski rosną dopiero po dostarczeniu ładunku."
			"gather_wood":
				knowledge["wood_source"] = "Znam las: zbieram 4 sztuki drewna i odnoszę je do magazynu."
				knowledge["delivery"] = "Zapasy wioski rosną dopiero po dostarczeniu ładunku."
			"deliver":
				knowledge["delivery"] = "Zapasy wioski rosną dopiero po dostarczeniu ładunku."
			"eat":
				knowledge["meal"] = "Jedna porcja poprawia sytość. Mogę zjeść własną lub odebrać ją z magazynu."
			"rest":
				knowledge["rest"] = "W domu odzyskuję siły do pracy."
			"warm":
				knowledge["warmth"] = "Ognisko pozwala mi się ogrzać."
			"build":
				knowledge["building"] = "Jeden etap budowy kosztuje 4 sztuki drewna."
	else:
		match action:
			"eat":
				knowledge["empty_food"] = "Gdy nie mam porcji i magazyn jest pusty, trzeba najpierw zebrać jedzenie."
			"build":
				knowledge["empty_wood"] = "Bez 4 sztuk drewna w magazynie nie ukończę etapu budowy."
			"deliver":
				knowledge["empty_cargo"] = "Nie mogę dostarczyć pustego ładunku."

func memory_for_ai(p: Dictionary) -> Dictionary:
	# Keep the model context bounded regardless of game age.
	var lessons: Array = []
	for key in ["empty_food", "empty_wood", "empty_cargo"]:
		if p["knowledge"].has(key):
			lessons.append(p["knowledge"][key])
	var successes: Dictionary = {}
	for key in SKILL_ACTIONS:
		var stats: Dictionary = p["experience"]["actions"].get(key, {})
		if int(stats.get("successes", 0)) > 0:
			successes[key] = int(stats["successes"])
	var recent: Array = []
	for event in p["episodes"].slice(-2):
		recent.append(str(event["text"]).left(120))
	var relevant_keys: Array = []
	if p["hunger"] < 50.0:
		relevant_keys.append_array(["food_source", "meal"])
	if p["rest"] < 40.0:
		relevant_keys.append("rest")
	if p["warmth"] < 40.0:
		relevant_keys.append("warmth")
	relevant_keys.append_array(["building" if p["job"] == "Budowniczy" else "wood_source" if p["job"] == "Drwal" else "food_source", "delivery"])
	var known_fact := ""
	for key in relevant_keys:
		if p["knowledge"].has(key):
			known_fact = str(p["knowledge"][key]).left(140)
			break
	return {"lessons": lessons.slice(0, 2), "known_fact": known_fact, "successful_jobs": successes, "recent": recent}

func _load_progress(p: Dictionary, saved: Dictionary) -> void:
	var saved_skills: Variant = saved.get("skills", null)
	if saved_skills is Dictionary:
		for key in SKILL_NAMES:
			var entry: Variant = saved_skills.get(key, {})
			if entry is Dictionary:
				var level := clampi(int(entry.get("level", 1)), 1, MAX_SKILL_LEVEL)
				p["skills"][key] = {"level": level, "xp": 0 if level == MAX_SKILL_LEVEL else clampi(int(entry.get("xp", 0)), 0, xp_needed(level) - 1)}
	else:
		var primary := "foraging" if p["job"] == "Zbieracz" else "woodcutting" if p["job"] == "Drwal" else "building"
		var old_level := clampi(int(saved.get("skill_level", 1)), 1, MAX_SKILL_LEVEL)
		var old_xp := clampi(int(saved.get("skill_xp", 0)), 0, 4)
		p["skills"][primary] = {"level": old_level, "xp": 0 if old_level == MAX_SKILL_LEVEL else int(float(old_xp) / 5.0 * xp_needed(old_level))}
	var known: Variant = saved.get("knowledge", {})
	if known is Dictionary:
		for key in ["food_source", "wood_source", "delivery", "meal", "rest", "warmth", "building", "empty_food", "empty_wood", "empty_cargo"]:
			if known.has(key):
				p["knowledge"][key] = str(known[key]).left(200)
	var history: Variant = saved.get("episodes", [])
	if history is Array:
		for event in history.slice(-40):
			if event is Dictionary:
				p["episodes"].append({"at": str(event.get("at", "")).left(60), "seconds": maxf(0, float(event.get("seconds", 0))),
					"action": str(event.get("action", "history")).left(40), "text": str(event.get("text", "")).left(240), "outcome": str(event.get("outcome", "history"))})
	if p["episodes"].is_empty():
		for note in p["memory"]:
			p["episodes"].append({"at": "Ze starszego zapisu", "seconds": 0.0, "action": "history", "text": str(note).left(240), "outcome": "history"})
	var saved_experience: Variant = saved.get("experience", {})
	if saved_experience is Dictionary:
		for key in ["delivered_food", "delivered_wood"]:
			p["experience"][key] = maxi(0, int(saved_experience.get(key, 0)))
		var actions: Variant = saved_experience.get("actions", {})
		if actions is Dictionary:
			for action in ACTIONS:
				if actions.get(action) is Dictionary:
					p["experience"]["actions"][action] = {"successes": maxi(0, int(actions[action].get("successes", 0))), "failures": maxi(0, int(actions[action].get("failures", 0)))}
	var milestones: Variant = saved.get("milestones", [])
	if milestones is Array:
		for milestone in milestones.slice(-27):
			if milestone is Dictionary:
				p["milestones"].append({"at": str(milestone.get("at", "")).left(60), "text": str(milestone.get("text", "")).left(200)})
