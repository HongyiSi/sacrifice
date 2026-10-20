extends "res://scripts/session.gd"
## UI test adapter: dispatch both viewpoints through the production validator.
func act(kind: String, payload: Array = []) -> void:
	var error: String = Actions.apply(game,team,kind,payload,int(state.match),int(state.round),int(state.revision))
	assert(error.is_empty(),error)
	state = game.snapshot(team)
	state.names = names.duplicate()
	changed.emit()
