# The six faces of a day, as one sprite sheet: sprites/decor/daytime.png.
#
#   ruby tools/make_daytime_sprites.rb sprites/decor
#
# Same approach as every other sprite in here — ASCII art plus a palette, Ruby
# stdlib only, run in MRI. Six frames in a row, in the order the day goes, so
# the HUD picks one by index and nothing has to map names to pictures.
require "zlib"

FRAME = 24
PHASES = ["morgen", "vormittag", "mittag", "nachmittag", "abend", "nacht"]

PALETTE = {
  "S" => [255, 214, 92],   # the sun, midday
  "s" => [246, 176, 62],   # ... lower and warmer
  "r" => [232, 116, 62],   # ... at the horizon
  "R" => [206, 78, 58],    # sunset red
  "y" => [255, 236, 170],  # rays / glare
  "H" => [86, 120, 148],   # the horizon line
  "M" => [226, 232, 244],  # moon
  "m" => [150, 168, 196],  # moon, shaded
  "t" => [198, 214, 240],  # stars
}

ART = {
  # Low sun just up, with the horizon under it.
  "morgen" => [
    "........................",
    "........................",
    "........................",
    "..........y.............",
    "........................",
    "....y.........y.........",
    "........................",
    "........rrrrrr..........",
    ".......rrssssrr.........",
    "......rrssssssrr........",
    "......rssssssssr........",
    "......rssssssssr........",
    "......rrssssssrr........",
    ".HHHHHHrrssssrrHHHHHHHH.",
    ".HHHHHHHrrrrrrHHHHHHHHH.",
    "........................",
    "........................",
    "........................",
    "........................",
    "........................",
    "........................",
    "........................",
    "........................",
    "........................",
  ],
  # Climbing, clear of the horizon.
  "vormittag" => [
    "........................",
    "........................",
    "..........y.............",
    "........................",
    "....y.........y.........",
    "........................",
    "........ssssss..........",
    ".......sssSSsss.........",
    "......sssSSSSsss........",
    "......ssSSSSSSss........",
    "......ssSSSSSSss........",
    "......sssSSSSsss........",
    ".......sssSSsss.........",
    "........ssssss..........",
    "........................",
    "....y.........y.........",
    "........................",
    "........................",
    "........................",
    "........................",
    "........................",
    "........................",
    "........................",
    "........................",
  ],
  # Overhead and glaring, rays all round.
  "mittag" => [
    "..........y.............",
    "..........y.............",
    "...y......y......y......",
    "....y....yyy....y.......",
    "........SSSSSS..........",
    ".......SSSSSSSS.........",
    "......SSSSSSSSSS........",
    "yyy..SSSSSSSSSSSS..yyy..",
    "yyy..SSSSSSSSSSSS..yyy..",
    "......SSSSSSSSSS........",
    ".......SSSSSSSS.........",
    "........SSSSSS..........",
    "....y....yyy....y.......",
    "...y......y......y......",
    "..........y.............",
    "..........y.............",
    "........................",
    "........................",
    "........................",
    "........................",
    "........................",
    "........................",
    "........................",
    "........................",
  ],
  # On the way down, warmer.
  "nachmittag" => [
    "........................",
    "........................",
    "........................",
    "....y.........y.........",
    "........................",
    "........................",
    "........ssssss..........",
    ".......ssssssss.........",
    "......sssSSSSsss........",
    "......ssSSSSSSss........",
    "......ssSSSSSSss........",
    "......sssSSSSsss........",
    ".......ssssssss.........",
    "........ssssss..........",
    "........................",
    "...y..........y.........",
    "........................",
    "........................",
    "........................",
    "........................",
    "........................",
    "........................",
    "........................",
    "........................",
  ],
  # Half gone into the sea, red.
  "abend" => [
    "........................",
    "........................",
    "........................",
    "........................",
    "........................",
    "........RRRRRR..........",
    ".......RRrrrrRR.........",
    "......RRrrssrrRR........",
    "......RrrssssrrR........",
    "......RrrssssrrR........",
    ".HHHHHHRRrrrrRRHHHHHHHH.",
    ".HHHHHHHRRRRRRHHHHHHHHH.",
    ".HHHHHHHHHHHHHHHHHHHHHH.",
    "........................",
    "........................",
    "........................",
    "........................",
    "........................",
    "........................",
    "........................",
    "........................",
    "........................",
    "........................",
    "........................",
  ],
  # A crescent and a few stars.
  "nacht" => [
    "........................",
    "...t....................",
    "........................",
    "..........MMMM..........",
    ".........MMMMMm.........",
    "........MMMmmmm......t..",
    "........MMmm............",
    ".t......MMmm............",
    "........MMmm............",
    "........MMMmmmm.........",
    ".........MMMMMm.........",
    "..........MMMM..........",
    "........................",
    "....t...............t...",
    "........................",
    "........................",
    "........................",
    "........................",
    "........................",
    "........................",
    "........................",
    "........................",
    "........................",
    "........................",
  ],
}

def png(pixels, w, h)
  raw = +""
  h.times do |y|
    raw << "\x00"
    w.times { |x| raw << pixels[y * w + x].pack("C4") }
  end
  chunk = lambda { |t, d| [d.bytesize].pack("N") + t + d + [Zlib.crc32(t + d)].pack("N") }
  "\x89PNG\r\n\x1a\n".b +
    chunk.call("IHDR", [w, h, 8, 6, 0, 0, 0].pack("NNC5")) +
    chunk.call("IDAT", Zlib::Deflate.deflate(raw)) + chunk.call("IEND", "")
end

if __FILE__ == $0
  out = ARGV[0] or abort "usage: ruby tools/make_daytime_sprites.rb <sprites/decor>"
  PHASES.each do |phase|
    rows = ART.fetch(phase)
    abort "#{phase}: #{rows.length} rows, expected #{FRAME}" unless rows.length == FRAME
    rows.each_with_index do |row, i|
      abort "#{phase} row #{i}: #{row.length} px, expected #{FRAME}" unless row.length == FRAME
    end
  end

  w = FRAME * PHASES.length
  pixels = []
  FRAME.times do |y|
    PHASES.each do |phase|
      FRAME.times do |x|
        color = PALETTE[ART[phase][y][x]]
        pixels << (color ? color + [255] : [0, 0, 0, 0])
      end
    end
  end
  File.binwrite(File.join(out, "daytime.png"), png(pixels, w, FRAME))
  puts "daytime.png  #{w}x#{FRAME}  (#{PHASES.length} frames: #{PHASES.join(', ')})"
end
