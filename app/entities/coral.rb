# A coral: the one thing in the book that does not move.
#
# Sibling of Crustacean — carries a species, reads its y off the sand under it —
# but with the walking taken out. That is not a shortcut, it is the point of
# them. Everything else in the sea has to be chased, waited out or crept up on,
# and the photograph is a question of patience; a coral holds perfectly still
# and lets you frame it exactly. So the reef is where a diver learns what a good
# frame *is*, on subjects that will not swim off while he works it out.
#
# It has no animation either. A swaying coral would be a plant, and the reef
# reads as busy because there are a lot of them in a lot of colours rather than
# because they wiggle.
class Coral
  attr_reader :species

  # x is segment-local, like every other creature. size is rolled once and kept:
  # a reef of identically sized brain corals looks stamped.
  def initialize(current_args, _sprite_index, species:, world:, x: 100, size: nil)
    @current_args = current_args
    @species = species
    @world = world
    @x = x
    @size = size || [2, 2, 3].sample
    @y = ground_y
  end

  def ground_y
    @world.floor_y_at(@x)
  end

  def x
    @x
  end

  def y
    @y
  end

  def size
    @size
  end

  # The sand can move under it — an island stamped over the segment reshapes the
  # floor — so the y is read rather than remembered. Nothing else happens: the
  # tick exists because everything in creatures_in_view is ticked.
  def tick(current_args, _sprite_index)
    @current_args = current_args
    @y = ground_y
  end

  # Game#update_shyness asks every creature it can see whether it wants to bolt.
  # A coral does not, and cannot; it is asked anyway, so it has to answer.
  def bolt_from(_local_x); end

  def drawn_to(_local_x); end

  def w
    species.frame_w * size
  end

  def h
    species.frame_h * size
  end

  # Sitting on the sand, the same way a crab does: y is the floor and a sprite's
  # y is its bottom edge. One frame, so no source_x arithmetic — the sheet is
  # the picture.
  def to_h
    {
      x: @x - w / 2,
      y: @y,
      w: w,
      h: h,
      path: species.sheet,
      source_x: 0,
      source_y: 0,
      source_w: species.frame_w,
      source_h: species.frame_h,
    }
  end
end
