# Generates the jellyfish sheets as PNGs with nothing but Ruby stdlib. Runs in
# MRI, not in DragonRuby: this is an authoring tool.
#
#   ruby tools/make_jelly_sprites.rb sprites/animals/jellies
#
# Like the whale and unlike the crustaceans, these are curves rather than drawn
# ASCII — a jellyfish is a bell and a set of trailing strands, and both are
# things a formula says better than a grid does.
#
# The one thing that makes them read as jellyfish rather than as mushrooms is
# that they are **see-through**: the bell is drawn at partial alpha, so the water
# and whatever is behind them shows through. That is why the palette carries an
# alpha channel per colour, which no other sprite tool here needs.
#
# The pulse is the animation and it is also the swimming: the bell squeezes
# narrow-and-tall, then relaxes wide-and-flat, and the strands lag behind it.
require "zlib"

FRAME_W = 24
FRAME_H = 30
FRAMES = 8

BELL_CY = 9.5    # centre of the bell
BELL_RX = 9.0    # ... and its resting half-width
BELL_RY = 7.0    # ... and half-height
PULSE = 0.22     # how far it squeezes, as a fraction
ARMS = 4         # thick oral arms under the bell
TENTACLES = 7    # and the fine stinging threads
CLEAR = [0, 0, 0, 0]

# A species is the same animal in another set of colours. Alpha is part of the
# colour here: how solid a jellyfish looks *is* what kind of jellyfish it is.
SPECIES = {
  # The moon jelly: almost colourless, four pale rings inside the bell.
  "mondqualle" => {
    bell: [206, 226, 240, 120], rim: [236, 246, 252, 190],
    organ: [176, 206, 232, 170], arm: [198, 220, 236, 150], thread: [206, 226, 240, 90],
  },
  # The fire jelly: warmer, denser, and it looks like it means it.
  "feuerqualle" => {
    bell: [236, 158, 130, 140], rim: [252, 208, 170, 210],
    organ: [222, 112, 92, 190], arm: [230, 140, 112, 170], thread: [236, 158, 130, 110],
  },
  # Deep water, lit from inside.
  "laternenqualle" => {
    bell: [150, 190, 236, 130], rim: [206, 238, 255, 220],
    organ: [122, 226, 214, 210], arm: [150, 200, 236, 160], thread: [160, 208, 240, 100],
  },
}

# The squeeze, as a factor on the bell's width. Wide and flat when relaxed,
# narrow and tall at the height of the contraction — the two are inverse, which
# is what makes it look like it is pushing water rather than merely resizing.
def pulse(frame)
  Math.sin(2 * Math::PI * frame / FRAMES)
end

def bell_radii(frame)
  p = pulse(frame)
  [BELL_RX * (1.0 - PULSE * p), BELL_RY * (1.0 + PULSE * p * 0.8)]
end

# The bell: the top half of an ellipse, with a margin that curls under. Only the
# top half — the underside of a jellyfish is where the arms come out, not skirt.
def bell_pixel(x, y, frame, colors)
  rx, ry = bell_radii(frame)
  cx = FRAME_W / 2.0 - 0.5
  dx = (x - cx) / rx
  dy = (y - BELL_CY) / ry
  d = Math.sqrt(dx * dx + dy * dy)
  return nil if d > 1.0
  return nil if y > BELL_CY + ry * 0.35 # the bell stops; arms take over

  return colors[:rim] if d > 0.78

  # Four gonad rings, the moon jelly's signature — set in from the rim and
  # arranged around the centre, so the bell reads as full of something.
  ring = Math.sqrt(((x - cx) / (rx * 0.52))**2 + ((y - BELL_CY + 0.5) / (ry * 0.52))**2)
  return colors[:organ] if ring > 0.62 && ring < 0.95 && (x - cx).abs > 1.2

  colors[:bell]
end

# The oral arms: short, thick, frilled, straight under the bell. They lag the
# pulse, so they gather as the bell squeezes and spread as it relaxes.
def arm_pixel(x, y, frame, colors)
  rx, = bell_radii(frame)
  cx = FRAME_W / 2.0 - 0.5
  top = BELL_CY + BELL_RY * 0.3
  return nil if y < top

  lag = pulse(frame - 1.5)
  ARMS.times do |i|
    spread = (i - (ARMS - 1) / 2.0) * (rx * 0.34) * (1.0 + 0.18 * lag)
    length = 7.0 + 2.0 * (1.0 - (i - (ARMS - 1) / 2.0).abs / 2.0)
    next if y > top + length

    sway = Math.sin((y - top) * 0.55 + lag * 1.4 + i) * 1.1
    return colors[:arm] if (x - (cx + spread + sway)).abs < 0.9
  end
  nil
end

# The stinging threads: long, fine, and they trail. Much longer than the animal
# is wide, which is the whole reason a field of them is something you steer
# around rather than through.
def thread_pixel(x, y, frame, colors)
  cx = FRAME_W / 2.0 - 0.5
  rx, = bell_radii(frame)
  top = BELL_CY + BELL_RY * 0.2
  return nil if y < top

  lag = pulse(frame - 2.5)
  TENTACLES.times do |i|
    anchor = cx + (i - (TENTACLES - 1) / 2.0) * (rx * 0.29)
    length = FRAME_H - top - (i.even? ? 1 : 4)
    next if y > top + length

    drift = (y - top) / length.to_f
    sway = Math.sin(drift * 3.1 + lag * 1.8 + i * 1.3) * (2.4 * drift)
    return colors[:thread] if (x - (anchor + sway)).abs < 0.55
  end
  nil
end

def frame_pixels(frame, colors)
  grid = Array.new(FRAME_H) { Array.new(FRAME_W, CLEAR) }
  FRAME_H.times do |y|
    FRAME_W.times do |x|
      grid[y][x] = bell_pixel(x, y, frame, colors) || arm_pixel(x, y, frame, colors) ||
                   thread_pixel(x, y, frame, colors) || CLEAR
    end
  end
  grid
end

def sheet_pixels(colors)
  frames = FRAMES.times.map { |f| frame_pixels(f, colors) }
  pixels = []
  FRAME_H.times do |y|
    FRAMES.times { |f| FRAME_W.times { |x| pixels << frames[f][y][x] } }
  end
  pixels
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

if __FILE__ == $0
  out = ARGV[0] or abort "usage: ruby tools/make_jelly_sprites.rb <sprites/animals/jellies>"
  require "fileutils"
  FileUtils.mkdir_p(out)
  SPECIES.each do |name, colors|
    File.binwrite(File.join(out, "#{name}.png"), png(sheet_pixels(colors), FRAME_W * FRAMES, FRAME_H))
    puts "#{name}.png  #{FRAME_W * FRAMES}x#{FRAME_H}  (#{FRAMES} x #{FRAME_W}x#{FRAME_H})"
  end
end
