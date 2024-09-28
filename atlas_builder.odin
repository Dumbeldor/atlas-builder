// By Karl Zylinski, http://zylinski.se -- Support me at https://www.patreon.com/karl_zylinski
//
// See README.md for documentation.

package atlas_builder

import "core:fmt"
import "core:os"
import "core:path/slashpath"
import "core:slice"
import "core:strings"
import "core:time"
import "core:c"
import "base:runtime"
import "core:unicode/utf8"
import "core:image/png"
import "vendor:stb/rect_pack"
import "vendor:stb/image"
import ase "aseprite"
import rl "vendor:raylib"

// Size of atlas in NxN pixels. Note: The outputted atlas PNG is cropped to the visible pixels.
ATLAS_SIZE :: 512

// Path to output final atlas PNG to
ATLAS_PNG_OUTPUT_PATH :: "atlas.png"

// Path to output atlas Odin metadata file to. Compile this as part of your game to get metadata
// about where in atlas your textures etc are.
ATLAS_ODIN_OUTPUT_PATH :: "atlas.odin"

// Set to false to not crop atlas after generation.
ATLAS_CROP :: true

// If you have a tileset (texture with tileset_) prefix, then this is says how many tiles wide it is
TILESET_WIDTH :: 10

// The NxN pixel size of each tile.
TILE_SIZE :: 8

// for package line at top of atlas Odin metadata file
PACKAGE_NAME :: "game"

// The folder within which to look for textures
TEXTURES_DIR :: "textures"

// The letters to extract from the font
LETTERS_IN_FONT :: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz1234567890?!&.,_:[]-+"

// The font to extract letters from
FONT_FILENAME :: "font.ttf"

// The font size of letters extracted from font
FONT_SIZE :: 32

Vec2i :: [2]int

Rect :: rl.Rectangle
Color :: [4]u8

Atlas_Texture_Rect :: struct {
	rect: Rect,
	size: Vec2i,
	offset_top: int,
	offset_right: int,
	offset_bottom: int,
	offset_left: int,
	name: string,
	duration: f32,
}

Atlas_Tile_Rect :: struct {
	rect: Rect,
	coord: Vec2i,
}

Atlas_Glyph :: struct {
	rect: Rect,
	glyph: rl.GlyphInfo,
}

asset_name :: proc(path: string) -> string {
	return fmt.tprintf("%s", strings.to_ada_case(slashpath.name(slashpath.base(path)), context.temp_allocator))
}

Texture_Data :: struct {
	source_size: Vec2i,
	source_offset: Vec2i,
	document_size: Vec2i,
	offset: Vec2i,
	name: string,
	pixels_size: Vec2i,
	pixels: []Color,
	duration: f32,
	is_tile: bool,
	tile_coord: Vec2i,
}

rect_intersect :: proc(r1, r2: Rect) -> Rect {
	x1 := max(r1.x, r2.x)
	y1 := max(r1.y, r2.y)
	x2 := min(r1.x + r1.width, r2.x + r2.width)
	y2 := min(r1.y + r1.height, r2.y + r2.height)
	if x2 < x1 { x2 = x1 }
	if y2 < y1 { y2 = y1 }
	return {x1, y1, x2 - x1, y2 - y1}
}

Tileset :: struct {
	pixels: []Color,
	pixels_size: Vec2i,
	visible_pixels_size: Vec2i,
	offset: Vec2i,
}

load_tileset :: proc(filename: string, t: ^Tileset) {
	data, data_ok := os.read_entire_file(filename)

	if !data_ok {
		fmt.printf("Failed loading tileset %v\n", filename)
		return
	}

	defer delete(data)
	doc: ase.Document
	defer ase.destroy_doc(&doc)

	_, umerr := ase.unmarshal(data[:], &doc)
	if umerr != nil {
		fmt.println(umerr)
		return
	}

	indexed := doc.header.color_depth == .Indexed
	palette: ase.Palette_Chunk
	if indexed {
		for f in doc.frames {
			for c in f.chunks {
				if p, ok := c.(ase.Palette_Chunk); ok {
					palette = p
					break
				}
			}
		}
	}
	
	if indexed && len(palette.entries) == 0 {
		fmt.println("Document is indexed, but found no palette!")
	}

	for f in doc.frames {
		for c in f.chunks {
			#partial switch cv in c {
				case ase.Cel_Chunk:
					if cl, ok := cv.cel.(ase.Com_Image_Cel); ok {
						if indexed {
							t.pixels = make([]Color, int(cl.width) * int(cl.height))
							for p, idx in cl.pixel {
								if p == 0 {
									continue
								}

								t.pixels[idx] = Color(palette.entries[u32(p)].color)
							}
						} else {
							t.pixels = slice.clone(transmute([]Color)(cl.pixel))
						}

						t.offset = {int(cv.x), int(cv.y)}
						t.pixels_size = {int(cl.width), int(cl.height)}
						t.visible_pixels_size = {int(doc.header.width), int(doc.header.height)}
					}
			}
		}
	}
}

Animation :: struct {
	name: string,
	first_texture: string,
	last_texture: string,
	document_size: Vec2i,
	loop_direction: ase.Tag_Loop_Dir,
	repeat: u16,
}

load_ase_texture_data :: proc(filename: string, textures: ^[dynamic]Texture_Data, animations: ^[dynamic]Animation) {
	data, data_ok := os.read_entire_file(filename)

	if !data_ok {
		return
	}

	doc: ase.Document

	_, umerr := ase.unmarshal(data[:], &doc)
	if umerr != nil {
		fmt.println(umerr)
		return
	}

	document_rect := Rect {
		0, 0,
		f32(doc.header.width), f32(doc.header.height),
	}

	base_name := asset_name(filename)
	frame_idx := 0
	animated := len(doc.frames) > 1
	skip_writing_main_anim := false
	indexed := doc.header.color_depth == .Indexed
	palette: ase.Palette_Chunk
	if indexed {
		for f in doc.frames {
			for c in f.chunks {
				if p, ok := c.(ase.Palette_Chunk); ok {
					palette = p
					break
				}
			}
		}
	}
	
	if indexed && len(palette.entries) == 0 {
		fmt.println("Document is indexed, but found no palette!")
	}

	visible_layers := make(map[u16]bool)
	defer delete(visible_layers)
	layer_index : u16
	for f in doc.frames {
		for &c in f.chunks {
			#partial switch &c in c {
			case ase.Layer_Chunk:
				if ase.Layer_Chunk_Flag.Visiable in c.flags {
					visible_layers[layer_index] = true
				}
				layer_index += 1
			}
		}
	}

	if len(visible_layers) == 0 {
		fmt.println("No visible layers in document!")
		return
	}
	
	for f in doc.frames {
		duration: f32 = f32(f.header.duration)/1000.0

		cels: [dynamic]^ase.Cel_Chunk
		cel_min := Vec2i { max(int), max(int) }
		cel_max := Vec2i { min(int), min(int) }

		for &c in f.chunks {
			#partial switch &c in c {
			case ase.Cel_Chunk:
				if c.layer_index in visible_layers {
					if cl, ok := &c.cel.(ase.Com_Image_Cel); ok {
						cel_min.x = min(cel_min.x, int(c.x))
						cel_min.y = min(cel_min.y, int(c.y))
						cel_max.x = max(cel_max.x, int(c.x) + int(cl.width))
						cel_max.y = max(cel_max.y, int(c.y) + int(cl.height))
						append(&cels, &c)
					}
				}
			case ase.Tags_Chunk:
				for tag in c {
					a := Animation {
						name = fmt.tprint(base_name, strings.to_ada_case(tag.name, context.temp_allocator), sep = "_"),
						first_texture = fmt.tprint(base_name, tag.from_frame, sep = ""),
						last_texture = fmt.tprint(base_name, tag.to_frame, sep = ""),
						loop_direction = tag.loop_direction,
						repeat = tag.repeat,
					}
					
					skip_writing_main_anim = true
					append(animations, a)
				}
			}
		}

		if len(cels) == 0 {
			continue
		}

		slice.sort_by(cels[:], proc(i, j: ^ase.Cel_Chunk) -> bool {
			return i.layer_index < j.layer_index
		})

		s := cel_max - cel_min
		pixels := make([]Color, int(s.x*s.y))

		combined_layers := Image {
			data = pixels,
			width = s.x,
			height = s.y,
		}

		for c in cels {
			cl := c.cel.(ase.Com_Image_Cel)
			cel_pixels: []Color

			if indexed {
				cel_pixels = make([]Color, int(cl.width) * int(cl.height))
				for p, idx in cl.pixel {
					if p == 0 {
						continue
					}
					
					cel_pixels[idx] = Color(palette.entries[u32(p)].color)
				}
			} else {
				cel_pixels = transmute([]Color)(cl.pixel)
			}

			source := Rect {
				0, 0,
				f32(cl.width), f32(cl.height),
			}

			from := Image {
				data = cel_pixels,
				width = int(cl.width),
				height = int(cl.height),
			}

			dest_pos := Vec2i {
				int(c.x) - cel_min.x,
				int(c.y) - cel_min.y,
			}

			draw_image(&combined_layers, from, source, dest_pos)
		}

		cels_rect := Rect {
			f32(cel_min.x), f32(cel_min.y),
			f32(s.x), f32(s.y),
		}

		source_rect := rect_intersect(cels_rect, document_rect)

		td := Texture_Data {
			source_size = { int(source_rect.width), int(source_rect.height)},
			source_offset = { int(source_rect.x - cels_rect.x), int(source_rect.y - cels_rect.y) },
			pixels_size = s,
			document_size = {int(doc.header.width), int(doc.header.height)},
			duration = duration,
			name = animated ? fmt.tprint(base_name, frame_idx, sep = "") : base_name,
			pixels = pixels,
		}

		if cel_min.x > 0 {
			td.offset.x = cel_min.x
		}

		if cel_min.y > 0 {
			td.offset.y = cel_min.y
		}

		append(textures, td)
		frame_idx += 1
	}

	if animated && frame_idx > 1 && !skip_writing_main_anim {
		a := Animation {
			name = base_name,
			first_texture = fmt.tprint(base_name, 0, sep = ""),
			last_texture = fmt.tprint(base_name, frame_idx - 1, sep = ""),
			document_size = {int(document_rect.width), int(document_rect.height)},
		}

		append(animations, a)
	}
}

Image :: struct {
	data: []Color,
	width: int,
	height: int,
}

draw_image :: proc(to: ^Image, from: Image, source: Rect, pos: Vec2i) {
	for sxf in 0..<source.width {
		for syf in 0..<source.height {
			sx := int(source.x+sxf)
			sy := int(source.y+syf)

			if sx < 0 || sx >= from.width {
				continue
			}

			if sy < 0 || sy >= from.height {
				continue
			}

			dx := pos.x + int(sxf)
			dy := pos.y + int(syf)

			if dx < 0 || dx >= to.width {
				continue
			}

			if dy < 0 || dy >= to.height {
				continue
			}

			from_idx := sy * from.width + sx
			to_idx := dy * to.width + dx
			to.data[to_idx] = from.data[from_idx]
		}
	}
}

draw_image_rectangle :: proc(to: ^Image, rect: Rect, color: Color) {
	for dxf in 0..<rect.width {
		for dyf in 0..<rect.height {
			dx := int(rect.x) + int(dxf)
			dy := int(rect.y) + int(dyf)

			if dx < 0 || dx >= to.width {
				continue
			}

			if dy < 0 || dy >= to.height {
				continue
			}

			to_idx := dy * to.width + dx
			to.data[to_idx] = color
		}
	}
}

get_image_pixel :: proc(img: Image, x: int, y: int) -> Color {
	idx := img.width * y + x

	if idx < 0 || idx >= len(img.data) {
		return {}
	}

	return img.data[idx]
}

load_png_texture_data :: proc(filename: string, textures: ^[dynamic]Texture_Data) {
	data, data_ok := os.read_entire_file(filename)

	if !data_ok {
		fmt.printf("Failed loading tileset %v\n", filename)
		return
	}

	defer delete(data)

	img, err := png.load_from_bytes(data)

	if err != nil {
		fmt.println(err)
		return
	}

	defer png.destroy(img)

	if img.depth != 8 && img.channels != 4 {
		fmt.println("Only 8 bpp, 4 channels PNG supported (this can probably be fixed by doing some work in `load_png_texture_data`")
		return
	}

	td := Texture_Data {
		source_size = {img.width, img.height},
		pixels_size = {img.width, img.height},
		document_size = {img.width, img.height},
		duration = 0,
		name = asset_name(filename),
		pixels = slice.clone(transmute([]Color)(img.pixels.buf[:])),
	}

	append(textures, td)
}

main :: proc() {
	textures: [dynamic]Texture_Data
	animations: [dynamic]Animation

	dir_path_to_file_infos :: proc(path: string) -> []os.File_Info {
		d, derr := os.open(path, os.O_RDONLY)
		if derr != nil {
			fmt.panicf("No %s folder found", path)
		}
		defer os.close(d)

		{
			file_info, ferr := os.fstat(d)
			defer os.file_info_delete(file_info)

			if ferr != nil {
				panic("stat failed")
			}
			if !file_info.is_dir {
				panic("not a directory")
			}
		}

		file_infos, _ := os.read_dir(d, -1)
		return file_infos
	}

	file_infos := dir_path_to_file_infos(TEXTURES_DIR)

	slice.sort_by(file_infos, proc(i, j: os.File_Info) -> bool {
		return time.diff(i.creation_time, j.creation_time) > 0
	})

	tileset: Tileset

	for fi in file_infos {
		is_ase := strings.has_suffix(fi.name, ".ase") || strings.has_suffix(fi.name, ".aseprite")
		is_png := strings.has_suffix(fi.name, ".png")
		if is_ase || is_png {
			path := fmt.tprintf("%s/%s", TEXTURES_DIR, fi.name)
			if strings.has_prefix(fi.name, "tileset") {
				load_tileset(path, &tileset)
			} else if is_ase {
				load_ase_texture_data(path, &textures, &animations)	
			} else if is_png {
				load_png_texture_data(path, &textures)
			}
		}
	}

	rc: rect_pack.Context
	rc_nodes: [ATLAS_SIZE]rect_pack.Node
	rect_pack.init_target(&rc, ATLAS_SIZE, ATLAS_SIZE, raw_data(rc_nodes[:]), ATLAS_SIZE)

	letters := utf8.string_to_runes(LETTERS_IN_FONT)
	num_letters := len(letters)
	

	pack_rects: [dynamic]rect_pack.Rect
	glyphs: [^]rl.GlyphInfo

	PackRectType :: enum {
		Texture,
		Glyph,
		Tile,
		ShapesTexture,
	}

	make_pack_rect_id :: proc(id: i32, type: PackRectType) -> i32 {
		t := u32(type)
		t <<= 29
		t |= u32(id)
		return i32(t)
	}

	make_tile_id :: proc(x, y: int) -> i32 {
		id: i32 = i32(x)
		id <<= 13
		return id | i32(y)
	}

	idx_from_rect_id :: proc(id: i32) -> int {
		return int((u32(id) << 3)>>3)
	}

	x_y_from_tile_id :: proc(id: i32) -> (x, y: int) {
		id_type_stripped := idx_from_rect_id(id)
		return int(id_type_stripped >> 13), int((u32(id_type_stripped)<<19)>>19)
	}

	rect_id_type :: proc(i: i32) -> PackRectType {
		return PackRectType(i >> 29)
	}

	if font_data, ok := os.read_entire_file(FONT_FILENAME); ok {
		glyphs = rl.LoadFontData(&font_data[0], i32(len(font_data)), FONT_SIZE, raw_data(letters), i32(num_letters), .BITMAP)

		for i in 0..<len(letters) {
			g := glyphs[i]

			append(&pack_rects, rect_pack.Rect {
				id = make_pack_rect_id(i32(i), .Glyph),
				w = rect_pack.Coord(g.image.width) + 1,
				h = rect_pack.Coord(g.image.height) + 1,
			})
		}
	} else {
		fmt.printfln("No %s file found", FONT_FILENAME)
	}

	for t, idx in textures {
		append(&pack_rects, rect_pack.Rect {
			id = make_pack_rect_id(i32(idx), .Texture),
			w = rect_pack.Coord(t.source_size.x) + 1,
			h = rect_pack.Coord(t.source_size.y) + 1,
		})
	}

	if tileset.pixels_size.x != 0 && tileset.pixels_size.y != 0 {
		h := tileset.pixels_size.y / TILE_SIZE
		w := tileset.pixels_size.x / TILE_SIZE
		top_left: rl.Vector2 = {-f32(tileset.offset.x), -f32(tileset.offset.y)}

		t_img := Image {
			data = tileset.pixels,
			width = tileset.pixels_size.x,
			height = tileset.pixels_size.y,
		}
		
		for x in 0 ..<w {
			for y in 0..<h {
				tx := f32(TILE_SIZE * x) + top_left.x
				ty := f32(TILE_SIZE * y) + top_left.y

				all_blank := true
				txx_loop: for txx in tx..<tx+TILE_SIZE {
					for tyy in ty..<ty+TILE_SIZE {
						if get_image_pixel(t_img, int(txx), int(tyy)) != {} {
							all_blank = false
							break txx_loop
						}
					}
				}

				if all_blank {
					continue
				}

				append(&pack_rects, rect_pack.Rect {
					id = make_pack_rect_id(make_tile_id(x, y), .Tile),
					w = TILE_SIZE+2,
					h = TILE_SIZE+2,
				})
			}
		}
	}

	append(&pack_rects, rect_pack.Rect {
		id = make_pack_rect_id(0, .ShapesTexture),
		w = 11,
		h = 11,
	})

	rect_pack_res := rect_pack.pack_rects(&rc, raw_data(pack_rects), i32(len(pack_rects)))

	if rect_pack_res != 1 {
		fmt.println("failed to pack some rects")
	}

	atlas_pixels := make([]Color, ATLAS_SIZE*ATLAS_SIZE)
	atlas := Image {
		data = atlas_pixels,
		width = ATLAS_SIZE,
		height = ATLAS_SIZE,
	}
	atlas_textures: [dynamic]Atlas_Texture_Rect
	atlas_tiles: [dynamic]Atlas_Tile_Rect

	atlas_glyphs: [dynamic]Atlas_Glyph
	shapes_texture_rect: Rect

	for rp in pack_rects {
		type := rect_id_type(rp.id)

		switch type {
		case .ShapesTexture:
			shapes_texture_rect = Rect {f32(rp.x), f32(rp.y), 10, 10}
			draw_image_rectangle(&atlas, shapes_texture_rect, rl.WHITE)
		case .Texture:
			idx := idx_from_rect_id(rp.id)

			t := textures[idx]

			t_img := Image {
				data = t.pixels,
				width = t.pixels_size.x,
				height = t.pixels_size.y,
			}

			source := Rect {f32(t.source_offset.x), f32(t.source_offset.y), f32(t.source_size.x), f32(t.source_size.y)}
			draw_image(&atlas, t_img, source, {int(rp.x), int(rp.y)})

			atlas_rect := Rect {f32(rp.x), f32(rp.y), source.width, source.height}
			offset_right := t.document_size.x - (int(atlas_rect.width) + t.offset.x)
			offset_bottom := t.document_size.y - (int(atlas_rect.height) + t.offset.y)

			ar := Atlas_Texture_Rect {
				rect = atlas_rect,
				size = t.document_size,
				offset_top = t.offset.y,
				offset_right = offset_right,
				offset_bottom = offset_bottom,
				offset_left = t.offset.x,
				name = t.name,
				duration = t.duration,
			}

			append(&atlas_textures, ar)	
		case .Glyph:
			idx := idx_from_rect_id(rp.id)
			g := glyphs[idx]
			img_grayscale := g.image

			grayscale := cast([^]u8)(img_grayscale.data)
			img_pixels := make([]Color, img_grayscale.width*img_grayscale.height)

			for i in 0..<img_grayscale.width*img_grayscale.height {
				a := grayscale[i]
				img_pixels[i].r = 255
				img_pixels[i].g = 255
				img_pixels[i].b = 255
				img_pixels[i].a = a
			}


			img := Image {
				data = img_pixels,
				width = int(img_grayscale.width),
				height = int(img_grayscale.height),
			}

			source := Rect {0, 0, f32(img.width), f32(img.height)}
			dest := Rect {f32(rp.x), f32(rp.y), source.width, source.height}

			draw_image(&atlas, img, source, {int(rp.x), int(rp.y)})

			ag := Atlas_Glyph {
				rect = dest,
				glyph = g,
			}

			append(&atlas_glyphs, ag)
		case .Tile:
			ix, iy := x_y_from_tile_id(rp.id)

			x := f32(TILE_SIZE * ix)
			y := f32(TILE_SIZE * iy)

			top_left: rl.Vector2 = {-f32(tileset.offset.x), -f32(tileset.offset.y)}

			t_img := Image {
				data = tileset.pixels,
				width = tileset.pixels_size.x,
				height = tileset.pixels_size.y,
			}
			
			source := Rect {x + top_left.x, y + top_left.y, TILE_SIZE, TILE_SIZE}
			dest := Rect {f32(rp.x) + 1, f32(rp.y) + 1, source.width, source.height}

			draw_image(&atlas, t_img, source, {int(rp.x), int(rp.y)})

			// Add padding to tiles by adding a pixel border around it and copying the nearest pixels
			// there. This helps with bleeding when doing subpixel camera movements.

			ts :: TILE_SIZE
			// Top
			{
				psource := Rect {
					source.x,
					source.y,
					ts,
					1,
				}

				draw_image(&atlas, t_img, psource, {int(dest.x), int(dest.y - 1)})
			}

			// Bottom
			{
				psource := Rect {
					source.x,
					source.y + ts -1,
					ts,
					1,
				}

				draw_image(&atlas, t_img, psource, {int(dest.x), int(dest.y + ts)})
			}

			// Left
			{
				psource := Rect {
					source.x,
					source.y,
					1,
					ts,
				}
				
				draw_image(&atlas, t_img, psource, {int(dest.x - 1), int(dest.y)})
			}

			// Right
			{
				psource := Rect {
					source.x + ts - 1,
					source.y,
					1,
					ts,
				}
				
				draw_image(&atlas, t_img, psource, {int(dest.x + ts), int(dest.y)})
			}

			at := Atlas_Tile_Rect {
				rect = dest,
				coord = {ix, iy},
			}

			append(&atlas_tiles, at)
		}
	}

	if ATLAS_CROP {
	//	rl.ImageAlphaCrop(&atlas, 0)	
	}

	img_write :: proc "c" (ctx: rawptr, data: rawptr, size: c.int) {
		context = runtime.default_context()
		os.write_entire_file(ATLAS_PNG_OUTPUT_PATH, slice.bytes_from_ptr(data, int(size)))
	}
	image.write_png_to_func(img_write, nil, ATLAS_SIZE, ATLAS_SIZE, 4, raw_data(atlas_pixels), ATLAS_SIZE * size_of(Color))

//	rl.ExportImage(atlas, ATLAS_PNG_OUTPUT_PATH)

	f, _ := os.open(ATLAS_ODIN_OUTPUT_PATH, os.O_WRONLY | os.O_CREATE | os.O_TRUNC)
	defer os.close(f)

	fmt.fprintln(f, "// This file is generated by running the atlas_builder.")
	fmt.fprintf(f, "package %s\n", PACKAGE_NAME)
	fmt.fprintln(f, "")
	fmt.fprintln(f, "// Note: This file assumes the existence of a type Rect that defines a rectangle in the same package, it can defined as:")
	fmt.fprintln(f, "// Rect :: rl.Rectangle")
	fmt.fprintln(f, "// or if you don't use raylib:")
	fmt.fprintln(f, "// Rect :: struct {")
	fmt.fprintln(f, "//     x: f32,")
	fmt.fprintln(f, "//     y: f32,")
	fmt.fprintln(f, "//     width: f32,")
	fmt.fprintln(f, "//     height: f32,")
	fmt.fprintln(f, "// }")
	fmt.fprintln(f, "// Just make sure you have something along those lines the same package as this file.")
	fmt.fprintln(f, "")

	fmt.fprintln(f, "TEXTURE_ATLAS_FILENAME :: \"atlas.png\"")
	fmt.fprintf(f, "ATLAS_FONT_SIZE :: %v\n", FONT_SIZE)
	fmt.fprintf(f, "LETTERS_IN_FONT :: \"%s\"\n\n", LETTERS_IN_FONT)

	fmt.fprintln(f, "// A generated square in the atlas you can use with rl.SetShapesTexture to make")
	fmt.fprintln(f, "// raylib shapes such as rl.DrawRectangleRec() use the atlas.")
	fmt.fprintf(f, "SHAPES_TEXTURE_RECT :: Rect {{%v, %v, %v, %v}}\n\n", shapes_texture_rect.x, shapes_texture_rect.y, shapes_texture_rect.width, shapes_texture_rect.height)

	fmt.fprintln(f, "Texture_Name :: enum {")
	fmt.fprint(f, "\tNone,\n")
	for r in atlas_textures {
		fmt.fprintf(f, "\t%s,\n", r.name)
	}
	fmt.fprintln(f, "}")
	fmt.fprintln(f, "")

	fmt.fprintln(f, "Atlas_Texture :: struct {")
	fmt.fprintln(f, "\trect: Rect,")
	fmt.fprintln(f, "\t// These offsets tell you how much space there is between the rect and the edge of the original document.")
	fmt.fprintln(f, "\t// The atlas is tightly packed, so empty pixels are removed. This can be especially apparent in animations where")
	fmt.fprintln(f, "\t// frames can have different offsets due to different amount of empty pixels around the frames.")
	fmt.fprintln(f, "\t// In many cases you need to add {offset_left, offset_top} to your position. But if you are")
	fmt.fprintln(f, "\t// flipping a texture, then you might need offset_bottom or offset_right.")
	fmt.fprintln(f, "\toffset_top: f32,")
	fmt.fprintln(f, "\toffset_right: f32,")
	fmt.fprintln(f, "\toffset_bottom: f32,")
	fmt.fprintln(f, "\toffset_left: f32,")
	fmt.fprintln(f, "\tdocument_size: [2]f32,")
	fmt.fprintln(f, "\tduration: f32,")
	fmt.fprintln(f, "}")
	fmt.fprintln(f, "")

	fmt.fprintln(f, "atlas_textures: [Texture_Name]Atlas_Texture = {")
	fmt.fprintln(f, "\t.None = {},")

	for r in atlas_textures {
		fmt.fprintf(f, "\t.%s = {{ rect = {{%v, %v, %v, %v}}, offset_top = %v, offset_right = %v, offset_bottom = %v, offset_left = %v, document_size = {{%v, %v}}, duration = %f}},\n", r.name, r.rect.x, r.rect.y, r.rect.width, r.rect.height, r.offset_top, r.offset_right, r.offset_bottom, r.offset_left, r.size.x, r.size.y, r.duration)
	}

	fmt.fprintln(f, "}\n")

	fmt.fprintln(f, "Animation_Name :: enum {")
	fmt.fprint(f, "\tNone,\n")
	for r in animations {
		fmt.fprintf(f, "\t%s,\n", r.name)
	}
	fmt.fprintln(f, "}")
	fmt.fprintln(f, "")

	fmt.fprintln(f, "Tag_Loop_Dir :: enum {")
	fmt.fprintln(f, "\tForward,")
	fmt.fprintln(f, "\tReverse,")
	fmt.fprintln(f, "\tPing_Pong,")
	fmt.fprintln(f, "\tPing_Pong_Reverse,")
	fmt.fprintln(f, "}")
	fmt.fprintln(f, "")

	fmt.fprintln(f, "// Any aseprite file with frames will create new animations. Also, any tags")
	fmt.fprintln(f, "// within the aseprite file will make that that into a separate animation.")
	fmt.fprintln(f, "Atlas_Animation :: struct {")
	fmt.fprintln(f, "\tfirst_frame: Texture_Name,")
	fmt.fprintln(f, "\tlast_frame: Texture_Name,")
	fmt.fprintln(f, "\tdocument_size: [2]f32,")
	fmt.fprintln(f, "\tloop_direction: Tag_Loop_Dir,")
	fmt.fprintln(f, "\trepeat: u16,")
	fmt.fprintln(f, "}")
	fmt.fprintln(f, "")

	fmt.fprintln(f, "atlas_animations := [Animation_Name]Atlas_Animation {")
	fmt.fprint(f, "\t.None = {},\n")

	for a in animations {
		fmt.fprintf(f, "\t.%v = {{ first_frame = .%v, last_frame = .%v, loop_direction = .%v, repeat = %v, document_size = {{%v, %v}} }},\n",
			a.name, a.first_texture, a.last_texture, a.loop_direction, a.repeat, a.document_size.x, a.document_size.y)
	}

	fmt.fprintln(f, "}\n")


	fmt.fprintln(f, "// All these are pre-generated so you can save tile IDs to data without")
	fmt.fprintln(f, "// worrying about their order changing later.")
	fmt.fprintln(f, "Tile_Id :: enum {")
	for y in 0..<TILESET_WIDTH {
		for x in 0..<TILESET_WIDTH {
			fmt.fprintf(f, "\tT0Y%vX%v,\n", y, x)
		}
	}
	fmt.fprintln(f, "}")
	fmt.fprintln(f, "")

	fmt.fprintln(f, "atlas_tiles := #partial [Tile_Id]Rect {")

	for at in atlas_tiles {
		fmt.fprintf(f, "\t.T0Y%vX%v = {{%v, %v, %v, %v}},\n",
			 at.coord.y, at.coord.x, at.rect.x, at.rect.y, at.rect.width, at.rect.height)
	}

	fmt.fprintln(f, "}\n")


	fmt.fprintln(f, "Atlas_Glyph :: struct {")
	fmt.fprintln(f, "\trect: Rect,")
	fmt.fprintln(f, "\tvalue: rune,")
	fmt.fprintln(f, "\toffset_x: int,")
	fmt.fprintln(f, "\toffset_y: int,")
	fmt.fprintln(f, "\tadvance_x: int,")
	fmt.fprintln(f, "}")
	fmt.fprintln(f, "")

	fmt.fprintln(f, "atlas_glyphs: []Atlas_Glyph = {")

	for ag in atlas_glyphs {
		fmt.fprintf(f, "\t{{ rect = {{%v, %v, %v, %v}}, value = %q, offset_x = %v, offset_y = %v, advance_x = %v}},\n",
			ag.rect.x, ag.rect.y, ag.rect.width, ag.rect.height, ag.glyph.value, ag.glyph.offsetX, ag.glyph.offsetY, ag.glyph.advanceX)
	}

	fmt.fprintln(f, "}")
}
