# Generates the collectible item sprites as PNGs with nothing but Ruby stdlib —
# same approach as make_decor_sprites.rb. Each sprite is ASCII art plus a
# palette; '.' (and any unlisted char) is transparent. Small treasures a diver
# finds on the sea floor: a message in a bottle, a lost shoe, a tin can, a gem,
# an old key.
require "zlib"

PALETTE = {
  "b" => [96, 168, 120],   # bottle glass, mid
  "B" => [58, 120, 84],    # bottle glass, dark
  "c" => [176, 220, 190],  # bottle glass, shine
  "P" => [232, 222, 190],  # rolled paper, lit
  "p" => [198, 184, 150],  # rolled paper, shade
  "k" => [150, 110, 66],   # cork
  "s" => [140, 92, 58],    # shoe leather, lit
  "S" => [92, 60, 40],     # shoe leather, dark
  "u" => [86, 80, 76],     # shoe sole, lit
  "U" => [44, 40, 38],     # shoe sole, dark
  "m" => [180, 186, 194],  # tin, lit
  "M" => [120, 126, 136],  # tin, dark
  "l" => [214, 126, 74],   # can label, lit
  "L" => [176, 92, 52],    # can label, dark
  "j" => [128, 208, 232],  # gem, bright
  "J" => [64, 140, 178],   # gem, facet
  "w" => [236, 250, 255],  # gem, sparkle
  "o" => [222, 186, 96],   # gold, lit
  "O" => [168, 132, 58],   # gold, dark
}

SPRITES = {
  # A corked bottle lying on its side, a rolled note sealed inside.
  "bottle" => [
    "...bbbbbbbbb.....",
    "..bcBBBBBBBBbb...",
    ".bBPpPpPpPpBBbkk.",
    "bBcPpPpPpPpBBBbkk",
    "bBBPpPpPpPpBBBbkk",
    ".bBPpPpPpPpBBbkk.",
    "..bBBBBBBBBbb....",
    "...bbbbbbbbb.....",
  ],
  # A lost boot, toe to the left, sole along the bottom.
  "shoe" => [
    ".......sss....",
    "......sSSSs...",
    "..sssssSSSSs..",
    ".sSSSSSSSSSSs.",
    "sSSSSSSSSSSSSs",
    "sSSSSSSSSSSSSs",
    "uuuuuuuuuuuuuu",
    ".UUUUUUUUUUUU.",
  ],
  # A dented tin can, standing, with a torn label around the middle.
  "can" => [
    ".mMMMMMMm.",
    "mMmmmmmmMm",
    "mMlLLLLlMm",
    "mMlLLLLlMm",
    "mMlLLLLlMm",
    "mMlLLLLlMm",
    "mMlLLLLlMm",
    "mMlLLLLlMm",
    "mMmmmmmmMm",
    ".mMMMMMMm.",
  ],
  # A cut gem, glinting.
  "jewel" => [
    "...wjjj....",
    "..jJjjjJj..",
    ".jJjjjjjJj.",
    "jJjjjjjjjJj",
    ".JjjjjjjjJ.",
    "..JjjjjJj..",
    "...JjjJ....",
    "....Jj.....",
  ],
  # An old key: ring bow on the left, a toothed bit on the right.
  "key" => [
    "..ooo..........",
    ".oO.Oo.........",
    ".oO.OoOOOOOOOO.",
    ".oOOOoOOOOO.O.O",
    ".oO.OoOOOOOOOO.",
    ".oO.Oo.........",
    "..ooo..........",
  ],
}

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

out = ARGV[0] or abort "usage: ruby make_item_sprites.rb <sprites/items dir>"
SPRITES.each do |name, rows|
  w = rows.map(&:length).max
  h = rows.length
  pixels = []
  h.times do |y|
    w.times do |x|
      ch = rows[y][x] || "."
      color = PALETTE[ch]
      pixels << (color ? color + [255] : [0, 0, 0, 0])
    end
  end
  File.binwrite(File.join(out, "#{name}.png"), png(pixels, w, h))
  puts "#{name}.png  #{w}x#{h}"
end
