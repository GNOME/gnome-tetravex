/* -*- Mode: vala; tab-width: 4; indent-tabs-mode: nil; c-basic-offset: 4 -*-
 *
 * Copyright (C) 2010-2013 Robert Ancell
 *
 * This program is free software: you can redistribute it and/or modify it under
 * the terms of the GNU General Public License as published by the Free Software
 * Foundation, either version 2 of the License, or (at your option) any later
 * version. See http://www.gnu.org/copyleft/gpl.html the full text of the
 * license.
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
    [CCode (notify = false)] public uint8 size { internal get; protected construct; }
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
    internal signal void tick ();

    [CCode (notify = false)] internal bool is_solved
    {
        internal get
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

            return true;
        }
    }

    internal Puzzle (uint8 size)
    {
        Object (size: size);
    }

    construct
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
                uint8 n = (uint8) Random.int_range (0, 10);
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
                uint8 n = (uint8) Random.int_range (0, 10);
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
        for (uint8 x = 0; x < size; x++)
        {
            for (uint8 y = 0; y < size; y++)
            {
                int32 n = Random.int_range (0, (int32) tiles.length ());
                Tile tile = tiles.nth_data ((uint) n);
                board [x + size, y] = tile;
                tiles.remove (tile);
            }
        }

        start_clock ();
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

        /* If placing onto the final area check if it fits */
        if (t0 != null && x1 < size && !tile_fits (x0, y0, x1, y1))
            return false;
        if (t1 != null && x0 < size && !tile_fits (x1, y1, x0, y0))
            return false;

        return true;
    }

    internal void switch_tiles (uint8 x0, uint8 y0, uint8 x1, uint8 y1)
    {
        if (x0 == x1 && y0 == y1)
            return;

        Tile? t0 = board [x0, y0];
        Tile? t1 = board [x1, y1];
        board [x0, y0] = t1;
        board [x1, y1] = t0;

        if (t0 != null)
            tile_moved ((!) t0, x1, y1);
        if (t1 != null)
            tile_moved ((!) t1, x0, y0);

        if (is_solved)
        {
            stop_clock ();
            solved ();
        }
    }

    /*\
    * * moving tiles
    \*/

    internal void move_up ()
    {
        if (!can_move_up ())
            return;

        for (uint8 y = 1; y < size; y++)
            for (uint8 x = 0; x < size; x++)
                switch_tiles (x, y, x, y - 1);
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
        if (!can_move_down ())
            return;

        for (uint8 y = size - 1; y > 0; y--)
            for (uint8 x = 0; x < size; x++)
                switch_tiles (x, y - 1, x, y);
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
        if (!can_move_left ())
            return;

        for (uint8 x = 1; x < size; x++)
            for (uint8 y = 0; y < size; y++)
                switch_tiles (x, y, x - 1, y);
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
        if (!can_move_right ())
            return;

        for (uint8 x = size - 1; x > 0; x--)
            for (uint8 y = 0; y < size; y++)
                switch_tiles (x - 1, y, x, y);
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
}
