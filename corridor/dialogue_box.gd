extends CanvasLayer
## Placeholder — adventure game dialogue UI

signal option_selected(option_index: int)

func _ready():
	layer = 150
	hide()

func show_dialogue(_character_avatar, _character_name: String, _dialogue_text: String, _options: Array):
	show()
