# Generates the coral sprite sheets as PNGs with nothing but Ruby stdlib —
# same approach as the other sprite tools: ASCII art plus a palette, '.' is
# transparent. Runs in MRI, not in DragonRuby: this is an authoring tool.
#
#   ruby tools/make_coral_sprites.rb sprites/animals/anchored
#
# One frame per species, no animation. Everything else in the sea moves, which
# is what its sprite sheet is for; a coral is the one thing down there that
# holds still, and a swaying coral would be a plant. The reef reads as busy
# because there are a lot of them in a lot of colours, not because they wiggle.
require "zlib"

# Structure is shared, colour is not: the same body plan in two palettes is two
# species on a reef, which is exactly how reefs look.
COMMON = {
  "." => nil,
  "k" => [58, 44, 52],   # the shaded underside every coral sits on
}

SHAPES = {
  # Brain coral: a boulder with a folded surface. The grooves are what make it a
  # brain rather than a rock, so they run the full width and never line up.
  "brain" => [
    "......AAAAAA......",
    "....AAaaaaaaAA....",
    "..AAaaBBaaBBaaAA..",
    "..AaaBBaaBBaaaaA..",
    ".AaaBBaaaaBBaaaaA.",
    ".AaBBaaBBaaaaBBaA.",
    "AaaaaaBBaaBBaaaaaA",
    "AaBBaaaaBBaaaaBBaA",
    "AaaaBBaaaaBBaaaaaA",
    ".AaaaaBBaaaaBBaaA.",
    ".AAaaaaaaaaaaaaAA.",
    "..AAaaaaaaaaaaAA..",
    "...kkAAAAAAAAkk...",
    ".....kkkkkkkk.....",
  ],

  # Staghorn: branches that fork upward. The trick is that no two tips end at
  # the same height — a coral that does is a comb.
  "staghorn" => [
    "..A....A......A...",
    "..Aa...Aa....Aa...",
    "..Aa...Aa..A.Aa...",
    "A.Aa.A.Aa..Aa Aa..",
    "Aa Aa Aa Aa Aa Aa.",
    ".AaaAaaAaaAaaAaa..",
    "..AaaaAaaaAaaaA...",
    "...AaaaaAaaaaA....",
    "....AaaaaAaaaA....",
    ".....AaaaaaaA.....",
    "......AaaaaA......",
    ".....kAAAAAk......",
    "......kkkkk.......",
  ],

  # Sea fan: a flat mesh held broadside to the current, so it is drawn as a net
  # rather than as a solid — a filled fan reads as a leaf.
  "fan" => [
    "...A...A...A...A..",
    "..AaA.AaA.AaA.AaA.",
    "..A.AaA.AaA.AaA.A.",
    ".AaA.A.AaA.A.AaA..",
    ".A.AaAaA.AaAaA.A..",
    "AaA.A.AaA.A.AaA...",
    "A.AaAaA.AaAaA.A...",
    ".AaA.AaA.AaA.A....",
    "..A.AaA.AaA.A.....",
    "...AaA.AaA.A......",
    "....A.AaA.A.......",
    ".....AaAaA........",
    "......AaA.........",
    ".....kAAAk........",
    "......kkk.........",
  ],

  # Organ pipe: a bundle of tubes of different heights, each with its mouth open
  # at the top. The open mouths are the whole tell.
  "pipe" => [
    "..B...B.....B.....",
    ".AaA.AaA...AaA....",
    ".AaA.AaA.B.AaA.B..",
    ".AaA.AaA.AaAaA.AaA",
    ".AaA.AaA.AaAaA.AaA",
    "BAaA.AaA.AaAaA.AaA",
    "AaAA.AaA.AaAaA.AaA",
    "AaAAaAaAaAaAaAaAaA",
    "AaAAaAaAaAaAaAaAaA",
    "AaaaaaaaaaaaaaaaaA",
    "AaaaaaaaaaaaaaaaaA",
    ".kAAAAAAAAAAAAAAk.",
    "..kkkkkkkkkkkkkk..",
  ],

  # The seahorse. Not a coral, but it belongs to the same mechanism: it grips a
  # frond and stays put, which is why it is in here rather than in the swarm.
  #
  # Drawn upright and narrow, against every other animal in the game — that
  # silhouette is the whole recognition, and it has to survive being twelve
  # pixels wide. So: the head bent forward at the top, the snout out in front of
  # it, the belly curving out, and the tail curled the other way at the bottom.
  # Everything else is detail that would not survive the scale anyway.
  "seahorse" => [
    "....AAA...",
    "...AaaaA..",
    "...AaBaA..",
    ".AAAaaaA..",
    "AaaaaaaA..",
    "AAAAaaaA..",
    "....AaaaA.",
    "....AaaaAA",
    "....AaaaaA",
    "....AaaaaA",
    "....AaaaA.",
    "....Aaaa..",
    "...Aaaa...",
    "...AaaA...",
    "..Aaaa....",
    "..AaaA....",
    "..AaaA....",
    "..AaaA....",
    "...AaA....",
    "...AAA....",
  ],

  # Soft coral: a fat lobed body with polyps out. No hard edges anywhere — it is
  # the one that should look like it would give if you pushed it.
  "soft" => [
    "...B..B...B..B....",
    "..BAaBAa.BAaBAa...",
    "..AaaaaaaaaaaaA...",
    ".AaaaaaaaaaaaaaA..",
    ".AaaBaaaaaaBaaaA..",
    "AaaaaaaaBaaaaaaaA.",
    "AaaaaaaaaaaaaaaaA.",
    "AaaBaaaaaaaaBaaaA.",
    ".AaaaaaaaaaaaaaA..",
    ".AaaaaaaaaaaaaaA..",
    "..AaaaaaaaaaaaA...",
    "...AaaaaaaaaaA....",
    "....kAAAAAAk......",
    ".....kkkkkk.......",
  ],
}

# A species is a shape plus three colours: body, lit side, and the specks.
PALETTES = {
  "hirnkoralle"   => { "A" => [176, 96, 118], "a" => [214, 138, 158], "B" => [120, 58, 82] },
  "geweihkoralle" => { "A" => [206, 132, 74],  "a" => [238, 176, 110], "B" => [154, 88, 46] },
  "faechergorgonie" => { "A" => [150, 86, 176], "a" => [190, 132, 214], "B" => [110, 56, 136] },
  "orgelkoralle"  => { "A" => [190, 74, 78],   "a" => [226, 122, 116], "B" => [244, 214, 180] },
  "lederkoralle"  => { "A" => [206, 174, 84],  "a" => [234, 212, 130], "B" => [246, 240, 196] },
  # Yellow against the kelp's green, or it is a twig.
  "seepferdchen"  => { "A" => [198, 156, 52],  "a" => [238, 200, 96],  "B" => [40, 34, 30] },
}

SPECIES = {
  "hirnkoralle"     => "brain",
  "geweihkoralle"   => "staghorn",
  "faechergorgonie" => "fan",
  "orgelkoralle"    => "pipe",
  "lederkoralle"    => "soft",
  "seepferdchen"    => "seahorse",
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

out = ARGV[0] or abort "usage: ruby make_coral_sprites.rb <sprites/animals/anchored dir>"
require "fileutils"
FileUtils.mkdir_p(out)

SPECIES.each do |name, shape_key|
  rows = SHAPES.fetch(shape_key)
  palette = COMMON.merge(PALETTES.fetch(name))
  w = rows.map(&:length).max
  h = rows.length
  pixels = []
  h.times do |y|
    w.times do |x|
      ch = rows[y][x] || "."
      colour = palette[ch]
      pixels << (colour ? colour + [255] : [0, 0, 0, 0])
    end
  end
  File.binwrite(File.join(out, "#{name}.png"), png(pixels, w, h))
  puts "#{name}.png  #{w}x#{h}  (#{shape_key})"
end
