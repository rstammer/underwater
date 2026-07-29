# Generates the campsite on the beach island as PNGs with nothing but Ruby
# stdlib — ASCII art plus a palette, '.' is transparent. Runs in MRI, not in
# DragonRuby: an authoring tool, the same as the other make_*_sprites.rb here.
#
#   ruby tools/make_camp_sprites.rb sprites/decor/camp
#
# Three buildings, a fire and the boys' ball. They have to read from a screen
# away at the scale the island's other decoration is drawn at, so each one is
# mostly silhouette with one loud detail: the tent is a triangle with a dark
# doorway, reception is the only thing with a straight roofline and a sign, and
# the fire is the only orange on the island.
#
# Rows are padded out to the width of the shape rather than counted by hand, and
# a row wider than the shape is an error — the same rule as the islanders.
require "zlib"

# A five-pixel-tall alphabet, only the letters the sign needs. It exists because
# the sign used to be blocks of colour standing in for writing, which reads as a
# sign from a distance and as nothing at all up close — and the reception of a
# campsite is precisely the thing you walk up to in order to read it.
#
# Glyphs carry their own width rather than sharing one: M needs five columns and
# an M squeezed into three is a smear, while everything else is comfortable in
# three. They are joined by a single blank column.
FONT_H = 5
FONT = {
  "A" => ["###", "#.#", "###", "#.#", "#.#"],
  "C" => ["###", "#..", "#..", "#..", "###"],
  "E" => ["###", "#..", "###", "#..", "###"],
  "G" => ["###", "#..", "#.#", "#.#", "###"],
  "I" => ["###", ".#.", ".#.", ".#.", "###"],
  "M" => ["#...#", "##.##", "#.#.#", "#...#", "#...#"],
  "N" => ["#..#", "##.#", "#.##", "#..#", "#..#"],
  "O" => ["###", "#.#", "#.#", "#.#", "###"],
  "P" => ["###", "#.#", "###", "#..", "#.."],
  "R" => ["###", "#.#", "###", "##.", "#.#"],
  "T" => ["###", ".#.", ".#.", ".#.", ".#."],
  "Z" => ["###", "..#", ".#.", "#..", "###"],
}

def glyphs(text)
  text.chars.map { |char| FONT[char] || abort("no glyph for #{char.inspect}") }
end

def text_width(text)
  letters = glyphs(text)
  letters.sum { |glyph| glyph[0].length } + letters.length - 1
end

def text_row(text, row)
  glyphs(text).map { |glyph| glyph[row] }.join(".")
end

# The board at the top of reception, as ASCII rows: a dark frame round pale
# boarding with the lines of type centred on it, one under the other.
#
# Two lines rather than one. "CAMPING - REZEPTION" on a single line is 73 px of
# glyph, which at the scale the camp is drawn at would make the sign a quarter
# of the screen wide and reception a building you cannot see past. Stacked, the
# longest line is REZEPTION at 36 px and the whole thing stays a sign.
def sign_board(lines, width)
  inner = width - 2
  rows = ["d" * width, "d#{"s" * inner}d"]
  lines.each do |line|
    pad = (inner - text_width(line)) / 2
    FONT_H.times do |row|
      type = ("." * pad + text_row(line, row)).ljust(inner, ".")
      rows << "d#{type.tr("#", "S").tr(".", "s")}d"
    end
    rows << "d#{"s" * inner}d"
  end
  rows << "d" * width
end

# The hut itself, and the posts that carry the board out past both of its sides
# — the sign is wider than the building it belongs to, the way a campsite gate
# is, and a board overhanging thin air would be a board overhanging thin air.
def on_posts(rows, width, posts)
  left = (width - rows.map(&:length).max) / 2
  rows.map do |row|
    line = "." * width
    line[left, row.length] = row
    posts.each { |col| 2.times { |i| line[col + i] = "d" if line[col + i] == "." } }
    line
  end
end

RECEPTION_W = 48
RECEPTION_POSTS = [2, RECEPTION_W - 4]

SHAPES = {
  # A ridge tent: a plain triangle, which is the one shape nothing else on the
  # island has. The doorway is what stops it reading as a rock — a dark slot
  # under the ridge, with the flaps folded back beside it.
  tent: [
    "............t............",
    "...........ttt...........",
    "..........ttttt..........",
    ".........ttttttt.........",
    "........ttttttttt........",
    ".......ttttttttttt.......",
    "......ttttttttttttt......",
    ".....tttttdddddttttt.....",
    "....ttttdddddddddtttt....",
    "...tttttddddddddduttt....",
    "..tttttuddddddddduttttt..",
    ".ttttttudddddddddutttttt.",
    "tttttttuddddddddduttttttt",
    "ppppppppppppppppppppppppp",
  ],
  # Reception, built like the Späti's stall rather than like a hut: a roof on
  # two posts, an open counter under it and a key board on the back wall. As a
  # closed cabin with lit windows it read as somebody's holiday home — you
  # cannot tell a building is a *desk* unless you can see the desk. The open
  # front is the whole point, so the counter gets the middle of the picture and
  # the back wall stays dark behind it.
  #
  # The sign that used to sit on its roof is gone from here: it is built by
  # sign_board now and carried above the whole thing on posts.
  reception_hut: [
    "rrrrrrrrrrrrrrrrrrrrrrrrrrrr",
    "RRRRRRRRRRRRRRRRRRRRRRRRRRRR",
    "d..........................d",
    "d..NNNNNNNNNNNNNNNNNNNNNN..d",
    "d..NkkNkkNkkNNNNNNNNNNNNN..d",
    "d..NNNNNNNNNNNNNNNNNNNNNN..d",
    "d..NkkNkkNkkNNNNNNNNNNNNN..d",
    "d..NNNNNNNNNNNNNNNNNNNNNN..d",
    "d..NNNNNNNNNNNNNNNNNNNNNN..d",
    "dppppppppppppppppppppppppppd",
    "dPPPPPPPPPPPPPPPPPPPPPPPPPPd",
    "dnnnnnnnnnnnnnnnnnnnnnnnnnnd",
    "dnnnn...nnnn...nnnn...nnnnnd",
    "dnnnnnnnnnnnnnnnnnnnnnnnnnnd",
    "dd........................dd",
  ],
  # The fire pit. A ring of stones with the logs crossed over it and a flame
  # that is the only orange thing on the island — which is the whole job, since
  # this is where the evening happens and where two people sit and play.
  fire: [
    "........ff........",
    ".......ffff.......",
    "......ffFFff......",
    ".....ffFFFFff.....",
    ".....fFFyyFFf.....",
    "....ffFyyyyFff....",
    "....fFFyyyyFFf....",
    ".....fFFyyFFf.....",
    "......ffFFff......",
    ".......ffff.......",
    "..LLLLLLLLLLLLLL..",
    "...LLLLLLLLLLLL...",
    ".ooLLLLLLLLLLLLoo.",
    "oOoooooooooooooOo.",
    ".oOooooooooooOo...",
  ],
  # The boys' ball. A disc, because it was a filled rectangle with a pale stripe
  # laid across it, and a stripe does not make a square round — at fourteen
  # pixels on screen the corners are most of what you see. Seven across is the
  # smallest circle that still reads as one, with the light on the top left and
  # the shade opposite, so it has a side facing the sun.
  ball: [
    "..bbb..",
    ".bhbbB.",
    "bhbbbBB",
    "mmmmmmm",
    "bbbbBBB",
    ".bbBBB.",
    "..bBB..",
  ],
}

# Reception is the sign and the hut together: the board on top, the hut beneath
# it, and the two posts down either side holding the overhang up.
SHAPES[:reception] =
  sign_board(["CAMPING", "REZEPTION"], RECEPTION_W) +
  on_posts(SHAPES[:reception_hut], RECEPTION_W, RECEPTION_POSTS)
SHAPES.delete(:reception_hut)

PALETTE = {
  "d" => [58, 42, 30],     # dark timber, and the tent's doorway
  "u" => [188, 170, 148],  # the tent's folded-back flap
  "p" => [150, 128, 100],  # ground line under a building, and the counter top
  "P" => [112, 92, 70],    # ... its shaded front edge
  "r" => [176, 82, 66],    # reception roof
  "R" => [136, 60, 48],    # ... its shadow side
  "w" => [96, 70, 46],     # planked wall
  "W" => [132, 100, 68],   # ... its lit side
  "l" => [255, 232, 168],  # lamplight through the windows
  "n" => [104, 78, 52],    # the counter front
  "s" => [238, 232, 214],  # the sign board ...
  "S" => [72, 108, 132],   # ... and the lettering on it
  "N" => [46, 38, 32],     # the shaded inside of the stall, behind the counter
  "k" => [212, 196, 150],  # key fobs on the board back there
  "L" => [104, 76, 48],    # logs
  "o" => [148, 146, 140],  # fire-ring stones ...
  "O" => [110, 108, 104],  # ... their shaded side
  "f" => [232, 128, 48],   # flame, outer ...
  "F" => [246, 176, 64],   # ... middle ...
  "y" => [255, 236, 150],  # ... and its hot centre
  "b" => [232, 96, 72],    # the boys' ball ...
  "B" => [176, 58, 46],    # ... its shaded side ...
  "h" => [255, 176, 156],  # ... the light on top ...
  "m" => [246, 236, 220],  # ... and the seam across it
}

# One drawing, several colours — the same trick the islanders use. Two tents in
# the same green read as one tent drawn twice.
PIECES = {
  "tent_green" => { shape: :tent, t: [92, 132, 88] },
  "tent_blue"  => { shape: :tent, t: [78, 112, 152] },
  # Not sand-coloured, which is what it was: pitched on sand it went invisible
  # from a screen away. A tent has to be a colour the island is not.
  "tent_sand"  => { shape: :tent, t: [204, 108, 72] },
  "reception"  => { shape: :reception },
  "fire"       => { shape: :fire },
  "ball"       => { shape: :ball },
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
  out = ARGV[0] or abort "usage: ruby tools/make_camp_sprites.rb <sprites/decor/camp>"

  SHAPES.each do |kind, rows|
    width = rows.map(&:length).max
    rows.each_with_index do |row, i|
      abort "#{kind} row #{i} is #{row.length} px, wider than #{width}" if row.length > width
    end
  end

  require "fileutils"
  FileUtils.mkdir_p(out)

  sizes = []
  PIECES.each do |key, piece|
    shape = SHAPES[piece[:shape]]
    w = shape.map(&:length).max
    h = shape.length
    rows = shape.map { |row| row.ljust(w, ".") }
    palette = PALETTE.dup
    palette["t"] = piece[:t] if piece[:t]

    pixels = []
    h.times do |y|
      w.times do |x|
        color = palette[rows[y][x]]
        pixels << (color ? color + [255] : [0, 0, 0, 0])
      end
    end
    File.binwrite(File.join(out, "#{key}.png"), png(pixels, w, h))
    puts "#{key}.png  #{w}x#{h}  (#{piece[:shape]})"
    sizes << format("    %-14s => { path: \"sprites/decor/camp/%s.png\", w: %d, h: %d },",
                    "\"#{key}\"", key, w, h)
  end

  # Printed so the table in app/world/camp.rb can be pasted rather than kept in
  # step by hand: a stale w/h there draws the sprite squashed without failing.
  puts
  puts "  CAMP_SPRITES for app/world/camp.rb:"
  puts sizes
end
