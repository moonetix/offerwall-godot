extends Node
## Demo sign-in against the server in server/. Replace it with your own accounts.
## The game keeps only a random sign-in token. It never holds the link salt or any Moonetix key.

signal sign_in_finished(ok: bool)
signal signed_out

## Your server. Use https in release builds.
const SERVER_URL := "http://127.0.0.1:3000"
const SAVE_PATH := "user://moonetix_demo_session.json"

var token := ""


func _ready() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		var data = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
		if typeof(data) == TYPE_DICTIONARY and data.has("token"):
			token = str(data["token"])


func is_signed_in() -> bool:
	return token != ""


func auth_headers() -> PackedStringArray:
	return PackedStringArray(["Authorization: Bearer " + token])


## Creates a guest player. Call it only after the player confirmed they are 16 or older.
func create_player() -> void:
	var http := HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(_on_player_created.bind(http))
	var headers := PackedStringArray(["Content-Type: application/json"])
	var body := JSON.stringify({"age_confirmed": true})
	if http.request(SERVER_URL + "/api/players", headers, HTTPClient.METHOD_POST, body) != OK:
		http.queue_free()
		sign_in_finished.emit(false)


func _on_player_created(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray, http: HTTPRequest) -> void:
	http.queue_free()
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 201:
		sign_in_finished.emit(false)
		return
	var data = JSON.parse_string(body.get_string_from_utf8())
	if typeof(data) != TYPE_DICTIONARY or not data.has("token"):
		sign_in_finished.emit(false)
		return
	token = str(data["token"])
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify({"token": token}))
		file.close()
	sign_in_finished.emit(true)


## The server no longer knows the token, for example after a database reset.
func sign_out() -> void:
	token = ""
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	signed_out.emit()
