public class Theme
{
    /* Colors of tiles and text */
    private Cairo.Pattern tile_colors[10];
    private Cairo.Pattern paused_color;
    private Cairo.Pattern text_colors[10];

    public Theme ()
    {
        tile_colors[0] = make_color_pattern ("#000000");
        tile_colors[1] = make_color_pattern ("#C17D11");
        tile_colors[2] = make_color_pattern ("#CC0000");
        tile_colors[3] = make_color_pattern ("#F57900");
        tile_colors[4] = make_color_pattern ("#EDD400");
        tile_colors[5] = make_color_pattern ("#73D216");
        tile_colors[6] = make_color_pattern ("#3465A4");
        tile_colors[7] = make_color_pattern ("#75507B");
        tile_colors[8] = make_color_pattern ("#BABDB6");
        tile_colors[9] = make_color_pattern ("#FFFFFF");
        
        paused_color = make_color_pattern ("#CCCCCC");

        text_colors[0] = new Cairo.Pattern.rgb (1, 1, 1);
        text_colors[1] = new Cairo.Pattern.rgb (1, 1, 1);
        text_colors[2] = new Cairo.Pattern.rgb (1, 1, 1);
        text_colors[3] = new Cairo.Pattern.rgb (1, 1, 1);
        text_colors[4] = new Cairo.Pattern.rgb (0, 0, 0);
        text_colors[5] = new Cairo.Pattern.rgb (0, 0, 0);
        text_colors[6] = new Cairo.Pattern.rgb (1, 1, 1);
        text_colors[7] = new Cairo.Pattern.rgb (1, 1, 1);
        text_colors[8] = new Cairo.Pattern.rgb (0, 0, 0);
        text_colors[9] = new Cairo.Pattern.rgb (0, 0, 0);
    }

    private Cairo.Pattern make_color_pattern (string color)
    {
        var r = (hex_value (color[1]) * 16 + hex_value (color[2])) / 255.0;
        var g = (hex_value (color[3]) * 16 + hex_value (color[4])) / 255.0;
        var b = (hex_value (color[5]) * 16 + hex_value (color[6])) / 255.0;
        return new Cairo.Pattern.rgb (r, g, b);
    }

    private double hex_value (char c)
    {
        if (c >= '0' && c <= '9')
            return c - '0';
        else if (c >= 'a' && c <= 'f')
            return c - 'a' + 10;
        else if (c >= 'A' && c <= 'F')
            return c - 'A' + 10;
        else
            return 0;
    }

    public void draw_arrow (Cairo.Context context, uint size, uint gap)
    {
        var w = gap * 0.5;
        var h = size * 1.5;
        var depth = uint.min ((uint) (size * 0.025), 2);
        var dx = 1.4142 * depth;
        var dy = 6.1623 * depth;
        
        /* Background */
        context.move_to (0, 0);
        context.line_to (w, h * 0.5);
        context.line_to (w, -h * 0.5);
        context.close_path ();
        context.set_source_rgba (0, 0, 0, 0.125);
        context.fill ();

        /* Arrow highlight */
        context.move_to (w, -h * 0.5);
        context.line_to (w, h * 0.5);
        context.line_to (w - depth, h * 0.5 - dy);
        context.line_to (w - depth, -h * 0.5 + dy);
        context.close_path ();
        context.set_source_rgba (1, 1, 1, 0.125);
        context.fill ();

        /* Arrow shadow */
        context.move_to (w, -h * 0.5);
        context.line_to (0, 0);
        context.line_to (w, h * 0.5);
        context.line_to (w - depth, h * 0.5 - dy);
        context.line_to (dx, 0);
        context.line_to (w - depth, -h * 0.5 + dy);
        context.close_path ();
        context.set_source_rgba (0, 0, 0, 0.25);
        context.fill ();   
    }

    public void draw_socket (Cairo.Context context, uint size)
    {
        var depth = uint.min ((uint) (size * 0.05), 4);

        /* Background */
        context.rectangle (depth, depth, size - depth * 2, size - depth * 2);
        context.set_source_rgba (0, 0, 0, 0.125);
        context.fill ();

        /* Shadow */
        context.move_to (size, 0);
        context.line_to (0, 0);
        context.line_to (0, size);
        context.line_to (depth, size - depth);
        context.line_to (depth, depth);
        context.line_to (size - depth, depth);
        context.close_path ();
        context.set_source_rgba (0, 0, 0, 0.25);
        context.fill ();

        /* Highlight */
        context.move_to (0, size);
        context.line_to (size, size);
        context.line_to (size, 0);
        context.line_to (size - depth, depth);
        context.line_to (size - depth, size - depth);
        context.line_to (depth, size - depth);
        context.close_path ();
        context.set_source_rgba (1, 1, 1, 0.125);
        context.fill ();
    }
    
    public void draw_paused_tile (Cairo.Context context, uint size)
    {
        draw_tile_background (context, size, paused_color, paused_color, paused_color, paused_color);
    }

    public void draw_tile (Cairo.Context context, uint size, Tile? tile)
    {
        draw_tile_background (context, size, tile_colors[tile.north], tile_colors[tile.east], tile_colors[tile.south], tile_colors[tile.west]);

        context.select_font_face ("Sans", Cairo.FontSlant.NORMAL, Cairo.FontWeight.BOLD);
        context.set_font_size (size / 3.5);
        context.set_source (text_colors[tile.north]);
        draw_number (context, size * 0.5, size / 5, tile.north);
        context.set_source (text_colors[tile.south]);
        draw_number (context, size * 0.5, size * 4 / 5, tile.south);
        context.set_source (text_colors[tile.east]);
        draw_number (context, size * 4 / 5, size * 0.5, tile.east);
        context.set_source (text_colors[tile.west]);
        draw_number (context, size / 5, size * 0.5, tile.west);
    }

    private void draw_tile_background (Cairo.Context context, uint size, Cairo.Pattern north_color, Cairo.Pattern east_color, Cairo.Pattern south_color, Cairo.Pattern west_color)
    {
        var depth = uint.min ((uint) (size * 0.05), 4);
        var dx = 2.4142 * depth;
        var dy = 1.4142 * depth;

        /* North */
        context.rectangle (0, 0, size, size * 0.5);
        context.set_source (north_color);
        context.fill ();

        /* North highlight */
        context.move_to (0, 0);
        context.line_to (size, 0);
        context.line_to (size - dx, depth);
        context.line_to (dx, depth);
        context.line_to (size * 0.5, size * 0.5 - dy);
        context.line_to (size * 0.5, size * 0.5);
        context.close_path ();
        context.set_source_rgba (1, 1, 1, 0.125);
        context.fill ();

        /* North shadow */
        context.move_to (size, 0);
        context.line_to (size * 0.5, size * 0.5);
        context.line_to (size * 0.5, size * 0.5 - dy);
        context.line_to (size - dx, depth);
        context.close_path ();
        context.set_source_rgba (0, 0, 0, 0.25);
        context.fill ();

        /* South */
        context.rectangle (0, size * 0.5, size, size * 0.5);
        context.set_source (south_color);
        context.fill ();

        /* South highlight */
        context.move_to (0, size);
        context.line_to (dx, size - depth);
        context.line_to (size * 0.5, size * 0.5 + dy);
        context.line_to (size * 0.5, size * 0.5);
        context.close_path ();
        context.set_source_rgba (1, 1, 1, 0.125);
        context.fill ();

        /* South shadow */
        context.move_to (0, size);
        context.line_to (size, size);
        context.line_to (size * 0.5, size * 0.5);
        context.line_to (size * 0.5, size * 0.5 + dy);
        context.line_to (size - dx, size - depth);
        context.line_to (dx, size - depth);
        context.close_path ();
        context.set_source_rgba (0, 0, 0, 0.25);
        context.fill ();

        /* East */
        context.move_to (size, 0);
        context.line_to (size, size);
        context.line_to (size * 0.5, size * 0.5);
        context.close_path ();
        context.set_source (east_color);
        context.fill ();

        /* East highlight */
        context.move_to (size, 0);
        context.line_to (size * 0.5, size * 0.5);
        context.line_to (size, size);
        context.line_to (size - depth, size - dx);
        context.line_to (size * 0.5 + dy, size * 0.5);
        context.line_to (size - depth, dx);
        context.close_path ();
        context.set_source_rgba (1, 1, 1, 0.125);
        context.fill ();

        /* East shadow */
        context.move_to (size, 0);
        context.line_to (size, size);
        context.line_to (size - depth, size - dx);
        context.line_to (size - depth, dx);
        context.close_path ();
        context.set_source_rgba (0, 0, 0, 0.25);
        context.fill ();

        /* West */
        context.move_to (0, 0);
        context.line_to (0, size);
        context.line_to (size * 0.5, size * 0.5);
        context.close_path ();
        context.set_source (west_color);
        context.fill ();

        /* West highlight */
        context.move_to (0, 0);
        context.line_to (0, size);
        context.line_to (depth, size - dx);
        context.line_to (depth, dx);
        context.close_path ();
        context.set_source_rgba (1, 1, 1, 0.125);
        context.fill ();

        /* West shadow */
        context.move_to (0, 0);
        context.line_to (size * 0.5, size * 0.5);
        context.line_to (0, size);
        context.line_to (depth, size - dx);
        context.line_to (size * 0.5 - dy, size * 0.5);
        context.line_to (depth, dx);
        context.close_path ();
        context.set_source_rgba (0, 0, 0, 0.25);
        context.fill ();

        /* Draw outline */
        context.set_line_width (1.0);
        context.set_source_rgb (0.0, 0.0, 0.0);
        context.rectangle (0.5, 0.5, size - 1.0, size - 1.0);
        context.stroke ();
    }

    private void draw_number (Cairo.Context context, double x, double y, uint number)
    {
        var text = "%u".printf (number);
        Cairo.TextExtents extents;
        context.text_extents (text, out extents);
        context.move_to (x - extents.width / 2.0, y + extents.height / 2.0);
        context.show_text (text);
    }
}