# Small deterministic PRNG (xorshift32). World generation seeds one of these so
# the same seed always yields the same world — reproducible, independent of the
# global rand state, and unit-testable. Not for cryptography, just for variety.
class Rng
  def initialize(seed)
    @state = (seed.to_i ^ 0x9E3779B9) & 0xFFFFFFFF
    @state = 1 if @state == 0
  end

  def next_u32
    x = @state
    x ^= (x << 13) & 0xFFFFFFFF
    x ^= (x >> 17)
    x ^= (x << 5) & 0xFFFFFFFF
    @state = x & 0xFFFFFFFF
  end

  # 0..(n-1). Uses the high bits (multiply-shift) rather than `% n`, which keeps
  # the distribution even for small n where xorshift's low bits are weak.
  def int(n)
    n <= 0 ? 0 : (next_u32 * n) >> 32
  end

  # inclusive a..b
  def between(a, b)
    a + int(b - a + 1)
  end

  # 0.0..1.0
  def float
    next_u32 / 4_294_967_296.0
  end

  def chance(probability)
    float < probability
  end

  def sample(array)
    array[int(array.length)]
  end
end
