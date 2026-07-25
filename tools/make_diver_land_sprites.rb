# Generates the diver's on-land sheet: sprites/diver_land.png.
#
#   ruby tools/make_diver_land_sprites.rb sprites
#
# Derived from the swimming diver rather than drawn fresh, so it is the same
# person on both sides of the waterline. The palette below is *sampled from
# sprites/diver_v2.png*, and the head, tank and torso are traced from its first
# upright frame; only the limbs are re-authored. In the water that frame holds
# its arms straight out and its legs hang with the flippers pointing down, which
# reads as treading water and reads as a starfish the moment he stands on sand.
#
# So on land: arms down at his sides, and the flippers folded flat and forward,
# which is what a diver in flippers actually looks like — he waddles, and that is
# the joke the sprite is allowed to tell.
#
# Layout matches sprites/diver_v2.png so Diver#to_h can swap sheets and nothing
# else: FRAMES frames per row, row 0 the walk cycle (used while he is moving),
# row 1 standing still.
require "zlib"

FRAME_W = 32
FRAME_H = 32
FRAMES = 12 # Diver::SPRITES_PER_ROW
# The art below is authored with the figure high in the frame, the way the
# swimming sheet has it; on land his feet have to sit on the very bottom row or
# he stands on a cushion of air. Everything is dropped by this before it is
# written out.
GROUND_DROP = 4

# Sampled from sprites/diver_v2.png — same suit, same tank, same flippers.
PALETTE = {
  "A" => [49, 65, 149],    # suit, lit
  "F" => [39, 49, 103],    # suit, shadow (the far side of him)
  "B" => [255, 195, 159],  # skin
  "C" => [222, 170, 139],  # skin, shaded
  "D" => [184, 184, 184],  # tank, lit
  "E" => [146, 146, 146],  # tank, shadow
  "G" => [255, 191, 0],    # flipper
  "H" => [214, 161, 0],    # flipper, shadow
}

# Head, tank and torso, traced from frame 0 of the swimming sheet — with the
# outstretched arms brought down along his body.
UPPER = [
  "................................",
  "................................",
  "................................",
  "................................",
  "................................",
  "................................",
  "...............AAA..............",
  "...............ABB..............",
  "...............AAC..............",
  ".............DEAF...............",
  ".............DAAAFF.............",
  ".............AAAAFF.............",
  "............ADEAAFF.............",
  "............ADEAAFF.............",
  "............A.EGGHF.............",
  "............B..AAFB.............",
]

# Standing: legs together under him, flippers flat on the ground and pointing
# the way he faces. Short ones — a flipper is longer than a foot, not twice the
# width of the man.
STAND_LOWER = [
  "...............AAF..............",
  "...............AAF..............",
  "...............A.F..............",
  "...............A.F..............",
  "...............A.F..............",
  "..............A..F..............",
  "..............A..F..............",
  "..............A..F..............",
  "..............A..F..............",
  "..............A..F..............",
  "..............GGGGG.............",
  "..............HHHHH.............",
  "................................",
  "................................",
  "................................",
  "................................",
]

# Mid-stride. What reads as walking at this size is a flipper *lifted off the
# ground* while the other stays planted — legs splayed from the hip in a wide V
# just read as the splits. So the two stride poses differ in which flipper is up,
# and the legs barely move. The near leg keeps its colour in both: swapping which
# leg was lit made the pair flicker rather than walk.
STRIDE_NEAR_UP = [
  "...............AAF..............",
  "...............AAF..............",
  "..............A..F..............",
  "..............A..F..............",
  ".............A...F..............",
  ".............A...F..............",
  "............A....F..............",
  "............A.....F.............",
  "............A.....F.............",
  "...........GGGGG..F.............",
  "...........HHHHH..GGGGG.........",
  "..................HHHHH.........",
  "................................",
  "................................",
  "................................",
  "................................",
]

STRIDE_FAR_UP = [
  "...............AAF..............",
  "...............AAF..............",
  "..............A..F..............",
  "..............A..F..............",
  "..............A...F.............",
  ".............A....F.............",
  ".............A.....F............",
  ".............A.....F............",
  ".............A.....F............",
  ".............A....GGGGG.........",
  "...........GGGGG..HHHHH.........",
  "...........HHHHH................",
  "................................",
  "................................",
  "................................",
  "................................",
]

# Composed, then dropped so his flippers rest on the bottom row of the frame —
# the sprite is drawn centred on his world position, so any empty rows under him
# are a gap of daylight between flipper and sand.
def pose(lower)
  (Array.new(GROUND_DROP) { "." * FRAME_W } + UPPER + lower).first(FRAME_H)
end

def stand_pose
  pose(STAND_LOWER)
end

# The walk: near flipper up, both down, far flipper up, both down. Each pose held
# for two frames, because the engine runs this sheet at eight frames to a cycle.
def walk_frames
  [pose(STRIDE_NEAR_UP), pose(STRIDE_NEAR_UP),
   pose(STAND_LOWER), pose(STAND_LOWER),
   pose(STRIDE_FAR_UP), pose(STRIDE_FAR_UP),
   pose(STAND_LOWER), pose(STAND_LOWER)]
end

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

def check!(rows, name)
  abort "#{name}: #{rows.length} rows, expected #{FRAME_H}" unless rows.length == FRAME_H
  rows.each_with_index do |row, i|
    abort "#{name} row #{i}: #{row.length} px, expected #{FRAME_W}" unless row.length == FRAME_W
  end
end

if __FILE__ == $0
  out = ARGV[0] or abort "usage: ruby tools/make_diver_land_sprites.rb <sprites>"

  walk = walk_frames
  stand = stand_pose
  check!(stand, "stand")
  walk.each_with_index { |f, i| check!(f, "walk #{i}") }

  # Row 0 is the walk (Diver#to_h reads it while he is moving), row 1 standing.
  rows_of_frames = [
    FRAMES.times.map { |i| walk[i % walk.length] },
    FRAMES.times.map { stand },
  ]

  w = FRAME_W * FRAMES
  h = FRAME_H * rows_of_frames.length
  pixels = []
  rows_of_frames.each do |frames|
    FRAME_H.times do |y|
      frames.each do |frame|
        FRAME_W.times do |x|
          color = PALETTE[frame[y][x]]
          pixels << (color ? color + [255] : [0, 0, 0, 0])
        end
      end
    end
  end

  File.binwrite(File.join(out, "diver_land.png"), png(pixels, w, h))
  puts "diver_land.png  #{w}x#{h}  (#{FRAMES} frames x #{rows_of_frames.length} rows of #{FRAME_W}x#{FRAME_H})"
end
