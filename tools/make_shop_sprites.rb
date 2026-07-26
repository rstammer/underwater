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

W = 112
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
  "h" => [96, 62, 44],     # Insa: hair ...
  "k" => [226, 176, 138],  # ... face and hands ...
  "e" => [40, 34, 32],     # ... eyes ...
  "t" => [86, 142, 156],   # ... and her shirt
  "S" => [72, 108, 132],   # lettering on the sign
  "f" => [196, 208, 216],  # a stack of film boxes
}

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
  "...................dd.............dd..................hhhhhh.....................dd....dbbccbbd..dBBccBBd",
  "...................dd.............dd..................hhhhhh.....................dd....dbbccbbd..dBBccBBd",
  "...................dd.............dd..................hhhhhh.....................dd....dbbccbbd..dBBccBBd",
  "...................dd.............dd..................hkkkkh.....................dd....dbbccbbd..dBBccBBd",
  ".......ygg.yoo.ygg.ddfyoo.........dd..................hekkeh.....................dd...ddbbccbbdddddBBccBBddddddd",
  ".......ggg.ooo.ggg.ddfooo.........dd..................hkkkkh.....................dd...ddbbccbbdddddBBccBBddddddd",
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
