# EconomyManager.gd
# Tracks player cash balance and broadcasts changes via signal.

extends Node

signal cash_changed(amount: int)

var cash: int = 250  # Starting cash

func _ready() -> void:
	cash_changed.emit(cash)

func set_cash(amount: int) -> void:
	cash = maxi(0, amount)
	cash_changed.emit(cash)

func reset_for_new_session(starting_cash: int = 1500) -> void:
	cash = maxi(0, starting_cash)
	cash_changed.emit(cash)

func add_cash(amount: int, play_sound: bool = true) -> void:
	cash += amount
	if play_sound and amount > 0:
		AudioManager.play_economy("earn")
	cash_changed.emit(cash)

func deduct_cash(amount: int, play_sound: bool = true) -> bool:
	if Data.game_mode == "sandbox":
		cash = maxi(0, cash - amount)
		if play_sound and amount > 0:
			AudioManager.play_economy("spend")
		cash_changed.emit(cash)
		return true
	if cash >= amount:
		cash -= amount
		if play_sound and amount > 0:
			AudioManager.play_economy("spend")
		cash_changed.emit(cash)
		return true
	AudioManager.play_economy("insufficient")
	return false
