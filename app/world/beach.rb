# The beach island and the seven people on it. Reopens Game.
#
# It is the counterpart to the shop: a fixed island (IslandWorld::BEACH_SECTOR)
# you can walk up, out to the left rather than the right, so the two places
# worth finding are not both in the same direction.
#
# Who is there and what they say lives in app/world/islander.rb. This is only
# the where and the how: each of them stands at a fixed fraction along the
# island, their feet on whatever rock is actually stamped there, and standing
# beside one lets you talk to them.
#
# Talking is a speech bubble, not a screen. The shop takes the whole display
# because it has a shelf to lay out; a sentence does not, and stopping the world
# for one line would make every one of them feel like a transaction. So the game
# keeps running, the line hangs over their head, and it fades on its own.
class Game
  ISLANDER_REACH = 110  # px: how close counts as standing beside somebody. Well
                        # under the shop's, because that is a row of stalls and
                        # this is one person you have walked up to
  ISLANDER_SAY_TICKS = 420 # how long a line stays up — read twice over, slowly
  ISLANDER_SCALE = 2
  # One drawing per person, not per kind (tools/make_islander_sprites.rb): the
  # four shapes are shared, but Flori and Falko stand within a stride of each
  # other, and two boys in the same trunks read as one boy drawn twice.
  ISLANDER_SPRITES = {
    "flori"     => { path: "sprites/decor/islanders/flori.png",     w: 11, h: 16 },
    "falko"     => { path: "sprites/decor/islanders/falko.png",     w: 11, h: 16 },
    "hendrik"   => { path: "sprites/decor/islanders/hendrik.png",   w: 13, h: 20 },
    "tall_pete" => { path: "sprites/decor/islanders/tall_pete.png", w: 13, h: 20 },
    "sebastian" => { path: "sprites/decor/islanders/sebastian.png", w: 23, h: 18 },
    "george"    => { path: "sprites/decor/islanders/george.png",    w: 23, h: 18 },
    "mike"      => { path: "sprites/decor/islanders/mike.png",      w: 13, h: 20 },
  }

  # --- where they stand ------------------------------------------------------

  # Nobody at all unless you are actually at the island: the roster is a roster,
  # not a crowd that follows you out to sea.
  #
  # Measured against the diver rather than against what the camera can see. The
  # two amount to the same thing in play — the camera is centred on him — but the
  # diver is the thing that is true whether or not anything has been drawn yet,
  # and "who is here" should not be a question about the viewport. A screen of
  # slack each way covers the drawing, since nothing further out than that can
  # be on screen.
  def beach_island_in_view?
    first = IslandWorld.first_x_for(IslandWorld::BEACH_SECTOR) - SCREEN_WIDTH
    last = first + IslandWorld.shape_for(IslandWorld::BEACH_SECTOR)[:span] + SCREEN_WIDTH * 2

    state.diver_global_x.between?(first, last)
  end

  # How far somebody shuffles along to find ground, and in what order they try:
  # their own spot first, then alternating outward. Exactly the trick the camp's
  # buildings needed (Game::CAMP_SHIFTS), for exactly the same reason — the dry
  # band is only its first and last dry sample, and the middle of it is not
  # reliably dry. A tent that landed in a dip was simply not built; a person who
  # landed in one was simply not there, which is worse, because a tent nobody
  # pitched looks like an empty beach and a missing musician looks like a bug.
  ISLANDER_SHIFTS = [0, 48, -48, 96, -96, 144, -144, 192, -192, 240, -240]

  # Placed one after another rather than all at once, so somebody shuffling
  # along cannot shuffle into somebody who is already standing there. Two people
  # inside one ISLANDER_REACH means the further of them can never be spoken to —
  # you always get the nearer — so this is a rule with teeth, not tidiness.
  def islanders
    standing = []
    Islander::ALL.each do |person|
      here = place_islander(person, standing)
      standing << here if here
    end
    standing
  end

  # Their ground is read off the world that is really stamped there, the way the
  # shop's hut is, rather than off the island's own maths. If the two ever
  # disagreed somebody would be standing in the air, and the world is the one
  # that is true. No rock under them at all (an odd island shape, a spot that
  # fell past the shore) simply means that person is not there today.
  #
  # The keeper is the exception in both halves: he is on the *other* island, and
  # his ground is the shop's, because he stands behind the shop's counter.
  def place_islander(person, standing = [])
    if person.kind == :keeper
      return nil unless at_the_shop_island?

      ground = shop_ground_y
      return nil if ground.nil?

      return Beachgoer.new(islander: person, x: shop_x, y: ground)
    end

    return nil unless beach_island_in_view?

    origin = islander_x(person)
    ISLANDER_SHIFTS.each do |shift|
      x = origin + shift
      next if standing.any? { |other| (other.x - x).abs <= ISLANDER_REACH }

      ground = crown_at_world_x(x)
      next if ground.nil? || ground <= WATERLINE_Y

      return Beachgoer.new(islander: person, x: x, y: ground)
    end
    nil
  end

  # Near enough to the shop island for its keeper to be a person you could speak
  # to. The same slack as the campsite's, and for the same reason: it answers
  # "is he here" off the diver rather than off the viewport.
  def at_the_shop_island?
    span = IslandWorld.shape_for(IslandWorld::SHOP_SECTOR)[:span]
    first = IslandWorld.first_x_for(IslandWorld::SHOP_SECTOR) - SCREEN_WIDTH

    state.diver_global_x.between?(first, first + span + SCREEN_WIDTH * 2)
  end

  # Where he stands relative to the reception door, in the order he tries. To
  # the left of it by preference, but the ground beside a building is not always
  # dry on the side you wanted — and standing on the other side of his own desk
  # beats not being on the island at all, which is what happened when this was a
  # single offset.
  WARDEN_OFFSETS = [-80, 80, -120, 120, 0]

  # Their spot is a fraction of the *dry* island, not of its span. An island
  # runs out under the water at both ends — the first fifth of this one is sea —
  # so spacing people along the span put the boy who plays at the water's edge
  # into the water, where place_islander then dropped him and he was simply not
  # there. Measured off the stamped world, so it stays right if the island's
  # shape ever changes.
  #
  # The warden is the exception: he is placed off the *building*, not off a
  # number, because the building moves. Reception slides along the island when
  # its own spot lands in a dip (Game::CAMP_SHIFTS), and Mike standing at the
  # fraction where it used to be is Mike standing in the sand next to nothing.
  def islander_x(person)
    if person.kind == :warden
      desk = camp_pieces.find { |piece| piece[:key] == "reception" }
      if desk
        standing = WARDEN_OFFSETS.map { |offset| desk[:x] + offset }
                                 .find { |at| (crown_at_world_x(at) || 0) > WATERLINE_Y }
        return standing || desk[:x]
      end
    end

    band = beach_band
    return 0 unless band

    band[:first] + ((band[:last] - band[:first]) * person.spot).to_i
  end

  BEACH_STEP = 32 # px between samples when working out where the island is dry
  # Cleared with the world cache at the start of a round (Game#reset_game): it is
  # measured off stamped segments, so it must not outlive the ones it read.

  # Where the island is out of the water. Worked out once per round and kept: it
  # is a walk along the whole island, and seven people plus five buildings
  # asking it separately every frame is the same walk twelve times.
  #
  # It used to also work out the highest clear point, for Mike, who sat up
  # there. He runs the campsite now and stands at reception like everybody else
  # stands somewhere, so that whole search — and the clearance rule that kept it
  # off George's toes — went with it.
  def beach_band
    return state.beach_band if state.beach_band

    first = IslandWorld.first_x_for(IslandWorld::BEACH_SECTOR)
    span = IslandWorld.shape_for(IslandWorld::BEACH_SECTOR)[:span]
    dry = (0..(span / BEACH_STEP)).map { |i| first + i * BEACH_STEP }
                                  .map { |x| [x, crown_at_world_x(x)] }
                                  .select { |(_, crown)| crown && crown > WATERLINE_Y }
    return nil if dry.empty?

    state.beach_band = { first: dry.first[0], last: dry.last[0] }
  end

  # The crown of whatever is stamped at a world x, across segment borders — the
  # island is wider than a segment, so half of it lives in the next one along.
  def crown_at_world_x(x)
    index = x.idiv(SCREEN_WIDTH)
    world_at(index).crown_y_at(x - index * SCREEN_WIDTH)
  end

  # --- talking to them -------------------------------------------------------

  # On foot, and beside them. On foot matters for the same reason it does at the
  # shop: you cannot hold a conversation while treading water below somebody.
  # The nearest one, because two of them stand close enough together that which
  # one you are actually next to is a real question.
  def islander_in_reach
    return nil unless on_land?

    islanders.select { |person| (state.diver_global_x - person.x).abs <= ISLANDER_REACH }
             .min_by { |person| (state.diver_global_x - person.x).abs }
  end

  def talk_key?
    inputs.keyboard.key_down.e
  end

  # E is the same key that picks things up, and that is the point: it is the
  # "do the thing in front of you" key. Nothing collectable is ever lying on a
  # beach — the treasures are on the sea floor — so the two can never both want
  # it at once.
  def update_talking
    return if game_paused?
    return unless talk_key? && islander_in_reach

    talk_to_islander
  end

  def talk_to_islander
    person = islander_in_reach
    return unless person

    state.islander_said = { name: person.name, text: islander_line(person.islander),
                            at: Kernel.tick_count }
    advance_islander(person.islander)
  end

  # Which of their lines comes next. Kept apart from talk_to_islander so that
  # reading what somebody would say never changes what they say.
  #
  # The stage is the diver's, not theirs: hearsay while he has never been down,
  # warier once he has been past what a suit is rated for, and something shared
  # once he has met the thing himself. A stage nobody wrote a line for falls back
  # to the one before, so a person with one thing to say still answers at every
  # stage rather than going silent at the interesting moment.
  def islander_line(person)
    pool = islander_pool(person)
    pool[islander_turn(person) % pool.length]
  end

  # Everything they have unlocked, newest first — *added* to what they always
  # had, not swapped for it.
  #
  # It used to replace: past the suit's rating you got the deep-water line and
  # only that, so a diver who had been down once never heard the hearsay again.
  # That threw away the best of what these people say — the boy who has decided
  # it has arms, the bather who has it third-hand — for anybody actually playing
  # the game rather than starting it. Now the stages accumulate: the newest
  # thing they have to say comes first, and talking on rotates through the rest.
  def islander_pool(person)
    pool = []
    pool += person.met unless state.kraken_met.to_i.zero?
    person.documented.each do |key, lines|
      pool += lines if (state.album || {}).key?(key)
    end
    pool += person.deeper if state.log_best.to_i >= SUIT_DEPTH_LIMIT
    pool += person.lines
    # Questions are the one thing that does *not* accumulate: they are asked
    # until they are answered and then they are done with.
    person.asks.each do |key, line|
      pool << line unless (state.album || {}).key?(key)
    end
    pool
  end

  def islander_turn(person)
    state.islander_turns ||= {}
    state.islander_turns[person.key].to_i
  end

  # Round the pool rather than off the end of it: somebody you keep talking to
  # starts again rather than repeating their last line for ever.
  def advance_islander(person)
    state.islander_turns ||= {}
    state.islander_turns[person.key] = islander_turn(person) + 1
  end

  def islander_speaking?
    said = state.islander_said
    !said.nil? && (Kernel.tick_count - said[:at]) < ISLANDER_SAY_TICKS
  end

  # --- drawing them ----------------------------------------------------------

  # Drawn standing on the rock: y is the ground, and a sprite's y is its bottom
  # edge. Only above water — under it the surface occludes the island anyway,
  # and a bather seen from below would be a person standing on the ceiling.
  def render_islanders
    return if submerged_visible?

    islanders.each do |person|
      sprite = ISLANDER_SPRITES[person.key]
      next unless sprite

      outputs.sprites << { x: person.x - state.camera_x - sprite[:w] * ISLANDER_SCALE / 2,
                           y: person.y - state.camera_y,
                           w: sprite[:w] * ISLANDER_SCALE, h: sprite[:h] * ISLANDER_SCALE,
                           path: sprite[:path] }
    end
  end

  ISLANDER_HINT_W = 300

  # A prompt over whoever you are standing next to, so "you can talk to this
  # one" is answered by the world rather than by a rule you have to remember.
  # Not while they are already talking — the bubble is over the same head.
  def render_islander_hint
    return if submerged_visible? || islander_speaking?

    person = islander_in_reach
    return unless person
    # The keeper's prompt lives on the stall's own card (shop_action_lines),
    # which is already up whenever you are close enough to talk to him.
    return if person.kind == :keeper

    lines = [{ text: person.name, size: 2, color: [232, 244, 252] },
             { text: "[ E ]  ansprechen", size: 0, color: [232, 226, 150] }]
    # The card hangs *down* from the y it is given, so its own height has to be
    # added on or it comes down over the head of the person it is pointing at —
    # which is exactly what it did. Measured the way render_boat_card measures
    # it rather than guessed at, so a third line can never bury somebody again.
    height = 28 + lines.sum { |line| boat_line_height(line) }

    render_boat_card(lines, ISLANDER_HINT_W, person.x - state.camera_x,
                     person.y + islander_head_room(person) + 16 + height - state.camera_y)
  end

  SPEECH_W = 620
  SPEECH_PAD = 14
  SPEECH_LINE_H = 22
  SPEECH_INK = [24, 40, 54]
  SPEECH_PAPER = [236, 244, 250]

  # What they just said, over their head, in a pale box — the one thing on the
  # island that is not the game's own dark panel. A rumour is somebody talking,
  # not a readout.
  def render_islander_speech
    return unless islander_speaking?

    said = state.islander_said
    person = islanders.find { |islander| islander.name == said[:name] }
    return unless person

    lines = wrap_speech(said[:text])
    x = person.x - state.camera_x
    bottom = person.y + islander_head_room(person) + 20 - state.camera_y
    height = SPEECH_PAD * 2 + SPEECH_LINE_H * lines.length + 18

    outputs.sprites << { x: x - SPEECH_W / 2, y: bottom, w: SPEECH_W, h: height,
                         r: SPEECH_PAPER[0], g: SPEECH_PAPER[1], b: SPEECH_PAPER[2],
                         a: 236, path: :solid }
    outputs.labels << { x: x - SPEECH_W / 2 + SPEECH_PAD, y: bottom + height - SPEECH_PAD,
                        text: said[:name], size_enum: 0, vertical_alignment_enum: 2,
                        r: 96, g: 132, b: 156 }
    lines.each_with_index do |line, i|
      outputs.labels << { x: x - SPEECH_W / 2 + SPEECH_PAD,
                          y: bottom + height - SPEECH_PAD - 20 - i * SPEECH_LINE_H,
                          text: line, size_enum: 1, vertical_alignment_enum: 2,
                          r: SPEECH_INK[0], g: SPEECH_INK[1], b: SPEECH_INK[2] }
    end
  end

  # How far over their feet their head is, so a bubble clears it. The keeper has
  # no sprite of his own — he is painted into the stall — so his headroom is the
  # stall's, or the bubble would sit inside the awning he is standing under.
  def islander_head_room(person)
    return DECOR_SPRITES["shop"][:h] * SHOP_SCALE if person.kind == :keeper

    sprite = ISLANDER_SPRITES[person.key]
    sprite ? sprite[:h] * ISLANDER_SCALE : 0
  end

  # Broken on words against the measured width of the box, rather than at a
  # character count: the lines are prose and prose has no column.
  SPEECH_CHARS = 44

  # Built by rebinding rather than by mutating a buffer: mruby has no unary plus
  # on a string literal, and `line = +""` is an error in the engine that only
  # shows the first time somebody actually says something — which is not a place
  # to find out.
  def wrap_speech(text)
    lines = []
    line = ""
    text.split(" ").each do |word|
      if line.empty?
        line = word
      elsif line.length + 1 + word.length <= SPEECH_CHARS
        line = "#{line} #{word}"
      else
        lines << line
        line = word
      end
    end
    lines << line unless line.empty?
    lines
  end
end
