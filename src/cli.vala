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

private const string KEY_GRID_SIZE = "grid-size";

namespace CLI
{
    private static int play_cli (string cli, string schema_name, out GLib.Settings settings, out Variant saved_game, out bool can_restore, out Puzzle puzzle, ref int colors, ref int game_size)
    {
        settings = new GLib.Settings (schema_name);

        saved_game = settings.get_value ("saved-game");
        can_restore = Puzzle.is_valid_saved_game (saved_game, /* restore finished game */ true);

        if ((game_size != int.MIN || colors != 10) && cli != "new")
        {
            /* Translators: command-line error message, displayed if the user plays in CLI and tries to use the change the number of colors or the game size while not specifying a new game; try `gnome-tetravex --cli show --size 3` */
            warning (_("Game size and colors number can only be given for new puzzles.") + "\n");
            puzzle = new Puzzle (2, 10); /* garbage */
            return Posix.EXIT_FAILURE;
        }

        uint8 size;
        bool new_puzzle;
        if (game_size != int.MIN)
        {
            settings.set_int (KEY_GRID_SIZE, game_size);
            size = (uint8) game_size;
            puzzle = new Puzzle (size, (uint8) colors);
            new_puzzle = true;
        }
        else if (colors != 10 || cli == "new")
        {
            size = (uint8) settings.get_int (KEY_GRID_SIZE);
            puzzle = new Puzzle (size, (uint8) colors);
            new_puzzle = true;
        }
        else if (can_restore)
        {
            puzzle = new Puzzle.restore ((!) saved_game);
            size = puzzle.size;
            new_puzzle = false;
        }
        else
        {
            size = (uint8) settings.get_int (KEY_GRID_SIZE);
            puzzle = new Puzzle (size, 10);
            new_puzzle = true;
        }

        switch (cli)    // TODO add translated commands? add translations?
        {
            case "help":
            case "HELP":
                assert_not_reached ();  // should be handled by the caller

            case "":
            case "show":
            case "status":
                if (new_puzzle)
                    break;

                print_board (puzzle, size);
                return Posix.EXIT_SUCCESS;

            case "new": // creation already handled, need saving
                break;

            case "up":
            case "l-up":
                /* Translators: command-line error message, displayed if the user plays in CLI and tries to use the “up” command while it cannot be performed; try `gnome-tetravex --cli new; gnome-tetravex --cli up` */
                if (!cli_move_tiles (puzzle, new_puzzle, true, Direction.UP, _("Cannot move up left-board tiles.")))
                    return Posix.EXIT_FAILURE;
                break;
            case "down":
            case "l-down":
                /* Translators: command-line error message, displayed if the user plays in CLI and tries to use the “down” command while it cannot be performed; try `gnome-tetravex --cli new; gnome-tetravex --cli down` */
                if (!cli_move_tiles (puzzle, new_puzzle, true, Direction.DOWN, _("Cannot move down left-board tiles.")))
                    return Posix.EXIT_FAILURE;
                break;
            case "left":
            case "l-left":
                /* Translators: command-line error message, displayed if the user plays in CLI and tries to use the “left” command while it cannot be performed; try `gnome-tetravex --cli new; gnome-tetravex --cli left` */
                if (!cli_move_tiles (puzzle, new_puzzle, true, Direction.LEFT, _("Cannot move left left-board tiles.")))
                    return Posix.EXIT_FAILURE;
                break;
            case "right":
            case "l-right":
                /* Translators: command-line error message, displayed if the user plays in CLI and tries to use the “right” command while it cannot be performed; try `gnome-tetravex --cli new; gnome-tetravex --cli right` */
                if (!cli_move_tiles (puzzle, new_puzzle, true, Direction.RIGHT, _("Cannot move right left-board tiles.")))
                    return Posix.EXIT_FAILURE;
                break;

            case "r-up":
                /* Translators: command-line error message, displayed if the user plays in CLI and tries to use the “r-up” command while it cannot be performed; try `gnome-tetravex --cli new; gnome-tetravex --cli r-up` */
                if (!cli_move_tiles (puzzle, new_puzzle, false, Direction.UP, _("Cannot move up right-board tiles.")))
                    return Posix.EXIT_FAILURE;
                break;
            case "r-down":
                /* Translators: command-line error message, displayed if the user plays in CLI and tries to use the “r-down” command while it cannot be performed; try `gnome-tetravex --cli new; gnome-tetravex --cli r-down` */
                if (!cli_move_tiles (puzzle, new_puzzle, false, Direction.DOWN, _("Cannot move down right-board tiles.")))
                    return Posix.EXIT_FAILURE;
                break;
            case "r-left":
                /* Translators: command-line error message, displayed if the user plays in CLI and tries to use the “r-left” command while it cannot be performed; try `gnome-tetravex --cli new; gnome-tetravex --cli r-left` */
                if (!cli_move_tiles (puzzle, new_puzzle, false, Direction.LEFT, _("Cannot move left right-board tiles.")))
                    return Posix.EXIT_FAILURE;
                break;
            case "r-right":
                /* Translators: command-line error message, displayed if the user plays in CLI and tries to use the “r-right” command while it cannot be performed; try `gnome-tetravex --cli new; gnome-tetravex --cli r-right` */
                if (!cli_move_tiles (puzzle, new_puzzle, false, Direction.RIGHT, _("Cannot move right right-board tiles.")))
                    return Posix.EXIT_FAILURE;
                break;

            case "end":
            case "finish":
                if (new_puzzle || puzzle.is_solved)
                {
                    puzzle_is_solved_message (/* alternative message */ true);
                    return Posix.EXIT_FAILURE;
                }

                if (puzzle.is_solved_right)
                    puzzle.finish (/* duration */ 0);
                else if (!puzzle.move_last_tile_if_possible ())
                {
                    /* Translators: command-line error message, displayed if the user plays in CLI and tries to use the “finish” command while the saved puzzle cannot be automatically finished; try `gnome-tetravex --cli new; gnome-tetravex --cli finish` */
                    warning (_("Cannot finish automatically. If you want to give up and view the solution, use “solve”.") + "\n");
                    return Posix.EXIT_FAILURE;
                }
                break;

            case "solve":
                if (new_puzzle || puzzle.is_solved)
                {
                    puzzle_is_solved_message (/* alternative message */ true);
                    return Posix.EXIT_FAILURE;
                }

                puzzle.solve ();
                break;

            default:
                if (new_puzzle || puzzle.is_solved)
                {
                    puzzle_is_solved_message ();
                    return Posix.EXIT_FAILURE;
                }

                uint8 tile_1_x;
                uint8 tile_1_y;
                uint8 tile_2_x;
                uint8 tile_2_y;
                if (!parse_cli (cli, size, out tile_1_x, out tile_1_y, out tile_2_x, out tile_2_y))
                {
                    /* Translators: command-line error message, displayed if the string is not a known command nor a valid move instruction; try `gnome-tetravex --cli new; gnome-tetravex --cli A2838I8U` */
                    warning (_("Cannot parse instruction, aborting.") + "\n");
                    return Posix.EXIT_FAILURE;
                }
                if (puzzle.get_tile (tile_1_x, tile_1_y) == null
                 && puzzle.get_tile (tile_2_x, tile_2_y) == null)
                {
                    /* Translators: command-line error message, displayed if the user plays in CLI and tries to invert two empty tiles */
                    warning (_("Both given tiles are empty, aborting.") + "\n");
                    return Posix.EXIT_FAILURE;
                }
                if (!puzzle.can_switch (tile_1_x, tile_1_y, tile_2_x, tile_2_y))
                {
                    /* Translators: command-line error message, displayed if the user plays in CLI and tries to do an invalid move */
                    warning (_("Cannot swap the given tiles, aborting.") + "\n");
                    print_board (puzzle, size);
                    return Posix.EXIT_FAILURE;
                }
                puzzle.switch_tiles (tile_1_x, tile_1_y, tile_2_x, tile_2_y);
                break;
        }

        print_board (puzzle, size);

        settings.set_value ("saved-game", puzzle.to_variant (/* save time */ false));

        return Posix.EXIT_SUCCESS;
    }

    private static bool cli_move_tiles (Puzzle puzzle, bool new_puzzle, bool left_board, Direction direction, string warning_string)
    {
        if (new_puzzle || puzzle.is_solved)
        {
            puzzle_is_solved_message ();
            return false;
        }
        bool success;
        switch (direction)
        {
            case Direction.UP:      success = puzzle.move_up (left_board);      break;
            case Direction.DOWN:    success = puzzle.move_down (left_board);    break;
            case Direction.LEFT:    success = puzzle.move_left (left_board);    break;
            case Direction.RIGHT:   success = puzzle.move_right (left_board);   break;
            default: assert_not_reached ();
        }
        if (!success)
        {
            warning (@"$warning_string\n");
            return false;
        }
        return true;
    }

    private static void puzzle_is_solved_message (bool alternative_message = false)
    {
        if (alternative_message)
            /* Translators: command-line error message, displayed if the user tries to solve the puzzle using CLI (with the “solve” or “finish” commands), while the puzzle is already solved */
            warning (_("Puzzle is already solved! If you want to start a new one, use “new”.") + "\n");
        else
            /* Translators: command-line error message, displayed if the user tries to do a move using CLI, while the puzzle is solved */
            warning (_("Puzzle is solved! If you want to start a new one, use “new”.") + "\n");
    }

    private static void print_board (Puzzle puzzle, uint8 size)
    {
        stdout.printf ("\n");
        for (uint8 y = 0; y < size; y++)
        {
            for (uint8 x = 0; x < 2 * size; x++)
            {
                Tile? tile = puzzle.get_tile (x, y);
                if (tile == null)
                    stdout.printf (" ╭╴ ╶╮");
                else
                    stdout.printf (@" ┌╴$(((!) tile).north)╶┐");
                if (x == size - 1)
                    stdout.printf ("  ");
            }
            stdout.printf ("\n");
            for (uint8 x = 0; x < 2 * size; x++)
            {
                Tile? tile = puzzle.get_tile (x, y);
                if (tile == null)
                    stdout.printf ("      ");
                else
                    stdout.printf (@" $(((!) tile).west) · $(((!) tile).east)");
                if (x == size - 1)
                    stdout.printf ("  ");
            }
            stdout.printf ("\n");
            for (uint8 x = 0; x < 2 * size; x++)
            {
                Tile? tile = puzzle.get_tile (x, y);
                if (tile == null)
                    stdout.printf (" ╰╴ ╶╯");
                else
                    stdout.printf (@" └╴$(((!) tile).south)╶┘");
                if (x == size - 1)
                    stdout.printf ("  ");
            }
            stdout.printf ("\n");
        }
        stdout.printf ("\n");
        if (puzzle.is_solved)
            /* Translators: command-line message, displayed when playing Tetravex in CLI under the board, if the puzzle was solved */
            stdout.printf (_("Puzzle is solved!") + "\n\n");
    }

    private static bool parse_cli (string cli, uint8 size,
                               out uint8 tile_1_x, out uint8 tile_1_y,
                               out uint8 tile_2_x, out uint8 tile_2_y)
    {
        tile_1_x = uint8.MAX;    //g
        tile_1_y = uint8.MAX;   //  ar
        tile_2_x = uint8.MAX;  //     ba
        tile_2_y = uint8.MAX; //        ge

        if (cli.length != 4)
            return false;

        char column_char = cli [0];
        if (!is_valid_column (column_char, size, out tile_1_x))
            return false;

        column_char = cli [2];
        if (!is_valid_column (column_char, size, out tile_2_x))
            return false;

        uint64 test;
        if (!uint64.try_parse (cli [1].to_string (), out test))
            return false;
        if (test <= 0 || test > size)
            return false;
        tile_1_y = (uint8) test - 1;

        if (!uint64.try_parse (cli [3].to_string (), out test))
            return false;
        if (test <= 0 || test > size)
            return false;
        tile_2_y = (uint8) test - 1;

        return true;
    }

    private static bool is_valid_column (char column_char, uint8 size, out uint8 column)
    {
        switch (column_char)
        {
            case 'a': column = 0;           return true;
            case 'b': column = 1;           return true;
            case 'c': column = 2;           return size >= 3;
            case 'd': column = 3;           return size >= 4;
            case 'e': column = 4;           return size >= 5;
            case 'f': column = 5;           return size == 6;
            case 'A': column = size;        return true;
            case 'B': column = size + 1;    return true;
            case 'C': column = size + 2;    return size >= 3;
            case 'D': column = size + 3;    return size >= 4;
            case 'E': column = size + 4;    return size >= 5;
            case 'F': column = size + 5;    return size == 6;
            default : column = uint8.MAX;   return false;
        }
    }
}
