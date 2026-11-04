extends SceneTree
const Sim = preload("res://scripts/simulation.gd")
var checks := 0
func check(condition: bool, label: String) -> void:
	if not condition:
		push_error("FAIL: " + label)
		quit(1)
		assert(condition, label)
	checks += 1
func advance(sim: RefCounted, seconds: float) -> void:
	for i in range(int(seconds / 0.05)):
		sim.step(0.05)
func command(sim: RefCounted, person: Dictionary, action: String) -> void:
	var count: int = sim.apply_decisions([{"name":person["name"], "action":action, "reason":"Test rozwoju"}], {person["name"]:person["revision"]})
	check(count == 1, "AI command accepted: " + action)
func _initialize() -> void:
	var sim := Sim.new()
	var p: Dictionary = sim.people[0]
	var initial_duration: float = sim.work_duration(p, "gather_food")
	for i in range(3):
		command(sim, p, "gather_food")
		advance(sim, 25)
	check(p["skills"]["foraging"]["level"] == 2 and p["skills"]["foraging"]["xp"] == 0, "three completed hauls produce level two")
	check(p["skills"]["woodcutting"]["level"] == 1 and p["skills"]["building"]["level"] == 1, "skills develop independently")
	check(sim.work_duration(p, "gather_food") < initial_duration, "level actually speeds work")
	check(is_equal_approx(sim.work_multiplier(p, "gather_food"), 1.08), "eight percent speed bonus")
	check(p["milestones"].size() == 1, "level milestone recorded")
	check(p["experience"]["delivered_food"] == 12, "personal delivery total recorded")
	check(p["knowledge"].has("food_source") and p["knowledge"].has("delivery"), "learned resource and delivery facts")
	check(not str(sim.memory_for_ai(p)["known_fact"]).is_empty(), "relevant learned fact included in AI context")
	check(p["experience"]["actions"]["gather_food"]["successes"] == 3, "successful jobs remembered")
	var before: String = JSON.stringify(p["skills"])
	command(sim, p, "eat")
	advance(sim, 5)
	check(JSON.stringify(p["skills"]) == before, "eating grants no work XP")
	p["inventory"]["food"] = 0
	sim.stock["food"] = 0
	command(sim, p, "eat")
	check(p["knowledge"].has("empty_food"), "failed meal creates permanent lesson")
	check(p["experience"]["actions"]["eat"]["failures"] == 1, "failure counted")
	check(sim.memory_for_ai(p)["lessons"].size() == 1, "lesson included in AI context")
	var snapshot: Array = sim.idle_snapshot()
	check(snapshot[0]["skills"]["foraging"] == 2 and snapshot[0]["memory"]["successful_jobs"]["gather_food"] == 3, "AI receives skills and experience")
	# A long session must not grow the prompt or discard learned facts.
	for i in range(45):
		command(sim, p, "wait")
		advance(sim, 6)
	check(p["episodes"].size() == 40 and p["memory"].size() == 12, "episodic memory bounded")
	check(p["knowledge"].has("empty_food") and p["experience"]["actions"]["gather_food"]["successes"] == 3, "long-term memory survives episode eviction")
	check(sim.memory_for_ai(p)["recent"].size() <= 2 and sim.memory_for_ai(p)["lessons"].size() <= 2, "prompt memory bounded")
	check(JSON.stringify(p["skills"]) == before, "waiting cannot farm XP")
	check(sim.save_game("user://test_progression.json"), "persistent progression saved")
	var restored := Sim.new()
	restored.load_game("user://test_progression.json")
	var r: Dictionary = restored.people[0]
	check(r["skills"] == p["skills"] and r["knowledge"] == p["knowledge"] and r["experience"] == p["experience"], "skills and long-term memory round trip")
	check(r["episodes"].size() == 40 and r["milestones"].size() == 1, "episodes and milestones round trip")
	var legacy := {"version":2, "residents":[{"name":"Mira", "skill_level":4, "skill_xp":2, "memory":["Dawne wspomnienie"]}]}
	var file := FileAccess.open("user://test_legacy_progression.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(legacy))
	file.close()
	var migrated := Sim.new()
	migrated.load_game("user://test_legacy_progression.json")
	check(migrated.people[0]["skills"]["foraging"]["level"] == 4, "old level migrated to job specialty")
	check(migrated.people[0]["episodes"][0]["text"] == "Dawne wspomnienie", "old memory preserved")
	# Validate cap without hundreds of full walks.
	sim._award_xp(p, "foraging", 100000)
	check(p["skills"]["foraging"]["level"] == 10 and p["skills"]["foraging"]["xp"] == 0, "skill level capped")
	check(is_equal_approx(sim.work_multiplier(p, "gather_food"), 1.72), "work bonus capped at 72 percent")
	var timed := Sim.new()
	var novice: Dictionary = timed.people[0]
	var expert: Dictionary = timed.people[1]
	expert["skills"]["foraging"]["level"] = 10
	novice["position"] = timed._spot(novice, "food")
	expert["position"] = timed._spot(expert, "food")
	command(timed, novice, "gather_food")
	command(timed, expert, "gather_food")
	timed.step(0.05)
	advance(timed, 1.25)
	check(novice["cargo_food"] == 0 and expert["cargo_food"] == 2, "experienced NPC actually gathers faster in simulation")
	print("PASS progression: ", checks, " assertions; learning, per-skill XP, speed, persistence, migration and bounded context")
	quit()
