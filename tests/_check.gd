extends SceneTree
func _init():
	for f in ["motore","ia","disegno","carta_token","vassoio","stato_giocatore","arena3d","main"]:
		var s = load("res://scripts/%s.gd" % f)
		print(f, " ", s != null and s.can_instantiate())
	quit()
