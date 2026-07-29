# Generates the island's people as PNGs with nothing but Ruby stdlib — ASCII art
# plus a palette, '.' is transparent. Runs in MRI, not in DragonRuby: an
# authoring tool, the same as the other make_*_sprites.rb here.
#
#   ruby tools/make_islander_sprites.rb sprites/decor/islanders
#
# Shape and palette are kept apart, the way the crustaceans do it: there are
# four drawings — a child, a bather, somebody sitting with a guitar, and
# somebody sitting looking out to sea — and seven people, each of whom is one of
# those shapes in their own colours. Flori and Falko stand next to each other,
# so two boys in identical trunks would read as one boy drawn twice.
#
# Rows are padded out to the width of the shape rather than counted by hand, the
# way the shop's art is: at twenty-odd characters a row, hand-aligning the right
# margin is a column-counting exercise and every edit risks a silent shift. What
# matters is the left-hand side, where the figure is, and that has no padding to
# be ambiguous about. A row longer than the shape is still an error.
require "zlib"

# Odd widths on purpose: a symmetrical figure wants a real middle column to hang
# the nose and the spine off.
SHAPES = {
  boy: [
    "....hhh....",
    "...hhhhh...",
    "...hsssh...",
    "...heseh...",
    "...hsssh...",
    "....sss....",
    "...ttttt...",
    "..sttttts..",
    "..sttttts..",
    "...ttttt...",
    "....ccc....",
    "....ccc....",
    "....s.s....",
    "....s.s....",
    "....s.s....",
    "...ss.ss...",
  ],
  bather: [
    ".....hhh.....",
    "....hhhhh....",
    "....hsssh....",
    "....heseh....",
    "....hsssh....",
    ".....sss.....",
    ".....sss.....",
    "...ttttttt...",
    "..stttttts...",
    "..stttttts...",
    "..stttttts...",
    "...ttttttt...",
    "...ccccccc...",
    "...ccccccc...",
    "....s...s....",
    "....s...s....",
    "....s...s....",
    "....s...s....",
    "....s...s....",
    "...ss...ss...",
  ],
  # Standing, with an electric slung across the front — the pose every pixel-art
  # guitarist is drawn in, and for a reason.
  #
  # Twice drawn sitting first, and twice it came out as somebody holding a
  # frying pan. The problem was never the detail on the body, it was the
  # geometry: a big round body under a steep neck *is* a pan, whatever you paint
  # on it. What reads as a guitar at this size is a small flat body with a waist,
  # and a long thin neck going out level from it. So: standing, body in front of
  # the belly, neck straight out to the right, headstock on the end, both hands
  # on the instrument.
  #
  # The body colour is per person (PEOPLE), because that is the loudest thing
  # about an electric guitar and it tells the two of them apart at a glance.
  # Sitting cross-legged at the fire. The guitar keeps *exactly* the geometry
  # that finally worked standing up — flat body, level neck one pixel thick,
  # headstock on the end — because that is what made it read as a guitar, and
  # sitting is not a reason to give it up. Only the legs change: folded, so the
  # silhouette widens at the bottom instead of standing on two posts.
  #
  # Sitting was tried twice before and failed twice, but both of those had the
  # instrument sitting *on* a lap under a steep neck. Here it is still held
  # across the front, and there is a fire beside him saying what he is sitting
  # at, which is the thing the earlier attempts had nothing of.
  musician: [
    "....hhhhh",
    "...hhhhhhh",
    "...hhsssshh",
    "...hseseshh",
    "...hssssshh",
    "....sssss",
    ".....sss",
    "...ttttttt",
    "..ttttttttt",
    "..sgggggggs",
    ".ggggggggggg........NN",
    ".gggGGgggggGnnnnnnnnnNN",
    ".ggggggggggg........NN",
    "..sgggggggs",
    "..ccccccccc",
    ".ccccccccccc",
    "cccccccccccccc",
    "ss..........ss",
  ],
  # The warden, standing at reception. The bather's shape with clothes on: a
  # shirt with sleeves and long trousers, which at this size is the whole of the
  # difference between somebody on holiday and somebody who works here.
  warden: [
    ".....hhh.....",
    "....hhhhh....",
    "....hsssh....",
    "....heseh....",
    "....hsssh....",
    ".....sss.....",
    ".....sss.....",
    "...ttttttt...",
    "..ttttttttt..",
    "..tttttttts..",
    "..stttttttt..",
    "...ttttttt...",
    "...ccccccc...",
    "...ccccccc...",
    "....c...c....",
    "....c...c....",
    "....c...c....",
    "....c...c....",
    "...dd...dd...",
    "...dd...dd...",
  ],
}

# Skin, eyes and the guitar are the same for everybody; hair, top and trunks are
# what tells them apart. Two of a kind never stand next to each other in the
# same colours.
COMMON = {
  "s" => [226, 176, 138], # skin
  "e" => [40, 34, 32],    # eyes
  "n" => [92, 62, 38],    # guitar neck ...
  "N" => [48, 32, 20],    # ... and the headstock on the end of it
}

PEOPLE = {
  # The boys, side by side at the water's edge.
  "flori"     => { shape: :boy,      h: [148, 96, 44],  t: [232, 108, 88], c: [58, 92, 148] },
  "falko"     => { shape: :boy,      h: [58, 44, 36],   t: [246, 216, 96], c: [76, 132, 96] },
  # The bathers, standing in the shallows — no shirt, so the top is skin.
  "hendrik"   => { shape: :bather,   h: [96, 62, 44],   t: [226, 176, 138], c: [200, 72, 64] },
  "tall_pete"     => { shape: :bather,   h: [176, 172, 164], t: [226, 176, 138], c: [54, 78, 132] },
  # The musicians. g is the guitar body and G its pickups — one black and one
  # cream, which is the fastest way to tell two standing guitarists apart.
  "sebastian"     => { shape: :musician, h: [42, 34, 30],   t: [124, 92, 156], c: [62, 78, 118],
                   g: [38, 36, 42], G: [206, 198, 180] },
  "george" => { shape: :musician, h: [156, 112, 60], t: [86, 142, 156], c: [62, 78, 118],
                   g: [232, 226, 208], G: [72, 68, 64] },
  # Mike, the warden.
  "mike"      => { shape: :warden,  h: [70, 56, 48],   t: [216, 208, 190], c: [110, 96, 80] },
}

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
  out = ARGV[0] or abort "usage: ruby tools/make_islander_sprites.rb <sprites/decor/islanders>"

  SHAPES.each do |kind, rows|
    width = rows.map(&:length).max
    rows.each_with_index do |row, i|
      abort "#{kind} row #{i} is #{row.length} px, wider than #{width}" if row.length > width
    end
  end

  require "fileutils"
  FileUtils.mkdir_p(out)

  sizes = []
  PEOPLE.each do |key, person|
    shape = SHAPES[person[:shape]]
    w = shape.map(&:length).max
    h = shape.length
    rows = shape.map { |row| row.ljust(w, ".") }
    palette = COMMON.merge("h" => person[:h], "t" => person[:t], "c" => person[:c])
    # Only the guitarists carry these; everybody else's shape never asks for them.
    palette["g"] = person[:g] if person[:g]
    palette["G"] = person[:G] if person[:G]

    pixels = []
    h.times do |y|
      w.times do |x|
        color = palette[rows[y][x]]
        pixels << (color ? color + [255] : [0, 0, 0, 0])
      end
    end
    File.binwrite(File.join(out, "#{key}.png"), png(pixels, w, h))
    puts "#{key}.png  #{w}x#{h}  (#{person[:shape]})"
    sizes << format("    %-11s => { path: \"sprites/decor/islanders/%s.png\", w: %d, h: %d },",
                    "\"#{key}\"", key, w, h)
  end

  # Printed so the table in app/world/beach.rb can be pasted rather than kept in
  # step by hand. Editing a shape changes its size, and a stale w/h there does
  # not fail — it silently draws the sprite squashed, which is easy to look
  # straight past. That happened to both guitarists.
  puts
  puts "  ISLANDER_SPRITES for app/world/beach.rb:"
  puts sizes
end
