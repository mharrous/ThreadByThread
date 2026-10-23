extends SceneTree
## Genera icon.ico (16–256 px, PNG dentro de ICO) a partir de icon.svg, para el icono del .exe.
##   godot --headless --path . --script res://tools/make_icon.gd

const SIZES := [16, 24, 32, 48, 64, 128, 256]


func _init() -> void:
	var svg := FileAccess.get_file_as_string("res://icon.svg")
	var pngs: Array[PackedByteArray] = []
	for s in SIZES:
		var img := Image.new()
		img.load_svg_from_string(svg, s / 128.0)
		pngs.append(img.save_png_to_buffer())
	var out := PackedByteArray()
	out.resize(6 + 16 * SIZES.size())
	out.encode_u16(0, 0)
	out.encode_u16(2, 1)
	out.encode_u16(4, SIZES.size())
	var offset := out.size()
	for i in SIZES.size():
		var e := 6 + i * 16
		var s: int = SIZES[i]
		out[e] = s % 256
		out[e + 1] = s % 256
		out[e + 2] = 0
		out[e + 3] = 0
		out.encode_u16(e + 4, 1)
		out.encode_u16(e + 6, 32)
		out.encode_u32(e + 8, pngs[i].size())
		out.encode_u32(e + 12, offset)
		offset += pngs[i].size()
	for p in pngs:
		out.append_array(p)
	var f := FileAccess.open("res://icon.ico", FileAccess.WRITE)
	f.store_buffer(out)
	f.close()
	print("Icono: res://icon.ico (%d bytes)" % out.size())
	quit()
