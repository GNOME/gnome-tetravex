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

private class TetravexCli : GLib.Application
{
    private string help_text = "\n  A1b2          " + "Invert two tiles, the one in A1, and the one in b2."
                             + "\n                " + "An uppercase targets a tile from the initial board."
                             + "\n                " + "A lowercase targets a tile in the left/final board."
                             + "\n                " + "Digits specify the rows of the two tiles to invert."
                             + "\n"
                             + "\n  (nothing)     " + "Show the current puzzle. Alias: “status” or “show”."
                             + "\n  new           " + "Create a new puzzle; for changing size, use --size."
                             + "\n  solve         " + "Give up with current puzzle, and view the solution."
                             + "\n"
                             + "\n  finish        " + "Finish current puzzle, automatically. Alias: “end”."
                             + "\n                " + "Works for puzzles solved right or if one tile left."
                             + "\n"
                             + "\n  up            " + "Move all left-board tiles up by one."
                             + "\n  down          " + "Move all left-board tiles down by one."
                             + "\n  left          " + "Move all left-board tiles left by one."
                             + "\n  right         " + "Move all left-board tiles right by one."
                             + "\n"
                             + "\n  r-up          " + "Move all right-board tiles up by one."
                             + "\n  r-down        " + "Move all right-board tiles down by one."
                             + "\n  r-left        " + "Move all right-board tiles left by one."
                             + "\n  r-right       " + "Move all right-board tiles right by one."
                             + "\n";

    private const string KEY_GRID_SIZE = "grid-size";

    private Variant saved_game;
    private bool can_restore = false;

    private static int game_size = int.MIN;
    private static int colors = 10;
    private static string? cli = null;

    private GLib.Settings settings;

    private Puzzle puzzle;

    private static string? [] remaining = new string? [2];
    private const OptionEntry [] option_entries =
    {
        /* Translators: command-line option description, see 'gnome-tetravex-cli --help' */
        { "colors",  'c', OptionFlags.NONE, OptionArg.INT,  ref colors,                 N_("Set number of colors (2-10)"),

        /* Translators: in the command-line options description, text to indicate the user should specify colors number, see 'gnome-tetravex-cli --help' */
                                                                                        N_("NUMBER") },

        /* Translators: command-line option description, see 'gnome-tetravex-cli --help' */
        { "size",    's', OptionFlags.NONE, OptionArg.INT,  ref game_size,              N_("Set size of board (2-6)"),

        /* Translators: in the command-line options description, text to indicate the user should specify size, see 'gnome-tetravex-cli --help' */
                                                                                        N_("SIZE") },

        /* Translators: command-line option description, see 'gnome-tetravex-cli --help' */
        { "version", 'v', OptionFlags.NONE, OptionArg.NONE, null,                       N_("Print release version and exit"),   null },

        { OPTION_REMAINING, 0, OptionFlags.NONE, OptionArg.STRING_ARRAY, ref remaining, "args", null },
        {}
    };

    private static int main (string[] args)
    {
        Intl.setlocale (LocaleCategory.ALL, "");
        Intl.bindtextdomain (GETTEXT_PACKAGE, LOCALEDIR);
        Intl.bind_textdomain_codeset (GETTEXT_PACKAGE, "UTF-8");
        Intl.textdomain (GETTEXT_PACKAGE);

        TetravexCli app = new TetravexCli ();
        return app.run (args);
    }

    private TetravexCli ()
    {
        Object (application_id: "org.gnome.TetravexCli", flags: ApplicationFlags.FLAGS_NONE);

        set_option_context_parameter_string ("[COMMAND]");
        set_option_context_description ("Available commands:" + help_text);
        add_main_option_entries (option_entries);
    }

    protected override int handle_local_options (GLib.VariantDict options)
    {
        if (options.contains ("version")
         || remaining [0] != null && (!) remaining [0] == "version")
        {
            /* NOTE: Is not translated so can be easily parsed */
            stderr.printf ("%1$s %2$s\n", "gnome-tetravex-cli", VERSION);
            return Posix.EXIT_SUCCESS;
        }

        if (game_size != int.MIN && (game_size < 2 || game_size > 6))
        {
            /* Translators: command-line error message, displayed on invalid game size request; see 'gnome-tetravex-cli -s 1' */
            stderr.printf (N_("Size could only be from 2 to 6.\n"));
            return Posix.EXIT_FAILURE;
        }

        if (colors < 2 || colors > 10)
        {
            /* Translators: command-line error message, displayed for an invalid number of colors; see 'gnome-tetravex-cli -c 1' */
            stderr.printf (N_("There could only be between 2 and 10 colors.\n"));
            return Posix.EXIT_FAILURE;
        }

        if (remaining [1] != null)
        {
            /* Translators: command-line error message, displayed for an invalid CLI command; see 'gnome-tetravex-cli new A1b2' */
            stderr.printf (N_("Failed to parse command-line arguments.\n"));
            return Posix.EXIT_FAILURE;
        }

        cli = remaining [0] ?? "";

        if ((!) cli == "help" || (!) cli == "HELP")
        {
            stdout.printf ("\n");
            stdout.printf ("To use `gnome-tetravex-cli`, pass as arg:");
            stdout.printf (help_text);
            stdout.printf ("\n");
            return Posix.EXIT_SUCCESS;
        }

        return CLI.play_cli ((!) cli, "org.gnome.TetravexCli", out settings, out saved_game, out can_restore, out puzzle, ref colors, ref game_size);
    }
}
