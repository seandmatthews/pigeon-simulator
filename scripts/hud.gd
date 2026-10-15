extends CanvasLayer
## The game HUD's layer (T-119, safe-area half): on touch devices the whole
## readout column shifts into the display safe area, so no label, bar or globe
## sits under the notch or the home indicator in landscape. On desktop the
## safe area is the whole window — every inset computes to zero, the layer
## offset stays (0, 0) and the layout is byte-identical to the pre-touch HUD
## (pinned by the Gate 1b `touch_layer_desktop_inert` read of the default
## window). The T-087 return fade is a full-rect child and must keep covering
## the whole window despite the layer shift, so it alone is expanded back over
## the insets.

func _ready() -> void:
	_apply_safe_area()
	get_viewport().size_changed.connect(_apply_safe_area)


## Reads the safe area through TouchControls.canvas_safe_rect (the same
## window-pixels → canvas mapping the touch widgets lay out with) and shifts
## the layer by the top-left inset. Right/bottom insets need no shift — the
## HUD column is anchored top-left — but they widen the full-rect children's
## compensation below.
func _apply_safe_area() -> void:
	var viewport := get_viewport()
	var safe := TouchControls.canvas_safe_rect(viewport)
	var canvas := viewport.get_visible_rect().size
	var inset_left := maxf(safe.position.x, 0.0)
	var inset_top := maxf(safe.position.y, 0.0)
	var inset_right := maxf(canvas.x - safe.end.x, 0.0)
	var inset_bottom := maxf(canvas.y - safe.end.y, 0.0)
	offset = Vector2(inset_left, inset_top)
	for child in get_children():
		var rect := child as ColorRect
		if rect != null and rect.anchor_left == 0.0 and rect.anchor_top == 0.0 \
				and rect.anchor_right == 1.0 and rect.anchor_bottom == 1.0:
			rect.offset_left = -inset_left
			rect.offset_top = -inset_top
			rect.offset_right = inset_right
			rect.offset_bottom = inset_bottom
