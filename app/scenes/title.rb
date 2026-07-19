class Game
  # Fish drifting across the title: reuse the in-game animal sheets so the look
  # stays consistent. dir +1 swims right, -1 swims left (sprite flipped).
  TITLE_FISH = [
    { path: "sprites/animals/scalar_32_16/orange.png", y: 470, speed: 0.9,  size: 2, dir: 1 },
    { path: "sprites/animals/scalar_32_16/blue.png",   y: 250, speed: 0.6,  size: 2, dir: -1 },
    { path: "sprites/animals/bass1_32_16/Grey.png",    y: 150, speed: 1.3,  size: 3, dir: 1 },
    { path: "sprites/animals/scalar_32_16/purple.png", y: 560, speed: 0.45, size: 1, dir: -1 },
    { path: "sprites/animals/bass1_32_16/Red.png",     y: 360, speed: 0.75, size: 2, dir: -1 },
  ]

  def title_tick
    if fire_input?
      spawn_at_surface
      state.game_scene = "surface"
      return
    end

    outputs.sprites << title_background
    outputs.sprites << title_light_rays
    outputs.sprites << title_seabed
    outputs.sprites << title_fish
    outputs.sprites << title_diver
    outputs.sprites << title_bubbles
    outputs.labels << title_labels
  end

  # Vertical depth gradient: dark and deep at the bottom, bright near the top.
  def title_background
    bands = 32
    (0...bands).map do |i|
      t = i / (bands - 1.0) # 0 at the bottom, 1 at the top
      {
        x: 0,
        y: i * grid.h / bands,
        w: grid.w,
        h: grid.h / bands + 1,
        r: (12 + 30 * t).to_i,
        g: (46 + 84 * t).to_i,
        b: (92 + 105 * t).to_i,
        path: :solid,
      }
    end
  end

  # Faint sunlight shafts coming down through the water.
  def title_light_rays
    [180, 520, 860, 1140].map do |x|
      { x: x, y: 0, w: 70, h: grid.h, r: 190, g: 225, b: 255, a: 16, path: :solid }
    end
  end

  # Sea floor with the generated decorations (seaweed sways, coral, starfish).
  def title_seabed
    items = [{ x: 0, y: 0, w: grid.w, h: 38, r: 26, g: 30, b: 46, path: :solid }]

    [120, 300, 770, 1050, 1190].each do |x|
      sway = Math.sin((Kernel.tick_count + x) / 45.0) * 3
      items << { x: x, y: 16, w: 14 * 3, h: 44 * 3, path: "sprites/decor/seaweed.png",
                 angle: sway, anchor_x: 0.5, anchor_y: 0 }
    end

    items << { x: 430, y: 20, w: 28 * 3, h: 30 * 3, path: "sprites/decor/coral.png" }
    items << { x: 890, y: 20, w: 28 * 2, h: 30 * 2, path: "sprites/decor/coral.png" }
    items << { x: 620, y: 18, w: 16 * 2, h: 16 * 2, path: "sprites/decor/starfish.png" }
    items << { x: 1070, y: 22, w: 16 * 3, h: 16 * 3, path: "sprites/decor/starfish.png" }
    items
  end

  def title_fish
    frame = 0.frame_index(count: SloppyScalar::SPRITES_PER_ROW, hold_for: 8, repeat: true) || 0
    span = grid.w + 200
    TITLE_FISH.each_with_index.map do |f, i|
      travel = (Kernel.tick_count * f[:speed] + i * 260) % span
      x = f[:dir] > 0 ? travel - 100 : grid.w + 100 - travel
      {
        x: x,
        y: f[:y],
        w: SloppyScalar::WIDTH * f[:size],
        h: SloppyScalar::HEIGHT * f[:size],
        path: f[:path],
        source_x: SloppyScalar::WIDTH * frame,
        source_y: SloppyScalar::HEIGHT * (frame / SloppyScalar::SPRITES_PER_ROW).floor,
        source_w: SloppyScalar::WIDTH,
        source_h: SloppyScalar::HEIGHT,
        flip_horizontally: f[:dir] < 0,
      }
    end
  end

  # Foreground bubbles rising and wrapping around.
  def title_bubbles
    (0...20).map do |i|
      speed = 0.6 + (i % 4) * 0.35
      scale = 2 + (i % 3)
      {
        x: (i * 137 + 40) % grid.w,
        y: (i * 80 + Kernel.tick_count * speed) % (grid.h + 60) - 30,
        w: 8 * scale,
        h: 8 * scale,
        path: "sprites/decor/bubble.png",
      }
    end
  end

  # The hero diver, gently swimming and bobbing in the centre.
  def title_diver
    frame = 0.frame_index(count: 8, hold_for: 10, repeat: true) || 0
    bob = Math.sin(Kernel.tick_count / 28.0) * 14
    {
      x: grid.w / 2,
      y: grid.h / 2 - 30 + bob,
      w: Diver::WIDTH * 4,
      h: Diver::HEIGHT * 4,
      anchor_x: 0.5,
      anchor_y: 0.5,
      path: Diver::PATH,
      source_x: Diver::WIDTH * frame,
      source_y: 0,
      source_w: Diver::WIDTH,
      source_h: Diver::HEIGHT,
    }
  end

  def title_labels
    cx = grid.w / 2
    labels = []
    labels << { x: cx + 4, y: grid.h - 94, text: "Underwater", size_enum: 24,
                alignment_enum: 1, r: 4, g: 20, b: 38, a: 150 } # drop shadow
    labels << { x: cx, y: grid.h - 90, text: "Underwater", size_enum: 24,
                alignment_enum: 1, r: 236, g: 246, b: 255 }
    labels << { x: cx, y: grid.h - 170, text: "Tauche ein und erkunde die Unterwasserwelt",
                size_enum: 4, alignment_enum: 1, r: 205, g: 228, b: 246 }
    labels << { x: cx, y: 118, text: "Pfeile / WASD  bewegen      Leertaste  sprinten      ESC  Pause",
                size_enum: 1, alignment_enum: 1, r: 188, g: 214, b: 236, a: 210 }
    if Kernel.tick_count.idiv(30).even?
      labels << { x: cx, y: 72, text: "Leertaste drücken zum Starten",
                  size_enum: 4, alignment_enum: 1, r: 255, g: 244, b: 205 }
    end
    labels
  end
end
