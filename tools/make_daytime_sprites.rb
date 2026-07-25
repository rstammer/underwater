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

# Drawn to read at 24 px on a HUD, which is smaller than it sounds: the first
# pass scattered single-pixel rays around each sun and at that size they were
# not rays, they were dirt. The disc fills most of the frame now and anything
# else is a connected stroke.
ART = {
  # Low sun just up, sitting on the horizon.
  "morgen" => [
    "........................",
    "........................",
    "........................",
    "........................",
    "........................",
    ".........rrrrrr.........",
    ".......rrrssssrrr.......",
    "......rrssssssssrr......",
    ".....rrssssssssssrr.....",
    ".....rsssssssssssss.....",
    "....rrssssssssssssrr....",
    "....rrssssssssssssrr....",
    "....rrssssssssssssrr....",
    ".....rsssssssssssss.....",
    ".....rrssssssssssrr.....",
    "..HHHHrrssssssssrrHHHH..",
    "..HHHHHrrrssssrrrHHHHH..",
    "..HHHHHHHrrrrrrHHHHHHH..",
    "........................",
    "........................",
    "........................",
    "........................",
    "........................",
    "........................",
  ],
  # Well clear of the horizon.
  "vormittag" => [
    "........................",
    "........................",
    "........................",
    ".........ssssss.........",
    ".......ssssssssss.......",
    "......ssssSSSSssss......",
    ".....sssSSSSSSSSsss.....",
    ".....ssSSSSSSSSSSss.....",
    "....ssSSSSSSSSSSSSss....",
    "....sSSSSSSSSSSSSSSs....",
    "....sSSSSSSSSSSSSSSs....",
    "....sSSSSSSSSSSSSSSs....",
    "....ssSSSSSSSSSSSSss....",
    ".....ssSSSSSSSSSSss.....",
    ".....sssSSSSSSSSsss.....",
    "......ssssSSSSssss......",
    ".......ssssssssss.......",
    ".........ssssss.........",
    "........................",
    "........................",
    "........................",
    "........................",
    "........................",
    "........................",
  ],
  # Overhead and glaring: four solid rays, not a sprinkle of pixels.
  "mittag" => [
    "..........yy............",
    "..........yy............",
    "..........yy............",
    ".........SSSSSS.........",
    ".......SSSSSSSSSS.......",
    "......SSSSSSSSSSSS......",
    ".....SSSSSSSSSSSSSS.....",
    ".....SSSSSSSSSSSSSS.....",
    "yy..SSSSSSSSSSSSSSSS..yy",
    "yy..SSSSSSSSSSSSSSSS..yy",
    "yy..SSSSSSSSSSSSSSSS..yy",
    "....SSSSSSSSSSSSSSSS....",
    ".....SSSSSSSSSSSSSS.....",
    ".....SSSSSSSSSSSSSS.....",
    "......SSSSSSSSSSSS......",
    ".......SSSSSSSSSS.......",
    ".........SSSSSS.........",
    "..........yy............",
    "..........yy............",
    "..........yy............",
    "........................",
    "........................",
    "........................",
    "........................",
  ],
  # On the way down, warmer than the morning.
  "nachmittag" => [
    "........................",
    "........................",
    "........................",
    ".........ssssss.........",
    ".......ssssssssss.......",
    "......sssssSSSssss......",
    ".....ssssSSSSSSssss.....",
    ".....sssSSSSSSSSsss.....",
    "....sssSSSSSSSSSSsss....",
    "....ssSSSSSSSSSSSSss....",
    "....ssSSSSSSSSSSSSss....",
    "....ssSSSSSSSSSSSSss....",
    "....sssSSSSSSSSSSsss....",
    ".....sssSSSSSSSSsss.....",
    ".....ssssSSSSSSssss.....",
    "......sssssSSSssss......",
    ".......sssssssssss......",
    ".........ssssss.........",
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
    ".........RRRRRR.........",
    ".......RRRRRRRRRR.......",
    "......RRRRrrrrRRRR......",
    ".....RRRrrrssrrrRRR.....",
    ".....RRrrrssssrrrRR.....",
    "....RRrrrssssssrrrRR....",
    "....RRrrrssssssrrrRR....",
    "..HHHHRrrrssssrrrRHHHH..",
    "..HHHHHRRrrrrrrRRHHHHH..",
    "..HHHHHHRRRRRRRRHHHHHH..",
    "..HHHHHHHHRRRRHHHHHHHH..",
    "..HHHHHHHHHHHHHHHHHHHH..",
    "........................",
    "........................",
    "........................",
    "........................",
    "........................",
    "........................",
    "........................",
    "........................",
  ],
  # A fat crescent and three stars, no confetti.
  "nacht" => [
    "........................",
    "........................",
    "..........MMMMM.........",
    ".......MMMMMMMMMm.......",
    "......MMMMMmmmmmmm......",
    ".....MMMMmm......mm.....",
    "....MMMMm...........t...",
    "....MMMm................",
    "....MMMm................",
    "....MMMm................",
    "....MMMMm...............",
    ".....MMMMmm......mm.....",
    "......MMMMMmmmmmmm......",
    ".......MMMMMMMMMm.......",
    "..........MMMMM.........",
    "........................",
    "..t.....................",
    "........................",
    "....................t...",
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
