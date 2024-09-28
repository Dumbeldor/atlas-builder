// This file is generated by running the atlas_builder.
package game

// Note: This file assumes the existence of a type Rect that defines a rectangle in the same package, it can defined as:
// Rect :: rl.Rectangle
// or if you don't use raylib:
// Rect :: struct {
//     x: f32,
//     y: f32,
//     width: f32,
//     height: f32,
// }
// Just make sure you have something along those lines the same package as this file.

TEXTURE_ATLAS_FILENAME :: "atlas.png"
ATLAS_FONT_SIZE :: 32
LETTERS_IN_FONT :: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz1234567890?!&.,_:[]-+"

// A generated square in the atlas you can use with rl.SetShapesTexture to make
// raylib shapes such as rl.DrawRectangleRec() use the atlas.
SHAPES_TEXTURE_RECT :: Rect {201, 19, 10, 10}

Texture_Name :: enum {
	None,
	Bush,
	Player0,
	Player1,
}

Atlas_Texture :: struct {
	rect: Rect,
	// These offsets tell you how much space there is between the rect and the edge of the original document.
	// The atlas is tightly packed, so empty pixels are removed. This can be especially apparent in animations where
	// frames can have different offsets due to different amount of empty pixels around the frames.
	// In many cases you need to add {offset_left, offset_top} to your position. But if you are
	// flipping a texture, then you might need offset_bottom or offset_right.
	offset_top: f32,
	offset_right: f32,
	offset_bottom: f32,
	offset_left: f32,
	document_size: [2]f32,
	duration: f32,
}

atlas_textures: [Texture_Name]Atlas_Texture = {
	.None = {},
	.Bush = { rect = {50, 0, 45, 18}, offset_top = 6, offset_right = 1, offset_bottom = 0, offset_left = 2, document_size = {48, 24}, duration = 0.100},
	.Player0 = { rect = {230, 0, 10, 18}, offset_top = 0, offset_right = 0, offset_bottom = 0, offset_left = 0, document_size = {10, 18}, duration = 0.100},
	.Player1 = { rect = {402, 0, 10, 17}, offset_top = 1, offset_right = 0, offset_bottom = 0, offset_left = 0, document_size = {10, 18}, duration = 0.100},
}

Animation_Name :: enum {
	None,
	Player,
}

Tag_Loop_Dir :: enum {
	Forward,
	Reverse,
	Ping_Pong,
	Ping_Pong_Reverse,
}

// Any aseprite file with frames will create new animations. Also, any tags
// within the aseprite file will make that that into a separate animation.
Atlas_Animation :: struct {
	first_frame: Texture_Name,
	last_frame: Texture_Name,
	document_size: [2]f32,
	loop_direction: Tag_Loop_Dir,
	repeat: u16,
}

atlas_animations := [Animation_Name]Atlas_Animation {
	.None = {},
	.Player = { first_frame = .Player0, last_frame = .Player1, loop_direction = .Forward, repeat = 0, document_size = {10, 18} },
}

// All these are pre-generated so you can save tile IDs to data without
// worrying about their order changing later.
Tile_Id :: enum {
	T0Y0X0,
	T0Y0X1,
	T0Y0X2,
	T0Y0X3,
	T0Y0X4,
	T0Y0X5,
	T0Y0X6,
	T0Y0X7,
	T0Y0X8,
	T0Y0X9,
	T0Y1X0,
	T0Y1X1,
	T0Y1X2,
	T0Y1X3,
	T0Y1X4,
	T0Y1X5,
	T0Y1X6,
	T0Y1X7,
	T0Y1X8,
	T0Y1X9,
	T0Y2X0,
	T0Y2X1,
	T0Y2X2,
	T0Y2X3,
	T0Y2X4,
	T0Y2X5,
	T0Y2X6,
	T0Y2X7,
	T0Y2X8,
	T0Y2X9,
	T0Y3X0,
	T0Y3X1,
	T0Y3X2,
	T0Y3X3,
	T0Y3X4,
	T0Y3X5,
	T0Y3X6,
	T0Y3X7,
	T0Y3X8,
	T0Y3X9,
	T0Y4X0,
	T0Y4X1,
	T0Y4X2,
	T0Y4X3,
	T0Y4X4,
	T0Y4X5,
	T0Y4X6,
	T0Y4X7,
	T0Y4X8,
	T0Y4X9,
	T0Y5X0,
	T0Y5X1,
	T0Y5X2,
	T0Y5X3,
	T0Y5X4,
	T0Y5X5,
	T0Y5X6,
	T0Y5X7,
	T0Y5X8,
	T0Y5X9,
	T0Y6X0,
	T0Y6X1,
	T0Y6X2,
	T0Y6X3,
	T0Y6X4,
	T0Y6X5,
	T0Y6X6,
	T0Y6X7,
	T0Y6X8,
	T0Y6X9,
	T0Y7X0,
	T0Y7X1,
	T0Y7X2,
	T0Y7X3,
	T0Y7X4,
	T0Y7X5,
	T0Y7X6,
	T0Y7X7,
	T0Y7X8,
	T0Y7X9,
	T0Y8X0,
	T0Y8X1,
	T0Y8X2,
	T0Y8X3,
	T0Y8X4,
	T0Y8X5,
	T0Y8X6,
	T0Y8X7,
	T0Y8X8,
	T0Y8X9,
	T0Y9X0,
	T0Y9X1,
	T0Y9X2,
	T0Y9X3,
	T0Y9X4,
	T0Y9X5,
	T0Y9X6,
	T0Y9X7,
	T0Y9X8,
	T0Y9X9,
}

atlas_tiles := #partial [Tile_Id]Rect {
	.T0Y0X0 = {243, 20, 8, 8},
	.T0Y1X0 = {253, 20, 8, 8},
	.T0Y0X1 = {38, 21, 8, 8},
	.T0Y1X1 = {8, 23, 8, 8},
	.T0Y0X2 = {18, 23, 8, 8},
	.T0Y1X2 = {28, 23, 8, 8},
	.T0Y0X3 = {213, 30, 8, 8},
	.T0Y1X3 = {223, 30, 8, 8},
	.T0Y0X4 = {233, 30, 8, 8},
	.T0Y0X5 = {243, 30, 8, 8},
	.T0Y0X6 = {253, 30, 8, 8},
	.T0Y0X7 = {233, 20, 8, 8},
	.T0Y0X8 = {223, 20, 8, 8},
	.T0Y0X9 = {213, 20, 8, 8},
}

Atlas_Glyph :: struct {
	rect: Rect,
	value: rune,
	offset_x: int,
	offset_y: int,
	advance_x: int,
}

atlas_glyphs: []Atlas_Glyph = {
	{ rect = {464, 1, 13, 15}, value = 'A', offset_x = 0, offset_y = 8, advance_x = 12},
	{ rect = {496, 18, 11, 15}, value = 'B', offset_x = 2, offset_y = 8, advance_x = 13},
	{ rect = {128, 1, 12, 17}, value = 'C', offset_x = 1, offset_y = 7, advance_x = 12},
	{ rect = {457, 18, 11, 15}, value = 'D', offset_x = 2, offset_y = 8, advance_x = 13},
	{ rect = {365, 19, 9, 15}, value = 'E', offset_x = 2, offset_y = 8, advance_x = 11},
	{ rect = {376, 19, 9, 15}, value = 'F', offset_x = 2, offset_y = 8, advance_x = 11},
	{ rect = {156, 1, 12, 17}, value = 'G', offset_x = 1, offset_y = 7, advance_x = 13},
	{ rect = {483, 18, 11, 15}, value = 'H', offset_x = 2, offset_y = 8, advance_x = 14},
	{ rect = {509, 1, 2, 15}, value = 'I', offset_x = 2, offset_y = 8, advance_x = 5},
	{ rect = {392, 1, 9, 16}, value = 'J', offset_x = 0, offset_y = 8, advance_x = 10},
	{ rect = {277, 19, 11, 15}, value = 'K', offset_x = 2, offset_y = 8, advance_x = 13},
	{ rect = {354, 19, 9, 15}, value = 'L', offset_x = 2, offset_y = 8, advance_x = 10},
	{ rect = {449, 1, 13, 15}, value = 'M', offset_x = 2, offset_y = 8, advance_x = 16},
	{ rect = {329, 19, 11, 15}, value = 'N', offset_x = 2, offset_y = 8, advance_x = 14},
	{ rect = {113, 1, 13, 17}, value = 'O', offset_x = 1, offset_y = 7, advance_x = 14},
	{ rect = {342, 19, 10, 15}, value = 'P', offset_x = 2, offset_y = 8, advance_x = 12},
	{ rect = {8, 1, 14, 20}, value = 'Q', offset_x = 1, offset_y = 7, advance_x = 14},
	{ rect = {316, 19, 11, 15}, value = 'R', offset_x = 2, offset_y = 8, advance_x = 12},
	{ rect = {142, 1, 12, 17}, value = 'S', offset_x = 0, offset_y = 7, advance_x = 12},
	{ rect = {443, 18, 12, 15}, value = 'T', offset_x = 0, offset_y = 8, advance_x = 12},
	{ rect = {264, 1, 12, 16}, value = 'U', offset_x = 1, offset_y = 8, advance_x = 14},
	{ rect = {429, 18, 12, 15}, value = 'V', offset_x = 0, offset_y = 8, advance_x = 11},
	{ rect = {429, 1, 18, 15}, value = 'W', offset_x = 0, offset_y = 8, advance_x = 17},
	{ rect = {479, 1, 12, 15}, value = 'X', offset_x = 0, offset_y = 8, advance_x = 11},
	{ rect = {493, 1, 12, 15}, value = 'Y', offset_x = -1, offset_y = 8, advance_x = 10},
	{ rect = {264, 19, 11, 15}, value = 'Z', offset_x = 1, offset_y = 8, advance_x = 12},
	{ rect = {51, 20, 9, 13}, value = 'a', offset_x = 1, offset_y = 11, advance_x = 11},
	{ rect = {183, 1, 11, 17}, value = 'b', offset_x = 1, offset_y = 7, advance_x = 12},
	{ rect = {62, 20, 9, 13}, value = 'c', offset_x = 1, offset_y = 11, advance_x = 10},
	{ rect = {196, 1, 10, 17}, value = 'd', offset_x = 1, offset_y = 7, advance_x = 12},
	{ rect = {411, 19, 10, 13}, value = 'e', offset_x = 1, offset_y = 11, advance_x = 11},
	{ rect = {242, 1, 8, 17}, value = 'f', offset_x = 0, offset_y = 6, advance_x = 6},
	{ rect = {38, 1, 11, 18}, value = 'g', offset_x = 1, offset_y = 11, advance_x = 11},
	{ rect = {368, 1, 10, 16}, value = 'h', offset_x = 1, offset_y = 7, advance_x = 12},
	{ rect = {424, 1, 3, 16}, value = 'i', offset_x = 1, offset_y = 7, advance_x = 5},
	{ rect = {1, 1, 5, 21}, value = 'j', offset_x = -1, offset_y = 7, advance_x = 5},
	{ rect = {356, 1, 10, 16}, value = 'k', offset_x = 1, offset_y = 7, advance_x = 11},
	{ rect = {252, 1, 4, 17}, value = 'l', offset_x = 1, offset_y = 7, advance_x = 5},
	{ rect = {84, 20, 16, 12}, value = 'm', offset_x = 1, offset_y = 11, advance_x = 18},
	{ rect = {102, 20, 10, 12}, value = 'n', offset_x = 1, offset_y = 11, advance_x = 12},
	{ rect = {398, 19, 11, 13}, value = 'o', offset_x = 1, offset_y = 11, advance_x = 12},
	{ rect = {170, 1, 11, 17}, value = 'p', offset_x = 1, offset_y = 11, advance_x = 12},
	{ rect = {208, 1, 10, 17}, value = 'q', offset_x = 1, offset_y = 11, advance_x = 12},
	{ rect = {126, 20, 7, 12}, value = 'r', offset_x = 1, offset_y = 11, advance_x = 7},
	{ rect = {73, 20, 9, 13}, value = 's', offset_x = 0, offset_y = 11, advance_x = 9},
	{ rect = {414, 1, 8, 16}, value = 't', offset_x = 0, offset_y = 8, advance_x = 7},
	{ rect = {114, 20, 10, 12}, value = 'u', offset_x = 1, offset_y = 12, advance_x = 12},
	{ rect = {166, 20, 11, 11}, value = 'v', offset_x = 0, offset_y = 12, advance_x = 10},
	{ rect = {135, 20, 16, 11}, value = 'w', offset_x = 0, offset_y = 12, advance_x = 16},
	{ rect = {179, 20, 10, 11}, value = 'x', offset_x = 0, offset_y = 12, advance_x = 10},
	{ rect = {304, 1, 11, 16}, value = 'y', offset_x = 0, offset_y = 12, advance_x = 10},
	{ rect = {191, 20, 9, 11}, value = 'z', offset_x = 0, offset_y = 12, advance_x = 9},
	{ rect = {387, 19, 9, 15}, value = '1', offset_x = 1, offset_y = 8, advance_x = 11},
	{ rect = {290, 19, 11, 15}, value = '2', offset_x = 0, offset_y = 8, advance_x = 11},
	{ rect = {291, 1, 11, 16}, value = '3', offset_x = 0, offset_y = 8, advance_x = 11},
	{ rect = {470, 18, 11, 15}, value = '4', offset_x = 0, offset_y = 8, advance_x = 11},
	{ rect = {317, 1, 11, 16}, value = '5', offset_x = 0, offset_y = 8, advance_x = 11},
	{ rect = {380, 1, 10, 16}, value = '6', offset_x = 1, offset_y = 8, advance_x = 11},
	{ rect = {303, 19, 11, 15}, value = '7', offset_x = 0, offset_y = 8, advance_x = 11},
	{ rect = {330, 1, 11, 16}, value = '8', offset_x = 0, offset_y = 8, advance_x = 11},
	{ rect = {343, 1, 11, 16}, value = '9', offset_x = 0, offset_y = 8, advance_x = 11},
	{ rect = {278, 1, 11, 16}, value = '0', offset_x = 0, offset_y = 8, advance_x = 11},
	{ rect = {220, 1, 9, 17}, value = '?', offset_x = 0, offset_y = 7, advance_x = 9},
	{ rect = {258, 1, 4, 17}, value = '!', offset_x = 1, offset_y = 7, advance_x = 6},
	{ rect = {97, 1, 14, 17}, value = '&', offset_x = 0, offset_y = 7, advance_x = 13},
	{ rect = {38, 31, 4, 4}, value = '.', offset_x = 1, offset_y = 20, advance_x = 5},
	{ rect = {1, 24, 4, 7}, value = ',', offset_x = 1, offset_y = 20, advance_x = 5},
	{ rect = {1, 33, 11, 2}, value = '_', offset_x = 0, offset_y = 24, advance_x = 11},
	{ rect = {423, 19, 4, 12}, value = ':', offset_x = 1, offset_y = 12, advance_x = 5},
	{ rect = {31, 1, 5, 20}, value = '[', offset_x = 2, offset_y = 7, advance_x = 6},
	{ rect = {24, 1, 5, 20}, value = ']', offset_x = 0, offset_y = 7, advance_x = 6},
	{ rect = {202, 31, 7, 3}, value = '-', offset_x = 0, offset_y = 16, advance_x = 6},
	{ rect = {153, 20, 11, 11}, value = '+', offset_x = 0, offset_y = 10, advance_x = 11},
}
