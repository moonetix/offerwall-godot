extends Control
## Coin HUD and age check. The balance shown here always comes from your server.

@onready var coins_label: Label = $Margin/VBox/CoinsLabel
@onready var player_label: Label = $Margin/VBox/PlayerLabel
@onready var status_label: Label = $Margin/VBox/StatusLabel
@onready var earn_button: Button = $Margin/VBox/EarnButton

var age_dialog := ConfirmationDialog.new()


func _ready() -> void:
	age_dialog.title = "Before you earn"
	age_dialog.dialog_text = "Offers are for players 16 or older, with a parent's permission under 18.\nAre you 16 or older?"
	age_dialog.ok_button_text = "I am 16 or older"
	age_dialog.cancel_button_text = "No"
	age_dialog.confirmed.connect(PlayerSession.create_player)
	age_dialog.canceled.connect(_on_age_declined)
	add_child(age_dialog)

	Wallet.changed.connect(_on_wallet_changed)
	PlayerSession.sign_in_finished.connect(_on_sign_in_finished)
	PlayerSession.signed_out.connect(_ask_age)
	earn_button.message.connect(_show_status)

	if PlayerSession.is_signed_in():
		Wallet.refresh()
	else:
		_ask_age()


func _ask_age() -> void:
	coins_label.text = "Coins: -"
	player_label.text = ""
	age_dialog.popup_centered()


func _on_age_declined() -> void:
	_show_status("Offers are only for players 16 or older.")


func _on_sign_in_finished(ok: bool) -> void:
	if ok:
		Wallet.refresh()
	else:
		_show_status("Could not reach the game server. Try again later.")


func _on_wallet_changed(balance: String, currency: String, player_id: int) -> void:
	coins_label.text = "%s: %s" % [currency, balance]
	player_label.text = "Player ID %d" % player_id


func _show_status(text: String) -> void:
	status_label.text = text
