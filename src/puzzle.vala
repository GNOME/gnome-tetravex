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

private class Tile : Object
{
    /* Edge colors */
    internal uint8 north;
    internal uint8 west;
    internal uint8 east;
    internal uint8 south;

    /* Solution location */
    [CCode (notify = false)] public uint8 x { internal get; protected construct; }
    [CCode (notify = false)] public uint8 y { internal get; protected construct; }

    internal Tile (uint8 x, uint8 y)
    {
        Object (x: x, y: y);
    }
}

private class Puzzle : Object
{
    [CCode (notify = false)] public uint8 size   { internal get; protected construct; }
    [CCode (notify = false)] public uint8 colors { internal get; protected construct; }
    private Tile? [,] board;

    /* Game timer */
    private double clock_elapsed;
    private Timer? clock;
    private uint clock_timeout;

    [CCode (notify = false)] internal double elapsed
    {
        get
        {
            if (clock == null)
                return 0.0;
            return clock_elapsed + ((!) clock).elapsed ();
        }
    }

    private bool _paused = false;
    [CCode (notify = true)] internal bool paused
    {
        internal set
        {
            _paused = value;
            if (clock != null)
            {
                if (value)
                    stop_clock ();
                else
                    continue_clock ();
            }
        }
        internal get { return _paused; }
    }

    internal signal void tile_moved (Tile tile, uint8 x, uint8 y);
    internal signal void solved ();
    internal signal void solved_right (bool is_solved);
    internal signal void show_end_game ();
    internal signal void tick ();

    [CCode (notify = false)] internal bool is_solved { internal get; private set; default = false; }
    private bool check_if_solved ()
    {
        /* Solved if entire left hand side is complete (we ensure only tiles
           that fit are allowed */
        for (uint8 x = 0; x < size; x++)
        {
            for (uint8 y = 0; y < size; y++)
            {
                Tile? tile = board [x, y];
                if (tile == null)
                    return false;
            }
        }

        is_solved = true;
        return true;
    }

    internal Puzzle (uint8 size, uint8 colors)
    {
        Object (size: size, colors: colors);
    }

    construct
    {
        do { init_board (size, (int32) colors, out board); }
        while (solved_on_right ());

        start_clock ();
    }
    private static inline void init_board (uint8 size, int32 colors, out Tile? [,] board)
    {
        board = new Tile? [size * 2, size];
        for (uint8 x = 0; x < size; x++)
            for (uint8 y = 0; y < size; y++)
                board [x, y] = new Tile (x, y);

        /* Pick random colours for edges */
        for (uint8 x = 0; x < size; x++)
        {
            for (uint8 y = 0; y <= size; y++)
            {
                uint8 n = (uint8) Random.int_range (0, colors);
                if (y >= 1)
                    ((!) board [x, y - 1]).south = n;
                if (y < size)
                    ((!) board [x, y]).north = n;
            }
        }
        for (uint8 x = 0; x <= size; x++)
        {
            for (uint8 y = 0; y < size; y++)
            {
                uint8 n = (uint8) Random.int_range (0, colors);
                if (x >= 1)
                    ((!) board [x - 1, y]).east = n;
                if (x < size)
                    ((!) board [x, y]).west = n;
            }
        }

        /* Pick up the tiles... */
        List<Tile> tiles = new List<Tile> ();
        for (uint8 x = 0; x < size; x++)
        {
            for (uint8 y = 0; y < size; y++)
            {
                tiles.append ((!) board [x, y]);
                board [x, y] = null;
            }
        }

        /* ...and place then randomly on the right hand side */
        int32 length = (int32) tiles.length ();
        for (uint8 x = 0; x < size; x++)
        {
            for (uint8 y = 0; y < size; y++)
            {
                int32 n = Random.int_range (0, length);
                Tile tile = tiles.nth_data ((uint) n);
                board [x + size, y] = tile;
                tiles.remove (tile);
                length--;
            }
        }
    }
    private bool solved_on_right ()
    {
        for (uint8 x = size; x < 2 * size; x++)
        {
            for (uint8 y = 0; y < size; y++)
            {
                Tile? tile = board [x, y];
                if (tile == null)
                    return false;

                if (x > 0        && board [x - 1, y] != null && ((!) board [x - 1, y]).east  != ((!) tile).west)
                    return false;
                if (x < size - 1 && board [x + 1, y] != null && ((!) board [x + 1, y]).west  != ((!) tile).east)
                    return false;
                if (y > 0        && board [x, y - 1] != null && ((!) board [x, y - 1]).south != ((!) tile).north)
                    return false;
                if (y < size - 1 && board [x, y + 1] != null && ((!) board [x, y + 1]).north != ((!) tile).south)
                    return false;
            }
        }
        return true;
    }

    internal Tile? get_tile (uint8 x, uint8 y)
    {
        return board [x, y];
    }

    internal void get_tile_location (Tile tile, out uint8 x, out uint8 y)
    {
        y = 0;  // garbage
        for (x = 0; x < size * 2; x++)
            for (y = 0; y < size; y++)
                if (board [x, y] == tile)
                    return;
    }

    private bool tile_fits (uint8 x0, uint8 y0, uint8 x1, uint8 y1)
    {
        Tile? tile = board [x0, y0];
        if (tile == null)
            return false;

        if (x1 > 0 && !(x1 - 1 == x0 && y1 == y0) && board [x1 - 1, y1] != null && ((!) board [x1 - 1, y1]).east != ((!) tile).west)
            return false;
        if (x1 < size - 1 && !(x1 + 1 == x0 && y1 == y0) && board [x1 + 1, y1] != null && ((!) board [x1 + 1, y1]).west != ((!) tile).east)
            return false;
        if (y1 > 0 && !(x1 == x0 && y1 - 1 == y0) && board [x1, y1 - 1] != null && ((!) board [x1, y1 - 1]).south != ((!) tile).north)
            return false;
        if (y1 < size - 1 && !(x1 == x0 && y1 + 1 == y0) && board [x1, y1 + 1] != null && ((!) board [x1, y1 + 1]).north != ((!) tile).south)
            return false;

        return true;
    }

    internal bool can_switch (uint8 x0, uint8 y0, uint8 x1, uint8 y1)
    {
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
        if (t0 != null && t1 != null && x0 <size && x1 < size)
        {
            if (x0 == x1)
            {
                if (y0 == y1 + 1 && ((!) t0).south != ((!) t1).north)
                    return false;
                if (y0 == y1 - 1 && ((!) t0).north != ((!) t1).south)
                    return false;
            }
            else if (y0 == y1)
            {
                if (x0 == x1 + 1 && ((!) t0).east != ((!) t1).west)
                    return false;
                if (x0 == x1 - 1 && ((!) t0).west != ((!) t1).west)
                    return false;
            }
        }

        return true;
    }

    private uint timeout_id = 0;
    [CCode (notify = false)] internal bool game_in_progress { internal get; private set; default = false; }
    [CCode (notify = true)]  internal bool is_solved_right  { internal get; private set; default = false; }
    internal void switch_tiles (uint8 x0, uint8 y0, uint8 x1, uint8 y1, uint delay_if_finished = 0)
    {
        _switch_tiles (x0, y0, x1, y1, delay_if_finished, /* undoing */ false, /* move id: one tile only */ 0);
    }
    private void _switch_tiles (uint8 x0, uint8 y0, uint8 x1, uint8 y1, uint delay_if_finished, bool undoing_or_redoing, uint move_id)
    {
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

        if (check_if_solved ())
        {
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
        else if (solved_on_right ())
            is_solved_right = true;
        else if (is_solved_right)
            is_solved_right = false;
    }

    /*\
    * * moving tiles
    \*/

    private uint last_move_id = 0;

    private inline void switch_one_of_many_tiles (uint8 x0, uint8 y0, uint8 x1, uint8 y1)
    {
        _switch_tiles (x0, y0, x1, y1, /* delay if finished */ 0, /* undoing or redoing */ false, last_move_id);
    }

    internal void move_up ()
    {
        if (!can_move_up () || last_move_id == uint.MAX)
            return;
        last_move_id++;

        for (uint8 y = 1; y < size; y++)
            for (uint8 x = 0; x < size; x++)
                switch_one_of_many_tiles (x, y, x, y - 1);
    }
    private bool can_move_up ()
    {
        for (uint8 x = 0; x < size; x++)
            if (board [x, 0] != null)
                return false;
        return true;
    }

    internal void move_down ()
    {
        if (!can_move_down () || last_move_id == uint.MAX)
            return;
        last_move_id++;

        for (uint8 y = size - 1; y > 0; y--)
            for (uint8 x = 0; x < size; x++)
                switch_one_of_many_tiles (x, y - 1, x, y);
    }
    private bool can_move_down ()
    {
        for (uint8 x = 0; x < size; x++)
            if (board [x, size - 1] != null)
                return false;
        return true;
    }

    internal void move_left ()
    {
        if (!can_move_left () || last_move_id == uint.MAX)
            return;
        last_move_id++;

        for (uint8 x = 1; x < size; x++)
            for (uint8 y = 0; y < size; y++)
                switch_one_of_many_tiles (x, y, x - 1, y);
    }
    private bool can_move_left ()
    {
        for (uint8 y = 0; y < size; y++)
            if (board [0, y] != null)
                return false;
        return true;
    }

    internal void move_right ()
    {
        if (!can_move_right () || last_move_id == uint.MAX)
            return;
        last_move_id++;

        for (uint8 x = size - 1; x > 0; x--)
            for (uint8 y = 0; y < size; y++)
                switch_one_of_many_tiles (x - 1, y, x, y);
    }
    private bool can_move_right ()
    {
        for (uint8 y = 0; y < size; y++)
            if (board [size - 1, y] != null)
                return false;
        return true;
    }

    /*\
    * * actions
    \*/

    internal void solve ()
    {
        List<Tile> wrong_tiles = new List<Tile> ();
        for (uint8 x = 0; x < size * 2; x++)
        {
            for (uint8 y = 0; y < size; y++)
            {
                Tile? tile = board [x, y];
                if (tile != null && (((!) tile).x != x || ((!) tile).y != y))
                    wrong_tiles.append ((!) tile);
                board [x, y] = null;
            }
        }

        foreach (Tile tile in wrong_tiles)
        {
            board [tile.x, tile.y] = tile;
            tile_moved (tile, tile.x, tile.y);
        }

        is_solved = true;
        solved ();
        stop_clock ();
    }

    /*\
    * * clock
    \*/

    private void start_clock ()
    {
        if (clock == null)
            clock = new Timer ();
        timeout_cb ();
    }

    private void stop_clock ()
    {
        if (clock == null)
            return;
        if (clock_timeout != 0)
            Source.remove (clock_timeout);
        clock_timeout = 0;
        ((!) clock).stop ();
        tick ();
    }

    private void continue_clock ()
    {
        if (clock == null)
            clock = new Timer ();
        else
            ((!) clock).@continue ();
        timeout_cb ();
    }

    private bool timeout_cb ()
        requires (clock != null)
    {
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

    [CCode (notify = true)] internal bool can_undo { internal get; private set; default = false; }
    [CCode (notify = true)] internal bool can_redo { internal get; private set; default = false; }
    private uint history_length = 0;
    private uint last_move_index = 0;

    private List<Inversion> reversed_history = new List<Inversion> ();
    private const uint animation_duration = 250; // FIXME might better be in view

    private class Inversion : Object
    {
        public uint8 x0 { internal get; protected construct; }
        public uint8 y0 { internal get; protected construct; }
        public uint8 x1 { internal get; protected construct; }
        public uint8 y1 { internal get; protected construct; }
        public uint  id { internal get; protected construct; }

        internal Inversion (uint8 x0, uint8 y0, uint8 x1, uint8 y1, uint id)
        {
            Object (x0: x0, y0: y0, x1: x1, y1: y1, id: id);
        }
    }

    private inline void add_to_history (uint8 x0, uint8 y0, uint8 x1, uint8 y1, uint id)
    {
        while (last_move_index > 0)
        {
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
    }

    internal void undo ()
    {
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
            while (move_id == ((!) inversion).id)
            {
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
    }
    private inline void undo_move (uint8 x0, uint8 y0, uint8 x1, uint8 y1)
    {
        _switch_tiles (x0, y0, x1, y1, animation_duration, /* no log */ true, /* garbage */ 0);

        last_move_index++;
    }

    internal void redo ()
    {
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
            while (move_id == ((!) inversion).id)
            {
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
    }
    private inline void redo_move (uint8 x0, uint8 y0, uint8 x1, uint8 y1)
    {
        last_move_index--;

        _switch_tiles (x0, y0, x1, y1, animation_duration, /* no log */ true, /* garbage */ 0);
    }
}
