extends SceneTree
const Sim = preload("res://scripts/simulation.gd")
var checks := 0
var failures := 0
func check(condition: bool, label: String) -> void:
	if not condition:
		push_error("FAIL: " + label)
		failures += 1
	checks += 1

func plan(sim: RefCounted, index: int, action: String, target: String = "") -> void:
	var p: Dictionary = sim.people[index]
	check(sim.apply_decisions([{"name": p["name"], "action": action, "target": target, "reason": "Test"}], {p["name"]: p["revision"]}) == 1, "accept " + action)

func advance(sim: RefCounted, seconds: float) -> void:
	for step in range(int(seconds / 0.05)):
		sim.step(0.05)

func _initialize() -> void:
	var sim := Sim.new()
	sim.life.options["threats"] = false
	check(sim.people[4]["home"] == -1 and sim.life.free_beds(sim) == 0, "initial crowding requires another house")
	check(not sim.life.family_blocker(sim, sim.people[0], sim.people[1]).is_empty(), "family requires relationship and housing")
	sim.houses = 2
	sim.stock["food"] = 60
	sim.life.assign_homes(sim)
	check(sim.life.free_beds(sim) == 3, "completed house adds four usable places")
	for p in sim.people:
		p["position"] = Vector2(315, 440)
	plan(sim, 0, "socialize", "Olek")
	advance(sim, 6)
	check(sim.people[0]["relationships"]["Olek"] == 35 and sim.people[1]["relationships"]["Mira"] == 35, "conversation builds reciprocal trust")
	plan(sim, 1, "socialize", "Mira")
	advance(sim, 6)
	check(sim.people[0]["relationships"]["Olek"] == 50, "second meeting reaches family threshold")
	plan(sim, 0, "start_family", "Olek")
	advance(sim, 7)
	check(sim.people[0]["pregnancy"] == 0 and sim.people[0]["family_intent"] == "Olek", "one decision cannot create pregnancy")
	check(sim.life.snapshot_person(sim, sim.people[1])["family_offer"].has("Mira"), "reciprocal offer reaches AI")
	plan(sim, 1, "start_family", "Mira")
	advance(sim, 7)
	check(sim.people[0]["pregnancy"] > 2.9 and sim.people[0]["partner"] == "Olek", "two adult decisions create family")
	check(sim.life.free_beds(sim) == 2, "pregnancy reserves bed")
	var save_path := "user://test_life_v4.json"
	check(sim.save_game(save_path), "save family before birth")
	var restored := Sim.new()
	restored.load_game(save_path)
	check(restored.people[0]["pregnancy"] > 2.9 and restored.people[0]["partner"] == "Olek", "pregnancy and partner survive restart")
	check(is_equal_approx(restored.life.days, sim.life.days) and restored.life.options["threats"] == false, "world clock and options persist")
	advance(restored, 722)
	check(restored.people.size() == 6 and restored.life.births == 1, "pregnancy produces exactly one child")
	var child: Dictionary = restored.people[5]
	check(child["age"] < 1 and child["parents"] == ["Mira", "Olek"], "child has age and parents")
	check(restored.people[0]["children"].has(child["name"]) and child["home"] >= 0, "parent links and housing assigned")
	plan(restored, 5, "gather_wood")
	check(child["phase"] == "idle" and child["last_result"].contains("Dziecko"), "child cannot work dangerous jobs")
	plan(restored, 5, "start_family", "Tomasz")
	check(child["pregnancy"] == 0 and child["phase"] == "idle", "child cannot reproduce")
	check(restored.save_game(save_path), "save expanded population")
	var expanded := Sim.new()
	expanded.load_game(save_path)
	check(expanded.people.size() == 6 and expanded.people[5]["parents"].size() == 2, "dynamic residents survive reload")
	check(expanded.people[5]["color"].to_html() == child["color"].to_html(), "new resident appearance persists")
	expanded.life.tick_world(expanded, float(expanded.life.options["day_seconds"]) * 12)
	check(expanded.people[5]["age"] >= 18 and expanded.people[5]["job"] == "Uczeń", "child grows into adult")
	check(not expanded.life.family_blocker(expanded, expanded.people[5], expanded.people[0]).is_empty(), "parent-child family rejected")
	var cap_sim := Sim.new()
	cap_sim.houses = 3
	cap_sim.stock["food"] = 100
	cap_sim.people[0]["relationships"]["Olek"] = 80
	cap_sim.people[1]["relationships"]["Mira"] = 80
	cap_sim.life.configure(cap_sim, {"population_limit": 5})
	check(cap_sim.life.family_blocker(cap_sim, cap_sim.people[0], cap_sim.people[1]).contains("limit"), "population limit blocks new pregnancy")
	cap_sim.life.configure(cap_sim, {"population_limit": 20, "births": false})
	check(cap_sim.life.family_blocker(cap_sim, cap_sim.people[0], cap_sim.people[1]).contains("wyłączone"), "birth setting enforced")
	var farm := Sim.new()
	farm.life.berries = 0
	plan(farm, 0, "gather_food")
	advance(farm, 12)
	check(farm.delivered["food"] == 0 and farm.people[0]["last_result"].contains("wyczerpane"), "empty food source fails with actionable reason")
	plan(farm, 0, "farm")
	advance(farm, 15)
	check(farm.stock["food"] == 16, "farm cannot teleport food before delivery")
	advance(farm, 12)
	check(farm.stock["food"] == 20 and farm.stock["wood"] == 17, "farm crop delivered with exact input cost")
	var hazard := Sim.new()
	hazard.people[0]["position"] = hazard._spot(hazard.people[0], "home")
	hazard.people[0]["warmth"] = 70
	hazard.people[1]["warmth"] = 70
	check(hazard.life.trigger_threat(hazard, "storm"), "storm triggered")
	check(not hazard.life.trigger_threat(hazard, "wolves"), "no overlapping events")
	advance(hazard, 10)
	check(hazard.people[0]["warmth"] > hazard.people[1]["warmth"] + 3, "house physically protects against cold")
	check(hazard.people[1]["episodes"].back()["text"].contains("burza"), "threat remembered by NPC")
	hazard.life.configure(hazard, {"threats": false})
	check(hazard.life.threat["kind"] == "", "disabling events ends current hazard")
	hazard.life.configure(hazard, {"threats": true})
	hazard.life.trigger_threat(hazard, "wolves")
	plan(hazard, 1, "guard")
	advance(hazard, 20)
	check(hazard.life.threat["kind"] == "" and hazard.stock["food"] == 16, "guard repels wolves before stock loss")
	var unguarded := Sim.new()
	unguarded.life.trigger_threat(unguarded, "wolves")
	advance(unguarded, 91)
	check(unguarded.stock["food"] == 13, "unguarded wolves consume bounded food")
	var healing := Sim.new()
	healing.people[1]["health"] = 20
	healing.people[1]["position"] = Vector2(185, 235)
	plan(healing, 0, "heal", "Olek")
	advance(healing, 8)
	check(healing.people[1]["health"] < 21, "healing not applied across map")
	advance(healing, 12)
	check(healing.people[1]["health"] > 49 and healing.stock["food"] == 14, "physical treatment uses exactly two food")
	check(healing.people[0]["medical_food"] == 0, "medical cargo consumed once")
	var mortality := Sim.new()
	mortality.people[0]["health"] = 1
	mortality.people[0]["hunger"] = 0
	advance(mortality, 10)
	check(mortality.people[0]["alive"] and mortality.people[0]["health"] == 1, "default prevents permanent death")
	mortality.life.configure(mortality, {"mortality": true})
	advance(mortality, 10)
	check(not mortality.people[0]["alive"] and mortality.life.deaths == 1, "optional mortality records one death")
	check(mortality.idle_snapshot().size() == 4, "dead residents excluded from AI plans")
	mortality.save_game(save_path)
	var dead_save := Sim.new()
	dead_save.load_game(save_path)
	check(not dead_save.people[0]["alive"] and dead_save.people[0]["phase"] == "dead", "death persists across restart")
	var stale := Sim.new()
	var revision: int = stale.people[0]["revision"]
	stale.life.trigger_threat(stale, "storm")
	check(stale.apply_decisions([{"name": "Mira", "action": "wait"}], {"Mira": revision}) == 0, "pre-alarm response rejected")
	var learning := Sim.new()
	learning.people[0]["age"] = 7.0
	learning.people[1]["skills"]["foraging"]["level"] = 3
	plan(learning, 0, "learn", "Olek")
	advance(learning, 7)
	check(learning.people[0]["skills"]["foraging"]["xp"] == 5, "child learns from experienced adult")
	var hauling := Sim.new()
	plan(hauling, 0, "gather_wood")
	advance(hauling, 7)
	check(hauling.people[0]["phase"] != "idle", "haul active before alert")
	hauling.life.trigger_threat(hauling, "storm")
	advance(hauling, 12)
	check(hauling.delivered["wood"] == 4, "alarm preserves physical delivery already in progress")
	var medical := Sim.new()
	medical.people[0]["position"] = medical._spot(medical.people[0], "storage")
	medical.people[1]["position"] = Vector2(100, 100)
	medical.people[1]["health"] = 20
	plan(medical, 0, "heal", "Olek")
	advance(medical, 6.2)
	check(medical.people[0]["medical_food"] == 2 and medical.stock["food"] == 14, "medical supplies physically withdrawn before travel")
	medical.save_game(save_path)
	var treatment_resume := Sim.new()
	treatment_resume.load_game(save_path)
	advance(treatment_resume, 20)
	check(treatment_resume.people[1]["health"] >= 50 and treatment_resume.stock["food"] == 14, "resume treatment does not charge twice")
	var big := Sim.new()
	big.houses = 5
	big.life.options["threats"] = false
	for i in range(15):
		big.people.append(big.make_person("Nowy %d" % i, "Zbieracz", "Spokojny", Color("9aac70"), Vector2(350, 400)))
	var decisions: Array = []
	var revisions: Dictionary = {}
	for p in big.people:
		decisions.append({"name": p["name"], "action": "gather_wood"})
		revisions[p["name"]] = p["revision"]
	check(big.apply_decisions(decisions, revisions) == 20, "20 residents can receive plans")
	var start_us := Time.get_ticks_usec()
	advance(big, 60)
	var runtime_ms := float(Time.get_ticks_usec() - start_us) / 1000
	check(big.delivered["wood"] == 80, "20 simultaneous hauls preserve resource accounting")
	check(big.idle_snapshot().size() == 20, "all 20 jobs finish without deadlock")
	print("20 NPC / 1200 fixed steps: ", snappedf(runtime_ms, 0.1), " ms on this test host (no model)")
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(save_path + suffix):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path + suffix))
	print("PASS village life: ", checks, " assertions; family consent, childhood, population persistence, resource limits, danger, defense, healing and death")
	quit(1 if failures > 0 else 0)
