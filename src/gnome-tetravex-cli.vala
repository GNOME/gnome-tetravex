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
    /* Translators: command-line help message, seen when running `gnome-tetravex-cli help`; introduces an explanation of what will happen when no command is given; nothing is NOT a keyword here, just go translate it; it would be similar to “(no command)” or “(empty)”, for example */
    private string nothing_text = _("(nothing)");
    private string help_text;

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

        /* pad nothing_text with spaces */
        if (nothing_text.length > 13)
            nothing_text = "()";
        nothing_text = "  " + nothing_text;
        for (int x = nothing_text.length; x < 16; x++)
            nothing_text += " ";

        help_text = ""
            /* Translators: command-line help message, seen when running `gnome-tetravex-cli help`; description of the action of the (as an example) “A1b2” command */
            + "\n" + "  A1b2          " + _("Invert two tiles, the one in A1, and the one in b2.")

            /* Translators: command-line help message, seen when running `gnome-tetravex-cli help`; explanation of the behavior of the (as an example) “A1b2” command; the meanings of a lowercase and of the digits are explained after */
            + "\n" + "                " + _("An uppercase targets a tile from the initial board.")

            /* Translators: command-line help message, seen when running `gnome-tetravex-cli help`; explanation of the behavior of the (as an example) “A1b2” command; the meanings of an uppercase and of the digits are explained before and after */
            + "\n" + "                " + _("A lowercase targets a tile in the left/final board.")

            /* Translators: command-line help message, seen when running `gnome-tetravex-cli help`; explanation of the behavior of the (as an example) “A1b2” command; the meanings of uppercases and lowercases are explained before */
            + "\n" + "                " + _("Digits specify the rows of the two tiles to invert.")
            + "\n"
            /* Translators: command-line help message, seen when running `gnome-tetravex-cli help`; description of the action when no command is given or when the “show” or “status” commands are given */
            + "\n" + nothing_text       + _("Show the current puzzle. Alias: “status” or “show”.")

            /* Translators: command-line help message, seen when running `gnome-tetravex-cli help`; description of the action of the “new” command */
            + "\n" + "  new           " + _("Create a new puzzle; for changing size, use --size.")

            /* Translators: command-line help message, seen when running `gnome-tetravex-cli help`; description of the action of the “solve” command */
            + "\n" + "  solve         " + _("Give up with current puzzle, and view the solution.")
            + "\n"
            /* Translators: command-line help message, seen when running `gnome-tetravex-cli help`; description of the action of the “finish” or “end” commands */
            + "\n" + "  finish        " + _("Finish current puzzle, automatically. Alias: “end”.")

            /* Translators: command-line help message, seen when running `gnome-tetravex-cli help`; explanation of the behavior of the “finish” or “end” commands; the command does something in two situations: if the puzzle has been solved in the right part of the board, and if there is only one tile remaining (“left”) on the right part of the board that could be moved automatically */
            + "\n" + "                " + _("Works for puzzles solved right or if one tile left.")
            + "\n"
            /* Translators: command-line help message, seen when running `gnome-tetravex-cli help`; description of the action of the “up” command */
            + "\n" + "  up            " + _("Move all left-board tiles up by one.")

            /* Translators: command-line help message, seen when running `gnome-tetravex-cli help`; description of the action of the “down” command */
            + "\n" + "  down          " + _("Move all left-board tiles down by one.")

            /* Translators: command-line help message, seen when running `gnome-tetravex-cli help`; description of the action of the “left” command */
            + "\n" + "  left          " + _("Move all left-board tiles left by one.")

            /* Translators: command-line help message, seen when running `gnome-tetravex-cli help`; description of the action of the “right” command */
            + "\n" + "  right         " + _("Move all left-board tiles right by one.")
            + "\n"
            /* Translators: command-line help message, seen when running `gnome-tetravex-cli help`; description of the action of the “r-up” command */
            + "\n" + "  r-up          " + _("Move all right-board tiles up by one.")

            /* Translators: command-line help message, seen when running `gnome-tetravex-cli help`; description of the action of the “r-down” command */
            + "\n" + "  r-down        " + _("Move all right-board tiles down by one.")

            /* Translators: command-line help message, seen when running `gnome-tetravex-cli help`; description of the action of the “r-left” command */
            + "\n" + "  r-left        " + _("Move all right-board tiles left by one.")

            /* Translators: command-line help message, seen when running `gnome-tetravex-cli help`; description of the action of the “r-right” command */
            + "\n" + "  r-right       " + _("Move all right-board tiles right by one.")
            + "\n";

        /* Translators: command-line message, seen when running `gnome-tetravex-cli --help` */
        set_option_context_parameter_string (_("[COMMAND]"));

        /* Translators: command-line help message, seen when running `gnome-tetravex-cli --help`; introduction of a list of options */
        set_option_context_description (_("Available commands:") + help_text);
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
            stderr.printf (_("Size could only be from 2 to 6.") + "\n");
            return Posix.EXIT_FAILURE;
        }

        if (colors < 2 || colors > 10)
        {
            /* Translators: command-line error message, displayed for an invalid number of colors; see 'gnome-tetravex-cli -c 1' */
            stderr.printf (_("There could only be between 2 and 10 colors.") + "\n");
            return Posix.EXIT_FAILURE;
        }

        if (remaining [1] != null)
        {
            /* Translators: command-line error message, displayed for an invalid CLI command; see 'gnome-tetravex-cli new A1b2' */
            stderr.printf (_("Failed to parse command-line arguments.") + "\n");
            return Posix.EXIT_FAILURE;
        }

        cli = remaining [0] ?? "";

        if ((!) cli == "help" || (!) cli == "HELP")
        {
            stdout.printf ("\n");
            /* Translators: command-line help message, seen when running `gnome-tetravex-cli help`; introduction of a list of options */
            stdout.printf (_("To use `gnome-tetravex-cli`, pass as argument:"));
            stdout.printf (help_text);
            stdout.printf ("\n");
            return Posix.EXIT_SUCCESS;
        }

        return CLI.play_cli ((!) cli, "org.gnome.TetravexCli", out settings, out saved_game, out can_restore, out puzzle, ref colors, ref game_size);
    }
}
