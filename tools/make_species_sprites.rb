# Generates the crustacean sprite sheets as PNGs with nothing but Ruby stdlib —
# same approach as tools/make_decor_sprites.rb: ASCII art plus a palette, '.' is
# transparent. Runs in MRI, not in DragonRuby: this is an authoring tool.
#
#   ruby tools/make_species_sprites.rb sprites/animals/crustaceans
#
# One sheet per species, FRAMES frames laid out in a single row — the shape and
# the palette are separate, so a species is a body plus a set of colours. The
# animation is generated rather than drawn: the walk cycle shifts the leg pixels
# a column left and right (LEG_PHASES), which is all a scuttle needs and keeps
# every species to one pose of hand-drawn art.
require "zlib"

FRAME_W = 20
FRAME_H = 12
FRAMES = 8
LEG_PHASES = [0, 1, 0, -1, 0, 1, 0, -1] # column offset of the legs, per frame

# Colours every crustacean shares, whatever its shell looks like.
COMMON = {
  "e" => [24, 22, 28],    # eye
  "a" => [70, 62, 58],    # antenna / feeler
}

# Body plans. 'S' shell, 's' shell highlight, 'c' claw, 'l' leg, 'e' eye,
# 'a' antenna. Drawn facing right; the game flips them when they walk left.
SHAPES = {
  # The classic crab: broad shell, two raised claws, four legs a side. Seen
  # head-on, the way a crab actually meets you on the sand.
  "crab" => [
    "....................",
    "cc..............cc..",
    "ccc............ccc..",
    ".cc............cc...",
    "..cc.SSSSSSS..cc....",
    "...cSSSSSSSSSc......",
    "...SSeSSSSSeSS......",
    "...SssssssssSS......",
    "...SSSSSSSSSSS......",
    "....SSSSSSSSS.......",
    "....l.l.l.l.l.......",
    "...l.l.l.l.l.l......",
  ],

  # A lobster: long segmented body, a fanned tail at the back, two heavy claws
  # reaching forward, and feelers out front.
  "lobster" => [
    "..............aaaaaa",
    ".............a......",
    "SS...........a......",
    "SSS..........cccccc.",
    "SSSS........cccccc..",
    "SSSSSSSSSSSSSSs.....",
    "SSSssssssssssseSs...",
    "SSSSSSSSSSSSSSs.....",
    "SSSl..l..l..lcccccc.",
    "SS.l..l..l..lcccccc.",
    "..l..l..l..l........",
    "....................",
  ],

  # A spiny lobster: no great claws at all, but two enormous feelers it waves
  # ahead of itself, and a ridged back.
  "spiny" => [
    "................aaaa",
    "..............aa....",
    "SS...........a......",
    "SSS..........a......",
    "SSSS.........a......",
    "SSSSsSSSsSSSsSSs....",
    "SSSssssssssssseSs...",
    "SSSSsSSSsSSSsSSs....",
    "SSSl..l..l..laa.....",
    "SS.l..l..l..l..aa...",
    "..l..l..l..l.....aaa",
    "....................",
  ],

  # A hermit crab: most of it is the borrowed snail shell, with a small face and
  # a pair of legs poking out the front.
  "hermit" => [
    "....................",
    "...SSSSSS...........",
    "..SSssssSS..........",
    ".SSsSSSSsSS.........",
    ".SSsSSSSsSSc........",
    ".SSsSSSSsSScc.......",
    "..SSssssSSecc.......",
    "...SSSSSSSSc........",
    "....SSSSSS..........",
    "....llllll..........",
    "...l..l..l..........",
    "..l...l...l.........",
  ],

  # A fiddler crab: one claw far too big for it, the other barely there. The
  # oversized one is the whole joke, so it gets the pixels.
  "fiddler" => [
    "....................",
    "..............cccc..",
    ".............cccccc.",
    "............ccc..cc.",
    "...c.......cccccccc.",
    "..cc.SSSSSSccccccc..",
    "...SSeSSSSSeSS......",
    "...SssssssssSS......",
    "...SSSSSSSSSSS......",
    "....SSSSSSSSS.......",
    "....l.l.l.l.l.......",
    "...l.l.l.l.l.l......",
  ],

  # A deep-sea spider crab: a small body carried high on absurdly long legs.
  # Almost all leg, which is what makes it read as *deep*.
  "spider" => [
    "l..................l",
    ".l................l.",
    "..l..............l..",
    "...l...cSSSSc...l...",
    "....l.SSeSSeSS.l....",
    ".....lSssssssSl.....",
    "..l...SSSSSSS...l...",
    "...l..lSSSSSl..l....",
    "....l..l...l..l.....",
    ".....l.l...l.l......",
    "......l.....l.......",
    ".....l.......l......",
  ],
}

# A species is a body plan plus its colours. Same shape, different creature —
# the shore crab and the sand crab are the same animal wearing another coat.
SPECIES = {
  "taschenkrebs" => { shape: "crab",
                      palette: { "S" => [176, 84, 62], "s" => [214, 128, 96],
                                 "c" => [196, 100, 74], "l" => [148, 68, 50] } },

  "hummer" => { shape: "lobster",
                palette: { "S" => [154, 46, 44], "s" => [206, 88, 74],
                           "c" => [178, 58, 50], "l" => [122, 36, 36] } },

  "languste" => { shape: "spiny",
                  palette: { "S" => [140, 96, 44], "s" => [204, 158, 78],
                             "c" => [160, 116, 56], "l" => [110, 74, 34] } },

  "einsiedler" => { shape: "hermit",
                    palette: { "S" => [150, 122, 86], "s" => [206, 180, 138],
                               "c" => [186, 118, 90], "l" => [162, 104, 78] } },

  "winkerkrabbe" => { shape: "fiddler",
                      palette: { "S" => [92, 122, 74], "s" => [138, 172, 106],
                                 "c" => [226, 196, 108], "l" => [76, 100, 60] } },

  "abgrundkrabbe" => { shape: "spider",
                       palette: { "S" => [178, 186, 202], "s" => [222, 228, 238],
                                  "c" => [166, 174, 192], "l" => [148, 158, 176] } },

  # Above the waterline, on an island's beach: sun-bleached and sandy.
  "strandkrabbe" => { shape: "crab",
                      palette: { "S" => [198, 158, 96], "s" => [236, 204, 142],
                                 "c" => [212, 172, 106], "l" => [170, 132, 78] } },
}

# The walk cycle, made rather than drawn: every frame is the one pose with its
# leg pixels slid `shift` columns along. Legs are whatever the artist marked 'l'
# — so a spider crab's whole silhouette animates and a hermit crab's two feet do.
def frame_rows(rows, shift)
  return rows if shift.zero?

  rows.map do |row|
    next row unless row.include?("l")

    shifted = "." * row.length
    row.each_char.with_index do |ch, x|
      next if ch == "."

      target = ch == "l" ? x + shift : x
      next if target < 0 || target >= row.length

      shifted[target] = ch
    end
    shifted
  end
end

def png(pixels, w, h)
  raw = +""
  h.times do |y|
    raw << "\x00" # filter: none
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

# The whole sheet as a pixel grid: FRAMES frames side by side, each the pose at
# its own leg phase, coloured through this species' palette.
def sheet_pixels(shape, palette)
  colors = COMMON.merge(palette)
  pixels = []
  FRAME_H.times do |y|
    FRAMES.times do |frame|
      rows = frame_rows(shape, LEG_PHASES[frame])
      FRAME_W.times do |x|
        ch = rows[y][x] || "."
        color = colors[ch]
        pixels << (color ? color + [255] : [0, 0, 0, 0])
      end
    end
  end
  pixels
end

def check_shapes!
  SHAPES.each do |name, rows|
    abort "#{name}: #{rows.length} rows, expected #{FRAME_H}" unless rows.length == FRAME_H
    rows.each_with_index do |row, i|
      abort "#{name} row #{i}: #{row.length} px, expected #{FRAME_W}" unless row.length == FRAME_W
    end
  end
end

if __FILE__ == $0
  check_shapes!
  out = ARGV[0] or abort "usage: ruby tools/make_species_sprites.rb <sprites/animals/crustaceans>"
  require "fileutils"
  FileUtils.mkdir_p(out)
  SPECIES.each do |name, spec|
    pixels = sheet_pixels(SHAPES[spec[:shape]], spec[:palette])
    File.binwrite(File.join(out, "#{name}.png"), png(pixels, FRAME_W * FRAMES, FRAME_H))
    puts "#{name}.png  #{FRAME_W * FRAMES}x#{FRAME_H}  (#{FRAMES} x #{FRAME_W}x#{FRAME_H}, #{spec[:shape]})"
  end
end
