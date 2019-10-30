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

        uint8 size;
        bool new_puzzle;
        if (game_size != int.MIN)
        {
            settings.set_int (KEY_GRID_SIZE, game_size);
            size = (uint8) game_size;
            puzzle = new Puzzle (size, (uint8) colors);
            new_puzzle = true;
        }
        else if (colors != 10 || (!) cli == "new")
        {
            size = (uint8) settings.get_int (KEY_GRID_SIZE);
            puzzle = new Puzzle (size, (uint8) colors);
            new_puzzle = true;
        }
        else if (can_restore)
        {
            size = (uint8) settings.get_int (KEY_GRID_SIZE);
            puzzle = new Puzzle.restore ((!) saved_game);
            new_puzzle = false;
        }
        else
        {
            size = (uint8) settings.get_int (KEY_GRID_SIZE);
            puzzle = new Puzzle (size, 10);
            new_puzzle = true;
        }

        switch ((!) cli)    // TODO add translated commands? add translations?
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
                if (!cli_move_tiles (puzzle, new_puzzle, /* left board */ true, Direction.UP, "Cannot move up left-board tiles."))
                    return Posix.EXIT_FAILURE;
                break;
            case "down":
            case "l-down":
                if (!cli_move_tiles (puzzle, new_puzzle, /* left board */ true, Direction.DOWN, "Cannot move down left-board tiles."))
                    return Posix.EXIT_FAILURE;
                break;
            case "left":
            case "l-left":
                if (!cli_move_tiles (puzzle, new_puzzle, /* left board */ true, Direction.LEFT, "Cannot move left left-board tiles."))
                    return Posix.EXIT_FAILURE;
                break;
            case "right":
            case "l-right":
                if (!cli_move_tiles (puzzle, new_puzzle, /* left board */ true, Direction.RIGHT, "Cannot move right left-board tiles."))
                    return Posix.EXIT_FAILURE;
                break;

            case "r-up":
                if (!cli_move_tiles (puzzle, new_puzzle, /* left board */ false, Direction.UP, "Cannot move up right-board tiles."))
                    return Posix.EXIT_FAILURE;
                break;
            case "r-down":
                if (!cli_move_tiles (puzzle, new_puzzle, /* left board */ false, Direction.DOWN, "Cannot move down right-board tiles."))
                    return Posix.EXIT_FAILURE;
                break;
            case "r-left":
                if (!cli_move_tiles (puzzle, new_puzzle, /* left board */ false, Direction.LEFT, "Cannot move left right-board tiles."))
                    return Posix.EXIT_FAILURE;
                break;
            case "r-right":
                if (!cli_move_tiles (puzzle, new_puzzle, /* left board */ false, Direction.RIGHT, "Cannot move right right-board tiles."))
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
                    warning ("Cannot finish automatically. If you want to give up and view the solution, use “solve”." + "\n");
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
                if (!parse_cli ((!) cli, size, out tile_1_x, out tile_1_y, out tile_2_x, out tile_2_y))
                {
                    warning ("Cannot parse “--cli” command, aborting." + "\n");
                    return Posix.EXIT_FAILURE;
                }
                if (puzzle.get_tile (tile_1_x, tile_1_y) == null
                 && puzzle.get_tile (tile_2_x, tile_2_y) == null)
                {
                    warning ("Both given tiles are empty, aborting." + "\n");
                    return Posix.EXIT_FAILURE;
                }
                if (!puzzle.can_switch (tile_1_x, tile_1_y, tile_2_x, tile_2_y))
                {
                    warning ("Cannot swap the given tiles, aborting." + "\n");
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
            warning ("Puzzle is already solved! If you want to start a new one, use “new”." + "\n");
        else
            warning ("Puzzle is solved! If you want to start a new one, use “new”." + "\n");
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
                    stdout.printf (" ┌─ ─┐");
                else
                    stdout.printf (@" ┌─$(((!) tile).north)─┐");
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
                    stdout.printf (" └─ ─┘");
                else
                    stdout.printf (@" └─$(((!) tile).south)─┘");
                if (x == size - 1)
                    stdout.printf ("  ");
            }
            stdout.printf ("\n");
        }
        stdout.printf ("\n");
        if (puzzle.is_solved)
            stdout.printf ("Puzzle is solved!\n\n");
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
