extends SceneTree
const Bridge = preload("res://scripts/ollama_bridge.gd")
var checks := 0
func check(condition: bool, label: String) -> void:
	if not condition:
		push_error("FAIL: " + label)
		quit(1)
		assert(condition, label)
	checks += 1
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var bridge := Bridge.new()
	bridge.auto_start = false
	root.add_child(bridge)
	var valid := '{"decisions":[{"name":"Mira","action":"gather_food","reason":"Zapas","next_actions":["eat","rest","build"]}]}'
	var answer: Dictionary = bridge._extract_decision_answer("```json\n" + valid + "\n```")
	check(answer["decisions"].size() == 1, "fenced response accepted")
	check(answer["decisions"][0]["next_actions"].size() == 2, "plan queue bounded")
	check(bridge._extract_decision_answer("garbage").is_empty(), "invalid JSON rejected quietly")
	answer = bridge._extract_decision_answer('{"decisions":[{"name":"Mira","action":"teleport"}]}')
	check(answer.get("decisions", []).is_empty(), "invalid actions never become work")
	var received: Array = []
	bridge.decisions_received.connect(func(decisions: Array): received.append_array(decisions))
	bridge.expected_names = ["Mira"]
	bridge.request_kind = "chat"
	var unknown := JSON.stringify({"message": {"content": '{"decisions":[{"name":"Unknown","action":"gather_food"}]}'}})
	bridge._on_api_request_completed(HTTPRequest.RESULT_SUCCESS, 200, PackedStringArray(), unknown.to_utf8_buffer())
	check(received.is_empty() and bridge.request_errors == 1, "unknown resident rejected")
	bridge.request_kind = "chat"
	bridge._on_api_request_completed(HTTPRequest.RESULT_SUCCESS, 200, PackedStringArray(), JSON.stringify({"message": {"content": valid}}).to_utf8_buffer())
	check(received.size() == 1 and bridge.last_valid_ms >= 0 and bridge.last_error.is_empty(), "valid response clears error")
	answer = bridge._extract_decision_answer('{"decisions":[{"name":"Mira","action":"start_family","target":"Olek","job":"Rolnik","goal":"Założyć rodzinę","next_actions":["socialize","farm"]}]}')
	check(answer["decisions"][0]["target"] == "Olek" and answer["decisions"][0]["job"] == "Rolnik", "family target and role preserved")
	check(answer["decisions"][0]["next_actions"] == ["farm"], "target-dependent action excluded from unqualified queue")
	# Exercise verified extraction on a worker, without downloading or executing a runtime.
	var zip_path := ProjectSettings.globalize_path("user://test_runtime.zip")
	var pack := ZIPPacker.new()
	check(pack.open(zip_path) == OK, "test archive created")
	pack.start_file("fixture.txt")
	pack.write_file("test runtime payload".to_utf8_buffer())
	pack.close_file()
	pack.close()
	var digest: String = bridge._sha256_file(zip_path)
	var worker := Thread.new()
	check(worker.start(bridge._verify_and_extract.bind(zip_path, digest)) == OK, "archive worker starts")
	var extracted: bool = worker.wait_to_finish()
	check(extracted and FileAccess.file_exists("user://wioska_ai_runtime/fixture.txt"), "worker verified and extracted archive")
	check(not FileAccess.file_exists(zip_path), "archive removed after extraction")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://wioska_ai_runtime/fixture.txt"))
	bridge.queue_free()
	await process_frame
	print("PASS bridge: ", checks, " assertions; validation, unknown names, bounded plans, background extraction")
	quit()
