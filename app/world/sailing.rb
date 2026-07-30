# Taking the boat somewhere else. Reopens Game.
#
# The boat used to be furniture: a fixed point at world x 120 that you swam out
# from and swam back to. Everything good about the game happens away from it,
# and everything the game asks of you is measured from it — air, the suit, the
# swim home — so the reachable sea was whatever one bottle could get you to and
# back from. Being able to pick home up and put it down somewhere else is what
# turns that into a career with a direction.
#
# It is a boat, not a taxi. There is no pilot to ask and no menu of ports: you
# climb in, you steer it yourself, and you stop where you decide to stop. The
# things that make it a decision rather than a convenience are the three costs —
# a day gone, fuel burnt, and a chart that only lets you go one sector past
# water you have actually swum.
class Game
  BOAT_SPEED = 7          # px per tick under way: about three times a sprint, so
                          # crossing a sector is twenty seconds rather than four
                          # minutes, and still slow enough to watch the sea go by.
                          # Played and confirmed — leave it alone
  BOAT_FUEL = 8           # credits a sector, charged when you drop the anchor.
                          # Down from 25 and then from 12, both in play: against
                          # a first upgrade at 150, moving house is meant to be
                          # a decision, not something you cannot afford to get
                          # wrong
  BOAT_BLOCK_TICKS = 260  # how long he goes on saying he will not go further
  ANCHOR_CLEARANCE = 420  # px of sea room she needs before he will leave her.
                          # Wide enough that "not right up against it" is
                          # obvious by eye rather than a pixel you have to hunt
  WAKE_TICKS = 6          # how long after the last push she is still throwing water:
                          # a few ticks, so the spray dies the moment he eases off
                          # rather than trailing behind him like an exhaust
  BOAT_DRAUGHT = 30       # px of her below the waterline, hull and ladder
  WAKE_FOAM = [236, 244, 250]
  WAKE_SHADE = [186, 208, 224]

  # --- getting in and out -----------------------------------------------------

  # The same key that picks things up and talks to people: the do-the-thing-in-
  # front-of-you key. Nothing collectable ever floats at the boat and nobody
  # stands on it, so the three can never want it at once.
  def update_sailing
    return if game_paused?

    if state.aboard
      sail(-1) if will_left?
      sail(1) if will_right?
      anchor_boat if inputs.keyboard.key_down.e
    elsif inputs.keyboard.key_down.e && at_the_boat?
      board_boat
    end
  end

  def board_boat
    return unless at_the_boat?

    state.aboard = true
    # He was standing in the shallows a moment ago and clamp_depth is about to
    # stop running, so nothing else would ever clear this — and a diver the game
    # still thinks is ashore walks instead of swimming when he gets out again.
    state.on_land = false
    state.airborne = false
    # Where the voyage started, so dropping the anchor knows what it cost. Kept
    # rather than measured against the mooring: a crossing you make in two legs
    # over two days should cost what two crossings cost.
    state.boarded_x = boat_x
    ride_along
  end

  # Stopping. The fuel comes out of his pocket if he has actually gone
  # somewhere; if he climbed in, thought better of it and climbed out, nothing
  # happened at all.
  #
  # It used to end the day as well, on the reasoning that a crossing is a day's
  # work. In the hand that is simply an interruption — you move the boat two
  # sectors and the game takes the afternoon off — so the crossing costs fuel
  # and the time it actually takes to steer, and nothing else.
  def anchor_boat
    return unless state.aboard
    # Not on top of an island. She would be on the rocks by morning, and there
    # is nowhere to tie up — until there is somewhere to tie up, which is what
    # a harbour will be for.
    return refuse_anchorage unless anchorage?

    state.aboard = false
    sailed = (boat_x - state.boarded_x.to_i).abs
    return if sailed < SCREEN_WIDTH / 4

    state.credits = [state.credits - voyage_fee, 0].max
    # Dropping the anchor is the only moment the new mooring can reach the disk.
    # The book is written when what it holds changes — a species developed, a
    # name typed, a day ended — and a voyage is none of those. It used to end
    # the day, which saved it as a side effect; when the day cost went, the only
    # thing that ever wrote the mooring went with it, silently, and you came
    # back at the old berth.
    save_book
  end

  # Sea room. Measured off the rock actually stamped in the world rather than
  # off the island's own maths, the same way the people standing on it are: if
  # the two ever disagreed, the world is the one that is true.
  def anchorage?
    step = ANCHOR_CLEARANCE / 3
    (-3..3).none? do |i|
      crown = crown_at_world_x(boat_x + i * step)
      !crown.nil? && crown > WATERLINE_Y
    end
  end

  def refuse_anchorage
    state.blocked_at = Kernel.tick_count
    state.block_reason = :anchorage
  end

  # By the sector, rounded up: casting off at all costs a sector's worth, and
  # the second one starts costing the moment you leave the first.
  def voyage_fee
    sectors = ((boat_x - state.boarded_x.to_i).abs / SCREEN_WIDTH.to_f).round
    [sectors, 1].max * BOAT_FUEL
  end

  # --- under way --------------------------------------------------------------

  # One tick of steering. Takes the direction rather than reading the keys, so
  # the whole of it is testable without faking input — and so the touch controls
  # drive exactly the same code the keyboard does.
  def sail(direction)
    return unless state.aboard

    boat_was = boat_x

    wanted = boat_x + direction * BOAT_SPEED
    low, high = boat_limits
    if wanted < low || wanted > high
      state.boat_x = wanted.clamp(low, high)
      state.blocked_at = Kernel.tick_count
      state.block_reason = :range
    else
      state.boat_x = wanted
    end
    # Only when she has actually made ground: held against the limit she is
    # under power but going nowhere, and foam pouring off a boat that is not
    # moving is worse than no foam at all.
    if state.boat_x != boat_was
      state.wake_at = Kernel.tick_count
      state.wake_dir = direction
      state.boat_heading = direction
    end
    ride_along
  end

  # Which way she is pointing. Kept rather than read off the tiller, so a boat
  # left facing west is still facing west in the morning.
  def boat_heading
    state.boat_heading.to_i.zero? ? 1 : state.boat_heading.to_i
  end

  def boat_moving?
    state.aboard && !state.wake_at.nil? &&
      (Kernel.tick_count - state.wake_at) < WAKE_TICKS
  end

  # The wash at the waterline. Without it the boat changed position while the
  # sea stayed glass, which reads as a sprite being dragged rather than as a
  # boat going somewhere — the movement had no weight at all.
  #
  # Worked out from the tick and the boat's own position rather than simulated,
  # the way the beach ball is: nothing to keep in state, nothing to drift, and
  # it cannot be left running by a pause.
  def render_wake
    return unless boat_moving?
    return if submerged_visible?

    # Off her stern, which is wherever her motor is — and her motor is wherever
    # she is pointing. Foam boiling off the bow is a boat going backwards.
    astern = -boat_heading
    x = boat_x - state.camera_x
    y = WATERLINE_Y - state.camera_y
    half = BOAT_SPRITE[:w] * 4 / 2

    # A curl at the bow, where she is pushing the water aside ...
    outputs.sprites << { x: x - astern * (half - 6) - 5, y: y - 4, w: 12, h: 6,
                         r: WAKE_FOAM[0], g: WAKE_FOAM[1], b: WAKE_FOAM[2],
                         a: 210, path: :solid }
    # ... and a train of it astern, thinning and sinking as it falls behind.
    6.times do |i|
      drift = (Kernel.tick_count / 2 + i * 7) % 14
      w = 14 - i * 2
      outputs.sprites << { x: x + astern * (half + i * 18 + drift), y: y - 2 - i,
                           w: w, h: 3,
                           r: WAKE_SHADE[0], g: WAKE_SHADE[1], b: WAKE_SHADE[2],
                           a: 200 - i * 28, path: :solid }
    end
  end

  # He is *in* it: his position is the boat's, and he sits at the waterline
  # rather than being towed along underwater. Written every tick under way, so
  # nothing can drift the two apart.
  def ride_along
    state.diver_global_x = boat_x
    state.depth_y = WATERLINE_Y - SURFACE_FLOAT_DEPTH
    center_camera
  end

  # How far it may be taken, in world x. One sector past the chart each way
  # (Game#boat_range) — the east limit is the *far* edge of that sector, because
  # being allowed into a sector means being allowed across it.
  def boat_limits
    west, east = boat_range
    [west * SCREEN_WIDTH, (east + 1) * SCREEN_WIDTH - 1]
  end

  # Whether the island has her *completely*. Painting her behind the rock is
  # only half an answer on its own: it hides the part of her the rock covers,
  # and at the surface underwater rock is not drawn at all — the sea's own
  # occlusion — so everything of her below the waterline goes on showing, with
  # nothing there to hide it.
  #
  # So she is dropped outright, but only once every part of her is over land.
  # Hiding her as soon as any of her met rock took her off screen a boat's
  # length clear of the sand, which read as a sprite being switched off rather
  # than as a boat going behind something.
  def boat_behind_island?
    half = BOAT_SPRITE[:w] * 4 / 2
    [-half, -half / 2, 0, half / 2, half].all? do |dx|
      crown = crown_at_world_x(boat_x + dx)
      !crown.nil? && crown > WATERLINE_Y
    end
  end

  def boat_blocked?
    !state.blocked_at.nil? && (Kernel.tick_count - state.blocked_at) < BOAT_BLOCK_TICKS
  end

  # He says it, rather than a rule appearing on the screen. The boat has not
  # stopped because the game will not let it — it has stopped because the man
  # steering it will not take it into water he has never been down into, which
  # is the same rule told as a reason.
  # Why she has stopped, or why he will not leave her here. Both are his own
  # words rather than a rule on the screen: a boat that stops for a reason reads
  # as a man deciding, and one that stops at an invisible line reads as a bug.
  #
  # Both are shorter than they want to be. The running message boxes are one
  # fixed width, and the first draft of the range line ran 703 px into a 560 px
  # box — out through the side of its own panel, while every character count was
  # perfectly happy. Measured, not counted, and a test keeps them that way.
  def boat_block_line
    if state.block_reason == :anchorage
      "So dicht an der Insel ankere ich nicht."
    else
      "Hier stoppen wir — da muss ich erst auf Erkundungstour."
    end
  end
end
