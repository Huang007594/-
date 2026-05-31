extends CanvasLayer
## Placeholder — adventure game inventory UI

signal item_selected(item_name: String)
signal closed

func _ready():
	layer = 151
	hide()

func show_inventory(_items: Array):
	show()
