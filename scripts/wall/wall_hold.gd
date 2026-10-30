class_name WallHold
extends RefCounted
## One hold on a climbing wall. Each type asks for a different tactic:
## jug      big, easy, recharges your strength
## crimp    small target, drains fast
## sloper   big but you slip if your body is not under it or you move too fast
## pinch    drains fast but stops a swing dead
## pocket   tiny, one hand only
## top      the finish: get both hands on it

const TYPES := {
	"jug": {"radius": 12.0, "drain": -0.14},
	"crimp": {"radius": 7.0, "drain": 0.05},
	"sloper": {"radius": 10.0, "drain": 0.03},
	"pinch": {"radius": 8.0, "drain": 0.045},
	"pocket": {"radius": 6.0, "drain": 0.065},
	"top": {"radius": 14.0, "drain": 0.0},
}

var pos := Vector2.ZERO
var type := "jug"


func _init(at := Vector2.ZERO, kind := "jug") -> void:
	pos = at
	type = kind


func radius() -> float:
	return TYPES[type].radius


func drain() -> float:
	return TYPES[type].drain
