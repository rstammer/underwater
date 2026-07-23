class RngTests
  def test_same_seed_same_sequence(args, assert)
    a = Rng.new(7)
    b = Rng.new(7)
    5.times { assert.equal! a.int(1000), b.int(1000) }
  end

  def test_different_seeds_diverge(args, assert)
    a = Rng.new(1)
    b = Rng.new(2)
    seq_a = 3.times.map { a.int(1_000_000) }
    seq_b = 3.times.map { b.int(1_000_000) }

    assert.true! seq_a != seq_b, "different seeds should produce different draws"
  end

  def test_int_stays_in_range(args, assert)
    r = Rng.new(3)
    20.times do
      v = r.int(10)
      assert.true! v >= 0 && v < 10, "int(10) out of range: #{v}"
    end
  end

  def test_between_is_inclusive_range(args, assert)
    r = Rng.new(9)
    50.times do
      v = r.between(5, 8)
      assert.true! v >= 5 && v <= 8, "between(5,8) out of range: #{v}"
    end
  end
end
