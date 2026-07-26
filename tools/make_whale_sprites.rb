# Generates the whale sheet as a PNG with nothing but Ruby stdlib. Runs in MRI,
# not in DragonRuby: this is an authoring tool.
#
#   ruby tools/make_whale_sprites.rb sprites/animals/whales
#
# Unlike the crustaceans, this one is not hand-drawn ASCII. At 112x38 a drawn
# grid would be four thousand characters to keep aligned by eye, and a whale is
# a *smooth* animal — its shape wants to be a curve, not a spelling.
#
# So the body is a profile function: a thickness that swells a third of the way
# back and tapers to the peduncle, a belly fuller than the back, flukes that
# flare at the very end. The animation is a travelling wave down that same
# centre line — the head barely moves, the tail sweeps — which is what makes it
# read as one long animal rather than a picture being wobbled.
require "zlib"

FRAME_W = 112
FRAME_H = 38
FRAMES = 8

CY = 18.0        # the centre line the body is hung from
MAX_HALF = 12.5  # half the thickest part of it
BODY_LEN = 88    # nose to peduncle; the rest is tail
BACK = 0.76      # how much of the thickness goes above the centre line ...
BELLY = 1.18     # ... and below it. A whale's belly is the fuller half.
WAVE_AMP = 3.6   # how far the tail sweeps
WAVE_LAG = 1.15  # how far the wave lags down the body — this is what makes it flow

BACK_INK    = [38, 54, 78, 255]
MID_INK     = [58, 80, 110, 255]
BELLY_INK   = [146, 166, 186, 255]
PLEAT_INK   = [120, 140, 162, 255]
EYE_INK     = [14, 16, 22, 255]
MOUTH_INK   = [28, 38, 56, 255]
CLEAR       = [0, 0, 0, 0]

NOSE_X = FRAME_W - 4 # a little air in front of the snout, the way the tail has some
TAIL_X = NOSE_X - BODY_LEN # where the flukes take over

# How far along the whole animal a column is, 0 at the nose and 1 at the fluke
# tips. The wave is written against this, so it runs the full length.
def along(x)
  (NOSE_X - x) / (FRAME_W - 1).to_f
end

# The travelling wave. Squared, so the head is almost still and the tail does
# the work; lagged, so the crest moves *down* the body instead of the whole
# animal bobbing as one piece.
def wave_dy(x, phase)
  s = along(x)
  WAVE_AMP * s * s * Math.sin(phase - s * WAVE_LAG)
end

# Half the body's thickness at this column. Peaks about a third back and tapers
# both ways; the exponent on t is what puts the shoulders forward of the middle
# and leaves the head blunt rather than pointed.
def half_thickness(x)
  return nil if x < TAIL_X || x > NOSE_X

  t = (NOSE_X - x) / BODY_LEN.to_f
  h = MAX_HALF * (Math.sin(Math::PI * (t**0.55))**0.85)
  h < 1.1 ? 1.1 : h
end

# The flukes: a wedge that stays slim at the stock and flares at the very end,
# with the median notch every whale tail has cut back into it.
#
# They stop short of the frame's edge. Run to x = 0 and the widest part of the
# tail *is* the edge, so the sheet reads as a whale someone has cropped — and
# the notch, which is the one detail that says "fluke" rather than "fin", gets
# cut off with it.
FLUKE_MARGIN = 5

def fluke_span(x)
  return nil if x >= TAIL_X || x < FLUKE_MARGIN

  u = (TAIL_X - x) / (TAIL_X - FLUKE_MARGIN).to_f # 0 at the stock, 1 at the tips
  spread = 1.4 + 12.0 * (u**1.5)
  notch = u > 0.68 ? (u - 0.68) / 0.32 * 6.5 : 0.0
  [spread, notch]
end

# A pectoral fin, swept back and down off the shoulder — the one thing that
# tells an eye "this is a whale" rather than "this is a very large fish".
FIN_FROM = 0.26
FIN_TO = 0.46

# A blade, not a lump: it leaves the shoulder and slants down and *back*,
# tapering to a point. Hung straight down off the belly it read as a growth.
def fin_pixel(x, y, cy)
  t = (NOSE_X - x) / BODY_LEN.to_f
  return nil if t < FIN_FROM || t > FIN_TO

  half = half_thickness(x)
  return nil unless half

  u = (t - FIN_FROM) / (FIN_TO - FIN_FROM) # 0 at the shoulder, 1 at the tip
  lead = cy + half * BELLY - 1.0 + 9.5 * u
  width = 5.5 * (1.0 - u) + 0.7
  return nil if y < lead || y > lead + width

  MID_INK
end

def body_pixel(x, y, cy)
  half = half_thickness(x)
  return nil unless half

  top = cy - half * BACK
  bottom = cy + half * BELLY
  return nil unless y >= top && y <= bottom

  # Shaded in three bands down the animal rather than per pixel: pixel art wants
  # areas, not a gradient.
  depth = (y - top) / (bottom - top)
  return BACK_INK if depth < 0.42
  return MID_INK if depth < 0.62

  # Ventral pleats: the grooves along the throat, as every third column. They
  # stop where the belly stops being a throat.
  t = (NOSE_X - x) / BODY_LEN.to_f
  return PLEAT_INK if t > 0.06 && t < 0.42 && (x % 3).zero?

  BELLY_INK
end

def tail_pixel(x, y, cy)
  spread, notch = fluke_span(x)
  return nil unless spread
  return nil if (y - cy).abs > spread
  return nil if notch > 0 && (y - cy).abs < notch

  (y - cy).abs > spread - 1.6 ? MID_INK : BACK_INK
end

# The eye, set back from the snout and just above the mouth line, and the line
# of the mouth itself. Both are two pixels of the whole animal and both are why
# it reads as an animal at all.
def face_pixel(x, y, cy)
  t = (NOSE_X - x) / BODY_LEN.to_f
  half = half_thickness(x)
  return nil unless half

  bottom = cy + half * BELLY
  return MOUTH_INK if t < 0.20 && (y - (bottom - half * 0.34)).abs < 0.6
  return EYE_INK if t > 0.11 && t < 0.145 && (y - (cy - half * 0.18)).abs < 1.1

  nil
end

def frame_pixels(frame)
  phase = 2 * Math::PI * frame / FRAMES
  grid = Array.new(FRAME_H) { Array.new(FRAME_W, CLEAR) }
  FRAME_W.times do |x|
    cy = CY + wave_dy(x, phase)
    FRAME_H.times do |y|
      grid[y][x] = tail_pixel(x, y, cy) || face_pixel(x, y, cy) ||
                   body_pixel(x, y, cy) || fin_pixel(x, y, cy) || CLEAR
    end
  end
  grid
end

def sheet_pixels
  frames = FRAMES.times.map { |f| frame_pixels(f) }
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
  out = ARGV[0] or abort "usage: ruby tools/make_whale_sprites.rb <sprites/animals/whales>"
  require "fileutils"
  FileUtils.mkdir_p(out)
  File.binwrite(File.join(out, "blauwal.png"), png(sheet_pixels, FRAME_W * FRAMES, FRAME_H))
  puts "blauwal.png  #{FRAME_W * FRAMES}x#{FRAME_H}  (#{FRAMES} x #{FRAME_W}x#{FRAME_H})"
end
