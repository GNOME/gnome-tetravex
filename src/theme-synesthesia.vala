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

private class SynesthesiaTheme : Theme {
    /*\
    * * colors arrays
    \*/

    private Cairo.Pattern text_colors [10];
    private Cairo.Pattern paused_color;
    private Cairo.Pattern tile_color;
    private Cairo.Pattern highlight_color;

    public SynesthesiaTheme () {
        // based on GNOME color palette
        text_colors [0] = make_color_pattern ("3d3846");    // black        // Dark 3
        text_colors [1] = make_color_pattern ("E01B24");    // red          // Red 3
        text_colors [2] = make_color_pattern ("FF7800");    // orange       // Orange 3
        text_colors [3] = make_color_pattern ("F8E45C");    // yellow       // Yellow 2
        text_colors [4] = make_color_pattern ("57E389");    // green        // Green 2
        text_colors [5] = make_color_pattern ("865E3C");    // brown        // Brown 4
        text_colors [6] = make_color_pattern ("1CD5D8");    // green blue
        text_colors [7] = make_color_pattern ("1a5fb4");    // dark blue    // Blue 5
        text_colors [8] = make_color_pattern ("9141AC");    // purple       // Purple 3
        text_colors [9] = make_color_pattern ("f6f5f4");    // white        // Light 2

        paused_color = make_color_pattern ("CCCCCC");
        tile_color = make_color_pattern ("CDCADA", /* transparency */ true);
        highlight_color = make_color_pattern ("DACACD", /* transparency */ true);
    }

    private static Cairo.Pattern make_color_pattern (string color, bool transparency = false) {
        double r = (hex_value (color [0]) * 16 + hex_value (color [1])) / 255.0;
        double g = (hex_value (color [2]) * 16 + hex_value (color [3])) / 255.0;
        double b = (hex_value (color [4]) * 16 + hex_value (color [5])) / 255.0;
        return new Cairo.Pattern.rgba (r, g, b, transparency ? 0.6 : 1.0);
    }

    private static double hex_value (char c) {
        if (c >= '0' && c <= '9')
            return c - '0';
        else if (c >= 'a' && c <= 'f')
            return c - 'a' + 10;
        else if (c >= 'A' && c <= 'F')
            return c - 'A' + 10;
        else
            return 0;
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

    /* socket */
    private uint tile_depth;
    private double size_minus_tile_depth;
    private double size_minus_two_tile_depths;    // socket only
    private Cairo.MeshPattern socket_pattern;
    private Cairo.Matrix matrix;                // also used for tile

    /* highlight */
    private Cairo.Pattern highlight_tile_pattern;

    /* tile only */
    private uint tile_margin;
    private int tile_size;
    private double half_size;
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
        arrow_w = new_size * PuzzleView.GAP_FACTOR * 0.5;
        arrow_x = (new_size * PuzzleView.GAP_FACTOR - arrow_w) * 0.5;
        arrow_half_h = arrow_w / Math.sqrt (3.0);
        neg_arrow_half_h = -arrow_half_h;

        /* socket and tiles */
        matrix = Cairo.Matrix.identity ();
        matrix.scale (1.0 / new_size, 1.0 / new_size);

        /* socket */
        tile_depth = uint.min ((uint) (new_size * 0.05), 4);
        size_minus_tile_depth = (double) new_size - tile_depth;
        size_minus_two_tile_depths = (double) (new_size - tile_depth * 2);
        init_socket_pattern ();

        /* highlight */
        half_size = new_size * 0.5;    // also for tile
        double highlight_radius = new_size * 0.45;
        highlight_tile_pattern = new Cairo.Pattern.radial (half_size, half_size, 0.0,
                                                           half_size, half_size, highlight_radius);
        highlight_tile_pattern.add_color_stop_rgba (0.0, 1.0, 1.0, 1.0, 1.0);
        highlight_tile_pattern.add_color_stop_rgba (0.2, 1.0, 1.0, 1.0, 0.8);
        highlight_tile_pattern.add_color_stop_rgba (0.3, 1.0, 1.0, 1.0, 0.5);
        highlight_tile_pattern.add_color_stop_rgba (0.4, 1.0, 1.0, 1.0, 0.2);
        highlight_tile_pattern.add_color_stop_rgba (0.5, 1.0, 1.0, 1.0, 0.1);
        highlight_tile_pattern.add_color_stop_rgba (1.0, 1.0, 1.0, 1.0, 0.0);

        /* tile */
        tile_margin = uint.min ((uint) (new_size * 0.05), 2) - 1;
        tile_size = (int) new_size - (int) tile_margin * 2;
        half_tile_size = tile_size * 0.5;

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
        socket_pattern.move_to (0.5, 0.0);
        socket_pattern.line_to (1.0, 0.5);
        socket_pattern.line_to (0.5, 1.0);
        socket_pattern.line_to (0.0, 0.5);
        socket_pattern.set_corner_color_rgba (0, 0.45, 0.45, 0.45, 0.5);
        socket_pattern.set_corner_color_rgba (1, 0.6 , 0.6 , 0.6 , 0.5);
        socket_pattern.set_corner_color_rgba (2, 0.7 , 0.7 , 0.7 , 0.5);
        socket_pattern.set_corner_color_rgba (3, 0.55, 0.55, 0.55, 0.5);
        socket_pattern.end_patch ();
        socket_pattern.set_matrix (matrix);
    }

    /*\
    * * drawing arrow
    \*/

    public override void draw_arrow (Cairo.Context context) {
        context.translate (arrow_x, 0.0);

        context.move_to (0.0, 0.0);
        context.line_to (arrow_w, arrow_half_h);
        context.line_to (arrow_w, neg_arrow_half_h);
        context.close_path ();
        context.set_source_rgba (0.5, 0.5, 0.6, 0.4);
        context.fill ();
    }

    /*\
    * * drawing sockets
    \*/

    public override void draw_socket (Cairo.Context context) {
        context.save ();

        context.translate (tile_margin, tile_margin);

        context.set_source (socket_pattern);
        context.move_to (half_tile_size, 0.0);
        context.line_to (tile_size, half_tile_size);
        context.line_to (half_tile_size, tile_size);
        context.line_to (0.0, half_tile_size);
        context.close_path ();
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
        draw_tile_background (context, paused_color);
    }

    public override void draw_tile (Cairo.Context context, Tile tile, bool highlight) {
        if (highlight)
            draw_tile_background (context, highlight_color);
        else
            draw_tile_background (context, tile_color);

        context.select_font_face ("Cantarell", Cairo.FontSlant.NORMAL, Cairo.FontWeight.BOLD);
        context.set_font_size (font_size);
        draw_number (context, text_colors [tile.north], half_size, north_number_y, tile.north);
        draw_number (context, text_colors [tile.south], half_size, south_number_y, tile.south);
        draw_number (context, text_colors [tile.east ], east_number_x , half_size, tile.east);
        draw_number (context, text_colors [tile.west ], west_number_x , half_size, tile.west);
    }

    private void draw_tile_background (Cairo.Context context, Cairo.Pattern pattern) {
        context.save ();

        context.rectangle (0.0, 0.0, size, size);
        context.clip ();

        context.translate (tile_margin, tile_margin);

        context.set_source (pattern);
        context.rectangle (0.0, 0.0, tile_size, tile_size);
        context.fill_preserve ();

        context.set_line_width (1.0);
        context.set_source_rgba (0.5, 0.5, 0.6, 0.4);
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
}
