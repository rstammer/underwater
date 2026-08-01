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
  "i" => [110, 166, 86],  # bush highlight. Was "h" — and "h" is taken further
                          # down by the boat's shaded hull, which silently gave
                          # every bush on every island a blue-grey top edge. The
                          # letters in here are one flat namespace; check before
                          # you claim one (a test does it now).
  "c" => [34, 74, 44],    # canopy shadow — the deepest green, for the underside
                          # of a crown and the gaps inside it
  "o" => [240, 210, 224], # blossom
  "U" => [206, 158, 182], # blossom, shaded
  "W" => [238, 240, 244], # gull, white
  "w" => [196, 202, 212], # gull, shaded
  "K" => [52, 58, 70],    # gull, wing tip
  "y" => [222, 196, 118], # dune grass, dry
  "Y" => [180, 200, 110], # dune grass, green
  "D" => [138, 116, 88],  # driftwood, lit
  "d" => [104, 84, 62],   # driftwood, shadow
  "R" => [186, 72, 54],   # crab shell
  "r" => [232, 120, 96],  # crab highlight
  "e" => [28, 26, 32],    # eye
  "P" => [120, 96, 70],   # flag pole
  "F" => [214, 74, 64],   # flag cloth
  "f" => [172, 52, 46],   # flag cloth, shaded
  "H" => [238, 240, 246], # boat hull, lit
  "h" => [176, 186, 198], # boat hull, shaded
  "S" => [52, 104, 164],  # boat stripe
  "N" => [246, 248, 250], # cabin
  "n" => [206, 214, 224], # cabin, shaded
  "V" => [126, 190, 218], # cabin window
  "v" => [78, 138, 170],  # window frame
  "O" => [186, 150, 102], # deck planks
  "M" => [72, 78, 90],    # outboard motor
  "m" => [46, 50, 60],    # motor, shaded
  "Q" => [222, 186, 72],  # the dive tanks on the foredeck ...
  "q" => [148, 118, 40],  # ... their shaded side and their valves
  "J" => [140, 98, 58],   # the cabin door ...
  "j" => [96, 64, 38],    # ... and its frame and shadowed edge. Not "E"/"e":
                          # "e" is already the crab's eye, and taking it would
                          # have quietly given every crab on every beach brown
                          # eyes instead of black ones
  "L" => [208, 214, 222], # ladder
  "A" => [92, 98, 110],   # antenna
  "Z" => [128, 134, 144], # boulder, lit
  "z" => [96, 102, 112],  # boulder, body
  "x" => [66, 70, 80],    # boulder, shadow
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
    "....iii.....",
    "..iiBBBii...",
    ".iBBBBBBBi..",
    "iBBBBBBBBBi.",
    "BBBBbBBBBBBB",
    "bBBBbbBBBBbb",
    ".bbb..bbbb..",
  ],
  # A boulder. The islands were all sand and greenery; a bit of loose rock on
  # the crown is what makes the greenery look like it grew somewhere.
  "rock" => [
    "....ZZZZZ.....",
    "..ZZZZZZZZZ...",
    ".ZZZZZZZzzzz..",
    ".ZZZZZzzzzzzz.",
    "ZZZZzzzzzzzzzz",
    "ZZzzzzzzzzzzzz",
    "zzzzzzzzzzzzzz",
    "zzzzzzzzzzzzzz",
    "xxzzzzzzzzzzxx",
    "..xxxxxxxxxx..",
  ],
  # A low fern: arching fronds off one base, no trunk — the thing that fills
  # the ground between the palms without pretending to be a small palm.
  "fern" => [
    "l...l....l...l",
    ".lg.lg..gl.gl.",
    "..lgglg.gllg..",
    "...gGgggGgg...",
    "....GGgGG.....",
    ".....GGG......",
    ".....GGG......",
    "......G.......",
    ".....bGb......",
  ],
  "grass" => [
    "..Y...Y.....",
    ".YY..YY..Y..",
    ".Yy..Yy.YY..",
    ".yy..yy.yy..",
    "yy...yy..yy.",
  ],
  "palm_small" => [
    "....gg..gg....",
    "..gllggllllg..",
    ".glGG.lTt.GGg.",
    "gGG...lTt..GGg",
    "......TTt.....",
    ".....TTt......",
    ".....TTt......",
    "....TTt.......",
    "....TTt.......",
    "...TTt........",
  ],
  "driftwood" => [
    "..dddddddddd..",
    ".dDDDDDDDDDDd.",
    "dDDdDDDDdDDDDd",
    ".dDDDDDDDDDDd.",
    "..dddddddddd..",
  ],
  "crab" => [
    "..R......R..",
    "...RRRRRR...",
    "..RreRRerR..",
    ".RRrrRRrrRR.",
    "..R.RRRR.R..",
    ".R..R..R..R.",
  ],
  "flag" => [
    ".....PFFFFF.",
    ".....PFFFf..",
    ".....PFff...",
    ".....Pf.....",
    ".....P......",
    ".....P......",
    ".....P......",
    ".....P......",
    ".....P......",
    "....PPP.....",
  ],
  # A small dive boat: cabin, an outboard bolted to the transom, and a ladder
  # over the side for climbing back aboard. The bottom rows sit below the
  # waterline, so the ladder reaches into the water.
  "boat" => [
    "..............A",
    "..............A",
    "..........nnnnnnnnnnnnnnnnnn",
    "..........nNNNNNNNNNNNNNNNNn",
    "..........nNjjjjNvvvvNvvvvvn..q..q",
    "..........nNjJJjNvVVvNvVVVVn..QQ.QQ",
    "..........nNjJJjNvvvvNvVVVVn..QQ.QQ.....H",
    "..........nNjJJjNNNNNNvvvvvn..QQ.QQ....HH",
    ".mmm......nNjJJjNNNNNNNNNNNn..qq.qq..HHHH",
    ".mMMmOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOHHHHHH",
    "..MMHHHHHHHHHHHHHLLLLHHHHHHHHHHHHHHHHHHHH",
    "..MMHSSSSSSSSSSSSLSSLSSSSSSSSSSSSSSSSSSHH",
    "..MMHHHHHHHHHHHHHLLLLHHHHHHHHHHHHHHHHHHH",
    "..mm.hhhhhhhhhhhhLhhLhhhhhhhhhhhhhhhhhh",
    "..mm..hhhhhhhhhhhLLLLhhhhhhhhhhhhhhhh",
    ".mmmm...hhhhhhhhhLhhLhhhhhhhhhhhhh",
    "...........hhhhhhLLLLhhhhhhhhhhhh",
    ".................L..L",
    ".................LLLL",
    "",
  ],
  "gull" => [
    "K..........K",
    ".Kw......wK.",
    "..WWw..wWW..",
    "....WWWW....",
  ],

  # --- what is left aboard the wreck ----------------------------------------
  #
  # A ship on the bottom is not a shape, it is a place somebody lived and
  # worked. These are the things that say so — and every one of them is drawn to
  # be read at a glance from its silhouette, because at this scale that is all
  # there is.

  # A barrel on its side, hoops and all. The hoops are the whole tell: without
  # them it is a log.
  "barrel" => [
    ".dddddddd.",
    "dDDwDDwDDd",
    "DDDwDDwDDD",
    "DDDwDDwDDD",
    "dDDwDDwDDd",
    ".dddddddd.",
  ],

  # The ship's wheel, still on its post at the stern. Spokes sticking out past
  # the rim are what make a circle a wheel.
  "wheel" => [
    "...D.D.D...",
    "..DDDDDDD..",
    ".DD..D..DD.",
    "DD...D...DD",
    "D..D.D.D..D",
    "DDDDDdDDDDD",
    "D..D.D.D..D",
    "DD...D...DD",
    ".DD..D..DD.",
    "..DDDDDDD..",
    "...D.D.D...",
    ".....d.....",
    ".....d.....",
    "....ddd....",
  ],

  # An anchor, fouled in the mud beside the bow. Read from the ring at the top,
  # the crossbar under it and the two flukes at the bottom.
  "anchor" => [
    "...ZZZ...",
    "..Z...Z..",
    "...ZZZ...",
    "....Z....",
    ".ZZZZZZZ.",
    "....Z....",
    "....Z....",
    "Z...Z...Z",
    "Zz..Z..zZ",
    ".ZzzZzzZ.",
    "..ZZZZZ..",
  ],

  # A chest, lid shut, bands across it. The one thing down here that suggests
  # somebody might still want what is in it.
  "chest" => [
    "..CCCCCCCC..",
    ".CCQCCCCQCC.",
    "CCCQCCCCQCCC",
    "cccQccccQccc",
    "cQQQQccQQQQc",
    "ccQccccccQcc",
    "cccccccccccc",
    ".dddddddddd.",
  ],

  # An old ship's gun, lying on the wreck's deck where it fell off its carriage.
  # Read at a glance from the silhouette alone: a heavy tube that is thicker at
  # the breech than at the muzzle, with the trunnion stub under it and the
  # cascabel knob at the back. Pointing left, the way the bow does.
  "cannon" => [
    "....MMMMMMMMMMMMMM..",
    "..MMmmmmmmmmmmmmMMm.",
    ".MmmmmmmmmmmmmmmmMMM",
    ".MmmmmmmmmmmmmmmmmMM",
    "..MMmmmmmmmmmmmmMMm.",
    "....MM..MMMM..MMMM..",
    "........MMMM........",
    ".......dDDDDd.......",
    "......dDDDDDDd......",
  ],

  # --- the wood -------------------------------------------------------------
  # Palms say atoll. These say the island carries a wood, which is what the
  # tunnels inside it always implied and the surface never showed. All of them
  # are lit from the upper left, like the palm: light side "l", body "g", far
  # side "G", and "c" where a crown closes over itself.

  # The ordinary tree of the place: one round crown, wider than it is tall, on a
  # short trunk. It is the only plant here bigger than a palm, so a stand of them
  # is what makes a skyline read as forest rather than as beach.
  "broadleaf" => [
    ".......gggggg.......",
    ".....gllllllllg.....",
    "...gglllllllllggg...",
    "..gllllllllllllcGg..",
    ".gllllllllllllggcGg.",
    ".glllllllllggGGGcGg.",
    "..gggllllggGGGGcGg..",
    "...gggggggGGGGcgg...",
    ".....ggcccccccg.....",
    "........TTt.........",
    "........TTt.........",
    "........TTt.........",
    ".......TTTt.........",
    ".......TTTt.........",
    "......TTTTtt........",
  ],

  # A tree fern: a slender scaly trunk with a single ring of fronds off the top.
  # The one plant that is unmistakably rain forest rather than woodland, and the
  # tall counterpart to the low fern already growing between the palms.
  "tree_fern" => [
    "l..l...l...l..l",
    ".ll.ll.l.ll.ll.",
    "..lgglglglggl..",
    "...ggGgGgGgg...",
    "....GGgcgGG....",
    "......TTt......",
    "......TtT......",
    "......TTt......",
    "......TtT......",
    "......TTt......",
    ".....bTTtb.....",
  ],

  # A banana plant: no trunk to speak of, just a stem and four big paddle leaves
  # arching off it. Broad flat leaves are the shape nothing else here has.
  "banana" => [
    "ll.........ll..",
    "lll.......lll..",
    "gll..lll..llg..",
    ".gll.lll.llg...",
    "..gl.ggg.lg....",
    "...g.ggg.g.....",
    "....cgTgc......",
    "......Tt.......",
    "......Tt.......",
    ".....bTtb......",
  ],

  # A dead trunk with the stubs of two branches. Nothing grows for ever, and a
  # wood with no dead wood in it is a park — this is the plant that says the
  # rest of them are alive.
  "snag" => [
    "...Dd...",
    "...Dd...",
    "D..Dd...",
    ".DdDd.dD",
    "..dDddD.",
    "...Dd...",
    "...Dd...",
    "...Dd...",
    "...Dd...",
    "..dDdd..",
  ],

  # A flowering shrub — the bush with blossom on it. The islands are green on
  # green on green; this is the one plant carrying a colour that is not.
  "flower_bush" => [
    "..o..o...o..",
    ".oiioUiioU..",
    "oiBBBBBBBio.",
    "iBBBBBBBBBBi",
    "BBBBbBBBBBBB",
    "bBBbbBBBBbbb",
    "..bb..bbb...",
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

# Her with the ladder hauled in: the same drawing with every ladder pixel given
# back to the hull. Derived rather than drawn a second time, because two copies
# of a boat drift apart the first time one of them is edited — and the colour
# under the ladder is not one colour, it is topsides, stripe or shaded bottom
# depending on the row, so each pixel takes whatever its left-hand neighbour is.
SPRITES["boat_underway"] = SPRITES["boat"].map do |row|
  cells = row.chars
  cells.each_index { |i| cells[i] = i.zero? ? "." : cells[i - 1] if cells[i] == "L" }
  cells.join
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
