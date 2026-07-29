# Generates the shop hut as a PNG with nothing but Ruby stdlib — ASCII art plus
# a palette, '.' is transparent. Runs in MRI, not in DragonRuby: an authoring
# tool, the same as the other make_*_sprites.rb here.
#
#   ruby tools/make_shop_sprites.rb sprites/decor
#
# One building, on a fixed island in sector 3. It has to read as *a shop* from
# a screen away and at the scale the island's other decoration is drawn at, so
# it is mostly silhouette: a lit doorway, a striped awning over a counter with
# things actually laid out on it, a rack of surfboards, and a crooked sign on
# the roof. The lit window and the boards are the important pixels — a dark hut
# on a dark island is a rock, and a counter with nothing on it is a shed.
#
# Rows are padded out to the full width rather than counted by hand: at 56
# characters a row, hand-aligned art is a column-counting exercise and every
# edit risks a silent one-pixel shift. Short rows simply mean empty air to the
# right.
require "zlib"

W = 152 # widened from 112 to make room for the drum kit on the right
H = 44

PALETTE = {
  "w" => [126, 92, 62],    # planked wall
  "W" => [150, 112, 76],   # ... its lit side
  "d" => [74, 52, 34],     # dark timber: posts, frame, counter legs
  "r" => [172, 74, 62],    # roof
  "R" => [204, 100, 80],   # ... catching the light
  "a" => [232, 226, 208],  # awning, pale stripe
  "A" => [196, 92, 78],    # awning, red stripe
  "l" => [255, 226, 150],  # lamp-light through the door
  "s" => [238, 232, 214],  # the sign
  "p" => [158, 118, 80],   # the counter top
  "g" => [110, 176, 140],  # goods: a row of green bottles ...
  "o" => [226, 150, 84],   # ... and stacked tins
  "y" => [246, 222, 140],  # highlights on both
  "b" => [46, 150, 168],   # surfboard, teal — darker than it was, so it reads
  "B" => [214, 146, 52],   # surfboard, amber — against a bright sky the pale
  "c" => [250, 250, 244],  # ones vanished; the white stripe is what says "board"
  "P" => [118, 84, 54],
  "N" => [58, 40, 26],    # the shaded inside of the hut    # the bar top's shaded front edge
  "n" => [104, 74, 48],    # the planking of the bar front
  "h" => [222, 184, 104],  # Andi: fair hair ...
  "k" => [226, 176, 138],  # ... face and hands ...
  "e" => [40, 34, 32],     # ... eyes ...
  "t" => [86, 142, 156],   # ... and his shirt
  "S" => [72, 108, 132],   # lettering on the sign
  "f" => [196, 208, 216],  # a stack of film boxes
  # Andi's kit, set up beside the stall. He is a sound engineer and Macblinded's
  # drummer, out here on holiday minding a counter — and this is the only place
  # the game *shows* you that rather than having somebody mention it. It is set
  # up, not packed away: he did not come here to stop playing.
  "m" => [178, 58, 52],    # drum shells, a red kit
  "M" => [212, 90, 78],    # ... their lit side
  "i" => [232, 226, 208],  # drum heads
  "z" => [226, 190, 92],   # cymbals, brass
  "Z" => [140, 116, 56],   # ... and the hardware holding them up
}

# Laid over the stall at a position rather than typed into its rows: the shop is
# 44 rows tall and hand-editing every one of them to make room on the right is
# how a silent one-column shift gets in.
#
# Kept to three things — one cymbal, one tom, one bass drum — because a full kit
# at this size is a smudge, and drawn bigger than a real kit would be beside a
# market stall. At true scale it came out eleven pixels across and landed on
# screen as a red dot: every detail was a single pixel, and a single pixel
# doubles to two. It has to be legible before it is accurate.
DRUMS_AT = [128, 24] # x, y (y counts down from the top, like the rows do)
DRUMS = [
  "..zzzzzzzzzzzz..",
  "..ZZZZZZZZZZZZ..",
  ".......ZZ.......",
  ".......ZZ.......",
  "..mmmmmZZ.......",
  "..miiimZZ.......",
  "..miiimZZ.......",
  "..mmMMMZZ.......",
  ".......ZZ.......",
  ".......ZZ.......",
  "..mmmmmmmmmmm...",
  ".mMMMMMMMMMMMm..",
  ".miiiiiiiiiiim..",
  ".miiiiiiiiiiim..",
  ".miiiiiiiiiiim..",
  ".miiiiiiiiiiim..",
  ".mMMMMMMMMMMMm..",
  "..mmmmmmmmmmm...",
  "..ZZ.......ZZ...",
  "..ZZ.......ZZ...",
]

# Drawn facing the camera; nothing flips it. The hut is on the left, the counter
# and its awning in the middle, the board rack on the right.
SHAPE = [
  "",
  "",
  "",
  "",
  "..........sssssssssssssssssssss",
  "..........sssssssssssssssssssss.........................................................bbbbbb",
  "..........ssSSssSSssSSssSSssSss.......................................................dbbbbbbb",
  "..........ssSSssSSssSSssSSssSss.......................................................dbbccbbd",
  "..........sssssssssssssssssssss...ddddddddddddddddddddddddddddddddddddddddddddddddd...dbbccbbd",
  "..........ssSSssSSssSSssSssssss...ddddddddddddddddddddddddddddddddddddddddddddddddd...dbbccbbd",
  "..........ssSSssSSssSSssSssssss....aaAAaaAAaaAAaaAAaaAAaaAAaaAAaaAAaaAAaaAAaaAAaaA....dbbccbbd.....BBBBBB",
  "..........sssssssssssssssssssss....aaAAaaAAaaAAaaAAaaAAaaAAaaAAaaAAaaAAaaAAaaAAaaA....dbbccbbd...dBBBBBBB",
  "..........sssssssssssssssssssss....aaAAaaAAaaAAaaAAaaAAaaAAaaAAaaAAaaAAaaAAaaAAaaA....dbbccbbd...dBBccBBd",
  "...................dd..............aaAAaaAAaaAAaaAAaaAAaaAAaaAAaaAAaaAAaaAAaaAAaaA....dbbccbbd...dBBccBBd",
  "...................dd..............aaAAaaAAaaAAaaAAaaAAaaAAaaAAaaAAaaAAaaAAaaAAaaA....dbbccbbd...dBBccBBd",
  "...................dd.............dd.............................................dd....dbbccbbd..dBBccBBd",
  "...................dd.............dd.............................................dd....dbbccbbd..dBBccBBd",
  "...................dd.............dd..................hhhhhh.....................dd....dbbccbbd..dBBccBBd",
  "...................dd.............dd..................hhhhhh.....................dd....dbbccbbd..dBBccBBd",
  "...................dd.............dd...................kkkk......................dd....dbbccbbd..dBBccBBd",
  ".......ygg.yoo.ygg.ddfyoo.........dd...................ekke......................dd...ddbbccbbdddddBBccBBddddddd",
  ".......ggg.ooo.ggg.ddfooo.........dd..................kkkkkk.....................dd...ddbbccbbdddddBBccBBddddddd",
  ".......ggg.ooo.ggg.ddfooo.........dd...................kkkk......................dd....dbbccbbd...dBBccBBd",
  ".......ggg.ooo.ggg.ddfooo.........dd..................tttttt.....................dd....dbbccbbd...dBBccBBd",
  ".......ggg.ooo.ggg.ddfooo.........dd..................tttttt.....................dd.....dbbccbbd..dBBccBBd",
  ".......ggg.ooo.ggg.ddfooo.........dd..yggygg..........tttttt............yoo.yff..dd.....dbbccbbd..dBBccBBd",
  "....pppppppppppppppddpppppp.......dd..gggggg........tttttttttt..........ooo.fff..dd.....dbbccbbd..dBBccBBd",
  "....ppppppppppppppppppppppp.......dd..gggggg........tttttttttt..........ooo.fff..dd.....dbbccbbd..dBBccBBd",
  "....PPPPPPPPPPPPPPPPPPPPPPP.......dd..gggggg........tttttttttt..........ooo.fff..dd.....dbbccbbd..dBBccBBd",
  ".....dd.................dd........dd..gggggg........tttttttttt..........ooo.fff..dd.....dbbccbbd...dBBccBBd",
  ".....dd.................dd........dd..gggggg........kttttttttk..........ooo.fff..dd.....dbbccbbd...dBBccBBd",
  ".....dd.................dd........ppppppppppppppppppppppppppppppppppppppppppppppppp.....dbbccbbd...dBBccBBd",
  ".....dd.................dd........ppppppppppppppppppppppppppppppppppppppppppppppppp.....dbbccbbd...dBBccBBd",
  ".....dd.................dd........ppppppppppppppppppppppppppppppppppppppppppppppppp......dbbccbbd..dBBccBBd",
  ".....dd.................dd........PPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPP......dbbccbbd..dBBccBBd",
  ".....dd.................dd........dnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnd......dbbccbbd..dBBccBBd",
  ".....dd.................dd........dnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnd......dbbccbbd..dBBccBBd",
  ".....dd.................dd........dnnn.......nnnn.......nnnn.......nnnn.......nnnnd......dbbccbbd..dBBccBBd",
  ".....dd.................dd........dnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnd......dbbccbbd...dBBccBBd",
  ".....dd.................dd........dnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnd......dbbccbbd...dBBccBBd",
  ".....dd.................dd........dnnn.......nnnn.......nnnn.......nnnn.......nnnnd......dbbccbbd...dBBccBBd",
  ".....dd.................dd........dnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnd......dbbccbbd...dBBccBBd",
  ".....dd.................dd........dnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnd.......dbbccbbd..dBBccBBd",
  ".....dd.................dd........dnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnd.......dbbccbbd..dBBccBBd",
]

def png(pixels, w, h)
  raw = +""
  h.times do |y|
    raw << "\x00"
    w.times { |x| raw << pixels[y * w + x].pack("C4") }
  end
  chunk = lambda do |type, data|
    [data.bytesize].pack("N") + type + data + [Zlib.crc32(type + data)].pack("N")
  end
  "\x89PNG\r\n\x1a\n".b +
    chunk.call("IHDR", [w, h, 8, 6, 0, 0, 0].pack("NNC5")) +
    chunk.call("IDAT", Zlib::Deflate.deflate(raw)) +
    chunk.call("IEND", "")
end

if __FILE__ == $0
  out = ARGV[0] or abort "usage: ruby tools/make_shop_sprites.rb <sprites/decor>"
  SHAPE.each_with_index do |row, i|
    abort "row #{i} is #{row.length} px, wider than #{W}" if row.length > W
  end
  abort "#{SHAPE.length} rows, expected #{H}" unless SHAPE.length == H

  require "fileutils"
  FileUtils.mkdir_p(out)
  rows = SHAPE.map { |row| row.ljust(W, ".") }

  # Stamp the kit in. '.' stays transparent so the stall shows through wherever
  # the block is empty.
  dx, dy = DRUMS_AT
  DRUMS.each_with_index do |drum_row, i|
    abort "drums row #{i} runs off the sprite" if dx + drum_row.length > W
    abort "drums row #{i} runs off the bottom" if dy + i >= H

    drum_row.each_char.with_index do |char, j|
      rows[dy + i][dx + j] = char unless char == "."
    end
  end

  pixels = []
  H.times do |y|
    W.times do |x|
      color = PALETTE[rows[y][x]]
      pixels << (color ? color + [255] : [0, 0, 0, 0])
    end
  end
  File.binwrite(File.join(out, "shop.png"), png(pixels, W, H))
  puts "shop.png  #{W}x#{H}"
end
