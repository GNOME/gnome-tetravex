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

private class TileImage : Object
{
    /* Tile being moved */
    internal Tile tile;

    /* Location of tile */
    internal double x;
    internal double y;

    /* Co-ordinates to move from */
    internal double source_x;
    internal double source_y;

    /* Time started moving */
    internal double source_time;

    /* Co-ordinates to target for */
    internal double target_x;
    internal double target_y;

    /* Duration of movement */
    internal double duration;

    internal TileImage (Tile tile)
    {
        this.tile = tile;
    }
}

private class PuzzleView : Gtk.DrawingArea
{
    /* Minimum size of a tile */
    private const int minimum_size = 80;

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
            ((!) _puzzle).tile_moved.connect (tile_moved_cb);
            ((!) _puzzle).notify ["paused"].connect (() => { queue_draw (); });
            queue_resize ();
        }
    }

    /* Theme */
    private Theme theme = new Theme ();

    /* Tile being controlled by the mouse */
    private TileImage? selected_tile = null;
    internal signal void tile_selected (bool selected);

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

    construct
    {
        set_events (Gdk.EventMask.EXPOSURE_MASK
                  | Gdk.EventMask.BUTTON_PRESS_MASK
                  | Gdk.EventMask.POINTER_MOTION_MASK
                  | Gdk.EventMask.BUTTON_RELEASE_MASK);

        animation_timer.start ();
    }

    [CCode (notify = false)] internal bool game_in_progress
    {
        internal get
        {
            if (puzzle.is_solved)
                return false;

            for (uint8 y = 0; y < puzzle.size; y++)
            {
                for (uint8 x = puzzle.size; x < puzzle.size * 2; x++)
                {
                    if (puzzle.get_tile (x, y) == null)
                        return true;
                }
            }
            return false;
        }
    }

    private void redraw_tile (TileImage image)
    {
        uint x_offset, y_offset, size, gap;
        get_dimensions (out x_offset, out y_offset, out size, out gap);

        queue_draw_area ((int) (image.x + 0.5), (int) (image.y + 0.5), (int) size, (int) size);
    }

    private void move_tile_to_location (TileImage image, uint x, uint y, double duration = 0)
    {
        uint x_offset, y_offset, size, gap;
        get_dimensions (out x_offset, out y_offset, out size, out gap);

        double target_x = (double) (x_offset + x * size);
        if (x >= puzzle.size)
            target_x += gap;
        double target_y = (double) (y_offset + y * size);
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

        uint x_offset, y_offset, size, gap;
        get_dimensions (out x_offset, out y_offset, out size, out gap);

        bool animating = false;
        HashTableIter<Tile, TileImage> iter = HashTableIter<Tile, TileImage> (tiles);
        while (true)
        {
            Tile tile;
            TileImage image;
            if (!iter.next (out tile, out image))
                break;

            if (image.x == image.target_x && image.y == image.target_y)
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
                var d = (t - image.source_time) / image.duration;
                image.x = image.source_x + (image.target_x - image.source_x) * d;
                image.y = image.source_y + (image.target_y - image.source_y) * d;
                animating = true;
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

    private void get_dimensions (out uint x, out uint y, out uint size, out uint gap)
    {
        /* Fit in with a half tile border and spacing between boards */
        uint width  = (uint) (get_allocated_width ()  / (2 * puzzle.size + 1.5));
        uint height = (uint) (get_allocated_height () / (puzzle.size + 1));
        size = uint.min (width, height);
        gap = size / 2;
        x = (get_allocated_width () - 2 * puzzle.size * size - gap) / 2;
        y = (get_allocated_height () - puzzle.size * size) / 2;
    }

    private void tile_moved_cb (Puzzle puzzle, Tile tile, uint8 x, uint8 y)
    {
        move_tile_to_location (tiles.lookup (tile), x, y, 0.2);
    }

    protected override bool configure_event (Gdk.EventConfigure event)
    {
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
        selected_tile = null;
        tile_selected (false);

        return false;
    }

    protected override bool draw (Cairo.Context context)
    {
        if (!puzzle_init_done)
            return false;

        uint x_offset, y_offset, size, gap;
        get_dimensions (out x_offset, out y_offset, out size, out gap);

        /* Draw arrow */
        context.save ();
        double w = gap * 0.5;
        double ax = x_offset + puzzle.size * size + (gap - w) * 0.5;
        double ay = y_offset + puzzle.size * size * 0.5;
        context.translate (ax, ay);
        theme.draw_arrow (context, size, gap);
        context.restore ();

        /* Draw sockets */
        for (uint y = 0; y < puzzle.size; y++)
        {
            for (uint x = 0; x < puzzle.size * 2; x++)
            {
                context.save ();
                if (x >= puzzle.size)
                    context.translate (x_offset + gap + x * size, y_offset + y * size);
                else
                    context.translate (x_offset + x * size, y_offset + y * size);
                theme.draw_socket (context, size);
                context.restore ();
            }
        }

        /* Draw stationary tiles */
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
                continue;

            context.save ();
            context.translate ((int) (image.x + 0.5), (int) (image.y + 0.5));
            if (puzzle.paused)
                theme.draw_paused_tile (context, size);
            else
                theme.draw_tile (context, size, tile);
            context.restore ();
        }

        /* Draw moving tiles */
        iter = HashTableIter<Tile, TileImage> (tiles);
        while (true)
        {
            Tile tile;
            TileImage image;
            if (!iter.next (out tile, out image))
                break;

            if ((selected_tile != null && image != (!) selected_tile)
             && (image.x == image.target_x)
             && (image.y == image.target_y))
                continue;

            context.save ();
            context.translate ((int) (image.x + 0.5), (int) (image.y + 0.5));
            if (puzzle.paused)
                theme.draw_paused_tile (context, size);
            else
                theme.draw_tile (context, size, tile);
            context.restore ();
        }

        /* Draw pause overlay */
        if (puzzle.paused)
        {
            context.set_source_rgba (0, 0, 0, 0.75);
            context.paint ();

            context.select_font_face ("Sans", Cairo.FontSlant.NORMAL, Cairo.FontWeight.BOLD);
            context.set_font_size (get_allocated_width () * 0.125);

            /* Translators: text that appears as an overlay on the board when the game is paused */
            var text = _("Paused");
            Cairo.TextExtents extents;
            context.text_extents (text, out extents);
            context.move_to ((get_allocated_width () - extents.width) / 2.0, (get_allocated_height () + extents.height) / 2.0);
            context.set_source_rgb (1, 1, 1);
            context.show_text (text);
        }

        return false;
    }

    private void pick_tile (double x, double y)
    {
        if (selected_tile != null)
            return;

        if (puzzle.is_solved)
            return;

        uint x_offset, y_offset, size, gap;
        get_dimensions (out x_offset, out y_offset, out size, out gap);

        HashTableIter<Tile, TileImage> iter = HashTableIter<Tile, TileImage> (tiles);
        while (true)
        {
            Tile tile;
            TileImage image;
            if (!iter.next (out tile, out image))
                break;

            if (x >= image.x && x <= image.x + size && y >= image.y && y <= image.y + size)
            {
                selected_tile = image;
                tile_selected (true);
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
        uint x_offset, y_offset, size, gap;
        get_dimensions (out x_offset, out y_offset, out size, out gap);

        return x > x_offset + size * puzzle.size + gap * 0.5;
    }

    private void drop_tile (double x, double y)
    {
        if (selected_tile == null)
            return;

        uint x_offset, y_offset, size, gap;
        get_dimensions (out x_offset, out y_offset, out size, out gap);

        /* Select from the middle of the tile */
        x += size * 0.5 - selected_x_offset;
        y += size * 0.5 - selected_x_offset;

        int16 tile_y = (int16) Math.floor ((y - y_offset) / size);
        tile_y = tile_y.clamp (0, (int16) puzzle.size - 1);

        /* Check which side we are on */
        int16 tile_x;
        if (on_right_half (x))
        {
            tile_x = (int16) puzzle.size + (int16) Math.floor ((x - (x_offset + puzzle.size * size + gap)) / size);
            tile_x = tile_x.clamp ((int16) puzzle.size, 2 * (int16) puzzle.size - 1);
        }
        else
        {
            tile_x = (int16) Math.floor ((x - x_offset) / size);
            tile_x = tile_x.clamp (0, (int16) puzzle.size - 1);
        }

        /* Drop the tile here, or move it back if can't */
        uint8 selected_x, selected_y;
        puzzle.get_tile_location (((!) selected_tile).tile, out selected_x, out selected_y);
        if (puzzle.can_switch (selected_x, selected_y, (uint8) tile_x, (uint8) tile_y))
            puzzle.switch_tiles (selected_x, selected_y, (uint8) tile_x, (uint8) tile_y);
        else
            move_tile_to_location ((!) selected_tile, selected_x, selected_y, 0.2);
        selected_tile = null;
        tile_selected (false);
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

    protected override bool button_press_event (Gdk.EventButton event)
    {
        if (puzzle.paused)
            return false;

        if (event.button == 1)
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
                if (selected_tile != null && !on_right_half (((!) selected_tile).x))
                    move_tile_to_right_half (((!) selected_tile).tile);
                selected_tile = null;
                tile_selected (false);
            }
        }

        return false;
    }

    protected override bool button_release_event (Gdk.EventButton event)
    {
        if (puzzle.paused)
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
            move_tile ((!) selected_tile, (int) (event.x - selected_x_offset), (int) (event.y - selected_y_offset));

        return false;
    }
}
