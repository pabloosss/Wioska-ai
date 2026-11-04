extends RefCounted
# World rules and finite activities. No autonomous job selector lives here.
const ROLES := ["Zbieracz", "Drwal", "Budowniczy", "Rolnik", "Strażnik", "Opiekun"]
const CHILD_ACTIONS := ["eat", "rest", "warm", "shelter", "socialize", "learn", "wait"]
var options := {"threats": true, "difficulty": 1, "births": true, "population_limit": 16,
	"day_seconds": 240, "pregnancy_days": 3, "child_days": 12, "needs_percent": 100,
	"mortality": false, "spoilage": false}
var threat := {"kind": "", "remaining": 0.0, "strength": 0.0}
var next_threat := 480.0
var event_serial := 0
var berries := 60.0
var next_child := 1
var births := 0
var deaths := 0
var last_day := 0
var days := 0.0

func prepare_person(p: Dictionary, index: int) -> void:
	p.merge({"age": float(23 + index % 5 * 3), "sex": "F" if index % 2 == 0 else "M", "alive": true,
		"health": 100.0, "social": 75.0, "relationships": {}, "partner": "", "parents": [],
		"children": [], "pregnancy": 0.0, "pregnancy_partner": "", "family_intent": "", "intent_until": 0.0,
		"family_cooldown": 0.0, "activity_target": "", "goal": "Przetrwać i znaleźć swoje miejsce w osadzie",
		"last_planned": -1.0, "home": -1, "medical_food": 0}, false)

func living(sim: RefCounted) -> Array:
	return sim.people.filter(func(p: Dictionary): return p["alive"])

func find_person(sim: RefCounted, person_name: String) -> Dictionary:
	for p in sim.people:
		if p["name"] == person_name:
			return p
	return {}

func free_beds(sim: RefCounted) -> int:
	return maxi(0, sim.houses * 4 - living(sim).size() - pregnancies(sim))

func pregnancies(sim: RefCounted) -> int:
	return living(sim).filter(func(p: Dictionary): return p["pregnancy"] > 0).size()

func configure(sim: RefCounted, values: Dictionary) -> void:
	for key in ["threats", "births", "mortality", "spoilage"]:
		if values.has(key):
			options[key] = bool(values[key])
	for key in ["difficulty", "population_limit", "day_seconds", "pregnancy_days", "child_days", "needs_percent"]:
		if values.has(key):
			var limits: Dictionary = {"difficulty": [1, 3], "population_limit": [5, 20], "day_seconds": [120, 1200], "pregnancy_days": [1, 12], "child_days": [6, 48], "needs_percent": [25, 200]}
			options[key] = clampi(int(values[key]), limits[key][0], limits[key][1])
	if not options["threats"] and not str(threat["kind"]).is_empty():
		threat = {"kind": "", "remaining": 0.0, "strength": 0.0}
		sim.log_event("Zagrożenia wyłączone — bieżące zdarzenie zakończono.")
	sim.dirty = true

func assign_homes(sim: RefCounted) -> void:
	var residents := living(sim)
	# Existing places are stable; children move into the first free bed.
	var used: Array = []
	for p in residents:
		if int(p["home"]) >= 0 and int(p["home"]) < sim.houses * 4 and not used.has(p["home"]):
			used.append(p["home"])
		else:
			p["home"] = -1
	for p in residents:
		if p["home"] >= 0:
			continue
		for bed in range(sim.houses * 4):
			if not used.has(bed):
				p["home"] = bed
				used.append(bed)
				break

func tick_world(sim: RefCounted, delta: float) -> void:
	days += delta / float(options["day_seconds"])
	berries = minf(60.0, berries + delta * 0.04)
	if int(days) > last_day:
		last_day = int(days)
		if options["spoilage"] and sim.stock["food"] > 0:
			var spoiled := maxi(1, int(sim.stock["food"] * 0.05))
			sim.stock["food"] -= spoiled
			sim.log_event("Zepsuło się %d porcji ze wspólnego magazynu." % spoiled)
	if options["threats"] and str(threat["kind"]).is_empty() and sim.elapsed >= next_threat:
		trigger_threat(sim, "storm" if event_serial % 2 == 0 else "wolves")
	if not str(threat["kind"]).is_empty():
		threat["remaining"] = maxf(0, threat["remaining"] - delta)
		if threat["remaining"] <= 0 or threat["strength"] <= 0:
			if threat["kind"] == "wolves" and threat["strength"] > 0:
				var lost := mini(int(sim.stock["food"]), int(ceil(threat["strength"])))
				sim.stock["food"] -= lost
				sim.log_event("Wilki odeszły, zabierając %d porcji z zapasów." % lost)
			else:
				sim.log_event("Zagrożenie minęło: " + threat_label())
			threat = {"kind": "", "remaining": 0.0, "strength": 0.0}
			next_threat = sim.elapsed + float(options["day_seconds"]) * 2.0
	assign_homes(sim)
	# Duplicate the list because births append residents.
	for p in sim.people.duplicate():
		if not p["alive"]:
			continue
		var was_child: bool = p["age"] < 18
		p["age"] += delta / float(options["day_seconds"]) * (18.0 / float(options["child_days"]) if was_child else 1.0 / 30.0)
		if was_child and p["age"] >= 18:
			p["job"] = "Uczeń"
			remember(sim, p, "Dorasta. Może samodzielnie wybrać zawód i założyć rodzinę.")
		p["family_cooldown"] = maxf(0, p["family_cooldown"] - delta / float(options["day_seconds"]))
		if p["pregnancy"] > 0:
			p["pregnancy"] = maxf(0, p["pregnancy"] - delta / float(options["day_seconds"]))
			if p["pregnancy"] <= 0:
				_birth(sim, p)

func tick_person(sim: RefCounted, p: Dictionary, delta: float) -> void:
	p["social"] = maxf(0, p["social"] - delta * 0.025)
	var inside: bool = p["home"] >= 0 and p["position"].distance_to(sim._spot(p, "home")) < 32
	var danger := str(threat["kind"])
	if danger == "storm" and not inside:
		p["warmth"] = maxf(0, p["warmth"] - delta * 0.35 * int(options["difficulty"]))
	var damage := 0.0
	if p["hunger"] < 5:
		damage += 0.12
	if p["warmth"] < 5:
		damage += 0.08
	if danger == "wolves" and not inside and p["phase"] != "guarding":
		damage += 0.08 * int(options["difficulty"])
	var old_health := float(p["health"])
	p["health"] = maxf(0 if options["mortality"] else 1, p["health"] - damage * delta)
	if damage == 0 and p["hunger"] > 50 and p["rest"] > 50 and p["warmth"] > 40:
		p["health"] = minf(100, p["health"] + delta * 0.02)
	if old_health >= 30 and p["health"] < 30:
		remember(sim, p, "Stan krytyczny: potrzebuję leczenia, jedzenia i schronienia.")
	if p["health"] <= 0:
		p["alive"] = false
		p["queue"].clear()
		p["phase"] = "dead"
		p["task"] = "Nie żyje"
		p["action"] = ""
		p["revision"] += 1
		p["pregnancy"] = 0.0
		deaths += 1
		remember(sim, p, "Umiera wskutek wyczerpania lub zagrożeń.")
		var partner := find_person(sim, p["partner"])
		if not partner.is_empty():
			partner["partner"] = ""
			remember(sim, partner, "Traci partnera: " + str(p["name"]))

func trigger_threat(sim: RefCounted, kind: String) -> bool:
	if not options["threats"] or not ["storm", "wolves"].has(kind) or not str(threat["kind"]).is_empty():
		return false
	event_serial += 1
	threat = {"kind": kind, "remaining": 75.0 + int(options["difficulty"]) * 15.0, "strength": float(3 * int(options["difficulty"]))}
	for p in living(sim):
		# Cancel only unstarted steps. An in-progress haul still finishes.
		p["queue"].clear()
		p["revision"] += 1
		p["knowledge"]["safety"] = "Dom chroni przed burzą i wilkami. Warta odstrasza wilki, leczenie pomaga rannym."
		remember(sim, p, "Alarm: " + ("nadchodzi zimna burza. Dom chroni przed wychłodzeniem." if kind == "storm" else "wilki przy osadzie. Warta chroni mieszkańców i zapasy."))
	sim.log_event("ZAGROŻENIE: " + threat_label() + ". AI otrzyma alarm w kolejnym cyklu.")
	return true

func threat_label() -> String:
	return "Zimna burza" if threat["kind"] == "storm" else "Wilki przy osadzie" if threat["kind"] == "wolves" else "Spokojnie"

func remember(sim: RefCounted, p: Dictionary, message: String) -> void:
	p["episodes"].append({"at": sim.clock_text(), "seconds": sim.elapsed, "action": "life", "text": message.left(240), "outcome": "history"})
	while p["episodes"].size() > 40:
		p["episodes"].pop_front()
	sim.log_event("%s: %s" % [p["name"], message])

func relation(p: Dictionary, other: Dictionary) -> int:
	return int(p["relationships"].get(other["name"], 20))

func allowed(p: Dictionary, action: String) -> bool:
	return p["alive"] and (p["age"] >= 18 or CHILD_ACTIONS.has(action))

func start(sim: RefCounted, p: Dictionary) -> void:
	match str(p["action"]):
		"farm":
			if p["cargo_food"] + p["cargo_wood"] > 0:
				sim._go(p, "to_storage", "storage", "Odnosi ładunek przed uprawą")
			else:
				sim._go(p, "to_farm", "farm", "Idzie uprawiać pole")
		"shelter":
			sim._go(p, "to_shelter", "home", "Szuka schronienia w domu")
		"guard":
			sim._go(p, "to_guard", "gate", "Idzie na wartę")
		"heal":
			sim._go(p, "to_heal", "storage", "Przygotowuje pomoc i posiłek")
		"start_family":
			sim._go(p, "to_family", "home", "Idzie porozmawiać o założeniu rodziny")
		"socialize", "learn":
			var target := find_person(sim, p["activity_target"])
			if target.is_empty() or not target["alive"] or target == p:
				sim._finish(p, "Wybierz istniejącą, żyjącą osobę jako target.", false)
			else:
				p["phase"] = "to_social" if p["action"] == "socialize" else "to_learn"
				p["target"] = target["position"]
				p["task"] = ("Idzie porozmawiać z " if p["action"] == "socialize" else "Idzie uczyć się od ") + str(target["name"])

func arrive(p: Dictionary, phase: String) -> void:
	var activities := {"to_farm": "farming", "to_shelter": "sheltering", "to_guard": "guarding", "to_heal": "healing", "to_family": "family", "to_social": "socializing", "to_learn": "learning"}
	if activities.has(phase):
		p["phase"] = activities[phase]
		p["task"] = {"farming": "Uprawia pole", "sheltering": "Przeczekuje zagrożenie", "guarding": "Pilnuje osady", "healing": "Przygotowuje leczenie", "family": "Rozmawia o rodzinie", "socializing": "Rozmawia", "learning": "Uczy się"}[p["phase"]]

func activity(sim: RefCounted, p: Dictionary, delta: float) -> void:
	match str(p["phase"]):
		"farming":
			if p["progress"] >= sim.work_duration(p, "farm"):
				if sim.stock["wood"] < 1:
					sim._finish(p, "Uprawa wymaga 1 drewna na narzędzia.", false)
				else:
					sim.stock["wood"] -= 1
					p["cargo_food"] = 4
					sim._go(p, "to_storage", "storage", "Niesie plon do magazynu")
		"sheltering":
			if p["home"] < 0:
				sim._finish(p, "Brak wolnego miejsca w domu. Potrzeba budowy.", false)
			else:
				p["warmth"] = minf(100, p["warmth"] + delta * 2)
				p["rest"] = minf(100, p["rest"] + delta)
				if str(threat["kind"]).is_empty() or p["progress"] >= 45:
					sim._finish(p, "Kończy pobyt w bezpiecznym schronieniu.")
		"guarding":
			if p["progress"] >= 12:
				if threat["kind"] == "wolves":
					threat["strength"] = maxf(0, threat["strength"] - 3.0)
					sim._finish(p, "Odstrasza wilki i chroni zapasy.")
				else:
					sim._finish(p, "Kończy obchód osady.")
		"healing":
			if p["progress"] >= 6:
				var target := find_person(sim, p["activity_target"] if not str(p["activity_target"]).is_empty() else p["name"])
				if target.is_empty() or not target["alive"] or (sim.stock["food"] < 2 and p["medical_food"] < 2):
					sim._finish(p, "Leczenie wymaga żyjącej osoby i 2 porcji w magazynie.", false)
				else:
					# Reserve the food at the warehouse and physically carry it to the patient.
					if p["medical_food"] < 2:
						sim.stock["food"] -= 2
						p["medical_food"] = 2
					p["target"] = target["position"]
					p["phase"] = "to_patient"
					p["task"] = "Idzie pomóc " + str(target["name"])
		"treating":
			if p["progress"] >= 3:
				var target := find_person(sim, p["activity_target"] if not str(p["activity_target"]).is_empty() else p["name"])
				if target.is_empty() or not target["alive"] or p["position"].distance_to(target["position"]) > 60 or p["medical_food"] < 2:
					sim._finish(p, "Nie udało się udzielić pomocy: osoba odeszła lub brak zapasów.", false)
				else:
					p["medical_food"] = 0
					target["health"] = minf(100, target["health"] + 30)
					target["hunger"] = minf(100, target["hunger"] + 20)
					remember(sim, target, "Otrzymuje pomoc od " + str(p["name"]))
					sim._finish(p, "Pomaga mieszkańcowi: " + str(target["name"]))
		"socializing", "learning":
			if p["progress"] >= 5:
				var target := find_person(sim, p["activity_target"])
				if target.is_empty() or not target["alive"] or p["position"].distance_to(target["position"]) > 70:
					sim._finish(p, "Rozmówca odszedł. Zaplanuj spotkanie z kimś w pobliżu.", false)
				elif p["phase"] == "learning" and target["age"] < 18:
					sim._finish(p, "Nauczycielem musi być dorosły.", false)
				else:
					p["relationships"][target["name"]] = mini(100, relation(p, target) + 15)
					target["relationships"][p["name"]] = mini(100, relation(target, p) + 15)
					p["social"] = minf(100, p["social"] + 35)
					target["social"] = minf(100, target["social"] + 20)
					if p["phase"] == "learning":
						var key := "building" if target["job"] == "Budowniczy" else "woodcutting" if target["job"] == "Drwal" else "foraging"
						if p["skills"][key]["level"] < target["skills"][key]["level"]:
							sim._award_xp(p, key, 5)
						sim._finish(p, "Uczy się od " + str(target["name"]) + ". XP rośnie tylko przy bardziej doświadczonym nauczycielu.")
					else:
						sim._finish(p, "Poznaje lepiej: " + str(target["name"]))
		"family":
			if p["progress"] >= 5:
				_family(sim, p)

func family_blocker(sim: RefCounted, p: Dictionary, other: Dictionary) -> String:
	if not options["births"]:
		return "Nowe ciąże są wyłączone."
	if other.is_empty() or not other["alive"] or other == p:
		return "Potrzebny jest żyjący partner (target)."
	if p["age"] < 18 or other["age"] < 18:
		return "Rodzinę mogą zakładać wyłącznie dorośli."
	if p["sex"] == other["sex"]:
		return "Narodziny w tej symulacji wymagają kobiety i mężczyzny."
	var ancestors_p := ancestors(sim, p, 3)
	var ancestors_other := ancestors(sim, other, 3)
	if ancestors_p.has(other["name"]) or ancestors_other.has(p["name"]):
		return "Bliskie pokrewieństwo wyklucza rodzicielstwo."
	for parent in ancestors_p:
		if ancestors_other.has(parent):
			return "Wspólni bliscy przodkowie wykluczają rodzicielstwo."
	if (p["partner"] != "" and p["partner"] != other["name"]) or (other["partner"] != "" and other["partner"] != p["name"]):
		return "Jedna z osób ma już partnera."
	if p["pregnancy"] > 0 or other["pregnancy"] > 0 or p["family_cooldown"] > 0 or other["family_cooldown"] > 0:
		return "Rodzina oczekuje dziecka lub odpoczywa po narodzinach."
	if relation(p, other) < 50 or relation(other, p) < 50:
		return "Relacja obu osób musi osiągnąć 50. Najpierw rozmowy."
	if not str(threat["kind"]).is_empty():
		return "Najpierw trzeba przetrwać zagrożenie."
	if free_beds(sim) < 1 or living(sim).size() + pregnancies(sim) >= int(options["population_limit"]):
		return "Brak miejsca na dziecko: zbuduj dom lub zwiększ limit populacji."
	if sim.stock["food"] < living(sim).size() * 2 + 4:
		return "Za mała rezerwa żywności dla nowej rodziny."
	for person in [p, other]:
		if person["health"] < 60 or person["hunger"] < 50 or person["rest"] < 40:
			return "Przyszli rodzice muszą być zdrowi, najedzeni i wypoczęci."
	return ""

func _family(sim: RefCounted, p: Dictionary) -> void:
	var other := find_person(sim, p["activity_target"])
	var blocker := family_blocker(sim, p, other)
	if not blocker.is_empty():
		sim._finish(p, blocker, false)
		return
	p["family_intent"] = other["name"]
	p["intent_until"] = sim.elapsed + float(options["day_seconds"])
	if other["family_intent"] != p["name"] or other["intent_until"] < sim.elapsed:
		sim._finish(p, "Proponuje rodzinę: " + str(other["name"]) + ". Potrzebna wzajemna decyzja AI w ciągu doby.")
		return
	p["partner"] = other["name"]
	other["partner"] = p["name"]
	var mother: Dictionary = p if p["sex"] == "F" else other
	mother["pregnancy"] = float(options["pregnancy_days"])
	mother["pregnancy_partner"] = other["name"] if mother == p else p["name"]
	p["family_intent"] = ""
	other["family_intent"] = ""
	remember(sim, other, "Wspólnie z " + str(p["name"]) + " zakłada rodzinę. Oczekują dziecka.")
	sim._finish(p, "Oboje decydują o założeniu rodziny. Rozpoczyna się oczekiwanie na dziecko.")

func _birth(sim: RefCounted, mother: Dictionary) -> void:
	var child_name := "Dziecko %d" % next_child
	while not find_person(sim, child_name).is_empty():
		next_child += 1
		child_name = "Dziecko %d" % next_child
	next_child += 1
	var child: Dictionary = sim.make_person(child_name, "Dziecko", "Ciekawski świata", mother["color"].lightened(0.15), mother["position"] + Vector2(20, 10))
	child["age"] = 0.0
	child["sex"] = "F" if next_child % 2 == 0 else "M"
	child["parents"] = [mother["name"], mother["pregnancy_partner"]]
	child["inventory"] = {"food": 0, "keepsake": "pamiątka od rodziców", "equipment": []}
	child["goal"] = "Dorastać, uczyć się i poznawać mieszkańców"
	sim.people.append(child)
	births += 1
	for parent_name in child["parents"]:
		var parent := find_person(sim, parent_name)
		if not parent.is_empty():
			parent["children"].append(child_name)
			parent["relationships"][child_name] = 80
			child["relationships"][parent_name] = 80
			parent["family_cooldown"] = 3.0
			remember(sim, parent, "Na świat przychodzi " + child_name + ".")
	mother["pregnancy_partner"] = ""
	assign_homes(sim)
	remember(sim, child, "Dołącza do osady. Rodzice: " + ", ".join(child["parents"]))

func snapshot_person(sim: RefCounted, p: Dictionary) -> Dictionary:
	var contacts: Array = []
	var candidates := living(sim).filter(func(other: Dictionary): return other != p)
	candidates.sort_custom(func(a: Dictionary, b: Dictionary): return p["position"].distance_squared_to(a["position"]) < p["position"].distance_squared_to(b["position"]))
	for other in candidates.slice(0, 3):
		contacts.append({"name": other["name"], "relation": relation(p, other), "adult": other["age"] >= 18, "sex": other["sex"], "job": other["job"], "available": ["idle", "resting", "warming", "waiting", "sheltering"].has(str(other["phase"]))})
	return {"adult": p["age"] >= 18, "sex": p["sex"], "health": roundi(p["health"]), "social": roundi(p["social"]),
		"has_bed": p["home"] >= 0, "partner": p["partner"], "pregnancy_days": snappedf(p["pregnancy"], 0.1),
		"goal": p["goal"], "nearby": contacts, "family_offer": _offers(sim, p)}

func _offers(sim: RefCounted, p: Dictionary) -> Array:
	var offers: Array = []
	for other in living(sim):
		if other["family_intent"] == p["name"] and other["intent_until"] >= sim.elapsed:
			offers.append(other["name"])
	return offers

func alerts(sim: RefCounted) -> Array[String]:
	var result: Array[String] = []
	if not str(threat["kind"]).is_empty():
		result.append("ALARM: %s • jeszcze %.0f s" % [threat_label(), threat["remaining"]])
	var count := living(sim).size()
	if sim.stock["food"] < count * 2:
		result.append("Małe zapasy jedzenia: cel minimum %d porcji." % (count * 2))
	if sim.houses * 4 < count:
		result.append("Brakuje %d miejsc w domach." % (count - sim.houses * 4))
	var injured := living(sim).filter(func(p: Dictionary): return p["health"] < 50).size()
	if injured > 0:
		result.append("Pomocy potrzebuje %d mieszkańców." % injured)
	if berries < 4:
		result.append("Jagody wyczerpane: uprawiaj pole lub poczekaj na odrost.")
	return result

func save_state() -> Dictionary:
	return {"options": options, "threat": threat, "next_threat": next_threat, "event_serial": event_serial,
		"berries": berries, "next_child": next_child, "births": births, "deaths": deaths, "days": days, "last_day": last_day}

func load_state(sim: RefCounted, data: Dictionary) -> void:
	configure(sim, data.get("options", {}))
	if data.get("threat") is Dictionary:
		var saved: Dictionary = data["threat"]
		if ["storm", "wolves"].has(str(saved.get("kind", ""))) and options["threats"]:
			threat = {"kind": saved["kind"], "remaining": clampf(float(saved.get("remaining", 0)), 0, 180), "strength": clampf(float(saved.get("strength", 0)), 0, 9)}
	next_threat = maxf(sim.elapsed, float(data.get("next_threat", sim.elapsed + 480)))
	event_serial = maxi(0, int(data.get("event_serial", 0)))
	berries = clampf(float(data.get("berries", 60)), 0, 60)
	next_child = maxi(1, int(data.get("next_child", 1)))
	births = maxi(0, int(data.get("births", 0)))
	deaths = maxi(0, int(data.get("deaths", 0)))
	days = maxf(0, float(data.get("days", sim.elapsed / float(options["day_seconds"])) ))
	last_day = maxi(0, int(data.get("last_day", int(days))))

func ancestors(sim: RefCounted, p: Dictionary, generations: int) -> Array:
	var result: Array = p["parents"].duplicate()
	if generations <= 1:
		return result
	for parent_name in p["parents"]:
		var parent := find_person(sim, parent_name)
		if not parent.is_empty():
			for name_value in ancestors(sim, parent, generations - 1):
				if not result.has(name_value):
					result.append(name_value)
	return result
