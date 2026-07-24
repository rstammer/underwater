class CreatureTests
  def fish(args, species_key: "burgunder", **rest)
    Creature.new(args, 0, species: Species[species_key], **rest)
  end

  def test_it_draws_from_its_species_sheet(args, assert)
    creature = fish(args, species_key: "burgunder", x: 0, y: 0)

    assert.equal! creature.to_h[:path], "sprites/animals/scalar_32_16/blue.png"
    assert.equal! creature.species.name, "Blauer Burgunder"
  end

  def test_to_h_structure_and_source_dimensions(args, assert)
    creature = fish(args, species_key: "zottelmaul", x: 100, y: 200)
    h = creature.to_h
    species = creature.species

    assert.equal! h[:x], 100
    assert.equal! h[:y], 200
    assert.equal! h[:source_w], species.frame_w
    assert.equal! h[:source_h], species.frame_h
    assert.equal! h[:path], species.sheet
    # size is 1 or 2, so width/height are a whole multiple of the sprite size
    assert.true! [species.frame_w, species.frame_w * 2].include?(h[:w])
    assert.true! [species.frame_h, species.frame_h * 2].include?(h[:h])
  end

  # A fish given a stretch of open water turns around at its ends instead of
  # carrying on into whatever rock is there.
  def test_tick_turns_around_at_the_ends_of_its_water(args, assert)
    creature = fish(args, x: 300, y: 0, from_x: 280, to_x: 340)

    400.times do
      creature.tick(args, 0)
      x = creature.to_h[:x]
      assert.true! x >= 280 && x <= 340, "the fish should stay in its water, was #{x}"
    end
  end

  def test_tick_turns_around_at_the_segment_edge(args, assert)
    # Start just shy of the right edge; any speed (>= 0.15) pushes it past
    # SCREEN_WIDTH, where it has to turn rather than carry on.
    creature = fish(args, species_key: "scalarus", x: SCREEN_WIDTH - 0.05, y: 0)
    creature.tick(args, 0)
    creature.tick(args, 0)
    h = creature.to_h

    assert.true! h[:x] <= SCREEN_WIDTH, "it stays in the segment, was #{h[:x]}"
    assert.true! h[:x] < SCREEN_WIDTH, "and is heading back, was #{h[:x]}"
    assert.true! h[:flip_horizontally], "swimming left, so the sprite faces left"
  end

  # Fish live at whatever depth they were spawned at — including far below the
  # old sea-floor level in a trench — and only drift around that home depth.
  def test_tick_keeps_the_fish_near_its_home_depth(args, assert)
    creature = fish(args, x: 0, y: -1500)
    400.times { creature.tick(args, 0) }
    y = creature.to_h[:y]

    assert.true! (y - -1500).abs <= Creature::DRIFT,
                 "a deep fish should stay in its depth band, was #{y}"
  end
end
