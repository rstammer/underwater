# The film strip, and the print that comes out of the camera.
#
# Both are about the same moment: you let go of the shutter and a frame is gone.
# It used to cost a digit in a label and produce a line of text at the foot of
# the screen, in the same size and the same place as "Rucksack voll" — so the one
# thing you are out here to do read like a housekeeping notice.
class ShotCardTests
  def build_game(args)
    game = Game.new
    game.args = args
    game
  end

  def diving(args)
    game = build_game(args)
    game.initialize_game(0)
    args.state.game_scene = "area1"
    args.state.depth_y = WATERLINE_Y - 400
    game.current_world
    game
  end

  def a_species
    Species::ALL.find { |s| s.habitat != :shore } || Species::ALL.first
  end

  # --- the film strip --------------------------------------------------------

  # It is the fourth clock, so it is the width of the other three. That is also
  # what makes it carry the gear ladder for free: twelve frames or thirty, the
  # strip is the same length and only the cells change.
  def test_the_strip_is_as_wide_as_the_gauges(args, assert)
    game = diving(args)
    args.state.film_left = 5

    cells = game.film_cells

    assert.equal! cells.length, game.film_capacity, "one cell per frame on the roll"
    left = cells.map { |c| c[:x] }.min
    right = cells.map { |c| c[:x] + c[:w] }.max
    assert.equal! left, Game::GAUGE_X, "it starts where the bars start"
    assert.true! (right - left - Game::GAUGE_W).abs <= 2,
                 "it ends where they end (#{right - left} px against #{Game::GAUGE_W})"
  end

  # Exposed frames are spent, and have to look spent.
  def test_exposed_frames_read_differently_from_free_ones(args, assert)
    game = diving(args)
    args.state.film_left = 3

    cells = game.film_cells
    spent = cells.select { |c| c[:spent] }

    assert.equal! spent.length, game.film_capacity - 3, "the used ones are marked"
    # The strip fills from the left, the way a roll winds on: what you have shot
    # is behind you, what is left is ahead.
    assert.true! cells.first[:spent], "the first cell is one he has already shot"
    assert.false! cells.last[:spent], "the last one is still free"
  end

  # A roll of thirty still has to fit the same strip.
  def test_a_bigger_roll_still_fits(args, assert)
    game = diving(args)
    film = Game::GEAR.find { |g| g[:key] == :film }
    args.state.gear = { film: film[:steps].length - 1 }
    args.state.film_left = game.film_capacity

    cells = game.film_cells
    assert.true! cells.length > 12, "this is the big roll (#{cells.length})"
    assert.true! cells.all? { |c| c[:w] >= 2 }, "every cell is still a visible cell"
    right = cells.map { |c| c[:x] + c[:w] }.max
    assert.true! right - Game::GAUGE_X <= Game::GAUGE_W + 2, "and none of it hangs off the end"
  end

  # --- the print -------------------------------------------------------------

  # The card needs the animal itself, which means the note has to remember which
  # animal it was — it only ever kept the finished label.
  def test_the_note_remembers_what_was_photographed(args, assert)
    game = diving(args)
    species = a_species

    game.note_shot(species, :perfekt, 3)
    note = args.state.shot_note

    assert.equal! note[:key], species.key, "the card can look the animal up"
    assert.equal! note[:flock], 3, "and knows it was a group"
    assert.equal! note[:quality], :perfekt
  end

  # It comes in, it stands, it goes. Driven off the same clock as the old line.
  def test_the_card_shows_up_and_then_goes_away(args, assert)
    game = diving(args)
    game.note_shot(a_species, :gut, 1)

    assert.false! game.shot_card.nil?, "the print is on screen right after the shutter"

    args.state.shot_at -= Game::NOTE_TICKS + 1
    assert.true! game.shot_card.nil?, "and gone again a couple of seconds later"
  end

  # The rule the whole game hangs on: film is exposed, not identified. Something
  # you have never developed stays nameless until the boat tells you, so the card
  # may show what you could see and nothing more.
  def test_the_card_does_not_name_an_undeveloped_animal(args, assert)
    game = diving(args)
    species = a_species
    args.state.album = {}

    game.note_shot(species, :perfekt, 1)
    card = game.shot_card

    assert.false! card[:text].include?(species.name),
                  "\"#{card[:text]}\" gives away a name the boat has not given yet"
    assert.true! card[:fresh], "but it is marked as one he has not had before"
  end

  def test_the_card_names_one_that_is_in_the_book(args, assert)
    game = diving(args)
    species = a_species
    args.state.album = { species.key => :gut }

    game.note_shot(species, :perfekt, 1)
    card = game.shot_card

    assert.true! card[:text].include?(species.name), "this one he has developed"
    assert.false! card[:fresh], "so it is not news"
  end

  # --- does it fit on the screen ---------------------------------------------

  # Drawn rather than described, because this is the part a test can see and I
  # cannot: the suite passed once before while the renderer was bailing out ahead
  # of the line that crashed.
  def test_the_card_draws_without_error(args, assert)
    game = diving(args)
    game.note_shot(a_species, :perfekt, 4)
    args.state.album = {}

    game.render_shot_card
    sprites = args.outputs.sprites.length
    game.note_shot(a_species, nil, 1) # the kraken: a shot with no grade at all
    game.render_shot_card

    assert.true! args.outputs.sprites.length > sprites, "it put something on screen"
  end

  # Everything on the print, as boxes, so overlaps are a thing a test can see.
  # They were not: the grade and the NEU badge printed on top of each other, and
  # the third line of a caption hung out of the bottom edge of the paper.
  def test_nothing_on_the_print_overlaps_anything_else(args, assert)
    game = diving(args)
    args.state.album = {}
    game.note_shot(a_species, :perfekt, 12) # long grade line *and* a NEU badge

    boxes = game.card_layout(game.shot_card)
    pairs = []
    boxes.each_with_index { |a, i| boxes.each_with_index { |b, j| pairs << [a, b] if j > i } }

    pairs.each do |a, b|
      keys = [a[:key], b[:key]]
      # The badge is a sticker *on* the print, so it is meant to sit on the
      # picture. It is not meant to sit on the grade, which is what it did.
      next if keys.include?(:badge) && keys.include?(:window)

      apart = a[:x] + a[:w] <= b[:x] || b[:x] + b[:w] <= a[:x] ||
              a[:y] + a[:h] <= b[:y] || b[:y] + b[:h] <= a[:y]
      assert.true! apart, "#{a[:key]} and #{b[:key]} sit on top of each other"
    end
  end

  # And all of it on the paper.
  def test_everything_on_the_print_is_on_the_paper(args, assert)
    game = diving(args)
    args.state.album = {}
    game.note_shot(a_species, :perfekt, 12)
    card = game.shot_card

    x = SCREEN_WIDTH - Game::CARD_RIGHT - Game::CARD_W
    y = Game::CARD_BOTTOM
    game.card_layout(card).each do |box|
      assert.true! box[:x] >= x, "#{box[:key]} runs off the left edge"
      assert.true! box[:x] + box[:w] <= x + Game::CARD_W, "#{box[:key]} runs off the right edge"
      assert.true! box[:y] >= y, "#{box[:key]} hangs out of the bottom"
      assert.true! box[:y] + box[:h] <= y + Game::CARD_H, "#{box[:key]} runs off the top"
    end
  end

  # The film strip had the same fault: the word "Film" sat straight on the cells.
  def test_the_film_label_clears_the_strip(args, assert)
    game = diving(args)
    cells = game.film_cells
    top = cells.first[:y] + cells.first[:h]

    assert.true! game.film_label_y >= top + 4,
                 "the label is #{game.film_label_y - top} px off the strip"
  end

  # ... and does not solve that by climbing into the gauge above it. The strip
  # hangs under the lowest bar, and the whole of it has to fit in that gap.
  def test_the_whole_strip_fits_under_the_gauges(args, assert)
    game = diving(args)
    lowest_gauge = game.gauges_bottom + Game::GAUGE_GAP

    assert.true! game.film_label_y < lowest_gauge,
                 "the word Film is #{game.film_label_y - lowest_gauge} px into the bar above it"
    assert.true! game.film_cells.first[:y] > 0, "and the strip is on the screen"
  end

  def test_the_card_is_wholly_on_the_screen(args, assert)
    game = diving(args)
    game.note_shot(a_species, :gut, 1)
    card = game.shot_card

    x = SCREEN_WIDTH - Game::CARD_RIGHT - Game::CARD_W
    assert.true! x > 0, "it has a left edge on the screen"
    assert.true! x + Game::CARD_W <= SCREEN_WIDTH, "and a right one"
    # rise is how far *down* it still is on the way in, so the lowest it ever sits
    lowest = Game::CARD_BOTTOM - Game::CARD_RISE
    assert.true! lowest > 0, "even sliding in, it is above the bottom edge"
    assert.true! card[:rise] <= Game::CARD_RISE, "and it never slides further than that"
  end

  # The caption is a sentence, not a word: the tease of an undeveloped animal can
  # be "ein Schneckenhaus mit Beinen". Every line of it has to fit the paper.
  def test_every_caption_fits_the_paper(args, assert)
    game = diving(args)
    room = Game::CARD_W - Game::CARD_PAD * 2
    args.state.album = {}

    Species::ALL.each do |species|
      game.note_shot(species, :perfekt, 1)
      game.wrap_card_text(game.shot_card[:text]).each do |line|
        width = args.gtk.calcstringbox(line, -1)[0]
        assert.true! width <= room,
                     "#{species.key}: \"#{line}\" is #{width.round} px on #{room} px of paper"
      end
    end
  end

  # One event, one place on the screen.
  def test_the_old_line_is_gone(args, assert)
    game = diving(args)
    game.note_shot(a_species, :gut, 1)

    slots = game.running_messages.map { |m| m[:slot] }
    assert.false! slots.include?(Game::SLOT_NOTE),
                  "the result of a shot is the card's job now, not a message row"
  end
end
