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

private class NostalgiaTheme : Theme {
    /*\
    * * colors arrays
    \*/

    private Cairo.Pattern tile_colors [10];
    private Cairo.Pattern paused_color;

    private unowned Cairo.Pattern text_colors [10];
    private Cairo.Pattern black_text_color = new Cairo.Pattern.rgb (0, 0, 0);
    private Cairo.Pattern white_text_color = new Cairo.Pattern.rgb (1, 1, 1);

    public NostalgiaTheme () {
        tile_colors [0] = make_color_pattern ("000000");
        tile_colors [1] = make_color_pattern ("C17D11");
        tile_colors [2] = make_color_pattern ("CC0000");
        tile_colors [3] = make_color_pattern ("F57900");
        tile_colors [4] = make_color_pattern ("EDD400");
        tile_colors [5] = make_color_pattern ("73D216");
        tile_colors [6] = make_color_pattern ("3465A4");
        tile_colors [7] = make_color_pattern ("75507B");
        tile_colors [8] = make_color_pattern ("BABDB6");
        tile_colors [9] = make_color_pattern ("FFFFFF");

        paused_color = make_color_pattern ("CCCCCC");

        text_colors [0] = white_text_color;
        text_colors [1] = white_text_color;
        text_colors [2] = white_text_color;
        text_colors [3] = white_text_color;
        text_colors [4] = black_text_color;
        text_colors [5] = black_text_color;
        text_colors [6] = white_text_color;
        text_colors [7] = white_text_color;
        text_colors [8] = black_text_color;
        text_colors [9] = black_text_color;
    }

    private static Cairo.Pattern make_color_pattern (string color) {
        double r = (hex_value (color [0]) * 16.0 + hex_value (color [1])) / 255.0;
        double g = (hex_value (color [2]) * 16.0 + hex_value (color [3])) / 255.0;
        double b = (hex_value (color [4]) * 16.0 + hex_value (color [5])) / 255.0;
        return new Cairo.Pattern.rgb (r, g, b);
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
    private double arrow_depth;
    private double arrow_dx;
    private double arrow_dy;
    private double neg_arrow_dy;
    private double arrow_w;
    private double arrow_x;
    private double arrow_w_minus_depth;

    /* socket only */
    private double socket_depth;
    private double size_minus_socket_depth;
    private double size_minus_two_socket_depths;

    /* highlight */
    private Cairo.Pattern highlight_tile_pattern;

    /* tile only */
    private double tile_depth;
    private double size_minus_tile_depth;
    private double tile_dx;
    private double tile_dy;
    private double size_minus_tile_dx;
    private double half_tile_size;
    private double half_tile_size_minus_dy;
    private double half_tile_size_plus_dy;
    private double size_minus_one;

    /* numbers */
    private double font_size;
    private double north_number_y;
    private double south_number_y;
    private double east_number_x;
    private double west_number_x;

    public override void configure (uint new_size) {
        if (size != 0 && size == new_size)
            return;

        configure_arrow (new_size);
        configure_socket (new_size);

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

        /* tiles */
        tile_depth = double.min (new_size * 0.05, 4.0);
        size_minus_tile_depth = (double) new_size - tile_depth;
        tile_dx = (Math.SQRT2 + 1.0) * tile_depth;
        tile_dy = Math.SQRT2 * tile_depth;
        size_minus_tile_dx = (double) new_size - tile_dx;
        half_tile_size_minus_dy = half_tile_size - tile_dy;
        half_tile_size_plus_dy = half_tile_size + tile_dy;
        size_minus_one = (double) (new_size - 1);

        /* numbers */
        font_size = new_size / 3.5;
        north_number_y = new_size / 5.0;
        south_number_y = new_size * 4.0 / 5.0;
        east_number_x = south_number_y;
        west_number_x = north_number_y;

        /* end */
        size = new_size;
    }

    private void configure_arrow (uint new_size) {
        arrow_half_h = new_size * 0.75;
        neg_arrow_half_h = -arrow_half_h;
        arrow_depth = double.min (new_size * 0.025, 2.0);
        arrow_depth = double.max (arrow_depth, 0.0);
        arrow_dx = Math.SQRT2 * arrow_depth;
        arrow_dy = arrow_half_h - 6.1623 * arrow_depth;
        neg_arrow_dy = -arrow_dy;
        arrow_w = new_size * PuzzleView.GAP_FACTOR * 0.5;
        arrow_x = (new_size * PuzzleView.GAP_FACTOR - arrow_w) * 0.5;
        arrow_w_minus_depth = arrow_w - arrow_depth;
    }

    private void configure_socket (uint new_size) {
        socket_depth = double.min (new_size * 0.05, 4.0);
        socket_depth = double.max (socket_depth, 0.0);
        size_minus_socket_depth = (double) new_size - socket_depth;
        size_minus_two_socket_depths = (double) new_size - socket_depth * 2.0;
    }

    /*\
    * * drawing arrow
    \*/

    public override void draw_arrow (Cairo.Context context) {
        context.translate (arrow_x, 0.0);

        /* Background */
        context.move_to (0.0, 0.0);
        context.line_to (arrow_w, arrow_half_h);
        context.line_to (arrow_w, neg_arrow_half_h);
        context.close_path ();
        context.set_source_rgba (0.0, 0.0, 0.0, 0.125);
        context.fill ();

        /* Arrow highlight */
        context.move_to (arrow_w, neg_arrow_half_h);
        context.line_to (arrow_w, arrow_half_h);
        context.line_to (arrow_w_minus_depth, arrow_dy);
        context.line_to (arrow_w_minus_depth, neg_arrow_dy);
        context.close_path ();
        context.set_source_rgba (0.6, 0.6, 0.5, 0.125);
        context.fill ();

        /* Arrow shadow */
        context.move_to (arrow_w, neg_arrow_half_h);
        context.line_to (0.0, 0.0);
        context.line_to (arrow_w, arrow_half_h);
        context.line_to (arrow_w_minus_depth, arrow_dy);
        context.line_to (arrow_dx, 0.0);
        context.line_to (arrow_w_minus_depth, neg_arrow_dy);
        context.close_path ();
        context.set_source_rgba (0.0, 0.0, 0.0, 0.25);
        context.fill ();
    }

    /*\
    * * drawing sockets
    \*/

    public override void draw_socket (Cairo.Context context) {
        /* Background */
        context.rectangle (socket_depth, socket_depth, size_minus_two_socket_depths, size_minus_two_socket_depths);
        context.set_source_rgba (0.0, 0.0, 0.0, 0.125);
        context.fill ();

        /* Highlight */
        context.move_to (0.0, size);
        context.line_to (size, size);
        context.line_to (size, 0.0);
        context.line_to (size_minus_socket_depth, socket_depth);
        context.line_to (size_minus_socket_depth, size_minus_socket_depth);
        context.line_to (socket_depth, size_minus_socket_depth);
        context.close_path ();
        context.set_source_rgba (0.6, 0.6, 0.5, 0.125);
        context.fill ();

        /* Shadow */
        context.move_to (size, 0.0);
        context.line_to (0.0, 0.0);
        context.line_to (0.0, size);
        context.line_to (socket_depth, size_minus_socket_depth);
        context.line_to (socket_depth, socket_depth);
        context.line_to (size_minus_socket_depth, socket_depth);
        context.close_path ();
        context.set_source_rgba (0.0, 0.0, 0.0, 0.25);
        context.fill ();
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
        draw_tile_background (context, paused_color, paused_color, paused_color, paused_color);
    }

    public override void draw_tile (Cairo.Context context, Tile tile, bool highlight) {
        draw_tile_background (
            context, tile_colors [tile.north], tile_colors [tile.east], tile_colors [tile.south],
            tile_colors [tile.west]
        );

        context.select_font_face ("sans-serif", Cairo.FontSlant.NORMAL, Cairo.FontWeight.BOLD);
        context.set_font_size (font_size);
        draw_number (context, text_colors [tile.north], half_tile_size, north_number_y, tile.north);
        draw_number (context, text_colors [tile.south], half_tile_size, south_number_y, tile.south);
        draw_number (context, text_colors [tile.east ], east_number_x , half_tile_size, tile.east);
        draw_number (context, text_colors [tile.west ], west_number_x , half_tile_size, tile.west);

        if (highlight) {
            context.set_source_rgba (1.0, 1.0, 1.0, 0.3);
            context.rectangle (0.0, 0.0, size, size);
            context.fill ();
        }
    }

    private void draw_tile_background (Cairo.Context context, Cairo.Pattern north_color, Cairo.Pattern east_color,
                                       Cairo.Pattern south_color, Cairo.Pattern west_color) {
        /* North */
        context.rectangle (0.0, 0.0, size, half_tile_size);
        context.set_source (north_color);
        context.fill ();

        /* North highlight */
        context.move_to (0.0, 0.0);
        context.line_to (size, 0.0);
        context.line_to (size_minus_tile_dx, tile_depth);
        context.line_to (tile_dx, tile_depth);
        context.line_to (half_tile_size, half_tile_size_minus_dy);
        context.line_to (half_tile_size, half_tile_size);
        context.close_path ();
        context.set_source_rgba (1.0, 1.0, 1.0, 0.125);
        context.fill ();

        /* North shadow */
        context.move_to (size, 0.0);
        context.line_to (half_tile_size, half_tile_size);
        context.line_to (half_tile_size, half_tile_size_minus_dy);
        context.line_to (size_minus_tile_dx, tile_depth);
        context.close_path ();
        context.set_source_rgba (0.0, 0.0, 0.0, 0.25);
        context.fill ();

        /* South */
        context.rectangle (0.0, half_tile_size, size, half_tile_size);
        context.set_source (south_color);
        context.fill ();

        /* South highlight */
        context.move_to (0.0, size);
        context.line_to (tile_dx, size_minus_tile_depth);
        context.line_to (half_tile_size, half_tile_size_plus_dy);
        context.line_to (half_tile_size, half_tile_size);
        context.close_path ();
        context.set_source_rgba (1.0, 1.0, 1.0, 0.125);
        context.fill ();

        /* South shadow */
        context.move_to (0.0, size);
        context.line_to (size, size);
        context.line_to (half_tile_size, half_tile_size);
        context.line_to (half_tile_size, half_tile_size_plus_dy);
        context.line_to (size_minus_tile_dx, size_minus_tile_depth);
        context.line_to (tile_dx, size_minus_tile_depth);
        context.close_path ();
        context.set_source_rgba (0.0, 0.0, 0.0, 0.25);
        context.fill ();

        /* East */
        context.move_to (size, 0.0);
        context.line_to (size, size);
        context.line_to (half_tile_size, half_tile_size);
        context.close_path ();
        context.set_source (east_color);
        context.fill ();

        /* East highlight */
        context.move_to (size, 0.0);
        context.line_to (half_tile_size, half_tile_size);
        context.line_to (size, size);
        context.line_to (size_minus_tile_depth, size_minus_tile_dx);
        context.line_to (half_tile_size_plus_dy, half_tile_size);
        context.line_to (size_minus_tile_depth, tile_dx);
        context.close_path ();
        context.set_source_rgba (1.0, 1.0, 1.0, 0.125);
        context.fill ();

        /* East shadow */
        context.move_to (size, 0.0);
        context.line_to (size, size);
        context.line_to (size_minus_tile_depth, size_minus_tile_dx);
        context.line_to (size_minus_tile_depth, tile_dx);
        context.close_path ();
        context.set_source_rgba (0.0, 0.0, 0.0, 0.25);
        context.fill ();

        /* West */
        context.move_to (0.0, 0.0);
        context.line_to (0.0, size);
        context.line_to (half_tile_size, half_tile_size);
        context.close_path ();
        context.set_source (west_color);
        context.fill ();

        /* West highlight */
        context.move_to (0.0, 0.0);
        context.line_to (0.0, size);
        context.line_to (tile_depth, size_minus_tile_dx);
        context.line_to (tile_depth, tile_dx);
        context.close_path ();
        context.set_source_rgba (1.0, 1.0, 1.0, 0.125);
        context.fill ();

        /* West shadow */
        context.move_to (0.0, 0.0);
        context.line_to (half_tile_size, half_tile_size);
        context.line_to (0.0, size);
        context.line_to (tile_depth, size_minus_tile_dx);
        context.line_to (half_tile_size_minus_dy, half_tile_size);
        context.line_to (tile_depth, tile_dx);
        context.close_path ();
        context.set_source_rgba (0.0, 0.0, 0.0, 0.25);
        context.fill ();

        /* Draw outline */
        context.set_line_width (1.0);
        context.set_source_rgb (0.0, 0.0, 0.0);
        context.rectangle (0.5, 0.5, size_minus_one, size_minus_one);
        context.stroke ();
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
}
