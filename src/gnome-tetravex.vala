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

private class Tetravex : Adw.Application {
    private static bool start_paused;
    private static int game_size = int.MIN;
    private static int colors = 10;

    private GLib.Settings settings;

    private Puzzle puzzle;
    private bool puzzle_init_done;
    private History history;

    private PuzzleView view;

    private SimpleAction undo_action;
    private SimpleAction redo_action;
    private SimpleAction pause_action;
    private SimpleAction solve_action;
    private SimpleAction finish_action;

    private const OptionEntry [] OPTION_ENTRIES = {
        /* Translators: command-line option description, see 'gnome-tetravex --help' */
        { "colors", 'c', OptionFlags.NONE, OptionArg.INT, ref colors, N_("Set number of colors (2-10)"),
        /* Translators: in the command-line options description, text to indicate the user should specify colors number, see 'gnome-tetravex --help' */
          N_("NUMBER") },

        /* Translators: command-line option description, see 'gnome-tetravex --help' */
        { "paused", 'p', OptionFlags.NONE, OptionArg.NONE, null, N_("Start the game paused"), null },

        /* Translators: command-line option description, see 'gnome-tetravex --help' */
        { "size", 's', OptionFlags.NONE, OptionArg.INT, ref game_size, N_("Set size of board (2-6)"),
        /* Translators: in the command-line options description, text to indicate the user should specify size, see 'gnome-tetravex --help' */
          N_("SIZE") },

        /* Translators: command-line option description, see 'gnome-tetravex --help' */
        { "version", 'v', OptionFlags.NONE, OptionArg.NONE, null, N_("Print release version and exit"), null },
    };

    private const GLib.ActionEntry[] ACTION_ENTRIES = {
        { "new-game", new_game_cb },
        { "pause", pause_cb },
        { "solve", solve_cb },
        { "finish", finish_cb },
        { "scores", scores_cb },
        { "move-up-l", move_up_l },
        { "move-down-l", move_down_l },
        { "move-left-l", move_left_l },
        { "move-right-l", move_right_l },
        { "move-up-r", move_up_r },
        { "move-down-r", move_down_r },
        { "move-left-r", move_left_r },
        { "move-right-r", move_right_r },
        { "escape", escape_cb },
        { "undo", undo_cb },
        { "redo", redo_cb },
        { "reload", reload_cb },
        { "size", null, "s", "'2'", size_changed_cb },
        { "rules", rules_cb },
        { "about", about_cb },
        { "quit", quit }
    };

    private static int main (string[] args) {
        Intl.setlocale (LocaleCategory.ALL, "");
        Intl.bindtextdomain (GETTEXT_PACKAGE, LOCALEDIR);
        Intl.bind_textdomain_codeset (GETTEXT_PACKAGE, "UTF-8");
        Intl.textdomain (GETTEXT_PACKAGE);

        Environment.set_application_name (_("Tetravex"));

        Tetravex app = new Tetravex ();
        return app.run (args);
    }

    private Tetravex () {
        Object (
            application_id: APP_ID,
            resource_base_path: "/org/gnome/Tetravex"
        );
        add_main_option_entries (OPTION_ENTRIES);
    }

    protected override int handle_local_options (GLib.VariantDict options) {
        if (options.contains ("version")) {
            /* NOTE: Is not translated so can be easily parsed */
            stderr.printf ("%1$s %2$s\n", "gnome-tetravex", VERSION);
            return Posix.EXIT_SUCCESS;
        }

        if (options.contains ("paused"))
            start_paused = true;

        if (game_size != int.MIN && (game_size < 2 || game_size > 6)) {
            /* Translators: command-line error message, displayed on invalid game size request; see 'gnome-tetravex -s 1' */
            stderr.printf (_("Size could only be from 2 to 6.") + "\n");
            return Posix.EXIT_FAILURE;
        }

        if (colors < 2 || colors > 10) {
            /* Translators: command-line error message, displayed for an invalid number of colors; see 'gnome-tetravex -c 1' */
            stderr.printf (_("There could only be between 2 and 10 colors.") + "\n");
            return Posix.EXIT_FAILURE;
        }

        /* Activate */
        return -1;
    }

    protected override void startup () {
        base.startup ();

        settings = new GLib.Settings (APP_ID);

        saved_game = settings.get_value ("saved-game");
        can_restore = Puzzle.is_valid_saved_game (saved_game);

        add_action_entries (ACTION_ENTRIES, this);
        add_action (settings.create_action ("theme"));

        set_accels_for_action ("app.solve", { "<Control>h" });
        set_accels_for_action ("app.new-game", { "<Control>n" });
        set_accels_for_action ("app.pause", { "<Control>p", "Pause" });
        set_accels_for_action ("app.move-up-l", { "<Control>Up" });
        set_accels_for_action ("app.move-down-l", { "<Control>Down" });
        set_accels_for_action ("app.move-left-l", { "<Control>Left" });
        set_accels_for_action ("app.move-right-l", { "<Control>Right" });
        set_accels_for_action ("app.move-up-r", { "<Shift><Control>Up" });
        set_accels_for_action ("app.move-down-r", { "<Shift><Control>Down" });
        set_accels_for_action ("app.move-left-r", { "<Shift><Control>Left" });
        set_accels_for_action ("app.move-right-r", { "<Shift><Control>Right" });
        set_accels_for_action ("app.escape", { "Escape" });
        set_accels_for_action ("app.undo", { "<Control>z" });
        set_accels_for_action ("app.redo", { "<Shift><Control>z" });
        set_accels_for_action ("app.reload", { "<Shift><Control>r" });
        set_accels_for_action ("app.rules", { "F1" });
        set_accels_for_action ("app.quit", { "<Control>q" });
        set_accels_for_action ("window.close", { "<Primary>w" });
    }

    private void create_window () {
        string history_path;
        if (colors == 10)
            history_path = Path.build_filename (Environment.get_user_data_dir (), "gnome-tetravex", "history");
        else
            history_path = Path.build_filename (
                Environment.get_user_data_dir (), "gnome-tetravex", "history-" + colors.to_string ()
            );
        history = new History (history_path);

        view = new PuzzleView ();
        settings.bind ("theme", view, "theme-id", SettingsBindFlags.GET | SettingsBindFlags.NO_SENSITIVITY);

        new TetravexWindow (this, view);
        settings.bind ("window-width", active_window, "default-width", SettingsBindFlags.DEFAULT);
        settings.bind ("window-height", active_window, "default-height", SettingsBindFlags.DEFAULT);
        settings.bind ("window-is-maximized", active_window, "maximized", SettingsBindFlags.DEFAULT);

        if (game_size != int.MIN)
            settings.set_int ("grid-size", game_size);
        else
            game_size = settings.get_int ("grid-size");
        ((SimpleAction) lookup_action ("size")).set_state ("%d".printf (game_size));

        undo_action = (SimpleAction) lookup_action ("undo");
        redo_action = (SimpleAction) lookup_action ("redo");
        pause_action = (SimpleAction) lookup_action ("pause");
        solve_action = (SimpleAction) lookup_action ("solve");
        finish_action = (SimpleAction) lookup_action ("finish");

        undo_action.set_enabled (false);
        redo_action.set_enabled (false);
        finish_action.set_enabled (false);

        view.notify ["tile-selected"].connect (() => {
                if (!puzzle_init_done)
                    return;
                if (puzzle.is_solved)
                    return;
                if (puzzle.is_solved_right)
                    solve_action.set_enabled (false);
                else
                    solve_action.set_enabled (!view.tile_selected && /* should never happen */ !puzzle.paused);
                finish_action.set_enabled (!view.tile_selected);
            });

        if (can_restore)
            new_game (saved_game);
        else
            new_game ();
    }

    protected override void shutdown () {
        base.shutdown ();

        settings.delay ();
        if (puzzle_init_done) {
            if (puzzle.game_in_progress && !puzzle.is_solved)
                settings.set_value ("saved-game", puzzle.to_variant ());
            else
                settings.@set ("saved-game", "m(yyda(yyyyyyyy)ua(yyyyu))", null);
        }
        settings.apply ();
    }

    protected override void activate () {
        Gtk.Window? window = active_window;
        if (window == null)
            create_window ();

        active_window.present ();
    }

    private Variant saved_game;
    private bool can_restore;

    private void new_game (Variant? saved_game = null, int? given_size = null) {
        pause_action.set_enabled (true);
        solve_action.set_enabled (true);
        finish_action.set_enabled (false);

        if (puzzle_init_done)
            SignalHandler.disconnect_by_func (puzzle, null, this);

        if (saved_game == null) {
            int size;
            if (given_size == null)
                size = settings.get_int ("grid-size");
            else
                size = (!) given_size;
            puzzle = new Puzzle ((uint8) size, (uint8) colors);
        }
        else {
            puzzle = new Puzzle.restore ((!) saved_game);
            if (puzzle.is_solved_right)
                solved_right_cb (puzzle.is_solved_right);
        }
        puzzle_init_done = true;
        puzzle.attempt_move.connect (attempt_move_cb);
        puzzle.paused_changed.connect (paused_changed_cb);
        puzzle.solved.connect (solved_cb);
        puzzle.solved_right.connect (solved_right_cb);
        puzzle.can_undo_redo_changed.connect (() => {
            undo_action.set_enabled (puzzle.can_undo && !puzzle.is_solved && !puzzle.paused);
            redo_action.set_enabled (puzzle.can_redo && !puzzle.is_solved && !puzzle.paused);
        });
        puzzle.show_end_game.connect (show_end_game_cb);
        ((TetravexWindow) active_window).new_game (puzzle);
        view.puzzle = puzzle;

        puzzle.start ();

        if (start_paused) {
            puzzle.paused = true;
            start_paused = false;
        }
        else if (saved_game != null)
            puzzle.paused = true;
        else
            view.grab_focus ();
    }

    private bool attempt_move_cb () {
        /* Cancel pause on click */
        if (puzzle.paused) {
            puzzle.paused = false;
            return false;
        }
        return true;
    }

    private void paused_changed_cb () {
        undo_action.set_enabled (puzzle.can_undo && !puzzle.is_solved && !puzzle.paused);
        redo_action.set_enabled (puzzle.can_redo && !puzzle.is_solved && !puzzle.paused);

        if (puzzle.is_solved_right) {
            solve_action.set_enabled (false);
            finish_action.set_enabled (!puzzle.paused && !view.tile_selected);
        }
        else {
            solve_action.set_enabled (!puzzle.paused && !view.tile_selected);
            finish_action.set_enabled (false);
        }

        if (!puzzle.paused)
            view.grab_focus ();
    }

    private void solved_cb (Puzzle puzzle) {
        undo_action.set_enabled (false);
        redo_action.set_enabled (false);
        pause_action.set_enabled (false);
        solve_action.set_enabled (false);
        finish_action.set_enabled (false);
    }

    private void solved_right_cb (bool is_solved_right) {
        if (is_solved_right) {
            solve_action.set_enabled (false);
            finish_action.set_enabled (/* should never happen */ !puzzle.paused);
            return;
        }

        solve_action.set_enabled (/* should never happen */ !puzzle.paused);
        finish_action.set_enabled (false);
    }

    private void show_end_game_cb (Puzzle puzzle) {
        DateTime date = new DateTime.now_local ();
        last_history_entry = new HistoryEntry (date, puzzle.size, puzzle.elapsed, /* old history format */ false);
        history.add ((!) last_history_entry);

        scores_cb ();
    }

    private void new_game_cb () {
        new_game ();
    }

    private HistoryEntry? last_history_entry;
    private void scores_cb () {
        var dialog = new ScoreDialog (history, puzzle.size, puzzle.is_solved ? last_history_entry : null);
        dialog.set_modal (true);
        dialog.set_transient_for (active_window);
        dialog.present ();
    }

    private async void _solve_cb () {
        if (puzzle.elapsed < 0.2)   // security against multi-click on new-game button
            return;

        if (puzzle.game_in_progress) {
            var dialog = new Adw.AlertDialog (
                _("Reveal Solution?"),
                _("This will end your current game.")
            ) {
                default_response = "cancel"
            };
            dialog.add_response ("cancel", _("_Keep Playing"));
            dialog.add_response ("give_up", _("_Give Up"));
            dialog.set_response_appearance ("give_up", Adw.ResponseAppearance.DESTRUCTIVE);

            var resp_id = yield dialog.choose (active_window, null);
            if (resp_id == "give_up")
                puzzle.solve ();
            return;
        }
        puzzle.solve ();
    }

    private void solve_cb () {
        _solve_cb.begin ();
    }

    private void finish_cb () {
        view.finish ();
    }

    private async void _size_changed_cb (SimpleAction action, Variant variant) {
        var size = int.parse (variant.get_string ());
        if (settings.get_int ("grid-size") != size) {
            if (puzzle.game_in_progress && !puzzle.is_solved) {
                var dialog = new Adw.AlertDialog (
                    _("Change Size?"),
                    _("This will end your current game.")
                ) {
                    default_response = "cancel"
                };
                dialog.add_response ("cancel", _("_Cancel"));
                dialog.add_response ("change_size", _("Change _Size"));
                dialog.set_response_appearance ("change_size", Adw.ResponseAppearance.DESTRUCTIVE);

                var resp_id = yield dialog.choose (active_window, null);
                if (resp_id != "change_size")
                    return;
            }

            settings.set_int ("grid-size", size);
            settings.apply ();

            new_game ();
        }
        action.set_state (variant);
    }

    private void size_changed_cb (SimpleAction action, Variant variant) {
        _size_changed_cb.begin (action, variant);
    }

    private void move_up_l () {
        view.move_up (/* left board */ true);
    }

    private void move_down_l () {
        view.move_down (/* left board */ true);
    }

    private void move_left_l () {
        if (!puzzle.is_solved_right)
            view.move_left (/* left board */ true);
        else if (!puzzle.paused && !view.tile_selected)
            view.finish ();
    }

    private void move_right_l () {
        view.move_right (/* left board */ true);
    }

    private void move_up_r () {
        view.move_up (/* left board */ false);
    }

    private void move_down_r () {
        view.move_down (/* left board */ false);
    }

    private void move_left_r () {
        view.move_left (/* left board */ false);
    }

    private void move_right_r () {
        view.move_right (/* left board */ false);
    }

    private void undo_cb () {
        if (view.tile_selected)
            view.release_selected_tile ();
        else
            view.undo ();
    }

    private void redo_cb () {
        if (view.tile_selected)
            view.release_selected_tile ();
        else
            view.redo ();
    }

    private void reload_cb () {
        if (view.tile_selected)
            view.release_selected_tile ();
        else
            view.reload ();
    }

    private void pause_cb () {
        puzzle.paused = !puzzle.paused;
    }

    private void escape_cb () {
        if (puzzle.is_solved)
            return;

        if (puzzle.paused)
            puzzle.paused = false;
        else if (view.tile_selected)
            view.release_selected_tile ();
    }

    /*\
    * * rules/about
    \*/

    private void rules_cb () {
        new RulesDialog ()
            .present (active_window);
    }

    private void about_cb () {
        var about_dialog = new Adw.AboutDialog.from_appdata (resource_base_path + "/metainfo.xml", VERSION) {
            copyright = "Copyright © 1998–2025 Tetravex Contributors",
            developers = {
                "Lars Rydlinge",
                "Robert Ancell",
                "Thomas H.P. Andersen",
                "Michael Catanzaro",
                "Mario Wenzel",
                "Arnaud Bonatti",
                "Mathias Bonn"
            },
            artists = {
                "Jakub Steiner"
            },
            documenters = {
                "Rob Bradford"
            },
            translator_credits = _("translator-credits"),
        };
        about_dialog.present (active_window);
    }
}
