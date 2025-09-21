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

public class Tile {
    /* Edge colors */
    public uint8 north;
    public uint8 west;
    public uint8 east;
    public uint8 south;

    /* Solution location */
    public uint8 x { get; private set; }
    public uint8 y { get; private set; }

    public Tile (uint8 x, uint8 y) {
        this.x = x;
        this.y = y;
    }
}

public class Puzzle {
    public uint8 size { get; private set; }
    public uint8 colors { get; private set; }
    private Tile? [,] board;

    /* Game timer */
    private Timer? clock;
    private uint clock_timeout;
    private double initial_time;

    public double elapsed {
        get {
            if (clock == null)
                return 0.0;
            return initial_time + ((!) clock).elapsed ();
        }
    }

    private bool _paused;
    public bool paused {
        set {
            _paused = value;
            if (clock != null) {
                if (value)
                    stop_clock ();
                else
                    continue_clock ();
            }
            paused_changed ();
        }
        get { return _paused; }
    }

    public signal bool attempt_move ();
    public signal void tile_moved (Tile tile, uint8 x, uint8 y);
    public signal void can_undo_redo_changed ();
    public signal void paused_changed ();
    public signal void solved ();
    public signal void solved_right (bool is_solved);
    public signal void show_end_game ();
    public signal void tick ();

    public bool is_solved { get; private set; }
    private bool check_if_solved () {
        /* Solved if entire left hand side is complete (we ensure only tiles
           that fit are allowed */
        for (uint8 x = 0; x < size; x++) {
            for (uint8 y = 0; y < size; y++) {
                Tile? tile = board [x, y];
                if (tile == null)
                    return false;
            }
        }

        is_solved = true;
        return true;
    }

    private bool restored;
    public Puzzle (uint8 size, uint8 colors) {
        this.size = size;
        this.colors = colors;

        if (!restored) {
            do { init_board (size, (int32) colors, out board); }
            while (solved_on_right ());
        }
    }
    private static inline void init_board (uint8 size, int32 colors, out Tile? [,] board) {
        board = new Tile? [size * 2, size];
        for (uint8 x = 0; x < size; x++)
            for (uint8 y = 0; y < size; y++)
                board [x, y] = new Tile (x, y);

        /* Pick random colours for edges */
        for (uint8 x = 0; x < size; x++) {
            for (uint8 y = 0; y <= size; y++) {
                uint8 n = (uint8) Random.int_range (0, colors);
                if (y >= 1)
                    ((!) board [x, y - 1]).south = n;
                if (y < size)
                    ((!) board [x, y]).north = n;
            }
        }
        for (uint8 x = 0; x <= size; x++) {
            for (uint8 y = 0; y < size; y++) {
                uint8 n = (uint8) Random.int_range (0, colors);
                if (x >= 1)
                    ((!) board [x - 1, y]).east = n;
                if (x < size)
                    ((!) board [x, y]).west = n;
            }
        }

        /* Pick up the tiles... */
        List<Tile> tiles = new List<Tile> ();
        for (uint8 x = 0; x < size; x++) {
            for (uint8 y = 0; y < size; y++) {
                tiles.append ((!) board [x, y]);
                board [x, y] = null;
            }
        }

        /* ...and place then randomly on the right hand side */
        int32 length = (int32) tiles.length ();
        for (uint8 x = 0; x < size; x++) {
            for (uint8 y = 0; y < size; y++) {
                int32 n = Random.int_range (0, length);
                Tile tile = tiles.nth_data ((uint) n);
                board [x + size, y] = tile;
                tiles.remove (tile);
                length--;
            }
        }
    }
    private bool solved_on_right () {
        for (uint8 x = size; x < 2 * size; x++) {
            for (uint8 y = 0; y < size; y++) {
                Tile? tile = board [x, y];
                if (tile == null)
                    return false;

                if (x > 0 && board [x - 1, y] != null && ((!) board [x - 1, y]).east != ((!) tile).west)
                    return false;
                if (x < size - 1 && board [x + 1, y] != null && ((!) board [x + 1, y]).west != ((!) tile).east)
                    return false;
                if (y > 0 && board [x, y - 1] != null && ((!) board [x, y - 1]).south != ((!) tile).north)
                    return false;
                if (y < size - 1 && board [x, y + 1] != null && ((!) board [x, y + 1]).north != ((!) tile).south)
                    return false;
            }
        }
        return true;
    }

    public Tile? get_tile (uint8 x, uint8 y) {
        return board [x, y];
    }

    public void get_tile_location (Tile tile, out uint8 x, out uint8 y) {
        y = 0;  // garbage
        for (x = 0; x < size * 2; x++)
            for (y = 0; y < size; y++)
                if (board [x, y] == tile)
                    return;
    }

    private bool tile_fits (uint8 x0, uint8 y0, uint8 x1, uint8 y1) {
        Tile? tile = board [x0, y0];
        if (tile == null)
            return false;

        if (x1 > 0 && !(x1 - 1 == x0 && y1 == y0) && board [x1 - 1, y1] != null
                && ((!) board [x1 - 1, y1]).east != ((!) tile).west)
            return false;
        if (x1 < size - 1 && !(x1 + 1 == x0 && y1 == y0) && board [x1 + 1, y1] != null
                && ((!) board [x1 + 1, y1]).west != ((!) tile).east)
            return false;
        if (y1 > 0 && !(x1 == x0 && y1 - 1 == y0) && board [x1, y1 - 1] != null
                && ((!) board [x1, y1 - 1]).south != ((!) tile).north)
            return false;
        if (y1 < size - 1 && !(x1 == x0 && y1 + 1 == y0) && board [x1, y1 + 1] != null
                && ((!) board [x1, y1 + 1]).north != ((!) tile).south)
            return false;

        return true;
    }

    public bool can_switch (uint8 x0, uint8 y0, uint8 x1, uint8 y1) {
        if (x0 == x1 && y0 == y1)
            return false;

        Tile? t0 = board [x0, y0];
        Tile? t1 = board [x1, y1];

        /* No tiles to switch */
        if (t0 == null && t1 == null)
            return false;

        /* if placing onto the final area, check if it fits regarding current tiles */
        if (t0 != null && x1 < size && !tile_fits (x0, y0, x1, y1))
            return false;
        if (t1 != null && x0 < size && !tile_fits (x1, y1, x0, y0))
            return false;

        /* if inverting two tiles of the final area, check that they are compatible */
        if (t0 != null && t1 != null && x0 < size && x1 < size) {
            if (x0 == x1) {
                if (y0 == y1 + 1 && ((!) t0).south != ((!) t1).north)
                    return false;
                if (y0 == y1 - 1 && ((!) t0).north != ((!) t1).south)
                    return false;
            }
            else if (y0 == y1) {
                if (x0 == x1 + 1 && ((!) t0).east != ((!) t1).west)
                    return false;
                if (x0 == x1 - 1 && ((!) t0).west != ((!) t1).west)
                    return false;
            }
        }

        return true;
    }

    private uint timeout_id;
    public bool game_in_progress { get; private set; }
    public bool is_solved_right { get; private set; }
    public void switch_tiles (uint8 x0, uint8 y0, uint8 x1, uint8 y1, uint delay_if_finished = 0) {
        _switch_tiles (x0, y0, x1, y1, delay_if_finished, /* undoing */ false, /* move id: one tile only */ 0);
    }
    private void _switch_tiles (uint8 x0, uint8 y0, uint8 x1, uint8 y1, uint delay_if_finished,
                                bool undoing_or_redoing, uint move_id) {
        if (x0 == x1 && y0 == y1)
            return;
        game_in_progress = true;

        Tile? t0 = board [x0, y0];
        Tile? t1 = board [x1, y1];
        if (t0 == null && t1 == null)   // might happen when move_up and friends are called
            return;

        board [x0, y0] = t1;
        board [x1, y1] = t0;

        if (t0 != null)
            tile_moved ((!) t0, x1, y1);
        if (t1 != null)
            tile_moved ((!) t1, x0, y0);

        if (!undoing_or_redoing)
            add_to_history (x0, y0, x1, y1, move_id);

        if (check_if_solved ()) {
            stop_clock ();
            solved ();
            if (delay_if_finished == 0)
                show_end_game ();
            else if (timeout_id == 0)
                timeout_id = Timeout.add (delay_if_finished, () => {
                        show_end_game ();
                        timeout_id = 0;
                        return Source.REMOVE;
                    });
        }
        else if (solved_on_right ()) {
            is_solved_right = true;
            solved_right (is_solved_right);
        }
        else if (is_solved_right) {
            is_solved_right = false;
            solved_right (is_solved_right);
        }
    }

    /*\
    * * moving tiles
    \*/

    private uint last_move_id;

    private inline void switch_one_of_many_tiles (uint8 x0, uint8 y0, uint8 x1, uint8 y1) {
        _switch_tiles (x0, y0, x1, y1, /* delay if finished */ 0, /* undoing or redoing */ false, last_move_id);
    }

    public bool move_up (bool left_board) {
        if (!can_move_up (left_board) || last_move_id == uint.MAX)
            return false;
        last_move_id++;

        uint8 base_x = left_board ? 0 : size;
        for (uint8 y = 1; y < size; y++)
            for (uint8 x = 0; x < size; x++)
                switch_one_of_many_tiles (base_x + x, y, base_x + x, y - 1);
        return true;
    }
    private bool can_move_up (bool left_board) {
        uint8 base_x = left_board ? 0 : size;
        for (uint8 x = 0; x < size; x++)
            if (board [base_x + x, 0] != null)
                return false;

        for (uint8 x = 0; x < size; x++)
            for (uint8 y = 1; y < size; y++)
                if (board [base_x + x, y] != null)
                    return true;

        return false;
    }

    public bool move_down (bool left_board) {
        if (!can_move_down (left_board) || last_move_id == uint.MAX)
            return false;
        last_move_id++;

        uint8 base_x = left_board ? 0 : size;
        for (uint8 y = size - 1; y > 0; y--)
            for (uint8 x = 0; x < size; x++)
                switch_one_of_many_tiles (base_x + x, y - 1, base_x + x, y);
        return true;
    }
    private bool can_move_down (bool left_board) {
        uint8 base_x = left_board ? 0 : size;
        for (uint8 x = 0; x < size; x++)
            if (board [base_x + x, size - 1] != null)
                return false;

        for (uint8 x = 0; x < size; x++)
            for (uint8 y = 0; y < size - 1; y++)
                if (board [base_x + x, y] != null)
                    return true;

        return false;
    }

    public bool move_left (bool left_board) {
        if (!can_move_left (left_board) || last_move_id == uint.MAX)
            return false;
        last_move_id++;

        uint8 base_x = left_board ? 0 : size;
        for (uint8 x = 1; x < size; x++)
            for (uint8 y = 0; y < size; y++)
                switch_one_of_many_tiles (base_x + x, y, base_x + x - 1, y);
        return true;
    }
    private bool can_move_left (bool left_board) {
        uint8 left_column = left_board ? 0 : size;
        for (uint8 y = 0; y < size; y++)
            if (board [left_column, y] != null)
                return false;

        for (uint8 x = 1; x < size; x++)
            for (uint8 y = 0; y < size; y++)
                if (board [left_column + x, y] != null)
                    return true;

        return false;
    }

    public bool move_right (bool left_board) {
        if (!can_move_right (left_board) || last_move_id == uint.MAX)
            return false;
        last_move_id++;

        uint8 base_x = left_board ? 0 : size;
        for (uint8 x = size - 1; x > 0; x--)
            for (uint8 y = 0; y < size; y++)
                switch_one_of_many_tiles (base_x + x - 1, y, base_x + x, y);
        return true;
    }
    private bool can_move_right (bool left_board) {
        uint8 left_column = left_board ? 0 : size;
        uint8 right_column = left_column + size - 1;
        for (uint8 y = 0; y < size; y++)
            if (board [right_column, y] != null)
                return false;

        for (uint8 x = 0; x < size - 1; x++)
            for (uint8 y = 0; y < size; y++)
                if (board [left_column + x, y] != null)
                    return true;

        return false;
    }

    public void try_move (uint8 x, uint8 y)
        requires (x < 2 * size)
        requires (y < size) {

        bool left_board = x < size;
        switch (can_move (x, y)) {
            case Direction.UP: move_up (left_board); return;
            case Direction.DOWN: move_down (left_board); return;
            case Direction.LEFT: move_left (left_board); return;
            case Direction.RIGHT: move_right (left_board); return;
            case Direction.NONE:
            default: return;
        }
    }

    private inline Direction can_move (uint8 x, uint8 y) {
        bool left_board = x < size;
        if (half_board_is_empty (left_board))
            return Direction.NONE;

        uint8 left_column = left_board ? 0 : size;
        uint8 right_column = left_board ? size - 1 : size * 2 - 1;

        if (y == 0 && can_move_up (left_board)
         && !(x == left_column && can_move_left (left_board))
         && !(x == right_column && can_move_right (left_board)))
            return Direction.UP;
        if (y == size - 1 && can_move_down (left_board)
         && !(x == left_column && can_move_left (left_board))
         && !(x == right_column && can_move_right (left_board)))
            return Direction.DOWN;
        if (x == left_column && can_move_left (left_board)
         && !(y == 0 && can_move_up (left_board))
         && !(y == size - 1 && can_move_down (left_board)))
            return Direction.LEFT;
        if (x == right_column && can_move_right (left_board)
         && !(y == 0 && can_move_up (left_board))
         && !(y == size - 1 && can_move_down (left_board)))
            return Direction.RIGHT;
        return Direction.NONE;
    }
    private inline bool half_board_is_empty (bool left_board) {
        uint8 base_x = left_board ? 0 : size;
        for (uint8 x = 0; x < size; x++)
            for (uint8 y = 0; y < size; y++)
                if (board [base_x + x, y] != null)
                    return false;
        return true;
    }

    /*\
    * * actions
    \*/

    public void start () {
        paused = false;
        start_clock ();
    }

    public void solve () {
        List<Tile> wrong_tiles = new List<Tile> ();
        for (uint8 x = 0; x < size * 2; x++) {
            for (uint8 y = 0; y < size; y++) {
                Tile? tile = board [x, y];
                if (tile != null && (((!) tile).x != x || ((!) tile).y != y))
                    wrong_tiles.append ((!) tile);
                board [x, y] = null;
            }
        }

        foreach (Tile tile in wrong_tiles) {
            board [tile.x, tile.y] = tile;
            tile_moved (tile, tile.x, tile.y);
        }

        is_solved = true;
        solved ();
        stop_clock ();
    }

    public void finish (uint duration) {
        for (uint8 x = 0; x < size; x++)
            for (uint8 y = 0; y < size; y++)
                switch_tiles (x + size, y, x, y, duration);
    }

    public bool only_one_remaining_tile (out uint8 empty_x, out uint8 empty_y) {
        bool empty_found = false;
        empty_x = uint8.MAX;    // garbage
        empty_y = uint8.MAX;    // garbage
        for (uint8 x = 0; x < size; x++)
            for (uint8 y = 0; y < size; y++)
                if (get_tile (x, y) == null) {
                    if (empty_found)
                        return false;
                    empty_found = true;
                    empty_x = x;
                    empty_y = y;
                }

        if (!empty_found)
            return false;
        return true;
    }

    /*\
    * * clock
    \*/

    private void start_clock () {
        if (clock == null)
            clock = new Timer ();
        timeout_cb ();
    }

    private void stop_clock () {
        if (clock == null)
            return;
        if (clock_timeout != 0)
            Source.remove (clock_timeout);
        clock_timeout = 0;
        ((!) clock).stop ();
        tick ();
    }

    private void continue_clock () {
        if (clock == null)
            clock = new Timer ();
        else
            ((!) clock).@continue ();
        timeout_cb ();
    }

    private bool timeout_cb () {
        /* Notify on the next tick */
        double elapsed = ((!) clock).elapsed ();
        int next = (int) (elapsed + 1.0);
        double wait = (double) next - elapsed;
        clock_timeout = Timeout.add ((int) (wait * 1000), timeout_cb);

        tick ();

        return false;
    }

    /*\
    * * history
    \*/

    public bool can_undo { get; private set; }
    public bool can_redo { get; private set; }
    private uint history_length;
    private uint last_move_index;

    private List<Inversion> reversed_history = new List<Inversion> ();

    private class Inversion {
        public uint8 x0 { get; private set; }
        public uint8 y0 { get; private set; }
        public uint8 x1 { get; private set; }
        public uint8 y1 { get; private set; }
        public uint id { get; private set; }

        public Inversion (uint8 x0, uint8 y0, uint8 x1, uint8 y1, uint id) {
            this.x0 = x0;
            this.y0 = y0;
            this.x1 = x1;
            this.y1 = y1;
            this.id = id;
        }
    }

    private inline void add_to_history (uint8 x0, uint8 y0, uint8 x1, uint8 y1, uint id) {
        while (last_move_index > 0) {
            unowned Inversion? inversion = reversed_history.nth_data (0);
            if (inversion == null)
                assert_not_reached ();
            reversed_history.remove ((!) inversion);

            last_move_index--;
            history_length--;
        }

        Inversion history_entry = new Inversion (x0, y0, x1, y1, id);
        reversed_history.prepend (history_entry);

        history_length++;
        can_undo = true;
        can_redo = false;
        can_undo_redo_changed ();
    }

    public void undo () {
        if (!can_undo)
            return;

        unowned List<Inversion>? inversion_item = reversed_history.nth (last_move_index);
        if (inversion_item == null) assert_not_reached ();

        unowned Inversion? inversion = ((!) inversion_item).data;
        if (inversion == null) assert_not_reached ();

        uint move_id = ((!) inversion).id;
        if (move_id == 0)   // one tile move
            undo_move (((!) inversion).x0, ((!) inversion).y0,
                       ((!) inversion).x1, ((!) inversion).y1);
        else
            while (move_id == ((!) inversion).id) {
                undo_move (((!) inversion).x0, ((!) inversion).y0,
                           ((!) inversion).x1, ((!) inversion).y1);

                inversion_item = ((!) inversion_item).next;
                if (inversion_item == null)
                    break;
                inversion = ((!) inversion_item).data;
            }

        if (last_move_index == history_length)
            can_undo = false;
        can_redo = true;
        can_undo_redo_changed ();
    }
    private inline void undo_move (uint8 x0, uint8 y0, uint8 x1, uint8 y1) {
        _switch_tiles (x0, y0, x1, y1, /* delay if finished */ 0, /* no log */ true, /* garbage */ 0);

        last_move_index++;
    }

    public void redo () {
        if (!can_redo)
            return;

        unowned List<Inversion>? inversion_item = reversed_history.nth (last_move_index - 1);
        if (inversion_item == null) assert_not_reached ();

        unowned Inversion? inversion = ((!) inversion_item).data;
        if (inversion == null) assert_not_reached ();

        uint move_id = ((!) inversion).id;
        if (move_id == 0)   // one tile move
            redo_move (((!) inversion).x0, ((!) inversion).y0,
                       ((!) inversion).x1, ((!) inversion).y1);
        else
            while (move_id == ((!) inversion).id) {
                redo_move (((!) inversion).x0, ((!) inversion).y0,
                           ((!) inversion).x1, ((!) inversion).y1);

                inversion_item = ((!) inversion_item).prev;
                if (inversion_item == null)
                    break;
                inversion = ((!) inversion_item).data;
            }

        if (last_move_index == 0)
            can_redo = false;
        can_undo = true;
        can_undo_redo_changed ();
    }
    private inline void redo_move (uint8 x0, uint8 y0, uint8 x1, uint8 y1) {
        last_move_index--;

        _switch_tiles (x0, y0, x1, y1, /* delay if finished */ 0, /* no log */ true, /* garbage */ 0);
    }

    public void reload () {
        if (!can_undo)
            return;

        unowned List<Inversion>? inversion_item = reversed_history.nth (last_move_index);
        if (inversion_item == null) assert_not_reached ();

        unowned Inversion? inversion;
        do {
            inversion = ((!) inversion_item).data;
            if (inversion == null) assert_not_reached ();

            undo_move (((!) inversion).x0, ((!) inversion).y0,
                       ((!) inversion).x1, ((!) inversion).y1);

            inversion_item = ((!) inversion_item).next;
        }
        while (inversion_item != null);

        can_undo = false;
        can_redo = true;
        can_undo_redo_changed ();
    }

    /*\
    * * save and restore
    \*/

    public Variant to_variant () {
        VariantBuilder builder = new VariantBuilder (new VariantType ("m(yyda(yyyyyyyy)ua(yyyyu))"));
        builder.open (new VariantType ("(yyda(yyyyyyyy)ua(yyyyu))"));

        // board
        builder.add ("y", size);
        builder.add ("y", colors);
        builder.add ("d", elapsed);

        // tiles
        builder.open (new VariantType ("a(yyyyyyyy)"));
        for (uint8 x = 0; x < size * 2; x++)
            for (uint8 y = 0; y < size; y++) {
                Tile? tile = board [x, y];
                if (tile == null)
                    continue;
                builder.add ("(yyyyyyyy)",
                             x, y,
                             ((!) tile).north, ((!) tile).east, ((!) tile).south, ((!) tile).west,
                             ((!) tile).x, ((!) tile).y);
            }
        builder.close ();

        // history
        builder.add ("u", history_length - last_move_index);
        builder.open (new VariantType ("a(yyyyu)"));
        unowned List<Inversion>? entry = reversed_history.last ();
        while (entry != null) {
            builder.add ("(yyyyu)",
                         ((!) entry).data.x0, ((!) entry).data.y0,
                         ((!) entry).data.x1, ((!) entry).data.y1,
                         ((!) entry).data.id);
            entry = ((!) entry).prev;
        }
        builder.close ();

        // end
        builder.close ();
        return builder.end ();
    }

    private struct SavedTile {
        public uint8 current_x;
        public uint8 current_y;
        public uint8 color_north;
        public uint8 color_east;
        public uint8 color_south;
        public uint8 color_west;
        public uint8 initial_x;
        public uint8 initial_y;
    }

    public static bool is_valid_saved_game (Variant maybe_variant) {
        Variant? variant = maybe_variant.get_maybe ();
        if (variant == null)
            return false;

        uint8 board_size;
        uint8 colors;
        double elapsed;
        ((!) variant).get_child (0, "y", out board_size);
        ((!) variant).get_child (1, "y", out colors);
        ((!) variant).get_child (2, "d", out elapsed);
        Variant array_variant = ((!) variant).get_child_value (3);
        if (array_variant.n_children () != board_size * board_size)
            return false;
        SavedTile [] saved_tiles = new SavedTile [board_size * board_size];

        VariantIter? iter = new VariantIter (array_variant);
        for (uint8 index = 0; index < board_size * board_size; index++) {
            variant = ((!) iter).next_value ();
            if (variant == null)
                assert_not_reached ();
            saved_tiles [index] = SavedTile ();
            ((!) variant).@get ("(yyyyyyyy)", out saved_tiles [index].current_x,
                                              out saved_tiles [index].current_y,
                                              out saved_tiles [index].color_north,
                                              out saved_tiles [index].color_east,
                                              out saved_tiles [index].color_south,
                                              out saved_tiles [index].color_west,
                                              out saved_tiles [index].initial_x,
                                              out saved_tiles [index].initial_y);
        }

        // sanity check
        if (board_size < 2 || board_size > 6)
            return false;

        if (colors < 2 || colors > 10)
            return false;

        foreach (unowned SavedTile tile in saved_tiles) {
            if (tile.initial_x >= board_size) return false;
            if (tile.initial_y >= board_size) return false;
            if (tile.current_x >= 2 * board_size) return false;
            if (tile.current_y >= board_size) return false;
            if (tile.color_north >= colors) return false;
            if (tile.color_east >= colors) return false;
            if (tile.color_south >= colors) return false;
            if (tile.color_west >= colors) return false;
        }

        // check that puzzle is solvable and that tiles do not overlap
        SavedTile? [,] initial_board = new SavedTile? [board_size, board_size];
        for (uint8 x = 0; x < board_size; x++)
            for (uint8 y = 0; y < board_size; y++)
                initial_board [x, y] = null;

        bool [,] current_board = new bool [board_size * 2, board_size];
        for (uint8 x = 0; x < board_size * 2; x++)
            for (uint8 y = 0; y < board_size; y++)
                current_board [x, y] = false;

        for (uint8 x = 0; x < board_size * board_size; x++) {
            unowned SavedTile tile = saved_tiles [x];
            if (initial_board [tile.initial_x, tile.initial_y] != null)
                return false;
            if (current_board [tile.current_x, tile.current_y] == true)
                return false;
            initial_board [tile.initial_x, tile.initial_y] = tile;
            current_board [tile.current_x, tile.current_y] = true;
        }

        for (uint8 x = 0; x < board_size; x++)
            for (uint8 y = 0; y < board_size - 1; y++) {
                SavedTile? x_y = initial_board [x, y];
                SavedTile? x_yplus1 = initial_board [x, y + 1];
                SavedTile? y_x = initial_board [y, x];
                SavedTile? yplus1_x = initial_board [y + 1, x];

                // We checked that there are enough saved tiles to fill
                // the initial board, and we checked that each saved
                // tile is in a unique position on the original board,
                // so by the pigeonhole principle, all positions on the
                // original board must have been filled by now
                assert (x_y != null);
                assert (x_yplus1 != null);
                assert (y_x != null);
                assert (yplus1_x != null);

                if (((!) x_y).color_south != ((!) x_yplus1).color_north)
                    return false;
                if (((!) y_x).color_east != ((!) yplus1_x).color_west)
                    return false;
            }

        // TODO validate history 1/2

        return true;
    }

    public Puzzle.restore (Variant maybe_variant) {
        Variant? variant = maybe_variant.get_maybe ();
        if (variant == null)
            assert_not_reached ();

        uint8 _size;
        uint8 _colors;
        double _elapsed;
        ((!) variant).get_child (0, "y", out _size);
        ((!) variant).get_child (1, "y", out _colors);
        ((!) variant).get_child (2, "d", out _elapsed);
        this.size = _size;
        this.colors = _colors;
        this.restored = true;
        this.initial_time = _elapsed;

        Variant array_variant = ((!) variant).get_child_value (3);
        board = new Tile? [size * 2, size];
        for (uint8 x = 0; x < size * 2; x++)
            for (uint8 y = 0; y < size; y++)
                board [x, y] = null;

        VariantIter? iter = new VariantIter (array_variant);
        for (uint8 index = 0; index < size * size; index++) {
            variant = ((!) iter).next_value ();
            if (variant == null)
                assert_not_reached ();
            uint8 current_x, current_y, color_north, color_east, color_south, color_west, initial_x, initial_y;
            ((!) variant).@get ("(yyyyyyyy)", out current_x,
                                              out current_y,
                                              out color_north,
                                              out color_east,
                                              out color_south,
                                              out color_west,
                                              out initial_x,
                                              out initial_y);
            Tile tile = new Tile (initial_x, initial_y);
            tile.north = color_north;
            tile.east = color_east;
            tile.south = color_south;
            tile.west = color_west;
            board [current_x, current_y] = tile;
        }
        game_in_progress = true;
        if (solved_on_right ()) {
            is_solved_right = true;
            solved_right (is_solved_right);
        }
        check_if_solved ();
    }

    // TODO restore history 2/2
}

private enum Direction {
    NONE,
    UP,
    DOWN,
    LEFT,
    RIGHT;
}
