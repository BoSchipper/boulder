class_name FlowHold
extends RefCounted
## One hold on the flow wall. Its colour says which button catches it, and every
## type asks for something else: how exact your catch must be (seconds around the
## dead point), what hanging on it costs per second, and how much speed you keep.

const TYPES := {
	"jug": {"action": "flow_jug", "color": "5fbf5a", "pad": "A", "key": "Z", "drain": -0.18,
		"perfect": 0.07, "good": 0.15, "net": 0.24, "carry": 1.0},
	"crimp": {"action": "flow_crimp", "color": "4f8fe0", "pad": "X", "key": "X", "drain": 0.11,
		"perfect": 0.04, "good": 0.08, "net": 0.12, "carry": 1.0},
	"sloper": {"action": "flow_sloper", "color": "f2cf3a", "pad": "Y", "key": "V", "drain": 0.08,
		"perfect": 0.06, "good": 0.11, "net": 0.11, "carry": 0.6},  # no "net": too much speed and you slide off
	"pinch": {"action": "flow_pinch", "color": "e0533f", "pad": "B", "key": "C", "drain": 0.09,
		"perfect": 0.08, "good": 0.18, "net": 0.28, "carry": 0.0},  # forgiving, but it stops your swing
	"top": {"action": "flow_jug", "color": "ffe08a", "pad": "A", "key": "Z", "drain": 0.0,
		"perfect": 0.09, "good": 0.18, "net": 0.3, "carry": 0.0},
}

var pos: Vector2
var type: String
var data: Dictionary


func _init(at: Vector2, hold_type: String) -> void:
	pos = at
	type = hold_type
	data = TYPES[hold_type]
