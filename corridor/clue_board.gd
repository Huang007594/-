extends CanvasLayer
## Placeholder — adventure game clue board UI

signal closed
signal clue_added(clue_data: Dictionary)

func _ready():
	layer = 153
	hide()

func show_clue_board():
	show()

func add_clue(_clue_data: Dictionary):
	pass
