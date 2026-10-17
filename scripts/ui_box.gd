extends StyleBox
class_name SlantBox
## Flat panel with a slanted right edge (menu tiles) or a clipped bottom-right corner (cards).

var color := Color("d8dbe3")
var slant := 0.0      # how far the bottom-right corner is pulled in (tiles)
var cut := 0.0        # size of the clipped bottom-right corner (cards)
var border := Color(0,0,0,0)
var border_width := 2.0

static func make(fill: Color, slant_px := 0.0, cut_px := 0.0, margin := Vector4(14,10,26,10)) -> SlantBox:
	var b := SlantBox.new()
	b.color = fill; b.slant = slant_px; b.cut = cut_px
	b.content_margin_left = margin.x; b.content_margin_top = margin.y
	b.content_margin_right = margin.z; b.content_margin_bottom = margin.w
	return b

func outline(c: Color, width := 2.0) -> SlantBox:
	border = c; border_width = width
	return self

func _points(r: Rect2) -> PackedVector2Array:
	var x0 := r.position.x; var y0 := r.position.y; var x1 := r.end.x; var y1 := r.end.y
	if cut > 0:
		return PackedVector2Array([Vector2(x0,y0),Vector2(x1,y0),Vector2(x1,y1-cut),Vector2(x1-cut,y1),Vector2(x0,y1)])
	return PackedVector2Array([Vector2(x0,y0),Vector2(x1,y0),Vector2(x1-slant,y1),Vector2(x0,y1)])

func _draw(to_canvas_item: RID, rect: Rect2) -> void:
	var pts := _points(rect)
	if color.a > 0:
		RenderingServer.canvas_item_add_polygon(to_canvas_item, pts, PackedColorArray([color]))
	if border.a > 0:
		var loop := pts.duplicate(); loop.append(pts[0])
		RenderingServer.canvas_item_add_polyline(to_canvas_item, loop, PackedColorArray([border]), border_width, true)
