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

private class PuzzleView : Gtk.DrawingArea
{
    private class TileImage : Object
    {
        /* Tile being moved */
        internal Tile tile;

        /* Location of tile */
        internal double x = 0.0;
        internal double y = 0.0;

        /* Co-ordinates to move from */
        internal double source_x = 0.0;
        internal double source_y = 0.0;

        /* Time started moving */
        internal double source_time = 0.0;

        /* Co-ordinates to target for */
        internal double target_x = 0.0;
        internal double target_y = 0.0;

        /* Duration of movement */
        internal double duration = 0.0;

        /* Whether the tile follows exactly cursor or nuns after it */
        internal bool snap_to_cursor = true;

        internal TileImage (Tile tile)
        {
            this.tile = tile;
        }
    }

    /* Minimum size of a tile */
    private const int minimum_size = 80;

    /* Animations duration */
    private const double animation_duration = 0.25;
    private const uint final_animation_duration = 250;
    private const double half_animation_duration = 0.15;

    /* Puzzle being rendered */
    private Puzzle? _puzzle = null;
    [CCode (notify = false)] private bool puzzle_init_done { get { return _puzzle != null; }}
    [CCode (notify = false)] internal Puzzle puzzle
    {
        private get { if (!puzzle_init_done) assert_not_reached (); return (!) _puzzle; }
        internal set
        {
            if (puzzle_init_done)
                SignalHandler.disconnect_by_func ((!) _puzzle, null, this);

            _puzzle = value;
            last_selected_tile = null;
            tiles.remove_all ();
            for (uint8 y = 0; y < ((!) _puzzle).size; y++)
            {
                for (uint8 x = 0; x < ((!) _puzzle).size * 2; x++)
                {
                    Tile? tile = ((!) _puzzle).get_tile (x, y);
                    if (tile == null)
                        continue;

                    TileImage image = new TileImage ((!) tile);
                    move_tile_to_location (image, x, y);
                    tiles.insert ((!) tile, image);
                }
            }
            sockets_xs = new double [2 * ((!) _puzzle).size, ((!) _puzzle).size];
            sockets_ys = new double [2 * ((!) _puzzle).size, ((!) _puzzle).size];

            ((!) _puzzle).tile_moved.connect (tile_moved_cb);
            ((!) _puzzle).notify ["paused"].connect (() => { queue_draw (); });
            queue_resize ();
        }
    }

    /* Theme */
    private Theme theme = new Theme ();

    /* Tile being controlled by the mouse */
    private TileImage? selected_tile = null;
    private TileImage? last_selected_tile = null;
    [CCode (notify = true)] internal bool tile_selected { internal get; private set; default = false; }

    /* Timeout to detect if a click is a selection or a drag */
    private uint selection_timeout = 0;

    /* The position inside the tile where the cursor is */
    private double selected_x_offset;
    private double selected_y_offset;

    /* Tile images */
    private HashTable<Tile, TileImage> tiles = new HashTable<Tile, TileImage> (direct_hash, direct_equal);

    /* Animation timer */
    private Timer animation_timer = new Timer ();
    private uint animation_timeout = 0;

    /* Set in configure event */
    private uint x_offset = 0;
    private uint y_offset = 0;
    private uint tilesize = 0;
    private uint gap = 0;
    private double arrow_x = 0.0;
    private double arrow_y = 0.0;
    private double [,] sockets_xs;
    private double [,] sockets_ys;
    private int board_x_maxi = 0;
    private int board_y_maxi = 0;
    private double snap_distance = 0.0;

    construct
    {
        set_events (Gdk.EventMask.EXPOSURE_MASK
                  | Gdk.EventMask.BUTTON_PRESS_MASK
                  | Gdk.EventMask.POINTER_MOTION_MASK
                  | Gdk.EventMask.BUTTON_RELEASE_MASK
                  | Gdk.EventMask.ENTER_NOTIFY_MASK
                  | Gdk.EventMask.LEAVE_NOTIFY_MASK);

        animation_timer.start ();
    }

    private void redraw_tile (TileImage image)
    {
        queue_draw_area ((int) (image.x + 0.5),
                         (int) (image.y + 0.5),
                         (int) tilesize,
                         (int) tilesize);
    }

    private void move_tile_to_location (TileImage image, uint x, uint y, double duration = 0)
    {
        double target_x = (double) (x_offset + x * tilesize);
        if (x >= puzzle.size)
            target_x += gap;
        double target_y = (double) (y_offset + y * tilesize);
        move_tile (image, target_x, target_y, duration);
    }

    private void move_tile (TileImage image, double x, double y, double duration = 0)   // FIXME double x and y, really?
    {
        if (image.x == x && image.y == y)
            return;

        image.source_x = image.x;
        image.source_y = image.y;
        image.source_time = animation_timer.elapsed ();
        image.target_x = x;
        image.target_y = y;
        image.duration = duration;

        /* Move immediately */
        if (duration == 0)
        {
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

    private bool animate_cb ()
    {
        double t = animation_timer.elapsed ();

        bool animating = false;
        HashTableIter<Tile, TileImage> iter = HashTableIter<Tile, TileImage> (tiles);
        while (true)
        {
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
            if (t >= image.source_time + image.duration)
            {
                image.x = image.target_x;
                image.y = image.target_y;
            }
            else
            {
                double d = (t - image.source_time) / image.duration;
                image.x = image.source_x + (image.target_x - image.source_x) * d;
                image.y = image.source_y + (image.target_y - image.source_y) * d;
                animating = true;
            }

            if (!image.snap_to_cursor)
            {
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

    protected override void get_preferred_width (out int minimum, out int natural)
    {
        int size = 0;
        if (puzzle_init_done)
            size = (int) ((puzzle.size * 2 + 1.5) * minimum_size);
        minimum = natural = int.max (size, 500);
    }

    protected override void get_preferred_height (out int minimum, out int natural)
    {
        int size = 0;
        if (puzzle_init_done)
            size = (int) ((puzzle.size + 1) * minimum_size);
        minimum = natural = int.max (size, 300);
    }

    private void tile_moved_cb (Puzzle puzzle, Tile tile, uint8 x, uint8 y)
    {
        move_tile_to_location (tiles.lookup (tile), x, y, animation_duration);
    }

    protected override bool configure_event (Gdk.EventConfigure event)
    {
        if (puzzle_init_done)
        {
            int allocated_width  = get_allocated_width ();
            int allocated_height = get_allocated_height ();
            /* Fit in with a half tile border and spacing between boards */
            uint width  = (uint) (allocated_width  / (2 * puzzle.size + 1.5));
            uint height = (uint) (allocated_height / (puzzle.size + 1));
            tilesize = uint.min (width, height);
            gap = tilesize / 2;
            x_offset = (allocated_width  - 2 * puzzle.size * tilesize - gap) / 2;
            y_offset = (allocated_height -     puzzle.size * tilesize      ) / 2;

            board_x_maxi = allocated_width  - (int) tilesize;
            board_y_maxi = allocated_height - (int) tilesize;

            snap_distance = (tilesize * puzzle.size) / 40.0;

            arrow_x = x_offset + puzzle.size * tilesize + gap * 0.25;
            arrow_y = y_offset + puzzle.size * tilesize * 0.5;

            /* Precalculate sockets positions */
            for (uint y = 0; y < puzzle.size; y++)
                for (uint x = 0; x < puzzle.size * 2; x++)
                {
                    if (x >= puzzle.size)
                        sockets_xs [x, y] = x_offset + gap + x * tilesize;
                    else
                        sockets_xs [x, y] = x_offset + x * tilesize;
                    sockets_ys [x, y] = y_offset + y * tilesize;
                }
        }

        /* Move everything to its correct location */
        HashTableIter<Tile, TileImage> iter = HashTableIter<Tile, TileImage> (tiles);
        while (true)
        {
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

        return false;
    }

    protected override bool draw (Cairo.Context context)
    {
        if (!puzzle_init_done)
            return false;

        /* Draw arrow */
        context.save ();
        context.translate (arrow_x, arrow_y);
        theme.draw_arrow (context, tilesize, gap);
        context.restore ();

        /* Draw sockets */
        for (uint y = 0; y < puzzle.size; y++)
            for (uint x = 0; x < puzzle.size * 2; x++)
            {
                context.save ();
                context.translate (sockets_xs [x, y], sockets_ys [x, y]);
                theme.draw_socket (context, tilesize);
                context.restore ();
            }

        /* Draw tiles */
        SList<TileImage> moving_tiles = new SList<TileImage> ();
        HashTableIter<Tile, TileImage> iter = HashTableIter<Tile, TileImage> (tiles);
        while (true)
        {
            Tile tile;
            TileImage image;
            if (!iter.next (out tile, out image))
                break;

            if ((selected_tile != null && image == (!) selected_tile)
             || (image.x != image.target_x)
             || (image.y != image.target_y))
            {
                moving_tiles.prepend (image);
                continue;
            }

            draw_image (context, image);
        }

        foreach (unowned TileImage image in moving_tiles)
            draw_image (context, image);

        /* Redraw last selected tile, fixing problem seen when interverting multiple times two contiguous tiles */
        if (selected_tile == null && last_selected_tile != null)
            draw_image (context, (!) last_selected_tile);

        /* Draw pause overlay */
        if (puzzle.paused)
            draw_pause_overlay (context);

        return false;
    }
    private inline void draw_image (Cairo.Context context, TileImage image)
    {
        context.save ();
        context.translate ((int) (image.x + 0.5), (int) (image.y + 0.5));
        if (puzzle.paused)
            theme.draw_paused_tile (context, tilesize);
        else
            theme.draw_tile (context, tilesize, image.tile);
        context.restore ();
    }
    private inline void draw_pause_overlay (Cairo.Context context)
    {
        context.set_source_rgba (0, 0, 0, 0.75);
        context.paint ();

        context.select_font_face ("Sans", Cairo.FontSlant.NORMAL, Cairo.FontWeight.BOLD);
        context.set_font_size (get_allocated_width () * 0.125);

        /* Translators: text that appears as an overlay on the board when the game is paused */
        string text = _("Paused");
        Cairo.TextExtents extents;
        context.text_extents (text, out extents);
        context.move_to ((get_allocated_width () - extents.width) / 2.0, (get_allocated_height () + extents.height) / 2.0);
        context.set_source_rgb (1, 1, 1);
        context.show_text (text);
    }

    private void pick_tile (double x, double y)
    {
        if (selected_tile != null)
            return;

        if (puzzle.is_solved)
            return;

        HashTableIter<Tile, TileImage> iter = HashTableIter<Tile, TileImage> (tiles);
        while (true)
        {
            Tile tile;
            TileImage image;
            if (!iter.next (out tile, out image))
                break;

            if (x >= image.x && x <= image.x + tilesize
             && y >= image.y && y <= image.y + tilesize)
            {
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
    }

    private bool selection_timeout_cb ()
    {
        selection_timeout = 0;
        return false;
    }

    private bool on_right_half (double x)
    {
        return x > x_offset + tilesize * puzzle.size + gap * 0.5;
    }

    private void drop_tile (double x, double y)
    {
        if (selected_tile == null)
            return;

        /* Select from the middle of the tile */
        x += tilesize * 0.5 - selected_x_offset;
        y += tilesize * 0.5 - selected_y_offset;

        int16 tile_y = (int16) Math.floor ((y - y_offset) / tilesize);
        tile_y = tile_y.clamp (0, (int16) puzzle.size - 1);

        /* Check which side we are on */
        int16 tile_x;
        if (on_right_half (x))
        {
            tile_x = (int16) puzzle.size + (int16) Math.floor ((x - (x_offset + puzzle.size * tilesize + gap)) / tilesize);
            tile_x = tile_x.clamp ((int16) puzzle.size, 2 * (int16) puzzle.size - 1);
        }
        else
        {
            tile_x = (int16) Math.floor ((x - x_offset) / tilesize);
            tile_x = tile_x.clamp (0, (int16) puzzle.size - 1);
        }

        /* Drop the tile here, or move it back if can't */
        uint8 selected_x, selected_y;
        puzzle.get_tile_location (((!) selected_tile).tile, out selected_x, out selected_y);
        if (puzzle.can_switch (selected_x, selected_y, (uint8) tile_x, (uint8) tile_y))
            puzzle.switch_tiles (selected_x, selected_y, (uint8) tile_x, (uint8) tile_y);
        else
            move_tile_to_location ((!) selected_tile, selected_x, selected_y, animation_duration);
        ((!) selected_tile).snap_to_cursor = true;
        selected_tile = null;
        tile_selected = false;
    }

    private void move_tile_to_right_half (Tile tile)
    {
        /* Pick the first open spot on the right side of the board */
        for (uint8 y = 0; y < puzzle.size; y++)
        {
            for (uint8 x = puzzle.size; x < puzzle.size * 2; x++)
            {
                if (puzzle.get_tile (x, y) == null)
                {
                    uint8 source_x, source_y;
                    puzzle.get_tile_location (tile, out source_x, out source_y);
                    puzzle.switch_tiles (source_x, source_y, x, y);
                    return;
                }
            }
        }
        assert_not_reached ();
    }

    [CCode (notify = false)] internal bool mouse_use_extra_buttons  { private get; internal set; default = true; }
    [CCode (notify = false)] internal int  mouse_back_button        { private get; internal set; default = 8; }
    [CCode (notify = false)] internal int  mouse_forward_button     { private get; internal set; default = 9; }

    protected override bool button_press_event (Gdk.EventButton event)
    {
        if (puzzle.paused || puzzle.is_solved)
            return false;

        if (event.button == 1 || event.button == 3)
            return main_button_pressed (event);

        if (!mouse_use_extra_buttons)
            return false;
        if (event.button == mouse_back_button)
            undo ();
        else if (event.button == mouse_forward_button)
            redo ();
        return false;
    }

    private inline bool main_button_pressed (Gdk.EventButton event)
    {
        if (event.type == Gdk.EventType.BUTTON_PRESS)
        {
            if (selected_tile == null)
                pick_tile (event.x, event.y);
            else
                drop_tile (event.x, event.y);
        }
        else if (event.type == Gdk.EventType.DOUBLE_BUTTON_PRESS)
        {
            /* Move tile from left to right on double click */
            pick_tile (event.x, event.y);
            if (selected_tile == null)
                return false;
            if (on_right_half (((!) selected_tile).x))
            {
                uint8 x;
                uint8 y;
                if (selected_tile_is_last_tile (out x, out y))
                {
                    uint8 selected_x, selected_y;
                    puzzle.get_tile_location (((!) selected_tile).tile, out selected_x, out selected_y);
                    if (puzzle.can_switch (selected_x, selected_y, x, y))
                        puzzle.switch_tiles (selected_x, selected_y, x, y, final_animation_duration);
                }
                else
                    return false;   /* consider double click as a single click */
            }
            else
                move_tile_to_right_half (((!) selected_tile).tile);
            ((!) selected_tile).snap_to_cursor = true;
            selected_tile = null;
            tile_selected = false;
        }

        return false;
    }
    private inline bool selected_tile_is_last_tile (out uint8 empty_x, out uint8 empty_y)
    {
        bool empty_found = false;
        empty_x = uint8.MAX;    // garbage
        empty_y = uint8.MAX;    // garbage
        for (uint8 x = 0; x < puzzle.size; x++)
            for (uint8 y = 0; y < puzzle.size; y++)
                if (puzzle.get_tile (x, y) == null)
                {
                    if (empty_found)
                        return false;
                    empty_found = true;
                    empty_x = x;
                    empty_y = y;
                }

        if (!empty_found)
            assert_not_reached ();
        return true;
    }

    protected override bool button_release_event (Gdk.EventButton event)
    {
        if (puzzle.paused || puzzle.is_solved)
            return false;

        if (event.button == 1 && selected_tile != null && selection_timeout == 0)
            drop_tile (event.x, event.y);

        if (selection_timeout != 0)
            Source.remove (selection_timeout);
        selection_timeout = 0;

        return false;
    }

    protected override bool motion_notify_event (Gdk.EventMotion event)
    {
        if (selected_tile != null)
        {
            int new_x = ((int) (event.x - selected_x_offset)).clamp (0, board_x_maxi);
            int new_y = ((int) (event.y - selected_y_offset)).clamp (0, board_y_maxi);

            double duration;
            if (((!) selected_tile).snap_to_cursor)
                duration = 0.0;
            else
                duration = ((!) selected_tile).duration;

            move_tile ((!) selected_tile, new_x, new_y, duration);
        }

        return false;
    }

    protected override bool leave_notify_event (Gdk.EventCrossing event)
    {
        if (selected_tile != null)
            ((!) selected_tile).snap_to_cursor = false;

        return false;
    }

    protected override bool enter_notify_event (Gdk.EventCrossing event)
    {
        if (selected_tile != null)
        {
            ((!) selected_tile).snap_to_cursor = false;
            ((!) selected_tile).duration = half_animation_duration;
        }

        return false;
    }

    internal void finish ()
    {
        for (uint8 x = 0; x < puzzle.size; x++)
            for (uint8 y = 0; y < puzzle.size; y++)
                puzzle.switch_tiles (x + puzzle.size, y, x, y, final_animation_duration);
    }

    internal void release_selected_tile ()
    {
        uint8 selected_x, selected_y;
        puzzle.get_tile_location (((!) selected_tile).tile, out selected_x, out selected_y);
        move_tile_to_location ((!) selected_tile, selected_x, selected_y, animation_duration);
        ((!) selected_tile).snap_to_cursor = true;
        selected_tile = null;
        tile_selected = false;
    }

    internal void undo ()
    {
        last_selected_tile = null;
        puzzle.undo ();
    }

    internal void redo ()
    {
        last_selected_tile = null;
        puzzle.redo ();
    }
}
