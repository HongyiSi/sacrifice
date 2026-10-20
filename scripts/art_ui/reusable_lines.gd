extends RefCounted
# Polyline geometry adapted from Godot 4.7.1 renderer_canvas_cull.cpp.
# Copyright (c) 2014-present Godot Engine contributors (see AUTHORS.md).
# Copyright (c) 2007-2014 Juan Linietsky, Ariel Manzur.
# 
# Permission is hereby granted, free of charge, to any person obtaining
# a copy of this software and associated documentation files (the
# "Software"), to deal in the Software without restriction, including
# without limitation the rights to use, copy, modify, merge, publish,
# distribute, sublicense, and/or sell copies of the Software, and to
# permit persons to whom the Software is furnished to do so, subject to
# the following conditions:
# 
# The above copyright notice and this permission notice shall be
# included in all copies or substantial portions of the Software.
# 
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
# IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
# CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
# TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
# SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
## Reuses mesh buffers for animated antialiased lines. CanvasItem's polyline
## commands rebuild GPU polygons on every redraw (costly on Safari/WebGL).
## Geometry follows Godot's CanvasItem feathered polyline, including end caps.
var canvas: CanvasItem
var meshes: Array[ArrayMesh] = []
var counts: Array[int] = []
var cursor := 0
var shapes: Dictionary = {}
var tint := Color.WHITE

func begin(target: CanvasItem) -> void:
	canvas = target
	cursor = 0

func finish() -> void:
	meshes.resize(cursor)
	counts.resize(cursor)
	for key in shapes.keys():
		if key >= cursor: shapes.erase(key)
	canvas = null

func draw_polyline(points: PackedVector2Array, color: Color, width: float, aa: bool) -> void:
	var start := cursor
	var cached: Dictionary = shapes.get(start,{})
	if cached.get("points") == points and cached.get("width") == width and cached.get("aa") == aa:
		for i in range(cached.count):
			canvas.draw_mesh(meshes[cursor],null,Transform2D.IDENTITY,color)
			cursor += 1
		return
	tint = color
	draw_polyline_colors(points, PackedColorArray([Color.WHITE]), width, aa)
	tint = Color.WHITE
	shapes[start] = {"points":points,"width":width,"aa":aa,"count":cursor-start}

func draw_polyline_colors(line: PackedVector2Array, colors: PackedColorArray, width: float, aa: bool) -> void:
	if line.size() < 2: return
	# Godot 4.7 compensates the line's core width before adding its feather.
	if aa and width > 0.0:
		if width <= 2.50001: width *= .5
		elif width <= 5.00001: width = remap(width, 2.5, 5.0, width*.5, width-.625)
		else: width -= .625
	var loop := line[0].is_equal_approx(line[-1])
	var first := Vector2.ZERO
	var last := Vector2.ZERO
	for i in range(1, line.size()):
		first = (line[i] - line[i-1]).normalized()
		if not first.is_zero_approx(): break
	for i in range(line.size()-1, 0, -1):
		last = (line[i] - line[i-1]).normalized()
		if not last.is_zero_approx(): break
	var caps := aa and not loop
	var n := line.size()*2
	var middle := PackedVector2Array(); middle.resize(n + (4 if caps else 0))
	var left := PackedVector2Array(); left.resize(n + (5 if caps else 0))
	var right := left.duplicate()
	var mc := PackedColorArray(); mc.resize(middle.size())
	var lc := PackedColorArray(); lc.resize(left.size())
	var rc := lc.duplicate()
	var feather := 1.25 * minf(width, 1.0)
	var previous := Vector2.ZERO
	var color := Color.WHITE
	for i in range(line.size()):
		var direction := previous if i == line.size()-1 else (line[i+1]-line[i]).normalized()
		if direction.is_zero_approx(): direction = previous
		if i == 0 and loop: previous = last
		elif i == line.size()-1 and loop: previous = first
		var base: Vector2
		if not loop and i == 0: base = first.orthogonal()
		elif not loop and i == line.size()-1: base = last.orthogonal()
		else:
			base = (previous*direction.length()-direction*previous.length()).normalized()
			var angle := atan2(base.cross(previous), base.dot(previous))
			if not is_zero_approx(sin(angle)) and not direction.is_equal_approx(previous):
				base *= clampf(1.0/sin(angle), -3.0, 3.0)
			else: base = direction.orthogonal()
			if base.is_zero_approx(): base = direction.orthogonal()
		var edge := base*width*.5
		var border := base*feather
		var pos := line[i]
		var j := i*2 + (2 if caps else 0)
		if i < colors.size(): color = colors[i]
		var clear := Color(color, 0.0)
		middle[j]=pos+edge; middle[j+1]=pos-edge
		mc[j]=color; mc[j+1]=color
		left[j]=pos+edge; left[j+1]=pos+edge+border
		lc[j]=color; lc[j+1]=clear
		right[j]=pos-edge; right[j+1]=pos-edge-border
		rc[j]=color; rc[j+1]=clear
		if caps and i == 0:
			var back := -direction*feather
			middle[0]=pos+edge+back; middle[1]=pos-edge+back
			left[0]=pos+edge+back; left[1]=pos+edge+back+border
			right[0]=pos-edge+back; right[1]=pos-edge+back-border
			mc[0]=clear; mc[1]=clear; lc[0]=clear; lc[1]=clear; rc[0]=clear; rc[1]=clear
		if caps and i == line.size()-1:
			var forward := previous*feather
			middle[n+2]=pos+edge+forward; middle[n+3]=pos-edge+forward
			mc[n+2]=clear; mc[n+3]=clear
			left[n+2]=pos+edge; left[n+3]=pos+edge+forward+border; left[n+4]=pos+edge+forward
			right[n+2]=pos-edge; right[n+3]=pos-edge+forward-border; right[n+4]=pos-edge+forward
			lc[n+2]=color; lc[n+3]=clear; lc[n+4]=clear
			rc[n+2]=color; rc[n+3]=clear; rc[n+4]=clear
		previous = direction
	if aa:
		# Degenerate connectors retain strip ordering without three draw calls.
		middle.append(middle[-1]); middle.append(left[0])
		mc.append(mc[-1]); mc.append(lc[0])
		middle.append_array(left); mc.append_array(lc)
		middle.append(middle[-1]); middle.append(right[0])
		mc.append(mc[-1]); mc.append(rc[0])
		middle.append_array(right); mc.append_array(rc)
	_strip(middle, mc)

func _strip(points: PackedVector2Array, colors: PackedColorArray) -> void:
	shapes.erase(cursor)
	if cursor == meshes.size():
		meshes.append(ArrayMesh.new()); counts.append(0)
	var mesh := meshes[cursor]
	if counts[cursor] != points.size():
		mesh.clear_surfaces()
		var arrays := []; arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX]=points; arrays[Mesh.ARRAY_COLOR]=colors
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLE_STRIP, arrays, [], {}, Mesh.ARRAY_FLAG_USE_2D_VERTICES | Mesh.ARRAY_FLAG_USE_DYNAMIC_UPDATE)
		# Animated vertices may move beyond the initial bounds; cards are tiny.
		mesh.custom_aabb = AABB(Vector3(-4096,-4096,-1), Vector3(8192,8192,2))
		counts[cursor]=points.size()
	else:
		mesh.surface_update_vertex_region(0, 0, points.to_byte_array())
		var bytes := PackedByteArray(); bytes.resize(colors.size()*4)
		for i in range(colors.size()):
			bytes[i*4]=colors[i].r8; bytes[i*4+1]=colors[i].g8
			bytes[i*4+2]=colors[i].b8; bytes[i*4+3]=colors[i].a8
		mesh.surface_update_attribute_region(0, 0, bytes)
	canvas.draw_mesh(mesh, null, Transform2D.IDENTITY, tint)
	cursor += 1

func draw_line(a: Vector2, b: Vector2, color: Color, width: float, aa: bool) -> void:
	canvas.draw_line(a,b,color,width,aa)
func draw_circle(center: Vector2, radius: float, color: Color) -> void:
	var cached: Dictionary = shapes.get(cursor,{})
	if cached.get("center") == center and cached.get("radius") == radius:
		canvas.draw_mesh(meshes[cursor],null,Transform2D.IDENTITY,color)
		cursor += 1
		return
	var points := PackedVector2Array()
	for i in range(64): points.append(center+Vector2(cos(i*TAU/64),sin(i*TAU/64))*radius)
	draw_colored_polygon(points,color)
	shapes[cursor-1].center=center; shapes[cursor-1].radius=radius
func draw_colored_polygon(points: PackedVector2Array, color: Color) -> void:
	var cached: Dictionary = shapes.get(cursor,{})
	if cached.get("points") == points and cached.get("polygon",false):
		canvas.draw_mesh(meshes[cursor],null,Transform2D.IDENTITY,color)
		cursor += 1
		return
	if cursor == meshes.size(): meshes.append(ArrayMesh.new()); counts.append(0)
	var mesh := meshes[cursor]; mesh.clear_surfaces()
	var arrays := []; arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX]=points
	arrays[Mesh.ARRAY_INDEX]=Geometry2D.triangulate_polygon(points)
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays,[],{},Mesh.ARRAY_FLAG_USE_2D_VERTICES)
	counts[cursor] = -1
	shapes[cursor] = {"points":points,"polygon":true}
	canvas.draw_mesh(mesh,null,Transform2D.IDENTITY,color)
	cursor += 1
