/* -*- Mode: vala; tab-width: 4; indent-tabs-mode: nil; c-basic-offset: 4 -*-

   This file is part of GNOME Tetravex.

   Copyright (C) 2010-2013 Robert Ancell
   Copyright (C) 2019 Arnaud Bonatti

   GNOME Tetravex is free software: you can redistribute it and/or modify
   it under the terms of the GNU General Public License as published by
   the Free Software Foundation, either version 2 of the License, or
   (at your option) any later version.

   GNOME Tetravex is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
   GNU General Public License for more details.

   You should have received a copy of the GNU General Public License along
   with this GNOME Tetravex.  If not, see <https://www.gnu.org/licenses/>.
*/

public abstract class Theme {
    // FIXME it is of the responsibility of the themes to ensure the overdraw does NOT draw over an neighbor tile; else bad things happen
    public int overdraw_top { get; protected set; }
    public int overdraw_left { get; protected set; }
    public int overdraw_right { get; protected set; }
    public int overdraw_bottom { get; protected set; }

    public abstract void configure (uint size);
    public abstract void draw_arrow (Cairo.Context context);
    public abstract void draw_socket (Cairo.Context context);
    public abstract void draw_highlight (Cairo.Context context, bool has_tile);
    public abstract void draw_paused_tile (Cairo.Context context);
    public abstract void draw_tile (Cairo.Context context, Tile tile, bool highlight);
}

public class PuzzleView : Gtk.DrawingArea {
    private class TileImage {
        /* Tile being moved */
        public Tile tile;

        /* Location of tile */
        public double x;
        public double y;

        /* Coordinates to move from */
        public double source_x;
        public double source_y;

        /* Time started moving */
        public double source_time;

        /* Coordinates to target for */
        public double target_x;
        public double target_y;

        /* Duration of movement */
        public double duration;

        /* Whether the tile follows exactly cursor or nuns after it */
        public bool snap_to_cursor = true;

        public TileImage (Tile tile) {
            this.tile = tile;
        }
    }

    /* Animations duration */
    private const double ANIMATION_DURATION = 0.25;
    private const uint FINAL_ANIMATION_DURATION = 250;
    private const double HALF_ANIMATION_DURATION = 0.15;

    /* Puzzle being rendered */
    private Puzzle _puzzle;
    private bool puzzle_init_done;
    public Puzzle puzzle {
        private get { if (!puzzle_init_done) assert_not_reached (); return _puzzle; }
        set {
            uint8 old_puzzle_size = 0;
            if (puzzle_init_done) {
                old_puzzle_size = _puzzle.size;
                SignalHandler.disconnect_by_func (_puzzle, null, this);
            }

            _puzzle = value;
            puzzle_init_done = true;
            last_selected_tile = null;
            tiles.remove_all ();
            for (uint8 y = 0; y < _puzzle.size; y++) {
                for (uint8 x = 0; x < _puzzle.size * 2; x++) {
                    Tile? tile = _puzzle.get_tile (x, y);
                    if (tile == null)
                        continue;

                    TileImage image = new TileImage ((!) tile);
                    move_tile_to_location (image, x, y);
                    tiles.insert ((!) tile, image);
                }
            }
            if (old_puzzle_size != _puzzle.size) {
                arrow_pattern = null;
                socket_pattern = null;
                sockets_xs = new double [2 * _puzzle.size, _puzzle.size];
                sockets_ys = new double [2 * _puzzle.size, _puzzle.size];
            }

            set_highlight_position ();
            _puzzle.solved.connect (() => clear_keyboard_highlight (/* only selection */ true));
            _puzzle.tile_moved.connect (tile_moved_cb);
            _puzzle.paused_changed.connect (queue_draw);
            queue_resize ();
        }
    }

    /* Theme */
    private Theme theme;
    public string theme_id {
        set {
            switch (value) {
                default:
                case "extrusion": theme = new ExtrusionTheme (); break;
                case "neoretro": theme = new NeoRetroTheme (); break;
                case "nostalgia": theme = new NostalgiaTheme (); break;
                case "synesthesia": theme = new SynesthesiaTheme (); break;
            }

            if (tilesize != 0)
                theme.configure (tilesize);
            arrow_pattern = null;
            socket_pattern = null;
            queue_draw ();
        }
    }

    /* Tile being controlled by the mouse */
    private TileImage? selected_tile;
    private TileImage? last_selected_tile;
    public bool tile_selected { get; private set; }

    /* Timeout to detect if a click is a selection or a drag */
    private uint selection_timeout;

    /* The position inside the tile where the cursor is */
    private double selected_x_offset;
    private double selected_y_offset;

    /* Tile images */
    private HashTable<Tile, TileImage> tiles = new HashTable<Tile, TileImage> (direct_hash, direct_equal);

    /* Animation timer */
    private Timer animation_timer = new Timer ();
    private uint animation_timeout;

    /* Set in configure event */
    public uint boardsize { get; private set; }
    public double x_offset_right { get; private set; }
    public double y_offset { get; private set; }
    public double right_margin { get; private set; }

    private double x_offset;
    private uint tilesize;
    private uint gap;
    private double arrow_x;
    private double arrow_local_y;
    private double [,] sockets_xs;
    private double [,] sockets_ys;
    private int board_x_maxi;
    private int board_y_maxi;
    private double snap_distance;

    /* Pre-rendered image */
    private uint render_size;
    private Cairo.Pattern? arrow_pattern;
    private Cairo.Pattern? socket_pattern;

    construct {
        focusable = true;

        init_mouse ();
        init_keyboard ();
        set_draw_func (draw);
        resize.connect (on_resize);

        animation_timer.start ();
    }

    private void redraw_tile (TileImage image) {
        queue_draw ();
//        queue_draw_area ((int) image.x - theme.overdraw_left,
//                         (int) image.y - theme.overdraw_top,
//                         (int) tilesize + theme.overdraw_left + theme.overdraw_right,
//                         (int) tilesize + theme.overdraw_top + theme.overdraw_bottom);
    }

    private void queue_draw_tile (uint8 x, uint8 y) {
        queue_draw ();
//        queue_draw_area ((int) sockets_xs [x, y] - theme.overdraw_left,
//                         (int) sockets_ys [x, y] - theme.overdraw_top,
//                         (int) tilesize + theme.overdraw_left + theme.overdraw_right,
//                         (int) tilesize + theme.overdraw_top + theme.overdraw_bottom);
    }

    private void move_tile_to_location (TileImage image, uint x, uint y, double duration = 0) {
        double target_x = x_offset + (double) (x * tilesize);
        if (x >= puzzle.size)
            target_x += (double) gap;
        double target_y = y_offset + (double) (y * tilesize);
        move_tile (image, target_x, target_y, duration);
    }

    private void move_tile (TileImage image, double x, double y, double duration = 0) {
        if (image.x == x && image.y == y)
            return;

        image.source_x = image.x;
        image.source_y = image.y;
        image.source_time = animation_timer.elapsed ();
        image.target_x = x;
        image.target_y = y;
        image.duration = duration;

        /* Move immediately */
        if (duration == 0) {
            redraw_tile (image);
            image.x = image.target_x;
            image.y = image.target_y;
            image.snap_to_cursor = true;
            redraw_tile (image);
            return;
        }

        /* Start animation (maximum of 100fps) */
        if (animation_timeout == 0)
            animation_timeout = Timeout.add (10, animate_cb);
    }

    private bool animate_cb () {
        double t = animation_timer.elapsed ();

        bool animating = false;
        HashTableIter<Tile, TileImage> iter = HashTableIter<Tile, TileImage> (tiles);
        while (true) {
            Tile tile;
            TileImage image;
            if (!iter.next (out tile, out image))
                break;

            if (image.x == image.target_x
                    && image.y == image.target_y)
                continue;

            /* Redraw where the tile was */
            redraw_tile (image);

            /* Move the tile */
            if (t >= image.source_time + image.duration) {
                image.x = image.target_x;
                image.y = image.target_y;
            }
            else {
                double d = (t - image.source_time) / image.duration;
                image.x = image.source_x + (image.target_x - image.source_x) * d;
                image.y = image.source_y + (image.target_y - image.source_y) * d;
                animating = true;
            }

            if (!image.snap_to_cursor) {
                double distance = Math.sqrt (Math.pow (image.x - image.target_x, 2)
                                           + Math.pow (image.y - image.target_y, 2));
                if (distance < snap_distance)
                    image.snap_to_cursor = true;
            }

            /* Draw where the tile is */
            redraw_tile (image);
        }

        /* Keep animating if still have tiles */
        if (animating)
            return true;

        animation_timeout = 0;
        return false;
    }

    private void tile_moved_cb (Puzzle puzzle, Tile tile, uint8 x, uint8 y) {
        move_tile_to_location ((!) tiles.lookup (tile), x, y, ANIMATION_DURATION);
    }

    public const double GAP_FACTOR = 0.5;
    private inline void on_resize (int allocated_width, int allocated_height) {
        if (puzzle_init_done) {
            /* Fit in with a half tile border and spacing between boards */
            uint width = (uint) (allocated_width / (2 * puzzle.size + 1.0 + /* 1 × */ GAP_FACTOR));
            uint height = (uint) (allocated_height / (puzzle.size + 1.0));
            tilesize = uint.min (width, height);
            boardsize = (int) (tilesize * puzzle.size);
            gap = (uint) (tilesize * GAP_FACTOR);
            theme.configure (tilesize);
            x_offset = (double) (allocated_width - 2 * boardsize - gap) / 2.0;
            y_offset = (double) (allocated_height - boardsize) / 2.0;

            board_x_maxi = allocated_width - (int) tilesize;
            board_y_maxi = allocated_height - (int) tilesize;

            snap_distance = boardsize / 40.0;

            arrow_x = x_offset + boardsize;
            arrow_local_y = boardsize * 0.5;

            x_offset_right = arrow_x + gap;
            right_margin = allocated_width - x_offset_right - boardsize;

            /* Precalculate sockets positions */
            for (uint8 y = 0; y < puzzle.size; y++)
                for (uint8 x = 0; x < puzzle.size * 2; x++) {
                    if (x >= puzzle.size)
                        sockets_xs [x, y] = x_offset + x * tilesize + gap;
                    else
                        sockets_xs [x, y] = x_offset + x * tilesize;
                    sockets_ys [x, y] = y_offset + y * tilesize;
                }
        }

        /* Move everything to its correct location */
        HashTableIter<Tile, TileImage> iter = HashTableIter<Tile, TileImage> (tiles);
        while (true) {
            Tile tile;
            TileImage image;
            if (!iter.next (out tile, out image))
                break;
            uint8 x, y;
            puzzle.get_tile_location (tile, out x, out y);
            move_tile_to_location (image, x, y);
        }
        if (selected_tile != null)
            ((!) selected_tile).snap_to_cursor = true;
        selected_tile = null;
        tile_selected = false;
    }

    private inline void init_patterns (Cairo.Context context) {
        render_size = tilesize;

        Cairo.Surface tmp_surface;
        Cairo.Context tmp_context;

        /* arrow pattern */
        tmp_surface = new Cairo.Surface.similar (context.get_target (), Cairo.Content.COLOR_ALPHA, (int) gap,
                                                                                                   (int) boardsize);
        tmp_context = new Cairo.Context (tmp_surface);

        tmp_context.save ();
        tmp_context.translate (0.0, arrow_local_y);
        theme.draw_arrow (tmp_context);
        tmp_context.restore ();

        arrow_pattern = new Cairo.Pattern.for_surface (tmp_surface);

        /* socket pattern */
        tmp_surface = new Cairo.Surface.similar (context.get_target (), Cairo.Content.COLOR_ALPHA, (int) tilesize,
                                                                                                   (int) tilesize);
        tmp_context = new Cairo.Context (tmp_surface);

        theme.draw_socket (tmp_context);

        socket_pattern = new Cairo.Pattern.for_surface (tmp_surface);
    }

    private void draw (Gtk.DrawingArea _this, Cairo.Context context, int width, int height) {
        if (!puzzle_init_done)
            return;

        if (arrow_pattern == null || socket_pattern == null || render_size != tilesize)
            init_patterns (context);

        /* Draw arrow */
        context.save ();
        context.translate (arrow_x, y_offset);
        context.set_source ((!) arrow_pattern);
        context.rectangle (0.0, 0.0, /* width and height */ gap, boardsize);
        context.fill ();
        context.restore ();

        /* Draw sockets */
        for (uint8 y = 0; y < puzzle.size; y++)
            for (uint8 x = 0; x < puzzle.size * 2; x++) {
                context.save ();
                context.translate (sockets_xs [x, y], sockets_ys [x, y]);

                context.set_source ((!) socket_pattern);
                context.rectangle (0.0, 0.0, /* width and height */ tilesize, tilesize);
                context.fill ();

                context.restore ();
            }

        /* Draw tiles */
        SList<TileImage> moving_tiles = new SList<TileImage> ();
        HashTableIter<Tile, TileImage> iter = HashTableIter<Tile, TileImage> (tiles);
        while (true) {
            Tile tile;
            TileImage image;
            if (!iter.next (out tile, out image))
                break;

            if (selected_tile != null && image == (!) selected_tile)
                continue;
            if (selected_tile == null && last_selected_tile != null && image == (!) last_selected_tile)
                continue;

            if (image.x != image.target_x
                    || image.y != image.target_y) {
                moving_tiles.prepend (image);
                continue;
            }

            draw_image (context, image);
        }

        /* Draw moving tiles on top of static tiles; in the order they want */
        foreach (unowned TileImage image in moving_tiles)
            draw_image (context, image);

        /* Draw selected tile –if any– at the end, as it is always on top; else */
        if (selected_tile != null)
            draw_image (context, (!) selected_tile);

        /* draw last selected tile instead, fixing problem seen when interverting multiple times two contiguous tiles */
        else if (last_selected_tile != null)
            draw_image (context, (!) last_selected_tile);

        /* Draw highlight */
        if (show_highlight && !puzzle.is_solved) {
            context.save ();
            context.translate (sockets_xs [highlight_x, highlight_y], sockets_ys [highlight_x, highlight_y]);
            theme.draw_highlight (context, puzzle.get_tile (highlight_x, highlight_y) != null);
            context.restore ();
        }
    }
    private void draw_image (Cairo.Context context, TileImage image) {
        context.save ();
        context.translate ((int) image.x, (int) image.y);
        if (puzzle.paused)
            theme.draw_paused_tile (context);
        else {
            uint8 tile_x;
            uint8 tile_y;
            puzzle.get_tile_location (image.tile, out tile_x, out tile_y);
            bool highlight = show_highlight && tile_selection
                          && kbd_selected_x == tile_x
                          && kbd_selected_y == tile_y;
            theme.draw_tile (context, image.tile, highlight);
        }
        context.restore ();
    }

    private void pick_tile (double x, double y) {
        if (selected_tile != null)
            return;

        if (puzzle.is_solved)
            return;

        HashTableIter<Tile, TileImage> iter = HashTableIter<Tile, TileImage> (tiles);
        while (true) {
            Tile tile;
            TileImage image;
            if (!iter.next (out tile, out image))
                break;

            if (x >= image.x && x <= image.x + tilesize
             && y >= image.y && y <= image.y + tilesize) {
                selected_tile = image;
                last_selected_tile = image;
                tile_selected = true;
                selected_x_offset = x - image.x;
                selected_y_offset = y - image.y;

                if (selection_timeout != 0)
                    Source.remove (selection_timeout);
                selection_timeout = Timeout.add (200, selection_timeout_cb);
            }
        }

        if (!tile_selected) {
            uint8 tile_x;
            uint8 tile_y;
            if (get_tile_coords (x, y, out tile_x, out tile_y))
                puzzle.try_move (tile_x, tile_y);
        }
    }
    private inline bool get_tile_coords (double event_x, double event_y, out uint8 tile_x, out uint8 tile_y) {
        if (!get_tile_coord_x (event_x, out tile_x)) {
            tile_y = 0; // garbage
            return false;
        }
        if (!get_tile_coord_y (event_y, out tile_y))
            return false;
        return true;
    }
    private inline bool get_tile_coord_x (double event_x, out uint8 tile_x) {
        for (tile_x = 0; tile_x < 2 * puzzle.size; tile_x++)
            if (event_x > sockets_xs [tile_x, 0] && event_x < sockets_xs [tile_x, 0] + tilesize)
                return true;
        return false;
    }
    private inline bool get_tile_coord_y (double event_y, out uint8 tile_y) {
        for (tile_y = 0; tile_y < puzzle.size; tile_y++)
            if (event_y > sockets_ys [0, tile_y] && event_y < sockets_ys [0, tile_y] + tilesize)
                return true;
        return false;
    }

    private bool selection_timeout_cb () {
        selection_timeout = 0;
        return false;
    }

    private bool on_right_half (double x) {
        return x > x_offset_right - gap * 0.5;
    }

    private void drop_tile (double x, double y) {
        if (selected_tile == null)
            return;

        /* Select from the middle of the tile */
        x += tilesize * 0.5 - selected_x_offset;
        y += tilesize * 0.5 - selected_y_offset;

        int16 tile_y = (int16) Math.floor ((y - y_offset) / tilesize);
        tile_y = tile_y.clamp (0, (int16) puzzle.size - 1);

        /* Check which side we are on */
        int16 tile_x;
        if (on_right_half (x)) {
            tile_x = (int16) puzzle.size + (int16) Math.floor ((x - x_offset_right) / tilesize);
            tile_x = tile_x.clamp ((int16) puzzle.size, 2 * (int16) puzzle.size - 1);
        }
        else {
            tile_x = (int16) Math.floor ((x - x_offset) / tilesize);
            tile_x = tile_x.clamp (0, (int16) puzzle.size - 1);
        }

        /* Drop the tile here, or move it back if can't */
        uint8 selected_x, selected_y;
        puzzle.get_tile_location (((!) selected_tile).tile, out selected_x, out selected_y);
        if (puzzle.can_switch (selected_x, selected_y, (uint8) tile_x, (uint8) tile_y))
            puzzle.switch_tiles (selected_x, selected_y, (uint8) tile_x, (uint8) tile_y);
        else
            move_tile_to_location ((!) selected_tile, selected_x, selected_y, ANIMATION_DURATION);
        ((!) selected_tile).snap_to_cursor = true;
        selected_tile = null;
        tile_selected = false;
    }

    private void move_tile_to_right_half (Tile tile) {
        /* Pick the first open spot on the right side of the board */
        for (uint8 y = 0; y < puzzle.size; y++) {
            for (uint8 x = puzzle.size; x < puzzle.size * 2; x++) {
                if (puzzle.get_tile (x, y) == null) {
                    uint8 source_x, source_y;
                    puzzle.get_tile_location (tile, out source_x, out source_y);
                    puzzle.switch_tiles (source_x, source_y, x, y);
                    return;
                }
            }
        }
        assert_not_reached ();
    }

    /*\
    * * mouse user actions
    \*/

    private void init_mouse () {
        var motion_controller = new Gtk.EventControllerMotion ();
        motion_controller.motion.connect (on_motion);
        motion_controller.enter.connect (on_mouse_in);
        motion_controller.leave.connect (on_mouse_out);
        add_controller (motion_controller);

        var click_controller = new Gtk.GestureClick ();
        click_controller.set_button (/* all buttons */ 0);
        click_controller.pressed.connect (on_click);
        click_controller.released.connect (on_release);
        add_controller (click_controller);
    }

    private const int MOUSE_BACK_BUTTON = 8;
    private const int MOUSE_FORWARD_BUTTON = 9;

    private inline void on_click (Gtk.GestureClick _controller, int n_press, double event_x, double event_y) {
        if (puzzle.is_solved || !puzzle.attempt_move () || puzzle.paused)
            return;
        clear_keyboard_highlight (/* only selection */ false);

        uint button = _controller.get_current_button ();
        if (button == Gdk.BUTTON_PRIMARY || button == Gdk.BUTTON_SECONDARY) {
            main_button_pressed (n_press, event_x, event_y);
            return;
        }

        if (button == MOUSE_BACK_BUTTON)
            undo ();
        else if (button == MOUSE_FORWARD_BUTTON)
            redo ();
    }

    private inline void main_button_pressed (int n_press, double event_x, double event_y) {
        if (puzzle.is_solved)   // security
            return;

        if (n_press == 1) {
            if (selected_tile == null)
                pick_tile (event_x, event_y);
            else
                drop_tile (event_x, event_y);
        }
        else {
            bool had_selected_tile = selected_tile != null;

            /* Move tile from left to right on double click */
            pick_tile (event_x, event_y);
            if (selected_tile == null)
                return;

            if (on_right_half (((!) selected_tile).x)) {
                uint8 x;
                uint8 y;
                if (puzzle.only_one_remaining_tile (out x, out y)) {
                    uint8 selected_x, selected_y;
                    puzzle.get_tile_location (((!) selected_tile).tile, out selected_x, out selected_y);
                    if (puzzle.can_switch (selected_x, selected_y, x, y))
                        puzzle.switch_tiles (selected_x, selected_y, x, y, FINAL_ANIMATION_DURATION);
                    else {   /* consider double click as a single click */
                        if (had_selected_tile)
                            drop_tile (event_x, event_y);
                        return;
                    }
                }
                else {       /* consider double click as a single click */
                    if (had_selected_tile)
                        drop_tile (event_x, event_y);
                    return;
                }
            }
            else if (!had_selected_tile)
                move_tile_to_right_half (((!) selected_tile).tile);
            ((!) selected_tile).snap_to_cursor = true;
            selected_tile = null;
            tile_selected = false;
        }
    }

    private inline void on_release (Gtk.GestureClick _controller, int n_press, double event_x, double event_y) {
        if (puzzle.paused || puzzle.is_solved)
            return;
        clear_keyboard_highlight (/* only selection */ false);

        uint button = _controller.get_current_button ();
        if ((button == Gdk.BUTTON_PRIMARY || button == Gdk.BUTTON_SECONDARY)
         && selected_tile != null && selection_timeout == 0)
            drop_tile (event_x, event_y);

        if (selection_timeout != 0)
            Source.remove (selection_timeout);
        selection_timeout = 0;
    }

    private inline void on_motion (Gtk.EventControllerMotion _controller, double event_x, double event_y) {
        if (selected_tile != null) {
            int new_x = ((int) (event_x - selected_x_offset)).clamp (0, board_x_maxi);
            int new_y = ((int) (event_y - selected_y_offset)).clamp (0, board_y_maxi);

            double duration;
            if (((!) selected_tile).snap_to_cursor)
                duration = 0.0;
            else
                duration = ((!) selected_tile).duration;

            move_tile ((!) selected_tile, new_x, new_y, duration);
        }
    }

    private inline void on_mouse_out () {
        if (selected_tile != null)
            ((!) selected_tile).snap_to_cursor = false;
    }

    private inline void on_mouse_in () {
        if (selected_tile != null) {
            ((!) selected_tile).snap_to_cursor = false;
            ((!) selected_tile).duration = HALF_ANIMATION_DURATION;
        }
    }

    public void finish () {
        puzzle.finish (FINAL_ANIMATION_DURATION);
    }

    public void release_selected_tile () {
        if (selected_tile == null)
            return;

        uint8 selected_x, selected_y;
        puzzle.get_tile_location (((!) selected_tile).tile, out selected_x, out selected_y);
        move_tile_to_location ((!) selected_tile, selected_x, selected_y, ANIMATION_DURATION);
        ((!) selected_tile).snap_to_cursor = true;
        selected_tile = null;
        tile_selected = false;
    }

    /*\
    * * history proxies
    \*/

    public void undo () {
        last_selected_tile = null;
        puzzle.undo ();
    }

    public void redo () {
        last_selected_tile = null;
        puzzle.redo ();
    }

    public void reload () {
        last_selected_tile = null;
        puzzle.reload ();
    }

    /*\
    * * keyboard user actions
    \*/

    private bool show_highlight;

    private bool highlight_set;
    private uint8 highlight_x = uint8.MAX;
    private uint8 highlight_y = uint8.MAX;
    private uint8 old_highlight_x = uint8.MAX;
    private uint8 old_highlight_y = uint8.MAX;

    private bool tile_selection;
    private uint8 kbd_selected_x = uint8.MAX;
    private uint8 kbd_selected_y = uint8.MAX;

    private void init_keyboard ()  // called on construct
    {
        var key_controller = new Gtk.EventControllerKey ();
        key_controller.key_pressed.connect (on_key_pressed);
        add_controller (key_controller);
    }

    private inline bool on_key_pressed (Gtk.EventControllerKey _controller, uint keyval, uint keycode,
                                        Gdk.ModifierType state) {
        if (!puzzle_init_done)
            return false;

        if (puzzle.is_solved || puzzle.paused)
            return false;

        if (tile_selected)
            return false;

        string key = (!) (Gdk.keyval_name (keyval) ?? "");
        if (key == "")
            return false;

        if (highlight_set && show_highlight && (key == "space" || key == "Return" || key == "KP_Enter")) {
            if (tile_selection) {
                if (highlight_x == kbd_selected_x && highlight_y == kbd_selected_y) {
                    clear_keyboard_highlight (/* only selection */ true);
                    return true;
                }
                if (puzzle.can_switch (highlight_x, highlight_y, kbd_selected_x, kbd_selected_y)) {
                    puzzle.switch_tiles (highlight_x, highlight_y, kbd_selected_x, kbd_selected_y);
                    clear_keyboard_highlight (/* only selection */ true);
                    return true;
                }
                if (puzzle.get_tile (highlight_x, highlight_y) != null) {
                    tile_selection = false;
                    queue_draw_tile (kbd_selected_x, kbd_selected_y);
                    kbd_selected_x = highlight_x;
                    kbd_selected_y = highlight_y;
                    tile_selection = true;
                    queue_draw_tile (highlight_x, highlight_y);
                    return true;
                }
            }
            else {
                Tile? tile = puzzle.get_tile (highlight_x, highlight_y);
                if (tile == null) {
                    puzzle.try_move (highlight_x, highlight_y);
                    return true;
                }

                if (highlight_x >= puzzle.size) {
                    uint8 x;
                    uint8 y;
                    if (puzzle.only_one_remaining_tile (out x, out y)) {
                        uint8 selected_x, selected_y;
                        puzzle.get_tile_location ((!) tile, out selected_x, out selected_y);
                        if (puzzle.can_switch (selected_x, selected_y, x, y)) {
                            puzzle.switch_tiles (selected_x, selected_y, x, y, FINAL_ANIMATION_DURATION);
                            return true;
                        }
                    }
                }
                tile_selection = true;
                kbd_selected_x = highlight_x;
                kbd_selected_y = highlight_y;
                queue_draw_tile (highlight_x, highlight_y);
            }
            return true;
        }

        if ((puzzle.size <= 2 && (key == "c" || key == "C" || key == "3" || key == "KP_3")) ||
            (puzzle.size <= 3 && (key == "d" || key == "D" || key == "4" || key == "KP_4")) ||
            (puzzle.size <= 4 && (key == "e" || key == "E" || key == "5" || key == "KP_5")) ||
            (puzzle.size <= 5 && (key == "f" || key == "F" || key == "6" || key == "KP_6")) ||
            (puzzle.size <= 6 && (key == "g" || key == "G" || key == "7" || key == "KP_7")) ||
            (puzzle.size <= 7 && (key == "h" || key == "H" || key == "8" || key == "KP_8")) ||
            (puzzle.size <= 8 && (key == "i" || key == "I" || key == "9" || key == "KP_9")) ||
            (puzzle.size <= 9 && (key == "j" || key == "J" || key == "0" || key == "KP_0")))
            return false;

        old_highlight_x = highlight_x;
        old_highlight_y = highlight_y;
        switch (key) {
            case "Up":
            case "KP_Up":
                set_highlight_position_if_needed ();
                if (highlight_y > 0) highlight_y--;
                break;
            case "Left":
            case "KP_Left":
                set_highlight_position_if_needed ();
                if (highlight_x > 0) highlight_x--;
                break;
            case "Right":
            case "KP_Right":
                set_highlight_position_if_needed ();
                if (highlight_x < puzzle.size * 2 - 1) highlight_x++;
                break;
            case "Down":
            case "KP_Down":
                set_highlight_position_if_needed ();
                if (highlight_y < puzzle.size - 1) highlight_y++;
                break;

            case "space":
            case "Return":
            case "KP_Enter":
                set_highlight_position_if_needed ();
                break;

            case "Escape": break;

            case "a": set_highlight_position_if_needed (); highlight_x = 0; break;
            case "b": set_highlight_position_if_needed (); highlight_x = 1; break;
            case "c": set_highlight_position_if_needed (); highlight_x = 2; break;
            case "d": set_highlight_position_if_needed (); highlight_x = 3; break;
            case "e": set_highlight_position_if_needed (); highlight_x = 4; break;
            case "f": set_highlight_position_if_needed (); highlight_x = 5; break;

            case "A": set_highlight_position_if_needed (); highlight_x = puzzle.size; break;
            case "B": set_highlight_position_if_needed (); highlight_x = puzzle.size + 1; break;
            case "C": set_highlight_position_if_needed (); highlight_x = puzzle.size + 2; break;
            case "D": set_highlight_position_if_needed (); highlight_x = puzzle.size + 3; break;
            case "E": set_highlight_position_if_needed (); highlight_x = puzzle.size + 4; break;
            case "F": set_highlight_position_if_needed (); highlight_x = puzzle.size + 5; break;

            case "1": case "KP_1": set_highlight_position_if_needed (); highlight_y = 0; break;
            case "2": case "KP_2": set_highlight_position_if_needed (); highlight_y = 1; break;
            case "3": case "KP_3": set_highlight_position_if_needed (); highlight_y = 2; break;
            case "4": case "KP_4": set_highlight_position_if_needed (); highlight_y = 3; break;
            case "5": case "KP_5": set_highlight_position_if_needed (); highlight_y = 4; break;
            case "6": case "KP_6": set_highlight_position_if_needed (); highlight_y = 5; break;

            case "Home":
            case "KP_Home":
                set_highlight_position_if_needed ();
                highlight_x = 0;
                break;
            case "End":
            case "KP_End":
                set_highlight_position_if_needed ();
                highlight_x = puzzle.size * 2 - 1;
                break;
            case "Page_Up":
            case "KP_Page_Up":
                set_highlight_position_if_needed ();
                highlight_y = 0;
                break;
            case "Page_Down":
            case "KP_Next":     // TODO use KP_Page_Down instead of KP_Next, probably a gtk+ or vala bug; check also KP_Prior
                set_highlight_position_if_needed ();
                highlight_y = puzzle.size - 1;
                break;

            // allow <Tab> and <Shift><Tab> to change focus
            default:
                return false;
        }

        highlight_set = true;

        if (key == "Escape") {
            if (tile_selection)
                clear_keyboard_highlight (/* only selection */ true);
            else
                clear_keyboard_highlight (/* only selection */ false);
        }
        else
            show_highlight = true;

        queue_draw_tile (old_highlight_x, old_highlight_y);
        if ((old_highlight_x != highlight_x)
                || (old_highlight_y != highlight_y))
            queue_draw_tile (highlight_x, highlight_y);
        return true;
    }

    private void set_highlight_position_if_needed () {
        if (highlight_set)
            /* If keyboard highlight is already set (and visible), this is good. */
            return;
        set_highlight_position ();
    }
    private void set_highlight_position () {
        // TODO better
        highlight_x = puzzle.size;
        highlight_y = 0;
    }

    private void clear_keyboard_highlight (bool only_selection) {
        if (!only_selection) {
            show_highlight = false;
            queue_draw_tile (highlight_x, highlight_y);
            highlight_set = false;
            highlight_x = uint8.MAX;
            highlight_y = uint8.MAX;
            old_highlight_x = uint8.MAX;
            old_highlight_y = uint8.MAX;
        }
        if (tile_selection) {
            tile_selection = false;
            queue_draw_tile (kbd_selected_x, kbd_selected_y);
            kbd_selected_x = uint8.MAX;
            kbd_selected_y = uint8.MAX;
        }
    }

    /*\
    * * moving all tiles
    \*/

    public void move_up (bool left_board) {
        if (selected_tile == null)
            puzzle.move_up (left_board);
    }

    public void move_down (bool left_board) {
        if (selected_tile == null)
            puzzle.move_down (left_board);
    }

    public void move_left (bool left_board) {
        if (selected_tile == null)
            puzzle.move_left (left_board);
    }

    public void move_right (bool left_board) {
        if (selected_tile == null)
            puzzle.move_right (left_board);
    }
}
