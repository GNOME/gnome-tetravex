/* -*- Mode: vala; tab-width: 4; indent-tabs-mode: nil; c-basic-offset: 4 -*-

   This file is part of GNOME Tetravex.

   Copyright (C) 2019 Arnaud Bonatti, with guidance from Jakub Steiner

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

private class ExtrusionTheme : Theme {
    /*\
    * * colors arrays
    \*/

    private Cairo.Pattern tile_colors_h [10];
    private Cairo.Pattern tile_colors_v [10];
    private Cairo.Pattern tile_highlights_h [10];
    private Cairo.Pattern tile_highlights_v [10];
    private Cairo.Pattern tile_shadows [10];

    private unowned Cairo.Pattern text_colors [10];
    private Cairo.Pattern black_text_color = new Cairo.Pattern.rgb (0.0, 0.0, 0.0);
    private Cairo.Pattern white_text_color = new Cairo.Pattern.rgb (1.0, 1.0, 1.0);

    private Cairo.Pattern paused_color_h;
    private Cairo.Pattern paused_color_v;

    public ExtrusionTheme () {
        // based on GNOME color palette             // white text
        make_color_pattern (0, "3d3846", true );    // black        // Dark 3
        make_color_pattern (1, "C01C28", true );    // red          // Red 4
        make_color_pattern (2, "FFA348", false );   // orange       // Orange 2
        make_color_pattern (3, "f6d32d", false );   // yellow       // Yellow 3
        make_color_pattern (4, "57E389", false );   // green        // Green 2
        make_color_pattern (5, "B5835A", true );    // brown        // Brown 2
        make_color_pattern (6, "99c1f1", false );   // light blue   // Blue 1
        make_color_pattern (7, "1a5fb4", true );    // dark blue    // Blue 5
        make_color_pattern (8, "c061cb", true );    // purple       // Purple 2
        make_color_pattern (9, "f6f5f4", false );   // white        // Light 2

        paused_color_h = make_dir_color_pattern ("CCCCCC", /* vertical */ false, 1.0);
        paused_color_v = make_dir_color_pattern ("CCCCCC", /* vertical */ true , 1.0);
    }

    private void make_color_pattern (uint position, string color, bool white_text) {
        tile_colors_h [position] = make_dir_color_pattern (color, /* vertical */ false, 1.00);
        tile_colors_v [position] = make_dir_color_pattern (color, /* vertical */ true , 1.00);
        tile_highlights_h [position] = make_dir_color_pattern (color, /* vertical */ false, 1.35);
        tile_highlights_v [position] = make_dir_color_pattern (color, /* vertical */ true , 1.35);

        tile_shadows [position] = make_shadow_color_pattern (color);

        if (white_text)
            text_colors [position] = white_text_color;
        else
            text_colors [position] = black_text_color;
    }

    private static Cairo.Pattern make_dir_color_pattern (string color, bool vertical, double color_factor) {
        double r0 = (hex_value (color [0]) * 16 + hex_value (color [1])) / 255.0 * color_factor;
        double g0 = (hex_value (color [2]) * 16 + hex_value (color [3])) / 255.0 * color_factor;
        double b0 = (hex_value (color [4]) * 16 + hex_value (color [5])) / 255.0 * color_factor;

        double r1 = double.min (r0 + 0.01, 1.0);
        double g1 = double.min (g0 + 0.01, 1.0);
        double b1 = double.min (b0 + 0.01, 1.0);

        Cairo.Pattern pattern;
        if (vertical)
            pattern = new Cairo.Pattern.linear (0.0, 0.0, 1.0, 0.0);
        else
            pattern = new Cairo.Pattern.linear (0.0, 0.0, 0.0, 1.0);
        pattern.add_color_stop_rgba (0.00, r0, g0, b0, 1.0);
        pattern.add_color_stop_rgba (0.50, r1, g1, b1, 1.0);
        pattern.add_color_stop_rgba (1.00, r0, g0, b0, 1.0);

        return pattern;
    }

    private static Cairo.Pattern make_shadow_color_pattern (string color) {
        double r = (hex_value (color [0]) * 16 + hex_value (color [1])) * 0.0032;    // * 0.82 / 255.0;
        double g = (hex_value (color [2]) * 16 + hex_value (color [3])) * 0.0032;
        double b = (hex_value (color [4]) * 16 + hex_value (color [5])) * 0.0032;

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
    private double arrow_w;
    private double arrow_x;

    private double arrow_clip_x;
    private double arrow_clip_y;
    private double arrow_clip_w;
    private double arrow_clip_h;

    /* highlight */
    private Cairo.Pattern highlight_tile_pattern;

    /* tile only */
    private const uint RADIUS_PERCENT = 8;
    private Cairo.Matrix matrix;
    private uint tile_margin;
    private int tile_size;
    private double half_tile_size;
    private double extrusion;

    private double lateral_shadow_width;
    private double west_shadow_limit;
    private double north_shadow_limit;

    /* numbers */
    private double font_size;
    private double half_tile_size_extruded;
    private double north_number_y_extruded;
    private double south_number_y_extruded;
    private double east_number_x;
    private double west_number_x;

    public override void configure (uint new_size) {
        if (size != 0 && size == new_size)
            return;

        /* arrow */
        arrow_w = new_size * PuzzleView.GAP_FACTOR / 3.0;
        arrow_x = (new_size * PuzzleView.GAP_FACTOR - arrow_w) * 0.5;
        arrow_half_h = arrow_w;
        neg_arrow_half_h = -arrow_half_h;

        arrow_clip_x = -arrow_x;
        arrow_clip_y = -new_size;
        arrow_clip_w = 2.0 * arrow_x + arrow_w;
        arrow_clip_h = 2.0 * new_size;

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
        matrix = Cairo.Matrix.identity ();
        matrix.scale (1.0 / new_size, 1.0 / new_size);
        tile_margin = uint.max ((uint) (new_size * 0.03), 2);
        tile_size = (int) new_size - (int) tile_margin * 2;
        overdraw_top = (int) (1.5 * tile_margin);
        extrusion = -overdraw_top;

        lateral_shadow_width = tile_margin + tile_size * (Math.SQRT2 / /* 2) * RADIUS_PERCENT / (2 * 100); */ 50.0);
        west_shadow_limit = new_size - lateral_shadow_width;
        north_shadow_limit = tile_margin + tile_size * (Math.SQRT2 / /* 2) * RADIUS_PERCENT / 100 */ 25.0) + extrusion;

        /* numbers */
        font_size = new_size * 4.0 / 19.0;
        half_tile_size_extruded = half_tile_size + extrusion;
        north_number_y_extruded = new_size * 4.0 / 18.0 + extrusion;
        south_number_y_extruded = new_size * 14.0 / 18.0 + extrusion;
        east_number_x = new_size * 15.0 / 19.0;
        west_number_x = new_size * 4.0 / 19.0;

        /* end */
        size = new_size;
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
        context.set_source_rgba (0.5, 0.5, 0.5, 0.4);
        context.fill ();
    }

    /*\
    * * drawing sockets
    \*/

    public override void draw_socket (Cairo.Context context) {
        context.save ();

        context.set_source_rgba (0.5, 0.5, 0.5, 0.3);
        rounded_square (context,
          /* x and y */ tile_margin, tile_margin,
          /* size    */ tile_size,
          /* radius  */ RADIUS_PERCENT);
        context.fill ();

        context.restore ();
    }

    /*\
    * * drawing highlight
    \*/

    public override void draw_highlight (Cairo.Context context, bool has_tile) {
        context.save ();

        if (has_tile)
            context.translate (0.0, extrusion);

        context.set_source (highlight_tile_pattern);
        context.rectangle (0.0, 0.0, /* width and height */ size, size);
        context.fill ();
        context.restore ();
    }

    /*\
    * * drawing tiles
    \*/

    public override void draw_paused_tile (Cairo.Context context) {
        draw_tile_shadow (context, paused_color_h, paused_color_v, paused_color_h, paused_color_v);
        draw_tile_background (context, paused_color_h, paused_color_v, paused_color_h, paused_color_v);
    }

    public override void draw_tile (Cairo.Context context, Tile tile, bool highlight) {
        tile_colors_h [tile.north].set_matrix (matrix);
        tile_colors_h [tile.east ].set_matrix (matrix);
        tile_colors_h [tile.south].set_matrix (matrix);
        tile_colors_h [tile.west ].set_matrix (matrix);
        tile_colors_v [tile.north].set_matrix (matrix);
        tile_colors_v [tile.east ].set_matrix (matrix);
        tile_colors_v [tile.south].set_matrix (matrix);
        tile_colors_v [tile.west ].set_matrix (matrix);

        draw_tile_shadow (
            context, tile_shadows [tile.north], tile_shadows [tile.east], tile_shadows [tile.south],
            tile_shadows [tile.west]
        );
        if (highlight)
            draw_tile_background (
                context, tile_highlights_h [tile.north], tile_highlights_v [tile.east],
                tile_highlights_h [tile.south], tile_highlights_v [tile.west]
            );
        else
            draw_tile_background (
                context, tile_colors_h [tile.north], tile_colors_v [tile.east], tile_colors_h [tile.south],
                tile_colors_v [tile.west]
            );

        context.select_font_face ("sans-serif", Cairo.FontSlant.NORMAL, Cairo.FontWeight.BOLD);
        context.set_font_size (font_size);
        draw_number (context, text_colors [tile.north], half_tile_size, north_number_y_extruded, tile.north);
        draw_number (context, text_colors [tile.south], half_tile_size, south_number_y_extruded, tile.south);
        draw_number (context, text_colors [tile.east ], east_number_x , half_tile_size_extruded, tile.east);
        draw_number (context, text_colors [tile.west ], west_number_x , half_tile_size_extruded, tile.west);
    }

    private void draw_tile_shadow (Cairo.Context context, Cairo.Pattern north_color, Cairo.Pattern east_color,
                                   Cairo.Pattern south_color, Cairo.Pattern west_color) {
        context.save ();

        /* Only write in the bottom of a rounded square */
        rounded_square (context,
          /* x and y */ tile_margin, tile_margin,
          /* size    */ tile_size,
          /* radius  */ RADIUS_PERCENT);
        context.clip ();

        context.rectangle (/* x and y */ 0.0, north_shadow_limit, /* width and height */ size, size);
        context.clip ();

        /* South */
        context.save ();

        context.rectangle (0.0, half_tile_size, size, half_tile_size);

        context.set_source (south_color);
        context.fill ();

        context.restore ();

        /* East */
        context.save ();

        context.rectangle (/* x and y */ west_shadow_limit, 0.0, /* width and height */ lateral_shadow_width, size);

        context.set_source (east_color);
        context.fill ();

        context.restore ();

        /* West */
        context.save ();

        context.rectangle (/* x and y */ 0.0, 0.0, /* width and height */ lateral_shadow_width, size);

        context.set_source (west_color);
        context.fill ();

        context.restore ();

        /* Draw color separation */
        context.reset_clip ();
        rounded_square (context,
          /* x and y */ tile_margin, tile_margin,
          /* size    */ tile_size,
          /* radius  */ RADIUS_PERCENT);

        context.set_source_rgba (0.0, 0.0, 0.0, 0.2);
        context.set_line_width (0.75);
        context.stroke_preserve ();
        context.clip ();

        context.move_to (lateral_shadow_width, 0.0);
        context.line_to (lateral_shadow_width, size);
        context.move_to (west_shadow_limit, 0.0);
        context.line_to (west_shadow_limit, size);
        context.set_source_rgba (0.4, 0.4, 0.4, 0.4);
        context.set_line_width (1.0);
        context.stroke ();

        context.restore ();
    }

    private void draw_tile_background (Cairo.Context context, Cairo.Pattern north_color, Cairo.Pattern east_color,
                                       Cairo.Pattern south_color, Cairo.Pattern west_color) {

        context.save ();

        context.translate (0.0, extrusion);

        /* Only write in a rounded square */
        rounded_square (context,
          /* x and y */ tile_margin, tile_margin,
          /* size    */ tile_size,
          /* radius  */ RADIUS_PERCENT);
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
        rounded_square (context,
          /* x and y */ tile_margin, tile_margin,
          /* size    */ tile_size,
          /* radius  */ RADIUS_PERCENT);

        context.set_source_rgba (0.0, 0.0, 0.0, 0.2);
        context.set_line_width (0.75);
        context.stroke_preserve ();
        context.clip ();

        context.move_to (0.0, 0.0);
        context.line_to (size, size);
        context.move_to (0.0, size);
        context.line_to (size, 0.0);
        context.set_source_rgba (0.4, 0.4, 0.4, 0.4);
        context.set_line_width (1.0);
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
