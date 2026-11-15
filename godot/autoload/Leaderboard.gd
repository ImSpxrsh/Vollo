extends Node

signal account_changed
signal score_posted(best: int, rank: int)

const SERVER_URL := "https://pzovpbbymphyxqryqlre.supabase.co"
const SERVER_KEY := "sb_publishable_HR4kXmr5lL6G81x1HAFnXw_DlUNpUhs"
const ACCOUNT_PATH := "user://account.cfg"
const TIMEOUT := 10.0

const ERRORS := {
	"bad_name": "Names are 3-16 letters, numbers or _",
	"short_password": "Password needs at least 4 characters",
	"name_taken": "That name is taken",
	"bad_login": "Wrong name or password",
	"bad_token": "Signed out, please log in again",
	"bad_score": "Score rejected",
}

var server_url := SERVER_URL
var server_key := SERVER_KEY
var token := ""
var username := ""
var online_best := 0
var online_rank := 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var env_url := OS.get_environment("VOLL_LEADERBOARD_URL")
	if not env_url.is_empty():
		server_url = env_url
		server_key = OS.get_environment("VOLL_LEADERBOARD_KEY")
	_load_account()
	GameManager.run_over.connect(_on_run_over)
	if is_logged_in():
		refresh_me()

func is_configured() -> bool:
	return not server_url.is_empty()

func is_logged_in() -> bool:
	return not token.is_empty()

func register(user_name: String, password: String) -> Dictionary:
	var res := await _rpc("voll_register", {"p_username": user_name.strip_edges(), "p_password": password})
	return await _after_login(res)

func login(user_name: String, password: String) -> Dictionary:
	var res := await _rpc("voll_login", {"p_username": user_name.strip_edges(), "p_password": password})
	return await _after_login(res)

func logout() -> void:
	if is_logged_in():
		_rpc("voll_logout", {"p_token": token})
	token = ""
	username = ""
	online_best = 0
	online_rank = 0
	_save_account()
	account_changed.emit()

func refresh_me() -> Dictionary:
	if not is_logged_in():
		return {"ok": false, "error": "Not logged in"}
	var res := await _rpc("voll_me", {"p_token": token})
	_apply_profile(res)
	return res

func submit(score: int) -> Dictionary:
	if not is_logged_in():
		return {"ok": false, "error": "Not logged in"}
	var res := await _rpc("voll_submit", {"p_token": token, "p_score": score, "p_variety": SaveManager.selected_variety})
	_apply_profile(res)
	if res.ok:
		score_posted.emit(online_best, online_rank)
	return res

func top(limit := 20) -> Dictionary:
	return await _rpc("voll_top", {"p_limit": limit})

func _after_login(res: Dictionary) -> Dictionary:
	if not res.ok:
		return res
	_apply_profile(res)
	if SaveManager.high_score > online_best:
		await submit(SaveManager.high_score)
	return res

func _apply_profile(res: Dictionary) -> void:
	if not res.ok:
		if res.get("code", "") == "bad_token":
			logout()
		return
	var data: Variant = res.data
	if typeof(data) != TYPE_DICTIONARY:
		return
	token = String(data.get("token", token))
	username = String(data.get("username", username))
	online_best = int(data.get("best", 0))
	var rank: Variant = data.get("rank")
	online_rank = int(rank) if rank != null else 0
	_save_account()
	account_changed.emit()

func _on_run_over(distance: int, _best: int, _is_new_best: bool, _bounces: int) -> void:
	if GameManager.versus or GameManager.is_custom_run() or not is_logged_in() or distance <= online_best:
		return
	submit(distance)

func _rpc(fn: String, args: Dictionary) -> Dictionary:
	if not is_configured():
		return {"ok": false, "code": "offline", "error": "Online leaderboard isn't set up yet"}
	var http := HTTPRequest.new()
	http.timeout = TIMEOUT
	http.accept_gzip = false
	add_child(http)
	var headers := PackedStringArray(["Content-Type: application/json", "Accept: application/json"])
	if not server_key.is_empty():
		headers.append("apikey: " + server_key)
		if server_key.begins_with("eyJ"):
			headers.append("Authorization: Bearer " + server_key)
	var url := server_url.trim_suffix("/") + "/rest/v1/rpc/" + fn
	var err := http.request(url, headers, HTTPClient.METHOD_POST, JSON.stringify(args))
	if err != OK:
		http.queue_free()
		return {"ok": false, "code": "net", "error": "Couldn't reach the leaderboard"}
	var reply: Array = await http.request_completed
	http.queue_free()
	var result: int = reply[0]
	var status: int = reply[1]
	var body := (reply[3] as PackedByteArray).get_string_from_utf8()
	if result != HTTPRequest.RESULT_SUCCESS:
		return {"ok": false, "code": "net", "error": "Couldn't reach the leaderboard"}
	var data: Variant = JSON.parse_string(body) if not body.is_empty() else null
	if status >= 200 and status < 300:
		return {"ok": true, "data": data}
	var code := ""
	if typeof(data) == TYPE_DICTIONARY:
		code = String(data.get("message", ""))
	return {"ok": false, "code": code, "error": String(ERRORS.get(code, "Server error (%d)" % status))}

func _load_account() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(ACCOUNT_PATH) != OK:
		return
	token = String(cfg.get_value("account", "token", ""))
	username = String(cfg.get_value("account", "username", ""))
	online_best = int(cfg.get_value("account", "best", 0))
	online_rank = int(cfg.get_value("account", "rank", 0))

func _save_account() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("account", "token", token)
	cfg.set_value("account", "username", username)
	cfg.set_value("account", "best", online_best)
	cfg.set_value("account", "rank", online_rank)
	cfg.save(ACCOUNT_PATH)
