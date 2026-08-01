# The boat screen: home base, and by now the most important screen in the game —
# what you carry against what lies in the hold, what you have sold, the Artenbuch
# the whole thing is *for*, and the log of a career. Reopens Game.
#
# It takes nearly the whole screen, in three pages behind a row of tabs. It used
# to be a 900x470 box with two pages and no way to see there was a second one,
# which was fine while it held four numbers and a list.
class Game
  MENU_BG = [12, 30, 48]
  MENU_PANEL = [17, 41, 63]   # the boxes inside it, a shade up from the ground
  MENU_ACCENT = [120, 190, 220]
  MENU_INK = [232, 244, 252]
  MENU_DIM_INK = [150, 184, 208]
  MENU_WARN = [240, 200, 150]

  MENU_MARGIN = 26            # air between the screen edge and the boat screen
  MENU_PAD = 26
  MENU_ROW_H = 52
  MENU_ICON_X = 26
  MENU_RULE_GAP = 8
  MENU_VEIL = 190
  MENU_HEAD_H = 74            # the band with the boat, the diver and the money
  MENU_TAB_H = 46
  MENU_FOOT_H = 44

  # The pages, in the order Tab walks them. Each carries the icon it is drawn
  # with — a sprite the game already owns, so a tab looks like what it holds.
  BOAT_PAGES = [
    { id: :hold, title: "Lager", icon: "sprites/items/jewel.png" },
    { id: :book, title: "Artenbuch", icon: "sprites/animals/scalar_32_16/blue.png" },
    { id: :jobs, title: "Aufträge", icon: "sprites/decor/flag.png" },
    { id: :log,  title: "Logbuch", icon: "sprites/decor/boat.png" },
    { id: :kit,  title: "Ausrüstung", icon: "sprites/items/jewel.png" },
  ]

  def home_menu_tick
    render_underwater # the frozen world behind the veil
    render_fog        # a no-op at the boat, where this screen lives — but the rule
                      # is that anything drawing the sea draws the dark with it
    outputs.sprites << { x: 0, y: 0, w: grid.w, h: grid.h, r: 4, g: 12, b: 22, a: MENU_VEIL, path: :solid }
    render_boat_screen
  end

  # Tab walks the pages round. With three of them a toggle no longer says
  # anything, which is why they are drawn as tabs now.
  def update_boat_page
    return unless state.game_scene == "home_menu"
    return unless inputs.keyboard.key_down.tab

    ids = BOAT_PAGES.map { |page| page[:id] }
    state.boat_page = ids[(ids.index(state.boat_page).to_i + 1) % ids.length]
  end

  def book_page?
    state.boat_page == :book
  end

  def hold_page?
    state.boat_page == :hold
  end

  def log_page?
    state.boat_page == :log
  end

  def kit_page?
    state.boat_page == :kit
  end

  # --- the frame ------------------------------------------------------------

  def menu_left
    MENU_MARGIN
  end

  def menu_right
    grid.w - MENU_MARGIN
  end

  def menu_bottom
    MENU_MARGIN
  end

  def menu_top
    grid.h - MENU_MARGIN
  end

  def menu_width
    menu_right - menu_left
  end

  # Where the page's own content begins and ends, once the head, the tabs and the
  # footer have taken theirs. Everything a page draws hangs off these two.
  def body_top
    menu_top - MENU_HEAD_H - MENU_TAB_H - 18
  end

  def body_bottom
    menu_bottom + MENU_FOOT_H
  end

  def render_boat_screen
    outputs.sprites << { x: menu_left, y: menu_bottom, w: menu_width, h: menu_top - menu_bottom,
                         r: MENU_BG[0], g: MENU_BG[1], b: MENU_BG[2], path: :solid }
    render_menu_head
    render_menu_tabs
    case state.boat_page
    when :book then render_artenbuch_page
    when :jobs then render_jobs_page
    when :log then render_logbook_page
    when :kit then render_kit_page
    else render_hold_page
    end
    render_menu_foot
  end

  # The band across the top: whose boat, and what he is worth. The balance is the
  # number this screen exists to move, so it gets the size and the gold.
  def render_menu_head
    top = menu_top
    outputs.sprites << { x: menu_left, y: top - MENU_HEAD_H, w: menu_width, h: MENU_HEAD_H,
                         r: MENU_PANEL[0], g: MENU_PANEL[1], b: MENU_PANEL[2], path: :solid }
    outputs.sprites << { x: menu_left, y: top - 4, w: menu_width, h: 4,
                         r: MENU_ACCENT[0], g: MENU_ACCENT[1], b: MENU_ACCENT[2], path: :solid }

    sprite = BOAT_SPRITE
    outputs.sprites << { x: menu_left + MENU_PAD, y: top - MENU_HEAD_H / 2,
                         w: sprite[:w] * 2, h: sprite[:h] * 2, path: sprite[:path],
                         anchor_x: 0, anchor_y: 0.5 }
    outputs.labels << { x: menu_left + MENU_PAD + 100, y: top - 24, text: "Dein Boot",
                        size_enum: 4, vertical_alignment_enum: 2,
                        r: MENU_INK[0], g: MENU_INK[1], b: MENU_INK[2] }
    outputs.labels << { x: menu_left + MENU_PAD + 100, y: top - 54, text: diver_name,
                        size_enum: 1, vertical_alignment_enum: 2,
                        r: MENU_DIM_INK[0], g: MENU_DIM_INK[1], b: MENU_DIM_INK[2] }

    outputs.labels << { x: menu_right - MENU_PAD, y: top - 22, text: "#{state.credits} Cr",
                        size_enum: 8, alignment_enum: 2, vertical_alignment_enum: 2,
                        r: CREDIT_INK[0], g: CREDIT_INK[1], b: CREDIT_INK[2] }
    render_sale_note(top) ||
      outputs.labels << { x: menu_right - MENU_PAD, y: top - 58, text: "Guthaben",
                          size_enum: 0, alignment_enum: 2, vertical_alignment_enum: 2,
                          r: MENU_DIM_INK[0], g: MENU_DIM_INK[1], b: MENU_DIM_INK[2] }
  end

  SALE_NOTE_TICKS = 210 # three and a half seconds of being news

  # What the last sale was, in the place where the money it made is — a balance
  # that moves without saying why is a balance you have to go and check. It takes
  # the "Guthaben" caption's place rather than finding room of its own, because
  # while it is up it *is* the caption.
  def render_sale_note(top)
    note = state.sale_note
    return nil unless note && Kernel.tick_count - note[:at] < SALE_NOTE_TICKS

    outputs.labels << { x: menu_right - MENU_PAD, y: top - 58, text: note[:text],
                        size_enum: 1, alignment_enum: 2, vertical_alignment_enum: 2,
                        r: CREDIT_INK[0], g: CREDIT_INK[1], b: CREDIT_INK[2] }
    true
  end

  # Sized so the whole row fits the panel with the Tab hint beside it. It was
  # 240, which was fine for four tabs and half a tab too wide for five.
  MENU_TAB_W = 184

  def render_menu_tabs
    y = menu_top - MENU_HEAD_H - MENU_TAB_H
    BOAT_PAGES.each_with_index do |page, i|
      x = menu_left + MENU_PAD + i * (MENU_TAB_W + 10)
      here = state.boat_page == page[:id]

      outputs.sprites << { x: x, y: y, w: MENU_TAB_W, h: MENU_TAB_H,
                           r: MENU_PANEL[0], g: MENU_PANEL[1], b: MENU_PANEL[2],
                           a: here ? 255 : 130, path: :solid }
      outputs.sprites << { x: x, y: y, w: MENU_TAB_W, h: 3,
                           r: MENU_ACCENT[0], g: MENU_ACCENT[1], b: MENU_ACCENT[2],
                           a: here ? 255 : 0, path: :solid }
      outputs.sprites << { x: x + 26, y: y + MENU_TAB_H / 2, w: 26, h: 26,
                           path: page[:icon], source_x: 0, source_y: 0,
                           source_w: 32, source_h: 16, anchor_x: 0.5, anchor_y: 0.5,
                           a: here ? 255 : 110 }
      ink = here ? MENU_INK : MENU_DIM_INK
      outputs.labels << { x: x + 50, y: y + MENU_TAB_H / 2 + 1, text: page[:title],
                          size_enum: 2, vertical_alignment_enum: 1,
                          r: ink[0], g: ink[1], b: ink[2] }
    end
    outputs.labels << { x: menu_right - MENU_PAD, y: y + MENU_TAB_H / 2 + 1,
                        text: "[ Tab ] blättert", size_enum: 0, alignment_enum: 2,
                        vertical_alignment_enum: 1,
                        r: MENU_DIM_INK[0], g: MENU_DIM_INK[1], b: MENU_DIM_INK[2] }
  end

  def render_menu_foot
    hint =
      if book_page?
        artenbuch_pages > 1 ? "← → blättern   ·   L / ESC zurück ins Wasser" : "L / ESC zurück ins Wasser"
      elsif log_page? || kit_page?
        "L / ESC zurück ins Wasser"
      else
        "Pfeiltasten wählen   ·   [ E ] verschieben   ·   [ V ] verkaufen   ·   L / ESC zurück ins Wasser"
      end
    outputs.labels << { x: (menu_left + menu_right) / 2, y: menu_bottom + MENU_FOOT_H - 14,
                        text: hint, size_enum: 1, alignment_enum: 1, vertical_alignment_enum: 2,
                        r: MENU_DIM_INK[0], g: MENU_DIM_INK[1], b: MENU_DIM_INK[2] }
  end

  # A framed box for a page to put a column in. Boxes rather than bare columns
  # because there is a lot on this screen now, and edges are what let an eye
  # find the one thing it came for.
  def render_box(x, y, w, h, title, title_color = nil)
    outputs.sprites << { x: x, y: y, w: w, h: h,
                         r: MENU_PANEL[0], g: MENU_PANEL[1], b: MENU_PANEL[2], path: :solid }
    outputs.sprites << { x: x, y: y + h - 2, w: w, h: 2,
                         r: MENU_ACCENT[0], g: MENU_ACCENT[1], b: MENU_ACCENT[2], a: 90, path: :solid }
    return unless title

    column_heading(x + 18, y + h - 16, title, w - 36, title_color)
  end

  # --- the pages ------------------------------------------------------------

  def render_hold_page
    top = body_top
    h = top - body_bottom - 10
    half = (menu_width - MENU_PAD * 2 - 20) / 2
    render_box(menu_left + MENU_PAD, body_bottom + 10, half, h,
               "Rucksack  #{state.inventory.length} / #{INVENTORY_MAX}",
               inventory_full? ? MENU_WARN : nil)
    render_box(menu_left + MENU_PAD + half + 20, body_bottom + 10, half, h,
               "Lager  #{state.stash.length}")

    rows_y = top - 76
    render_pack_column(menu_left + MENU_PAD + 18, rows_y, half - 36)
    render_hold_column(menu_left + MENU_PAD + half + 38, rows_y, half - 36)
  end

  # The career, which until now was four numbers squeezed beside the hold. This
  # dive on the left, everything before it on the right — that contrast is the
  # whole reason to keep a log.
  def logbook_rows
    [
      ["Tiefster Punkt", "#{state.log_deepest} m"],
      ["Sektoren erkundet", "#{state.log_sectors.length}"],
      ["Inseln gefunden", "#{state.log_islands.length} / #{ISLAND_COUNT}"],
      ["Höhlen durchtaucht", "#{state.log_caves.length}"],
    ]
  end

  def career_rows
    [
      ["Tag", "#{state.day}"],
      ["Tauchgänge", "#{state.log_dives}"],
      ["Tiefster Punkt je", "#{state.log_best} m"],
      ["Arten im Artenbuch", "#{album_found} / #{Species::ALL.length}"],
      ["Fundstücke verkauft", "#{state.log_sold}"],
      ["Insgesamt verdient", "#{state.log_earned} Cr"],
    ]
  end

  def render_logbook_page
    top = body_top
    h = top - body_bottom - 10
    half = (menu_width - MENU_PAD * 2 - 20) / 2
    render_box(menu_left + MENU_PAD, body_bottom + 10, half, h, "Dieser Tauchgang")
    render_box(menu_left + MENU_PAD + half + 20, body_bottom + 10, half, h, "Deine Laufbahn")

    render_tally(menu_left + MENU_PAD + 18, top - 84, half - 36, logbook_rows)
    render_tally(menu_left + MENU_PAD + half + 38, top - 84, half - 36, career_rows)
  end

  # What you are actually wearing, by name. The shop sells rungs on a ladder;
  # this is the only place that says what the rung you are standing on is
  # *called* — and a diver talks about their kit by its name, not its number.
  #
  # Every piece is listed, including the ones you have never upgraded: "what
  # have I got?" is a question about all of it, and a page that only showed
  # purchases would answer a different one.
  def kit_rows
    GEAR.map do |item|
      key = item[:key]
      { name: item[:name], title: gear_title(key),
        value: "#{gear_value(key)} #{item[:unit]}",
        top: gear_top?(key) }
    end
  end

  KIT_ROW_H = 74

  ASSIGNMENT_DONE_INK = [156, 226, 150]
  ASSIGNMENT_READY_INK = [255, 214, 120]

  # Where the job stands, in one line. Lives here rather than in the briefing
  # window because the boat screen shows it too, on its way past.
  def assignment_state_line(job = todays_assignment)
    return ["Abgegeben. #{job.fee} Cr sind drauf.", ASSIGNMENT_DONE_INK] if assignment_paid?
    return ["Im Kasten — entwickeln, dann zahlt das Magazin.", ASSIGNMENT_READY_INK] if assignment_done?(job)

    ["Noch nicht auf dem Film.", MENU_DIM_INK]
  end

  JOBS_ROW_H = 44
  JOBS_ROWS = 7

  # Today's job at the top, then the ones already done, newest first.
  #
  # The done ones are here because finishing one otherwise leaves no trace: the
  # fee goes into the same pile as everything else, and by the evening there is
  # nothing to say that Tuesday had you waiting out a school of six in the dark.
  # The Artenbuch records what the sea holds; this records what you did in it.
  def render_jobs_page
    top = body_top
    render_box(menu_left + MENU_PAD, body_bottom + 10,
               menu_width - MENU_PAD * 2, top - body_bottom - 10,
               "Aufträge")

    x = menu_left + MENU_PAD + 24
    right = menu_right - MENU_PAD - 24
    y = top - 82

    y = render_todays_job_row(x, right, y)
    done = assignment_log

    if done.empty?
      outputs.labels << { x: x, y: y - 16, text: "Noch keinen Auftrag abgegeben.",
                          size_enum: 1, vertical_alignment_enum: 2,
                          r: MENU_DIM_INK[0], g: MENU_DIM_INK[1], b: MENU_DIM_INK[2] }
      return
    end

    outputs.labels << { x: x, y: y - 10, text: "Erledigt", size_enum: 0,
                        vertical_alignment_enum: 2,
                        r: MENU_DIM_INK[0], g: MENU_DIM_INK[1], b: MENU_DIM_INK[2] }
    y -= 40
    done.first(JOBS_ROWS).each do |entry|
      outputs.labels << { x: x, y: y, text: "Tag #{entry[:day]}", size_enum: 0,
                          vertical_alignment_enum: 2,
                          r: MENU_DIM_INK[0], g: MENU_DIM_INK[1], b: MENU_DIM_INK[2] }
      outputs.labels << { x: x + 92, y: y, text: entry[:text].to_s, size_enum: 1,
                          vertical_alignment_enum: 2,
                          r: MENU_INK[0], g: MENU_INK[1], b: MENU_INK[2] }
      outputs.labels << { x: right, y: y, text: "#{entry[:fee]} Cr", size_enum: 1,
                          alignment_enum: 2, vertical_alignment_enum: 2,
                          r: CREDIT_INK[0], g: CREDIT_INK[1], b: CREDIT_INK[2] }
      y -= JOBS_ROW_H
    end

    return unless done.length > JOBS_ROWS

    outputs.labels << { x: x, y: y, text: "… und #{done.length - JOBS_ROWS} weitere",
                        size_enum: 0, vertical_alignment_enum: 2,
                        r: MENU_DIM_INK[0], g: MENU_DIM_INK[1], b: MENU_DIM_INK[2] }
  end

  # The one at the top is the one you can still do something about, so it gets
  # the state line and the key that opens the full briefing.
  def render_todays_job_row(x, right, y)
    job = todays_assignment
    unless job
      outputs.labels << { x: x, y: y, text: "Heute liegt nichts an.", size_enum: 2,
                          vertical_alignment_enum: 2,
                          r: MENU_DIM_INK[0], g: MENU_DIM_INK[1], b: MENU_DIM_INK[2] }
      return y - 70
    end

    state_text, ink = assignment_state_line(job)
    outputs.labels << { x: x, y: y, text: "Heute — #{assignment_short(job)}", size_enum: 3,
                        vertical_alignment_enum: 2,
                        r: MENU_INK[0], g: MENU_INK[1], b: MENU_INK[2] }
    outputs.labels << { x: right, y: y, text: "#{job.fee} Cr", size_enum: 3,
                        alignment_enum: 2, vertical_alignment_enum: 2,
                        r: CREDIT_INK[0], g: CREDIT_INK[1], b: CREDIT_INK[2] }
    outputs.labels << { x: x, y: y - 34, text: state_text, size_enum: 1,
                        vertical_alignment_enum: 2, r: ink[0], g: ink[1], b: ink[2] }
    outputs.labels << { x: right, y: y - 34, text: "[ T ]  ganzer Auftrag", size_enum: 0,
                        alignment_enum: 2, vertical_alignment_enum: 2,
                        r: MENU_DIM_INK[0], g: MENU_DIM_INK[1], b: MENU_DIM_INK[2] }
    y - 92
  end

  def render_kit_page
    top = body_top
    render_box(menu_left + MENU_PAD, body_bottom + 10,
               menu_width - MENU_PAD * 2, top - body_bottom - 10,
               "Was du trägst")

    x = menu_left + MENU_PAD + 24
    right = menu_right - MENU_PAD - 24
    y = top - 84
    kit_rows.each do |row|
      outputs.labels << { x: x, y: y, text: row[:name], size_enum: 0,
                          vertical_alignment_enum: 2,
                          r: MENU_DIM_INK[0], g: MENU_DIM_INK[1], b: MENU_DIM_INK[2] }
      outputs.labels << { x: x, y: y - 24, text: row[:title], size_enum: 3,
                          vertical_alignment_enum: 2,
                          r: MENU_INK[0], g: MENU_INK[1], b: MENU_INK[2] }
      outputs.labels << { x: right, y: y - 20, text: row[:value], size_enum: 2,
                          alignment_enum: 2, vertical_alignment_enum: 2,
                          r: CREDIT_INK[0], g: CREDIT_INK[1], b: CREDIT_INK[2] }
      if row[:top]
        outputs.labels << { x: right, y: y - 48, text: "das Beste, was Andi hat",
                            size_enum: 0, alignment_enum: 2, vertical_alignment_enum: 2,
                            r: MENU_DIM_INK[0], g: MENU_DIM_INK[1], b: MENU_DIM_INK[2] }
      end
      y -= KIT_ROW_H
    end
  end

  def render_tally(x, y, width, rows)
    rows.each do |label, value|
      outputs.labels << { x: x, y: y, text: label, size_enum: 1, vertical_alignment_enum: 2,
                          r: MENU_DIM_INK[0], g: MENU_DIM_INK[1], b: MENU_DIM_INK[2] }
      outputs.labels << { x: x + width, y: y, text: value, size_enum: 3, alignment_enum: 2,
                          vertical_alignment_enum: 2, r: MENU_INK[0], g: MENU_INK[1], b: MENU_INK[2] }
      y -= MENU_ROW_H
    end
  end

  BOOK_GAP = 56
  BOOK_ROW_H = 50
  BOOK_INSET = 18 # air between the box's edge and the roster inside it

  # The width of one of the book's two columns. Derived from the box, not written
  # down — it *was* written down, the box grew under it, and the right-hand
  # column's grade and fee printed ten pixels past the panel onto the bare
  # screen. Nothing in here should know the window's width twice.
  def book_inner_w
    menu_width - MENU_PAD * 2 - BOOK_INSET * 2
  end

  def book_col_w
    (book_inner_w - BOOK_GAP).idiv(2)
  end
  # Two columns of this many. Set by what actually fits between the headings and
  # the footer — the roster outgrew the screen and the last rows were printing
  # down through the hint line and over each other. Two more fit since the screen
  # grew to nearly the whole window.
  BOOK_ROWS = 7
  BOOK_PER_PAGE = BOOK_ROWS * 2

  # One row per species in the sea, in the order they live from the shallows
  # down: what you have, and — just as importantly — what you haven't. A plain
  # method, so the tally is testable without reading it back off the screen.
  # Only the species you've laid eyes on — the book fills in as you explore
  # rather than betraying the whole sea from the first dive.
  def artenbuch_rows
    Species::ALL.select { |species| species_known?(species.key) }.map do |species|
      quality = state.album[species.key]
      flock = (state.flocks || {})[species.key] || 0
      { species: species, quality: quality, flock: flock,
        fee: (quality ? photo_fee(species, quality) : 0) + flock_fee(species, flock) }
    end
  end

  # Known to the book: sighted in the water, or already documented (which implies
  # you saw it).
  def species_known?(key)
    (state.sighted && state.sighted[key]) || !state.album[key].nil?
  end

  # --- turning the pages ----------------------------------------------------

  def artenbuch_pages
    pages = (artenbuch_rows.length + BOOK_PER_PAGE - 1).idiv(BOOK_PER_PAGE)
    pages < 1 ? 1 : pages
  end

  # The slice on show. Clamped rather than trusted: the roster grows as you
  # explore, and a page number left over from a fuller book would show nothing.
  def artenbuch_page_rows
    page = (state.artenbuch_page || 0)
    page = artenbuch_pages - 1 if page >= artenbuch_pages
    page = 0 if page < 0
    state.artenbuch_page = page
    artenbuch_rows[page * BOOK_PER_PAGE, BOOK_PER_PAGE] || []
  end

  # Wraps, because a two-page book is quicker to flick round than to back out of.
  # A plain state change, so paging is testable without simulated keys.
  def turn_artenbuch_page(by)
    state.artenbuch_page = ((state.artenbuch_page || 0) + by) % artenbuch_pages
  end

  def update_artenbuch_paging
    return unless state.game_scene == "home_menu" && book_page?

    turn_artenbuch_page(-1) if inputs.keyboard.key_down.left
    turn_artenbuch_page(1) if inputs.keyboard.key_down.right
  end

  # One box across the width, the roster in two columns inside it. The balance
  # used to have the second heading here; it lives in the head band now, where it
  # belongs, and the book gets the whole width to itself.
  def render_artenbuch_page
    all = artenbuch_rows
    heading = "Artenbuch  #{album_found} / #{all.length} gesichtet"
    heading += "    ·    Seite #{state.artenbuch_page + 1} / #{artenbuch_pages}" if artenbuch_pages > 1
    render_box(menu_left + MENU_PAD, body_bottom + 10,
               menu_width - MENU_PAD * 2, body_top - body_bottom - 10, heading)
    render_artenbuch(menu_left + MENU_PAD + BOOK_INSET, body_top - 76)
  end

  def render_artenbuch(x, row_y)
    all = artenbuch_rows
    rows = artenbuch_page_rows
    cx = x + book_col_w + BOOK_GAP / 2 # centre of the two-column spread

    if all.empty?
      outputs.labels << { x: cx, y: row_y - 60, text: "Noch nichts gesichtet — tauch und sieh dich um.",
                          size_enum: 1, alignment_enum: 1, vertical_alignment_enum: 2,
                          r: MENU_DIM_INK[0], g: MENU_DIM_INK[1], b: MENU_DIM_INK[2] }
      return
    end

    # Down the left column first, then down the right — a page of a book, read
    # the way a page is read.
    rows.each_with_index do |row, i|
      col_x = x + (i < BOOK_ROWS ? 0 : book_col_w + BOOK_GAP)
      render_book_row(col_x, row_y - (i % BOOK_ROWS) * BOOK_ROW_H, row)
    end

    # A quiet reminder the sea still holds more, without a number that would
    # spoil it — on the last page, where "more" means more than the whole book.
    return unless all.length < Species::ALL.length && state.artenbuch_page == artenbuch_pages - 1

    outputs.labels << { x: cx, y: row_y - BOOK_ROWS * BOOK_ROW_H - 4,
                        text: "… und weitere Arten, noch ungesichtet", size_enum: 0,
                        alignment_enum: 1, vertical_alignment_enum: 2,
                        r: MENU_DIM_INK[0], g: MENU_DIM_INK[1], b: MENU_DIM_INK[2], a: 150 }
  end

  # A documented species stands in its own colours with the grade of the photo;
  # one still missing sits in the dark with its latin name, which is the whole
  # invitation to go and look for it.
  def render_book_row(x, y, row)
    species = row[:species]
    found = !row[:quality].nil?
    ink = found ? MENU_INK : MENU_DIM_INK

    outputs.sprites << { x: x + 26, y: y, w: species.frame_w, h: species.frame_h,
                         path: species.sheet, anchor_x: 0.5, anchor_y: 0.5,
                         source_x: 0, source_y: 0,
                         source_w: species.frame_w, source_h: species.frame_h,
                         a: found ? 255 : 70 }
    outputs.labels << { x: x + 60, y: y + 10, text: species.name, size_enum: 1,
                        vertical_alignment_enum: 1, r: ink[0], g: ink[1], b: ink[2] }
    # The school stands under the latin name rather than beside the grade: it is
    # a second photograph of the animal, not a footnote to the first, and a
    # species that shoals but has never been caught in one has an empty line
    # there that says so.
    subtitle = species.latin
    subtitle += "   ·   Schwarm bis #{row[:flock]}" if (row[:flock] || 0) > 1
    outputs.labels << { x: x + 60, y: y - 10, text: subtitle, size_enum: 0,
                        vertical_alignment_enum: 1,
                        r: MENU_DIM_INK[0], g: MENU_DIM_INK[1], b: MENU_DIM_INK[2], a: 150 }

    right = found ? "#{row[:quality]}   #{row[:fee]}" : "—"
    outputs.labels << { x: x + book_col_w, y: y, text: right, size_enum: 1,
                        alignment_enum: 2, vertical_alignment_enum: 1,
                        r: ink[0], g: ink[1], b: ink[2] }
  end

  # What you're carrying: one row per piece, INVENTORY_MAX slots deep, so the
  # empty rows show how much room is left.
  def render_pack_column(x, row_y, width)
    INVENTORY_MAX.times do |i|
      kind = state.inventory[i]
      y = row_y - i * MENU_ROW_H
      if kind
        render_exchange_row(x, y, width, kind, nil, selected?(PACK_SIDE, i), true)
      else
        empty_row(x, y, "— leer —")
      end
    end
  end

  # The hold: one row per kind with how many of it are down there. Rows go dim
  # while the pack is full — nothing can come up until something goes back.
  def render_hold_column(x, row_y, width)
    stacks = hold_stacks
    return empty_row(x, row_y, "Noch nichts eingelagert") if stacks.empty?

    stacks.each_with_index do |stack, i|
      render_exchange_row(x, row_y - i * MENU_ROW_H, width, stack[:kind], stack[:count],
                          selected?(HOLD_SIDE, i), !inventory_full?)
    end
  end

  def selected?(side, index)
    state.exchange_side == side && state.exchange_index == index
  end

  # A column title with a rule under it. The label hangs from its top edge
  # (vertical_alignment_enum: 2), so the rule has to clear the text's actual
  # height — a fixed offset ran the line straight through the letters.
  def column_heading(x, y, text, width, color = nil)
    color ||= MENU_DIM_INK
    outputs.labels << { x: x, y: y, text: text, size_enum: 1, vertical_alignment_enum: 2,
                        r: color[0], g: color[1], b: color[2] }
    outputs.sprites << { x: x, y: y - text_height(text, 1) - MENU_RULE_GAP, w: width, h: 1,
                         r: MENU_ACCENT[0], g: MENU_ACCENT[1], b: MENU_ACCENT[2], a: 60, path: :solid }
  end

  def text_height(text, size_enum)
    args.gtk.calcstringbox(text, size_enum)[1]
  end

  # One line of either list: the item's icon, its name, and — in the hold — how
  # many of them there are. The selected row gets a lit bar behind it.
  def render_exchange_row(x, y, width, kind, count, selected, live)
    if selected
      outputs.sprites << { x: x - 10, y: y - 23, w: width + 20, h: 46,
                           r: MENU_ACCENT[0], g: MENU_ACCENT[1], b: MENU_ACCENT[2],
                           a: live ? 55 : 30, path: :solid }
    end

    # The icon, big enough to be a picture rather than a bullet — this screen is
    # a shelf of things, and things are quicker to recognise than to read.
    sprite = ITEM_SPRITES[kind]
    outputs.sprites << { x: x + MENU_ICON_X, y: y, w: sprite[:w] * 3, h: sprite[:h] * 3,
                         path: sprite[:path], anchor_x: 0.5, anchor_y: 0.5,
                         a: live ? 255 : 120 }

    ink = live ? MENU_INK : MENU_DIM_INK
    outputs.labels << { x: x + 66, y: y + 10, text: ITEM_NAMES[kind], size_enum: 2,
                        vertical_alignment_enum: 1, r: ink[0], g: ink[1], b: ink[2] }
    # What it fetches, under the name — so you can see which of them is worth
    # carrying home before you decide what to drop.
    outputs.labels << { x: x + 66, y: y - 13, text: "#{ITEM_VALUES[kind]} Cr", size_enum: 0,
                        vertical_alignment_enum: 1,
                        r: CREDIT_INK[0], g: CREDIT_INK[1], b: CREDIT_INK[2],
                        a: live ? 190 : 110 }
    return unless count

    outputs.labels << { x: x + width, y: y, text: "#{count}x", size_enum: 3, alignment_enum: 2,
                        vertical_alignment_enum: 1, r: ink[0], g: ink[1], b: ink[2] }
  end

  def empty_row(x, y, text)
    outputs.labels << { x: x + 66, y: y, text: text, size_enum: 1, vertical_alignment_enum: 1,
                        r: MENU_DIM_INK[0], g: MENU_DIM_INK[1], b: MENU_DIM_INK[2], a: 130 }
  end
end
