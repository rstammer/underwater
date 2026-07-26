# Generates the shop hut as a PNG with nothing but Ruby stdlib — ASCII art plus
# a palette, '.' is transparent. Runs in MRI, not in DragonRuby: an authoring
# tool, the same as the other make_*_sprites.rb here.
#
#   ruby tools/make_shop_sprites.rb sprites/decor
#
# One building, on a fixed island in sector 3. It has to read as *a shop* from
# a screen away and at the scale the island's other decoration is drawn at, so
# it is mostly silhouette: a lit doorway, a striped awning over a counter, and a
# crooked sign on the roof. The lit window is the important pixel — a dark hut
# on a dark island is a rock.
require "zlib"

W = 34
H = 26

PALETTE = {
  "w" => [126, 92, 62],    # planked wall
  "W" => [150, 112, 76],   # ... its lit side
  "d" => [74, 52, 34],     # dark timber, posts, frame
  "r" => [172, 74, 62],    # roof
  "R" => [204, 100, 80],   # ... catching the light
  "a" => [232, 226, 208],  # awning, pale stripe
  "A" => [196, 92, 78],    # awning, red stripe
  "l" => [255, 226, 150],  # lamp-light through the door
  "s" => [238, 232, 214],  # the sign
  "p" => [92, 66, 44],     # counter
}

# Drawn facing the camera; nothing flips it.
SHAPE = [
  "..........ss.ss.ss................",
  "..........s.....s.................",
  "..........sssssss.................",
  "..............d...................",
  "..............d...................",
  "....rrrrrrrrrrrrrrrrrrrr..........",
  "...rRRRRRRRRRRRRRRRRRRRRr.........",
  "..rRRRRRRRRRRRRRRRRRRRRRRr........",
  ".rrrrrrrrrrrrrrrrrrrrrrrrrr.......",
  ".dwwwwwwwwwwwwwwwwwwwwwwwwd.......",
  ".dwWWWWwwwwwwwwwwwwwwwwwwwd.......",
  ".dwWllWwwwwwwwwwwwwwwwwwwwd.......",
  ".dwWllWwwwwwwwwwwaAaAaAaAaAaAa....",
  ".dwWllWwwwwwwwwwwaAaAaAaAaAaAa....",
  ".dwWllWwwwwwwwwwwd...........d....",
  ".dwWllWwwwwwwwwwwd...........d....",
  ".dwWllWwwwwwwwwwwd...........d....",
  ".dwWllWwwwwwwwwwwppppppppppppd....",
  ".dwWllWwwwwwwwwwwppppppppppppd....",
  ".dwWllWwwwwwwwwwwd.........d.d....",
  ".dwWllWwwwwwwwwwwd.........d.d....",
  ".dwWllWwwwwwwwwwwd.........d.d....",
  ".dwwwwwwwwwwwwwwwd.........d.d....",
  ".dddddddddddddddddd........d.d....",
  "..................................",
  "..................................",
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
    abort "row #{i}: #{row.length} px, expected #{W}" unless row.length == W
  end
  abort "#{SHAPE.length} rows, expected #{H}" unless SHAPE.length == H

  require "fileutils"
  FileUtils.mkdir_p(out)
  pixels = []
  H.times do |y|
    W.times do |x|
      color = PALETTE[SHAPE[y][x]]
      pixels << (color ? color + [255] : [0, 0, 0, 0])
    end
  end
  File.binwrite(File.join(out, "shop.png"), png(pixels, W, H))
  puts "shop.png  #{W}x#{H}"
end
