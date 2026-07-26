# Taking the picture, as an act rather than a query. Reopens Game.
#
# It used to be one keypress: F asked the sea for the nearest creature in front
# of you and graded the answer by how far away it was. Two things were wrong
# with that. It was not a skill — you swam up and pressed. And a photo was *one
# animal*, so "two fish in one frame" or "a yellow fish" were not hard to ask
# for, they were impossible: there was no picture to ask about, only a subject.
#
# So a photo is a **crop** now. Hold the shutter and a frame opens wide and
# closes steadily for as long as you hold it; let go and whatever is inside it
# is the photograph. The skill is composition — get the animal large, whole and
# centred, and (for a species shot) alone.
#
# The zoom runs one way on purpose. An oscillating frame would be a quick-time
# event — "release on the green" — and the sea already has a skill worth having
# in the shy fish, where the animal behaves and you respond. Closing steadily
# means the only question is *when it fits*, which is a thing about the picture
# rather than about your reflexes. Overshoot and you clip the animal, which is a
# real photographic mistake and reads as one.
#
# You can swim while framing: waiting still for a shy fish and composing the
# shot are then one continuous act instead of two modes. And letting go of the
# frame without shooting costs nothing — film is spent by the shutter, so
# practising is free.
class Game
  FRAME_WIDE = 620       # px across at its widest, the moment you press
  FRAME_TIGHT = 70       # ... and the tightest it will close to
  FRAME_CLOSE = 4.2      # px per tick it closes. About two seconds end to end
  FRAME_ASPECT = 0.68    # a picture, not a square
  FRAME_AHEAD = 90       # px in front of him the frame sits — he shoots forwards

  def framing?
    !!state.framing
  end

  def reset_framing
    state.framing = false
    state.frame_w = FRAME_WIDE
  end

  # Held, not tapped: the whole mechanic is the difference between the two.
  def shutter_held?
    inputs.keyboard.key_held.f || (state.touch_pressed || []).include?(:photo)
  end

  def update_framing
    if shutter_held?
      open_frame unless framing?
      close_frame
    elsif framing?
      release_shutter
    end
  end

  def open_frame
    state.framing = true
    state.frame_w = FRAME_WIDE
  end

  def close_frame
    state.frame_w -= FRAME_CLOSE
    state.frame_w = FRAME_TIGHT if state.frame_w < FRAME_TIGHT
  end

  # Let go without shooting. Costs nothing — film is spent by the shutter.
  def cancel_framing
    reset_framing
  end

  # The shot first, *then* the viewfinder shuts. The other way round reset the
  # frame to its widest before take_photo ever looked at it, so every photograph
  # came out as the wide-open shot however carefully it had been composed — and
  # the composition worked perfectly right up to the moment it was used.
  def release_shutter
    take_photo
    reset_framing
  end

  # Where the camera is pointed, in world coordinates. Ahead of him rather than
  # on him: you photograph what you are facing, and a frame centred on the diver
  # would put him in his own pictures.
  def frame_rect
    w = state.frame_w || FRAME_WIDE
    h = w * FRAME_ASPECT
    ahead = state.direction == :left ? -FRAME_AHEAD : FRAME_AHEAD
    { x: state.diver_global_x + ahead - w / 2, y: state.depth_y - h / 2, w: w, h: h }
  end

  # Everything that could be *in* a picture, as bodies rather than points. Read
  # off each animal's own to_h, because that is where it is actually drawn — a
  # rect worked out separately would drift from the sprite the moment either
  # changed.
  def framed_bodies
    offset = world_index * SCREEN_WIDTH
    list = creatures_in_view.map do |creature|
      sprite = creature.to_h
      { species: creature.species,
        rect: { x: offset + sprite[:x], y: sprite[:y], w: sprite[:w], h: sprite[:h] } }
    end
    if shark_present?
      list << { species: Species["schattenhai"],
                rect: state.shark.hitbox(offset + state.dark_shark.x, state.dark_shark.y) }
    end
    list << { species: whale_species, rect: whale_rect } if whale_present? && whale_species
    list
  end

  # What the picture came out as. A plain report rather than a grade, so the
  # grading can change — and so a later assignment ("two fish", "something over
  # a metre") can ask its own questions of the same numbers instead of needing
  # its own machinery.
  def frame_report(rect = frame_rect)
    inside = framed_bodies.select { |body| body[:rect].intersect_rect?(rect) }
    return nil if inside.empty?

    # The biggest thing in the picture is what the picture is of.
    subject = inside.max_by { |body| body[:rect][:w] * body[:rect][:h] }
    { species: subject[:species],
      fill: frame_fill(subject[:rect], rect),
      whole: whole_in?(subject[:rect], rect),
      centred: frame_centring(subject[:rect], rect),
      company: inside.length - 1 }
  end

  def frame_fill(body, rect)
    (body[:w] * body[:h]) / (rect[:w] * rect[:h]).to_f
  end

  # Nothing hanging out of the edge. This is the thing the old distance rule
  # could not say at all: it held that nearer is always better, which is how a
  # thirty-metre whale broke it.
  def whole_in?(body, rect)
    body[:x] >= rect[:x] && body[:y] >= rect[:y] &&
      body[:x] + body[:w] <= rect[:x] + rect[:w] &&
      body[:y] + body[:h] <= rect[:y] + rect[:h]
  end

  # 0 dead centre, 1 at the corner.
  def frame_centring(body, rect)
    dx = (body[:x] + body[:w] / 2) - (rect[:x] + rect[:w] / 2)
    dy = (body[:y] + body[:h] / 2) - (rect[:y] + rect[:h] / 2)
    Math.sqrt(dx * dx + dy * dy) / Math.sqrt((rect[:w] / 2)**2 + (rect[:h] / 2)**2)
  end

  # --- what it is worth --------------------------------------------------------

  # Measured rather than guessed. A 32x16 fish fills 0.154 of a frame closed to
  # 70 px and a 64x32 one fills the same at 140 — so one threshold covers both
  # sizes, and the difference between them is simply how far you have to close.
  #
  # The centring numbers from the same measurement are the interesting part: as
  # the frame closes it shrinks around its *own* middle, so an animal that is a
  # little off-centre drifts to the edge (0.05 at 620 px, 0.85 at 70). Composing
  # a tight shot therefore means putting yourself where the frame will end up —
  # which is the skill, and nobody had to design it.
  FILL_PERFECT = 0.14
  FILL_GOOD = 0.03
  CENTRED_ENOUGH = 0.45

  # For a species shot: large, whole, centred and alone. Every one of those is a
  # thing a photographer would say, which is the test of whether the rule is the
  # right shape — and every one is a number a later assignment can ask for
  # differently ("a group of three" wants company, not solitude).
  def frame_quality(report)
    return :unscharf unless report
    return :unscharf unless report[:whole] # clipped is a bad photograph

    quality =
      if report[:fill] >= FILL_PERFECT && report[:centred] <= CENTRED_ENOUGH &&
         report[:company].zero?
        :perfekt
      elsif report[:fill] >= FILL_GOOD
        :gut
      else
        :unscharf
      end
    state.sprinting ? blurred(quality) : quality
  end
end
