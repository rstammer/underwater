# Deterministic 1-D value noise over the unbounded world x axis.
#
# The terrain is built by *sampling a function of the world position*, not by
# rolling dice per segment. That's what lets neighbouring segments be generated
# independently and still meet seamlessly: both ask the same function for the
# same world x. Every layer of the sea floor (broad shelves, basins, dunes,
# ragged edge) is one call to this with a different wavelength and seed.
module Noise
  # Smoothly interpolated noise in 0.0..1.0. `wavelength` is the distance in
  # world px between control points — big = broad, slow features.
  def self.value(x, wavelength, seed)
    cell = x.idiv(wavelength)
    t = (x - cell * wavelength) / wavelength.to_f
    t = t * t * (3 - 2 * t) # smoothstep: flat at the control points, no kinks
    a = jitter(cell, seed)
    b = jitter(cell + 1, seed)
    a + (b - a) * t
  end

  # The raw, *un*-interpolated value of one cell (0.0..1.0). Used on its own as
  # the ragged top layer of the sand — no interpolation means neighbouring cells
  # jump, which is exactly the pixelated, jagged edge we want.
  def self.jitter(cell, seed)
    rng = Rng.new((cell * 0x9E3779B1) ^ (seed * 0x85EBCA6B + 0x27D4EB2F))
    rng.next_u32 # warm past the seeded state so neighbouring cells decorrelate
    rng.float
  end
end
