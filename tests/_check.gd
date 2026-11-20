extends SceneTree
func _init():
	for f in ["motore","ia","generatore","disegno","carta_token","vassoio","stato_giocatore","arena3d","main"]:
		var s = load("res://scripts/%s.gd" % f)
		print(f, " ", s != null and s.can_instantiate())
	for f in ["regole_test","bilancia","screenshots"]:
		print(f, " ", load("res://tests/%s.gd" % f) != null)
	quit()
