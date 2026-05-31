extends CanvasLayer
## Placeholder — adventure game letter reader UI

signal closed
signal page_changed(page_index: int)

func _ready():
	layer = 152
	hide()

func load_letter(_title: String, _textures: Array, _notes: Array):
	show()
