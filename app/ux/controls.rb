# On-screen touch controls for phones. Reopens Game.
#
# The web build can't be played on a phone with no keyboard, so this reads
# `args.inputs.touch` — a hash of active touches in *screen* coordinates
# (1280x720), the same space the HUD lives in — and turns it into the same
# intents the keyboard raises. Nothing here touches the physics: movement, sprint
# and the shutter read `will_left?` / `will_sprint?` / `tapped?(:photo)`, which OR
# keyboard and touch, so the desktop keyboard keeps working untouched and both can
# be present at once.
#
# The pieces that make a decision — a stick vector into directions, a point into a
# button — are pure methods, tested without faking a single real touch; the small
# stateful shell (which touch is the stick, its anchor, which buttons fired this
# tick) sits in args.state.
#
# Controls appear only once a finger has actually touched the screen
# (state.touch_seen), so a keyboard player never sees a button.
class Game
  STICK_ZONE_W = 560   # a touch starting in the left this-many px is the joystick
  STICK_DEADZONE = 26  # px of travel from the anchor before it counts as a push
  STICK_RANGE = 100    # px of travel that reads as full tilt (the nub's reach)
  STICK_SPRINT = 86    # ... and this far out means "sprint"

  # The action buttons, per context, as data — the renderer and the hit-test read
  # the same list so a button you can see is always a button you can press.
  def control_layout
    case control_context
    when :diving
      diving_layout
    when :name
      [{ id: :start, label: name_start_label, x: (SCREEN_WIDTH - 360) / 2, y: 208, w: 360, h: 64 }]
    when :pause
      [{ id: :quit, label: "Beenden", x: (SCREEN_WIDTH - 300) / 2, y: 300, w: 300, h: 68 }]
    when :title
      title_layout
    else
      []
    end
  end

  # The shutter and the pause, and — once he is standing on rock — the hop.
  #
  # Walking ashore is half the game: beaches, crabs to photograph, a way over an
  # island. On a phone it was unreachable, because the hop is on the space bar
  # and a phone has not got one. You could wade up to the first terrace and no
  # further. It appears only on land, so the button turns up exactly when it
  # starts meaning something — and underwater that key is the sprint, which is
  # held rather than tapped and is the joystick's job already.
  def diving_layout
    buttons = [{ id: :photo, label: "F", x: SCREEN_WIDTH - 184, y: 44, w: 140, h: 140 },
               { id: :pause, label: "II", x: SCREEN_WIDTH - 108, y: SCREEN_HEIGHT - 150, w: 88, h: 88 }]
    return buttons unless on_land?

    buttons << { id: :jump, label: "SPRUNG", size: 3,
                 x: SCREEN_WIDTH - 344, y: 44, w: 140, h: 140 }
    buttons
  end

  # The title only has buttons when there is a choice to make. Without a book to
  # carry on it takes a tap anywhere, so a button would only be in the way.
  def title_layout
    return [] unless saved_book?

    [{ id: :carry_on, label: "Weitertauchen", x: (SCREEN_WIDTH - 360) / 2, y: 96, w: 360, h: 64 },
     { id: :start_over, label: "Neu anfangen", x: (SCREEN_WIDTH - 260) / 2, y: 22, w: 260, h: 60 }]
  end

  # The joystick steers only while diving; the paused screens get taps (anywhere,
  # or on a button) but never a stick, and a stray thumb mustn't move a frozen
  # world behind a menu.
  def control_context
    return :diving if !game_paused? && ["area1", "area2"].include?(state.game_scene)
    return state.game_scene.to_sym if ["title", "name", "game_over", "pause"].include?(state.game_scene)

    :none
  end

  def touch_points
    args.inputs.touch.map { |id, point| { id: id, x: point.x, y: point.y } }
  end

  # Read the touches once per tick and turn them into intents. Runs early, before
  # movement and sprint read them.
  def update_controls
    points = touch_points
    state.touch_seen = true if points.length > 0

    # A new touch this tick — the "tap anywhere to go on" of the title and the
    # game-over screen.
    ids = points.map { |point| point[:id] }
    state.touch_began = (ids - (state.touch_ids || [])).length > 0
    state.touch_ids = ids

    if control_context == :diving
      update_stick(points)
      state.touch_intents = stick_intents(points)
    else
      state.stick_id = nil
      state.stick_anchor = nil
      state.touch_intents = {}
    end

    # Buttons are hit-tested against whatever the current context draws, so the
    # F button underwater and the start button on the name screen both work here.
    buttons = buttons_under(points)
    state.touch_tapped = buttons - (state.touch_pressed || []) # rising edge only
    state.touch_pressed = buttons
    # What counts as "moving" for the animation. On land only the walk does:
    # holding down there gets him nowhere, so it must not set him marching.
    state.swim_pose = will_left? || will_right? || (will_down? && !on_land?)
  end

  # Did a fresh finger land this tick? Used where any tap means "go on".
  def touch_began?
    !!state.touch_began
  end

  # The floating joystick: the first touch that lands in the left zone (and not on
  # a button) becomes the stick, anchored where it touched down; it stops being
  # the stick the moment that finger lifts.
  def update_stick(points)
    active = points.find { |point| point[:id] == state.stick_id }
    if active.nil?
      state.stick_id = nil
      state.stick_anchor = nil
    end

    return if state.stick_id

    claim = points.find { |point| point[:x] < STICK_ZONE_W && button_at(point).nil? }
    return unless claim

    state.stick_id = claim[:id]
    state.stick_anchor = { x: claim[:x], y: claim[:y] }
  end

  # Which way the stick is pushed, and whether it's pushed far enough to sprint.
  def stick_intents(points)
    return {} unless state.stick_anchor

    point = points.find { |p| p[:id] == state.stick_id }
    return {} unless point

    stick_vector_intents(point[:x] - state.stick_anchor.x, point[:y] - state.stick_anchor.y)
  end

  # Pure: an offset from the anchor into a set of direction intents. y is up in
  # DragonRuby (and touch shares that space), so a finger dragged upward — dy
  # positive — means swim up. Each axis clears the dead zone on its own, so a
  # diagonal push raises both, which is exactly how the diver angles.
  def stick_vector_intents(dx, dy)
    intents = {}
    intents[:left] = true if dx <= -STICK_DEADZONE
    intents[:right] = true if dx >= STICK_DEADZONE
    intents[:up] = true if dy >= STICK_DEADZONE
    intents[:down] = true if dy <= -STICK_DEADZONE
    intents[:sprint] = true if Math.sqrt(dx * dx + dy * dy) >= STICK_SPRINT
    intents
  end

  def buttons_under(points)
    points.map { |point| button_at(point) }.compact.uniq
  end

  # The id of the button under a point, or nil. Pure.
  def button_at(point)
    button = control_layout.find do |b|
      point[:x] >= b[:x] && point[:x] <= b[:x] + b[:w] &&
        point[:y] >= b[:y] && point[:y] <= b[:y] + b[:h]
    end
    button && button[:id]
  end

  # --- what the game asks, keyboard OR touch --------------------------------

  def touch?(intent)
    intents = state.touch_intents
    !!(intents && intents[intent])
  end

  def tapped?(id)
    tapped = state.touch_tapped
    !!(tapped && tapped.include?(id))
  end

  def will_left?
    inputs.left || touch?(:left)
  end

  def will_right?
    inputs.right || touch?(:right)
  end

  def will_up?
    inputs.up || touch?(:up)
  end

  def will_down?
    inputs.down || touch?(:down)
  end

  def will_sprint?
    inputs.keyboard.key_held.space || touch?(:sprint)
  end

  # The start button on the name screen names the default so a phone player knows
  # they can just tap through; once they've typed something, it's their name.
  def name_start_label
    named? ? "Los geht's" : "Los als #{DIVER_NAME}"
  end

  # Tapping start dives in — under the typed name, or the default if the field is
  # still empty (a phone has no keyboard to type one).
  def touch_start_name
    state.player_name = DIVER_NAME if state.player_name.strip.empty?
    confirm_name
  end

  # --- drawing --------------------------------------------------------------
  #
  # Drawn from the same layout the hit-test reads, in screen space (the HUD's
  # space), only once a finger has touched and only while diving.

  STICK_INK = [150, 198, 224]
  BUTTON_BG = [16, 40, 62]
  BUTTON_INK = [232, 244, 252]

  def render_touch_controls
    return unless state.touch_seen && control_context == :diving

    render_joystick
    render_buttons
  end

  # The floating base where the thumb landed, and the nub at the current push
  # (clamped to its reach) — only while a finger is actually working the stick.
  def render_joystick
    return unless state.stick_anchor

    ax = state.stick_anchor.x
    ay = state.stick_anchor.y
    ring(ax, ay, STICK_RANGE, 60)

    point = touch_points.find { |p| p[:id] == state.stick_id }
    return unless point

    dx = point[:x] - ax
    dy = point[:y] - ay
    mag = Math.sqrt(dx * dx + dy * dy)
    if mag > STICK_RANGE
      dx = dx * STICK_RANGE / mag
      dy = dy * STICK_RANGE / mag
    end
    ring(ax + dx, ay + dy, 44, 150)
  end

  def render_buttons
    control_layout.each do |button|
      pressed = (state.touch_pressed || []).include?(button[:id])
      outputs.sprites << { x: button[:x], y: button[:y], w: button[:w], h: button[:h],
                           r: BUTTON_BG[0], g: BUTTON_BG[1], b: BUTTON_BG[2],
                           a: pressed ? 230 : 150, path: :solid }
      outputs.sprites << { x: button[:x], y: button[:y] + button[:h] - 4, w: button[:w], h: 4,
                           r: STICK_INK[0], g: STICK_INK[1], b: STICK_INK[2],
                           a: pressed ? 255 : 150, path: :solid }
      # A word needs smaller type than a letter does; the button says how big it
      # wants to be read, rather than the renderer assuming every label is "F".
      outputs.labels << { x: button[:x] + button[:w] / 2, y: button[:y] + button[:h] / 2,
                          text: button[:label], size_enum: button[:size] || 6,
                          alignment_enum: 1, vertical_alignment_enum: 1,
                          r: BUTTON_INK[0], g: BUTTON_INK[1], b: BUTTON_INK[2] }
    end
  end

  # A soft filled disc, near enough with a square for a prototype.
  def ring(cx, cy, radius, alpha)
    outputs.sprites << { x: cx - radius, y: cy - radius, w: radius * 2, h: radius * 2,
                         r: STICK_INK[0], g: STICK_INK[1], b: STICK_INK[2], a: alpha,
                         path: :solid }
  end
end
