private class TileImage
{
    /* Tile being moved */
    public Tile tile;

    /* Location of tile */
    public double x;
    public double y;

    /* Co-ordinates to move from */
    public double source_x;
    public double source_y;

    /* Time started moving */
    public double source_time;

    /* Co-ordinates to target for */
    public double target_x;
    public double target_y;

    /* Duration of movement */
    public double duration;

    public TileImage (Tile tile)
    {
        this.tile = tile;
    }
}

public class PuzzleView : Gtk.DrawingArea
{
    /* Minimum size of a tile */
    private const int minimum_size = 40;

    /* Puzzle being rendered */
    private Puzzle? _puzzle = null;
    public Puzzle puzzle
    {
        get { return _puzzle; }
        set
        {
            if (_puzzle != null)
                SignalHandler.disconnect_by_func (_puzzle, null, this);
            _puzzle = value;
            tiles.remove_all ();
            for (var y = 0; y < puzzle.size; y++)
            {
                for (var x = 0; x < puzzle.size * 2; x++)
                {
                    var tile = puzzle.get_tile (x, y);
                    if (tile == null)
                        continue;

                    var image = new TileImage (tile);
                    move_tile_to_location (image, x, y);
                    tiles.insert (tile, image);
                }
            }
            _puzzle.tile_moved.connect (tile_moved_cb);
            queue_resize ();
        }
    }
    
    /* Theme */
    private Theme theme;

    public bool click_to_move = false;

    /* Tile being controlled by the mouse */
    private TileImage? selected_tile = null;

    /* The position inside the tile where the cursor is */
    private double selected_x_offset;
    private double selected_y_offset;

    /* Tile images */
    private HashTable<Tile, TileImage> tiles;

    /* Animation timer */
    private Timer animation_timer;
    private uint animation_timeout = 0;

    private bool _is_paused = false;
    public bool is_paused
    {
        get { return _is_paused; }
        set
        {
            _is_paused = value;
            queue_draw ();
        }
    }

    public PuzzleView ()
    {
        set_events (Gdk.EventMask.EXPOSURE_MASK | Gdk.EventMask.BUTTON_PRESS_MASK | Gdk.EventMask.POINTER_MOTION_MASK | Gdk.EventMask.BUTTON_RELEASE_MASK);

        tiles = new HashTable <Tile, TileImage> (direct_hash, direct_equal);
        
        theme = new Theme ();

        animation_timer = new Timer ();
        animation_timer.start ();
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

        var target_x = x_offset + x * size;
        if (x >= puzzle.size)
            target_x += gap;
        var target_y = y_offset + y * size;
        move_tile (image, target_x, target_y, duration);
    }

    private void move_tile (TileImage image, double x, double y, double duration = 0)
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
        var t = animation_timer.elapsed ();
        
        uint x_offset, y_offset, size, gap;
        get_dimensions (out x_offset, out y_offset, out size, out gap);

        var animating = false;
        var iter = HashTableIter<Tile, TileImage> (tiles);
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

    public override void get_preferred_width (out int minimum, out int natural)
    {
        var size = 0;
        if (puzzle != null)
            size = (int) ((puzzle.size * 2 + 1.5) * minimum_size);
        minimum = natural = int.max (size, 500);
    }

    public override void get_preferred_height (out int minimum, out int natural)
    {
        var size = 0;
        if (puzzle != null)
            size = (int) ((puzzle.size + 1) * minimum_size);
        minimum = natural = int.max (size, 300);
    }
    
    private void get_dimensions (out uint x, out uint y, out uint size, out uint gap)
    {
        /* Fit in with a half tile border and spacing between boards */
        var width = (uint) (get_allocated_width () / (2 * puzzle.size + 1.5));
        var height = (uint) (get_allocated_height () / (puzzle.size + 1));
        size = uint.min (width, height);
        gap = size / 2;
        x = (get_allocated_width () - 2 * puzzle.size * size - gap) / 2;
        y = (get_allocated_height () - puzzle.size * size) / 2;
    }

    private void tile_moved_cb (Puzzle puzzle, Tile tile, uint x, uint y)
    {
        move_tile_to_location (tiles.lookup (tile), x, y, 0.2);
    }
    
    public override bool configure_event (Gdk.EventConfigure event)
    {
        /* Move everything to its correct location */
        var iter = HashTableIter<Tile, TileImage> (tiles);
        while (true)
        {
            Tile tile;
            TileImage image;
            if (!iter.next (out tile, out image))
                break;
            uint x, y;
            puzzle.get_tile_location (tile, out x, out y);
            move_tile_to_location (image, x, y);
        }
        selected_tile = null;

        return false;
    }

    public override bool draw (Cairo.Context context)
    {
        if (puzzle == null)
            return false;

        uint x_offset, y_offset, size, gap;
        get_dimensions (out x_offset, out y_offset, out size, out gap);

        /* Draw arrow */
        context.save ();
        var w = gap * 0.5;
        var ax = x_offset + puzzle.size * size + (gap - w) * 0.5;
        var ay = y_offset + puzzle.size * size * 0.5;
        context.translate (ax, ay);
        theme.draw_arrow (context, size, gap);
        context.restore ();

        /* Draw sockets */
        for (var y = 0; y < puzzle.size; y++)
        {
            for (var x = 0; x < puzzle.size * 2; x++)
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
        var iter = HashTableIter<Tile, TileImage> (tiles);
        while (true)
        {
            Tile tile;
            TileImage image;
            if (!iter.next (out tile, out image))
                break;

            if (image == selected_tile || image.x != image.target_x || image.y != image.target_y)
                continue;

            context.save ();
            context.translate ((int) (image.x + 0.5), (int) (image.y + 0.5));
            if (is_paused)
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

            if (image != selected_tile && image.x == image.target_x && image.y == image.target_y)
                continue;

            context.save ();
            context.translate ((int) (image.x + 0.5), (int) (image.y + 0.5));
            if (is_paused)
                theme.draw_paused_tile (context, size);
            else
                theme.draw_tile (context, size, tile);
            context.restore ();
        }

        /* Draw pause overlay */
        if (is_paused)
        {
            context.set_source_rgba (0, 0, 0, 0.75);
            context.paint ();

            context.select_font_face ("Sans", Cairo.FontSlant.NORMAL, Cairo.FontWeight.BOLD);
            context.set_font_size (get_allocated_width () * 0.125);

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

        var iter = HashTableIter<Tile, TileImage> (tiles);
        while (true)
        {
            Tile tile;
            TileImage image;
            if (!iter.next (out tile, out image))
                break;

            if (x >= image.x && x <= image.x + size && y >= image.y && y <= image.y + size)
            {
                selected_tile = image;
                selected_x_offset = x - image.x;
                selected_y_offset = y - image.y;
            }
        }
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

        var tile_y = (int) Math.floor ((y - y_offset) / size);
        tile_y = int.max (tile_y, 0);
        tile_y = int.min (tile_y, (int) puzzle.size - 1);

        /* Check which side we are on */
        int tile_x;
        if (x > x_offset + size * puzzle.size + gap * 0.5)
        {
            tile_x = (int) puzzle.size + (int) Math.floor ((x - (x_offset + puzzle.size * size + gap)) / size);
            tile_x = int.max (tile_x, (int) puzzle.size);
            tile_x = int.min (tile_x, 2 * (int) puzzle.size - 1);
        }
        else
        {
            tile_x = (int) Math.floor ((x - x_offset) / size);
            tile_x = int.max (tile_x, 0);
            tile_x = int.min (tile_x, (int) puzzle.size - 1);
        }

        /* Drop the tile here, or move it back if can't */
        uint selected_x, selected_y;
        puzzle.get_tile_location (selected_tile.tile, out selected_x, out selected_y);
        if (puzzle.can_switch (selected_x, selected_y, (uint) tile_x, (uint) tile_y))
            puzzle.switch_tiles (selected_x, selected_y, (uint) tile_x, (uint) tile_y);
        else
            move_tile_to_location (selected_tile, selected_x, selected_y, 0.2);
        selected_tile = null;
    }

    public override bool button_press_event (Gdk.EventButton event)
    {
        if (is_paused)
            return false;

        /* Ignore double click events */
        if (event.type != Gdk.EventType.BUTTON_PRESS)
            return false;

        if (event.button == 1)
        {
            if (selected_tile == null)
                pick_tile (event.x, event.y);
            else if (click_to_move)
                drop_tile (event.x, event.y);
        }

        return false;
    }

    public override bool button_release_event (Gdk.EventButton event)
    {
        if (event.button == 1 && selected_tile != null && !click_to_move)
            drop_tile (event.x, event.y);
            
        return false;
    }

    public override bool motion_notify_event (Gdk.EventMotion event)
    {
        if (selected_tile != null)
            move_tile (selected_tile, (int) (event.x - selected_x_offset), (int) (event.y - selected_y_offset));

        return false;
    }
}
