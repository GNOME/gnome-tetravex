/* -*- Mode: vala; tab-width: 4; indent-tabs-mode: nil; c-basic-offset: 4 -*-

   This file is part of GNOME Tetravex.

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

private class NeoRetroTheme : Theme {
    /*\
    * * colors arrays
    \*/

    private Cairo.Pattern tile_colors_h [10];
    private Cairo.Pattern tile_colors_v [10];
    private Cairo.Pattern tile_highlights_h [10];
    private Cairo.Pattern tile_highlights_v [10];

    private unowned Cairo.Pattern text_colors [10];
    private Cairo.Pattern black_text_color = new Cairo.Pattern.rgb (0.0, 0.0, 0.0);
    private Cairo.Pattern white_text_color = new Cairo.Pattern.rgb (1.0, 1.0, 1.0);

    private Cairo.Pattern paused_color_h;
    private Cairo.Pattern paused_color_v;

    public NeoRetroTheme () {                       // white text //  L    H    V
                                                    //          +45
        make_color_pattern (0, "000000", true );    //  0           // dark
        make_color_pattern (1, "850023", true );    // 20   75   10 // red
        make_color_pattern (2, "e26e1e", false );   // 60   75   55 // orange
        make_color_pattern (3, "cccc24", false );   // 80   75  100 // yellow
        make_color_pattern (4, "00c656", false );   // 70   75  145 // light green
        make_color_pattern (5, "005c59", true );    // 30   75  190 // dark green
        make_color_pattern (6, "008de0", false );   // 50   75  235 // light blue
        make_color_pattern (7, "001d87", true );    // 10   75  280 // dark blue
        make_color_pattern (8, "a021a6", true );    // 40   75  325 // purple
        make_color_pattern (9, "e2e2e2", false );   // 90           // white

        paused_color_h = make_dir_color_pattern ("CCCCCC", /* vertical */ false, 1.0);
        paused_color_v = make_dir_color_pattern ("CCCCCC", /* vertical */ true , 1.0);
    }

    private void make_color_pattern (uint position, string color, bool white_text) {
        tile_colors_h [position] = make_dir_color_pattern (color, /* vertical */ false, 1.0);
        tile_colors_v [position] = make_dir_color_pattern (color, /* vertical */ true , 1.0);
        tile_highlights_h [position] = make_dir_color_pattern (color, /* vertical */ false, 1.4);
        tile_highlights_v [position] = make_dir_color_pattern (color, /* vertical */ true , 1.4);

        if (white_text)
            text_colors [position] = white_text_color;
        else
            text_colors [position] = black_text_color;
    }

    private static Cairo.Pattern make_dir_color_pattern (string color, bool vertical, double color_factor) {
        double r0 = (hex_value (color [0]) * 16 + hex_value (color [1])) / 255.0 * color_factor;
        double g0 = (hex_value (color [2]) * 16 + hex_value (color [3])) / 255.0 * color_factor;
        double b0 = (hex_value (color [4]) * 16 + hex_value (color [5])) / 255.0 * color_factor;

        double r1 = double.min (r0 + 0.10, 1.0);
        double g1 = double.min (g0 + 0.10, 1.0);
        double b1 = double.min (b0 + 0.10, 1.0);

        double r2 = double.min (r0 + 0.25, 1.0);
        double g2 = double.min (g0 + 0.25, 1.0);
        double b2 = double.min (b0 + 0.25, 1.0);

        double r5 = double.min (r0 + 0.15, 1.0);
        double g5 = double.min (g0 + 0.15, 1.0);
        double b5 = double.min (b0 + 0.15, 1.0);

        Cairo.Pattern pattern;
        if (vertical)
            pattern = new Cairo.Pattern.linear (0.0, 0.0, 1.0, 0.0);
        else
            pattern = new Cairo.Pattern.linear (0.0, 0.0, 0.0, 1.0);
        pattern.add_color_stop_rgba (0.00, r2, g2, b2, 1.0);
        pattern.add_color_stop_rgba (0.08, r1, g1, b1, 1.0);
        pattern.add_color_stop_rgba (0.50, r5, g5, b5, 1.0);
        pattern.add_color_stop_rgba (0.92, r1, g1, b1, 1.0);
        pattern.add_color_stop_rgba (1.00, r0, g0, b0, 1.0);

        return pattern;
    }

    private static double hex_value (char c) {
        if (c >= '0' && c <= '9')
            return c - '0';
        else if (c >= 'a' && c <= 'f')
            return c - 'a' + 10;
        else if (c >= 'A' && c <= 'F')
            return c - 'A' + 10;
        else
            return 0.0;
    }

    /*\
    * * configuring variables
    \*/

    private uint size;

    /* arrow */
    private double arrow_half_h;
    private double neg_arrow_half_h;
    private double arrow_w;
    private double arrow_x;

    private double arrow_clip_x;
    private double arrow_clip_y;
    private double arrow_clip_w;
    private double arrow_clip_h;

    /* socket */
    private uint socket_margin;
    private int socket_size;
    private Cairo.MeshPattern socket_pattern;
    private Cairo.Matrix matrix;                // also used for tile

    /* highlight */
    private Cairo.Pattern highlight_tile_pattern;

    /* tile only */
    private uint tile_margin;
    private int tile_size;
    private double half_tile_size;

    /* numbers */
    private double font_size;
    private double north_number_y;
    private double south_number_y;
    private double east_number_x;
    private double west_number_x;

    public override void configure (uint new_size) {
        if (size != 0 && size == new_size)
            return;

        /* arrow */
        arrow_half_h = new_size * 0.5;
        neg_arrow_half_h = -arrow_half_h;
        arrow_w = new_size * PuzzleView.GAP_FACTOR * 0.5;
        arrow_x = (new_size * PuzzleView.GAP_FACTOR - arrow_w) * 0.5;

        arrow_clip_x = -arrow_x;
        arrow_clip_y = -new_size;
        arrow_clip_w = 2.0 * arrow_x + arrow_w;
        arrow_clip_h = 2.0 * new_size;

        /* socket and tile */
        matrix = Cairo.Matrix.identity ();
        matrix.scale (1.0 / new_size, 1.0 / new_size);

        /* socket */
        socket_margin = uint.min ((uint) (new_size * 0.05), 2);
        socket_size = (int) new_size - (int) socket_margin * 2;

        init_socket_pattern ();

        /* highlight */
        half_tile_size = new_size * 0.5;    // also for tile
        double highlight_radius = new_size * 0.45;
        highlight_tile_pattern = new Cairo.Pattern.radial (half_tile_size, half_tile_size, 0.0,
                                                           half_tile_size, half_tile_size, highlight_radius);
        highlight_tile_pattern.add_color_stop_rgba (0.0, 1.0, 1.0, 1.0, 1.0);
        highlight_tile_pattern.add_color_stop_rgba (0.2, 1.0, 1.0, 1.0, 0.8);
        highlight_tile_pattern.add_color_stop_rgba (0.3, 1.0, 1.0, 1.0, 0.5);
        highlight_tile_pattern.add_color_stop_rgba (0.4, 1.0, 1.0, 1.0, 0.2);
        highlight_tile_pattern.add_color_stop_rgba (0.5, 1.0, 1.0, 1.0, 0.1);
        highlight_tile_pattern.add_color_stop_rgba (1.0, 1.0, 1.0, 1.0, 0.0);

        /* tile */
        tile_margin = uint.min ((uint) (new_size * 0.05), 2) - 1;
        tile_size = (int) new_size - (int) tile_margin * 2;

        /* numbers */
        font_size = new_size * 4.0 / 19.0;
        north_number_y = new_size * 4.0 / 18.0;
        south_number_y = new_size * 14.0 / 18.0;
        east_number_x = new_size * 15.0 / 19.0;
        west_number_x = new_size * 4.0 / 19.0;

        /* end */
        size = new_size;
    }

    private void init_socket_pattern () {
        socket_pattern = new Cairo.MeshPattern ();
        socket_pattern.begin_patch ();
        socket_pattern.move_to (0.0, 0.0);
        socket_pattern.line_to (1.0, 0.0);
        socket_pattern.line_to (1.0, 1.0);
        socket_pattern.line_to (0.0, 1.0);
        socket_pattern.set_corner_color_rgba (0, 0.3, 0.3, 0.3, 0.3);
        socket_pattern.set_corner_color_rgba (1, 0.4, 0.4, 0.4, 0.3);
        socket_pattern.set_corner_color_rgba (2, 0.7, 0.7, 0.7, 0.3);
        socket_pattern.set_corner_color_rgba (3, 0.6, 0.6, 0.6, 0.3);
        socket_pattern.end_patch ();
        socket_pattern.set_matrix (matrix);
    }

    /*\
    * * drawing arrow
    \*/

    public override void draw_arrow (Cairo.Context context) {
        context.translate (arrow_x, 0.0);

        /*\
         *  To ease the drawing, we base the arrow on a simple shape. We clip
         *  the exterior of this shape, by clipping a large rectangle around,
         *  and excluding the shape. Then we stroke the shape, only drawing a
         *  border at its exterior; two times, the first a bit larger, making
         *  a border. Then, we reset the exterior clip, we clip the shape for
         *  real (its interior), and we fill it (two times) with same colors.
        \*/

        /* clipping exterior */

        context.rectangle (arrow_clip_x, arrow_clip_y, arrow_clip_w, arrow_clip_h);

        context.move_to (arrow_w, arrow_half_h);
        context.line_to (0.0, 0.0);
        context.line_to (arrow_w, neg_arrow_half_h);
        context.curve_to (0.0, 10.0,                // Bézier control point for origin
                          0.0, -10.0,               // Bézier control point for destination
                          arrow_w, arrow_half_h);   // destination

        context.clip ();

        /* drawing exterior border */

        context.move_to (arrow_w, arrow_half_h);
        context.line_to (0.0, 0.0);
        context.line_to (arrow_w, neg_arrow_half_h);
        context.curve_to (0.0, 10.0,                // Bézier control point for origin
                          0.0, -10.0,               // Bézier control point for destination
                          arrow_w, arrow_half_h);   // destination

        context.set_line_join (Cairo.LineJoin.ROUND);
        context.set_line_cap (Cairo.LineCap.ROUND);

        context.set_line_width (14.0);
        context.set_source_rgba (0.4, 0.4, 0.4, 0.3);  // fill color 1, including border
        context.stroke_preserve ();

        context.set_line_width (12.0);
        context.set_source_rgba (1.0, 1.0, 1.0, 0.1);    // fill color 2
        context.stroke_preserve ();

        /* filling interior */

        context.reset_clip ();  // forget the border clip
        context.clip ();       // clip to the current path

        context.set_source_rgba (0.4, 0.4, 0.4, 0.3);  // fill color 1
        context.fill_preserve ();

        context.set_source_rgba (1.0, 1.0, 1.0, 0.1);    // fill color 2
        context.fill ();
    }

    /*\
    * * drawing sockets
    \*/

    public override void draw_socket (Cairo.Context context) {
        context.save ();

        context.set_source (socket_pattern);

        rounded_square (context,
          /* x and y */ socket_margin, socket_margin,
          /* size    */ socket_size,
          /* radius  */ 8);
        context.fill_preserve ();

        context.set_line_width (1.0);
        context.set_source_rgba (0.4, 0.4, 0.4, 0.3);
        context.stroke ();

        context.restore ();
    }

    /*\
    * * drawing highlight
    \*/

    public override void draw_highlight (Cairo.Context context, bool has_tile) {
        context.set_source (highlight_tile_pattern);
        context.rectangle (0.0, 0.0, /* width and height */ size, size);
        context.fill ();
    }

    /*\
    * * drawing tiles
    \*/

    public override void draw_paused_tile (Cairo.Context context) {
        draw_tile_background (context, paused_color_h, paused_color_v, paused_color_h, paused_color_v);
    }

    public override void draw_tile (Cairo.Context context, Tile tile, bool highlight) {
        if (highlight) {
            tile_highlights_h [tile.north].set_matrix (matrix);
            tile_highlights_h [tile.south].set_matrix (matrix);
            tile_highlights_v [tile.east ].set_matrix (matrix);
            tile_highlights_v [tile.west ].set_matrix (matrix);

            draw_tile_background (
                context, tile_highlights_h [tile.north], tile_highlights_v [tile.east],
                tile_highlights_h [tile.south], tile_highlights_v [tile.west]
            );
        }
        else {
            tile_colors_h [tile.north].set_matrix (matrix);
            tile_colors_h [tile.south].set_matrix (matrix);
            tile_colors_v [tile.east ].set_matrix (matrix);
            tile_colors_v [tile.west ].set_matrix (matrix);

            draw_tile_background (
                context, tile_colors_h [tile.north], tile_colors_v [tile.east],
                tile_colors_h [tile.south], tile_colors_v [tile.west]
            );
        }

        context.select_font_face ("sans-serif", Cairo.FontSlant.NORMAL, Cairo.FontWeight.BOLD);
        context.set_font_size (font_size);
        draw_number (context, text_colors [tile.north], half_tile_size, north_number_y, tile.north);
        draw_number (context, text_colors [tile.south], half_tile_size, south_number_y, tile.south);
        draw_number (context, text_colors [tile.east ], east_number_x , half_tile_size, tile.east);
        draw_number (context, text_colors [tile.west ], west_number_x , half_tile_size, tile.west);
    }

    private void draw_tile_background (Cairo.Context context, Cairo.Pattern north_color, Cairo.Pattern east_color,
                                       Cairo.Pattern south_color, Cairo.Pattern west_color) {
        context.save ();

        /* Only write in a rounded square */
        rounded_square (context,
          /* x and y */ tile_margin, tile_margin,
          /* size    */ tile_size,
          /* radius  */ 8);
        context.clip_preserve ();

        /* North */
        context.save ();

        // fill all the clip, part of it will be rewritten after */

        context.set_source (north_color);
        context.fill ();

        context.restore ();

        /* South */
        context.save ();

        context.rectangle (0.0, half_tile_size, size, half_tile_size);

        context.set_source (south_color);
        context.fill ();

        context.restore ();

        /* East */
        context.save ();

        context.move_to (size, 0.0);
        context.line_to (size, size);
        context.line_to (half_tile_size, half_tile_size);
        context.close_path ();

        context.set_source (east_color);
        context.fill ();

        context.restore ();

        /* West */
        context.save ();

        context.move_to (0.0, 0.0);
        context.line_to (0.0, size);
        context.line_to (half_tile_size, half_tile_size);
        context.close_path ();

        context.set_source (west_color);
        context.fill ();

        context.restore ();

        /* Draw outline and diagonal lines */
        context.reset_clip ();
        context.set_line_width (1.5);
        rounded_square (context,
          /* x and y */ tile_margin, tile_margin,
          /* size    */ tile_size,
          /* radius  */ 8);

        context.set_source_rgba (0.4, 0.4, 0.4, 0.4);
        context.stroke_preserve ();
        context.clip ();

        context.move_to (0.0, 0.0);
        context.line_to (size, size);
        context.move_to (0.0, size);
        context.line_to (size, 0.0);
        context.stroke ();

        context.restore ();
    }

    private static void draw_number (Cairo.Context context, Cairo.Pattern text_color, double x, double y,
                                     uint8 number) {
        context.set_source (text_color);

        string text = "%hu".printf (number);
        Cairo.TextExtents extents;
        context.text_extents (text, out extents);
        context.move_to (x - extents.width / 2.0, y + extents.height / 2.0);
        context.show_text (text);
    }

    /*\
    * * drawing utilities
    \*/

    private const double HALF_PI = Math.PI_2;
    private static void rounded_square (Cairo.Context context, double x, double y, int size, double radius_percent) {
        if (radius_percent <= 0.0)
            assert_not_reached ();  // could be replaced by drawing a rectangle, but not used here

        if (radius_percent > 50.0)
            radius_percent = 50.0;
        double radius_arc = radius_percent * size / 100.0;
        double x1 = x + radius_arc;
        double y1 = y + radius_arc;
        double x2 = x + size - radius_arc;
        double y2 = y + size - radius_arc;

        context.move_to (x, y1);
        context.arc (x1, y1, radius_arc, Math.PI, -HALF_PI);
        context.arc (x2, y1, radius_arc, -HALF_PI, 0.0);
        context.arc (x2, y2, radius_arc, 0.0, HALF_PI);
        context.arc (x1, y2, radius_arc, HALF_PI, Math.PI);
        context.close_path ();
    }
}
