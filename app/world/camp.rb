# The campsite on the beach island. Reopens Game.
#
# The island used to be a beach with people standing on it. It is a campsite
# now, which is what turns a row of strangers into a place: they are here for
# the same reason, and the tents say so without anybody having to.
#
# Everything stands at a fixed fraction along the dry island (Game#beach_band),
# laid out the way you walk it: the water and the children first, then the
# bathers, then reception at the gate with Mike in it, the tents behind that,
# and the fire pit at the far end where the evening happens. The people are
# spaced into the same run (app/world/islander.rb), so the two lists are read
# together — a tent must not land on Tall Pete.
#
# Reception carries the campsite's sign, and the sign says CAMPING / REZEPTION
# in letters you can actually read (tools/make_camp_sprites.rb). That is the
# reason it is the widest thing here: a board with nine three-pixel letters on
# it is 144 px across on screen, wider than the hut under it, so it is carried
# over the top on posts the way a gate sign is. It used to be five blocks of
# colour standing in for writing — which reads as a sign from a screen away and
# as nothing at all from where you stand, at the one building on this island
# that exists to be walked up to and read.
class Game
  # Somebody named this place after the thing nobody here has seen. That is the
  # joke and it is also the point: the campers repeat a rumour, and the rumour
  # is painted on the sign at the gate. Spanish because whoever built it was
  # from somewhere else, which is how holiday places tend to get their names.
  CAMP_NAME = "Campamento del Kraken Profundo"
  CAMP_SCALE = 3
  # Kept in step with what tools/make_camp_sprites.rb prints. A stale w or h
  # here draws the sprite squashed without failing anywhere, so a test holds the
  # table against the pictures themselves.
  CAMP_SPRITES = {
    "tent_green" => { path: "sprites/decor/camp/tent_green.png", w: 25, h: 14 },
    "tent_blue"  => { path: "sprites/decor/camp/tent_blue.png",  w: 25, h: 14 },
    "tent_sand"  => { path: "sprites/decor/camp/tent_sand.png",  w: 25, h: 14 },
    "reception"  => { path: "sprites/decor/camp/reception.png",  w: 48, h: 30 },
    "fire"       => { path: "sprites/decor/camp/fire.png",       w: 18, h: 15 },
    "ball"       => { path: "sprites/decor/camp/ball.png",       w: 7,  h: 7 },
  }

  # Where each one stands. Chosen against the people's spots rather than spread
  # evenly: reception sits just past Mike because he works there, and the fire
  # sits between the two musicians because that is what they are sitting round.
  CAMP_PIECES = [
    { key: "reception",  spot: 0.90 },
    { key: "tent_green", spot: 0.60 },
    { key: "tent_blue",  spot: 0.68 },
    { key: "tent_sand",  spot: 0.76 },
    { key: "fire",       spot: 0.44 },
  ]

  def camp_pieces
    return [] unless beach_island_in_view?

    CAMP_PIECES.map { |piece| place_camp_piece(piece) }.compact
  end

  def camp_piece_x(piece)
    band = beach_band
    return nil unless band

    band[:first] + ((band[:last] - band[:first]) * piece[:spot]).to_i
  end

  # How far a building may slide to find ground it can stand on, and in what
  # order it tries: its own spot first, then alternating outward.
  #
  # It needs this because the dry band is *not* dry all the way through — it is
  # only the first and last dry samples, and some islands dip under the water in
  # between. Reception is the widest thing on the island and landed in one of
  # those dips on about one round in twenty: no ground, so it was not built, so
  # the campsite had no reception and Mike stood at nothing.
  #
  # It carries the sign now and is wider again for it — 144 px on screen against
  # 84 — so it asks for more flat ground than anything else here. Measured over
  # 120 rounds after the widening: built in all of them.
  CAMP_SHIFTS = [0, 32, -32, 64, -64, 96, -96, 128, -128, 160, -160]

  CAMP_ELBOW = 130 # px a tent keeps from anybody standing about

  def place_camp_piece(piece)
    origin = camp_piece_x(piece)
    return nil unless origin

    sprite = CAMP_SPRITES[piece[:key]]
    # Reception and the fire are meant to be stood at, so they may share their
    # ground; a tent nudged along must not come down on somebody's head.
    keep_clear = !["reception", "fire"].include?(piece[:key])

    CAMP_SHIFTS.each do |shift|
      x = origin + shift
      next if keep_clear && standing_spots.any? { |spot| (x - spot).abs < CAMP_ELBOW }

      ground = camp_ground_at(x, sprite[:w] * CAMP_SCALE / 2)
      return { key: piece[:key], x: x, y: ground, sprite: sprite } if ground
    end
    nil
  end

  # Where the people who stand at a fixed fraction will end up. Deliberately not
  # asking Game#islanders: the warden's position is read off reception, so that
  # would be this method asking for the answer it is being used to work out.
  def standing_spots
    band = beach_band
    return [] unless band

    width = band[:last] - band[:first]
    Islander::ALL.reject { |person| person.kind == :warden || person.kind == :keeper }
                 .map { |person| band[:first] + (width * person.spot).to_i }
  end

  # The *lowest* rock under the whole width of it, not the height at its middle
  # — the same rule the shop's hut needed. The island is terraced, so anything
  # centred on a step had its far end hanging in the air over the drop. Sitting
  # it on the lowest ground buries a pixel or two of the near end instead, which
  # reads as a tent pitched on a slope rather than one floating off a ledge.
  # Nil if any of it would be standing in the sea.
  def camp_ground_at(x, half)
    grounds = [x - half, x, x + half].map { |at| crown_at_world_x(at) }
    return nil if grounds.any?(&:nil?)

    ground = grounds.min
    ground > WATERLINE_Y ? ground : nil
  end

  # Drawn before the people, so somebody standing at reception stands in front
  # of it rather than behind the counter.
  def render_camp
    return if submerged_visible?

    camp_pieces.each do |piece|
      sprite = piece[:sprite]
      h = sprite[:h] * CAMP_SCALE
      h += fire_flicker if piece[:key] == "fire"

      outputs.sprites << { x: piece[:x] - state.camera_x - sprite[:w] * CAMP_SCALE / 2,
                           y: piece[:y] - state.camera_y,
                           w: sprite[:w] * CAMP_SCALE, h: h,
                           path: sprite[:path] }
    end
  end

  # --- the ball ---------------------------------------------------------------

  BALL_FLIGHT = 96     # ticks for one throw, there or back
  BALL_ARC = 90        # how high it goes at the top of its arc
  BALL_HEIGHT = 30     # how far above their feet it leaves a hand
  # The islanders' scale, deliberately: drawn at anything else its pixels are a
  # different size from the pixels of the two boys throwing it, and a ball with
  # a finer grain than the children reads as belonging to another picture.
  BALL_SCALE = 2

  # Flori and Falko are throwing a ball to each other. It is worked out from the
  # tick count rather than simulated: there is no physics here to get right, and
  # a ball that is a function of the clock cannot drift, cannot be left behind by
  # a paused game, and needs nothing kept in state.
  # The tick is a parameter with a default rather than read straight off the
  # clock, so a test can ask where the ball is at any moment without having to
  # move the world's clock underneath everything else.
  def ball_between(tick = Kernel.tick_count)
    players = islanders.select { |person| person.kind == :boy }.sort_by(&:x)
    return nil unless players.length == 2

    from, to = players
    phase = (tick % (BALL_FLIGHT * 2)) / BALL_FLIGHT.to_f
    # Second half of the cycle is the throw back, so t runs 0..1 both ways and
    # the two of them are never both holding it.
    going = phase < 1
    t = going ? phase : phase - 1
    left, right = going ? [from, to] : [to, from]

    { x: left.x + (right.x - left.x) * t,
      y: [left.y, right.y].max + BALL_HEIGHT + Math.sin(t * Math::PI) * BALL_ARC }
  end

  # A drawn disc rather than two solids stacked (tools/make_camp_sprites.rb). It
  # was a filled rectangle with a pale stripe laid across it, on the theory that
  # a seam would say "ball" — but at that size the corners are most of what you
  # see, and a stripe does not make a square round. The picture also gets it a
  # lit side, which a solid cannot have at all.
  def render_ball
    return if submerged_visible?

    ball = ball_between
    return unless ball

    sprite = CAMP_SPRITES["ball"]
    w = sprite[:w] * BALL_SCALE
    h = sprite[:h] * BALL_SCALE
    outputs.sprites << { x: ball[:x] - state.camera_x - w / 2,
                         y: ball[:y] - state.camera_y - h / 2,
                         w: w, h: h, path: sprite[:path] }
  end

  # The flame breathes rather than sits there. Stretching the whole sprite a few
  # pixels is enough at this size and costs nothing — a second animated sprite
  # for six pixels of fire would be six pixels of fire and a lot of machinery.
  # Two waves out of step, so it never settles into a pulse you can count.
  def fire_flicker
    (Math.sin(Kernel.tick_count / 9.0) * 3 + Math.sin(Kernel.tick_count / 5.0) * 2).round
  end
end
