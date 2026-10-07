# EconomyManager.gd
# Tracks player cash balance and broadcasts changes via signal.

extends Node

signal cash_changed(amount: int)

var cash: int = 250  # Starting cash

func _ready() -> void:
	cash_changed.emit(cash)

func add_cash(amount: int) -> void:
	cash += amount
	cash_changed.emit(cash)

func deduct_cash(amount: int) -> bool:
	if cash >= amount:
		cash -= amount
		cash_changed.emit(cash)
		return true
	AudioManager.play_ui("error")
	return false
