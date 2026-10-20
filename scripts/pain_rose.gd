extends Control
## The same painted rose is shared by activation and the persistent pawn pose.
const Art=preload("res://scripts/cinema/atlas.gd")
const Layout=preload("res://scripts/board_layout.gd")
const OFFSET=Vector2(-10,18)
const SIDE=90.0
var sprite:Control
var dormant=false
static func anchor(board,id):return Layout.pawn_center(id,id/3==board.mine)+OFFSET
static func paint(canvas,at,alpha=1.0,growth=1.0,angle=0.0):
	Art.draw_prop(canvas,"pain",at,SIDE,angle,alpha,Vector2.ONE*(.48+.52*growth))
static func install(board,pawn,target,pawn_sprite):
	var status=pawn.get("ongoing_effects",[]).filter(func(s):return s.key=="pain")
	if status.is_empty():return
	var e=board.view.get("animation",{})
	# Activation owns the rose until the matching, opaque final pose is reached.
	if e.get("style","")=="pain" and e.get("op","")=="activate" and e.get("action",{}).get("actor",-1)==pawn.id:return
	var node=load("res://scripts/pain_rose.gd").new()
	node.sprite=pawn_sprite;node.dormant=status[0].get("dormant",false)
	node.mouse_filter=Control.MOUSE_FILTER_IGNORE;node.size=target.size
	node.set_meta("persistent_pain",pawn.id);target.add_child(node)
func _ready():
	texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	queue_redraw()
func _process(_dt):queue_redraw()
func _draw():
	if not is_instance_valid(sprite):return
	# Follow the pawn's actual shake/lift transform, without inheriting its corpse tint.
	var at=sprite.get_transform()*Vector2(sprite.size.x*.5+OFFSET.x,59+OFFSET.y)
	paint(self,at,.70 if dormant else 1.0,1.0,sprite.rotation)
