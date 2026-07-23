# Generates the island's decor sprites as PNGs with nothing but Ruby stdlib —
# same approach as the earlier decor art (seaweed, coral, boat).
# Each sprite is ASCII art plus a palette; '.' is transparent.
require "zlib"

PALETTE = {
  "T" => [92, 64, 40],    # palm trunk, dark
  "t" => [124, 88, 54],   # palm trunk, lit
  "G" => [48, 104, 52],   # frond / leaf, deep green
  "g" => [76, 148, 72],   # leaf, mid
  "l" => [124, 184, 92],  # leaf, lit
  "C" => [176, 132, 68],  # coconut
  "b" => [58, 92, 48],    # bush shadow
  "B" => [84, 132, 62],   # bush body
  "h" => [110, 166, 86],  # bush highlight
  "W" => [238, 240, 244], # gull, white
  "w" => [196, 202, 212], # gull, shaded
  "K" => [52, 58, 70],    # gull, wing tip
  "y" => [222, 196, 118], # dune grass, dry
  "Y" => [180, 200, 110], # dune grass, green
}

SPRITES = {
  "palm" => [
    "......gg....gg......",
    "....glllggllllg.....",
    "..gllGGlllGGllllg...",
    ".glGG...lTt...GGlg..",
    "gGG....lTTt....GGGg.",
    "........TCt.........",
    "........TCt.........",
    ".......TTt..........",
    ".......TTt..........",
    "......TTt...........",
    "......TTt...........",
    ".....TTt............",
    ".....TTt............",
    ".....TTt............",
    "....TTt.............",
    "....TTt.............",
  ],
  "bush" => [
    "....hhh.....",
    "..hhBBBhh...",
    ".hBBBBBBBh..",
    "hBBBBBBBBBh.",
    "BBBBbBBBBBBB",
    "bBBBbbBBBBbb",
    ".bbb..bbbb..",
  ],
  "grass" => [
    "..Y...Y.....",
    ".YY..YY..Y..",
    ".Yy..Yy.YY..",
    ".yy..yy.yy..",
    "yy...yy..yy.",
  ],
  "gull" => [
    "K..........K",
    ".Kw......wK.",
    "..WWw..wWW..",
    "....WWWW....",
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

out = ARGV[0] or abort "usage: ruby make_sprites.rb <sprites/decor dir>"
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
