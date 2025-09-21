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

using Gtk;

private class Tetravex : Adw.Application
{
    /* Translators: name of the program, as seen in the headerbar, in GNOME Shell, or in the about dialog */
    private const string PROGRAM_NAME = _("Tetravex");

    private static bool start_paused = false;
    private static int game_size = int.MIN;
    private static int colors = 10;

    private GLib.Settings settings;

    private Puzzle puzzle;
    private bool puzzle_init_done = false;
    private History history;

    private PuzzleView view;

    private SimpleAction undo_action;
    private SimpleAction redo_action;
    private SimpleAction pause_action;
    private SimpleAction solve_action;
    private SimpleAction finish_action;

    private const OptionEntry [] option_entries =
    {
        /* Translators: command-line option description, see 'gnome-tetravex --help' */
        { "colors",  'c', OptionFlags.NONE, OptionArg.INT,  ref colors,                 N_("Set number of colors (2-10)"),

        /* Translators: in the command-line options description, text to indicate the user should specify colors number, see 'gnome-tetravex --help' */
                                                                                        N_("NUMBER") },

        /* Translators: command-line option description, see 'gnome-tetravex --help' */
        { "paused",  'p', OptionFlags.NONE, OptionArg.NONE, null,                       N_("Start the game paused"),            null },

        /* Translators: command-line option description, see 'gnome-tetravex --help' */
        { "size",    's', OptionFlags.NONE, OptionArg.INT,  ref game_size,              N_("Set size of board (2-6)"),

        /* Translators: in the command-line options description, text to indicate the user should specify size, see 'gnome-tetravex --help' */
                                                                                        N_("SIZE") },

        /* Translators: command-line option description, see 'gnome-tetravex --help' */
        { "version", 'v', OptionFlags.NONE, OptionArg.NONE, null,                       N_("Print release version and exit"),   null },
        {}
    };

    private const GLib.ActionEntry[] action_entries =
    {
        { "new-game",       new_game_cb     },
        { "pause",          pause_cb        },
        { "solve",          solve_cb        },
        { "finish",         finish_cb       },
        { "scores",         scores_cb       },
        { "move-up-l",      move_up_l       },
        { "move-down-l",    move_down_l     },
        { "move-left-l",    move_left_l     },
        { "move-right-l",   move_right_l    },
        { "move-up-r",      move_up_r       },
        { "move-down-r",    move_down_r     },
        { "move-left-r",    move_left_r     },
        { "move-right-r",   move_right_r    },
        { "undo",           undo_cb         },
        { "redo",           redo_cb         },
        { "reload",         reload_cb       },
        { "size",           null,           "s",    "'2'",  size_changed    },
        { "help",           help_cb         },
        { "about",          about_cb        },
        { "quit",           quit            }
    };

    private static int main (string[] args)
    {
        Intl.setlocale (LocaleCategory.ALL, "");
        Intl.bindtextdomain (GETTEXT_PACKAGE, LOCALEDIR);
        Intl.bind_textdomain_codeset (GETTEXT_PACKAGE, "UTF-8");
        Intl.textdomain (GETTEXT_PACKAGE);

        Environment.set_application_name (PROGRAM_NAME);

        Tetravex app = new Tetravex ();
        return app.run (args);
    }

    private Tetravex ()
    {
        Object (
            application_id: APP_ID,
            resource_base_path: "/org/gnome/Tetravex"
        );
        add_main_option_entries (option_entries);
    }

    protected override int handle_local_options (GLib.VariantDict options)
    {
        if (options.contains ("version"))
        {
            /* NOTE: Is not translated so can be easily parsed */
            stderr.printf ("%1$s %2$s\n", "gnome-tetravex", VERSION);
            return Posix.EXIT_SUCCESS;
        }

        if (options.contains ("paused"))
            start_paused = true;

        if (game_size != int.MIN && (game_size < 2 || game_size > 6))
        {
            /* Translators: command-line error message, displayed on invalid game size request; see 'gnome-tetravex -s 1' */
            stderr.printf (_("Size could only be from 2 to 6.") + "\n");
            return Posix.EXIT_FAILURE;
        }

        if (colors < 2 || colors > 10)
        {
            /* Translators: command-line error message, displayed for an invalid number of colors; see 'gnome-tetravex -c 1' */
            stderr.printf (_("There could only be between 2 and 10 colors.") + "\n");
            return Posix.EXIT_FAILURE;
        }

        /* Activate */
        return -1;
    }

    protected override void startup ()
    {
        base.startup ();

        settings = new GLib.Settings (APP_ID);

        saved_game = settings.get_value ("saved-game");
        can_restore = Puzzle.is_valid_saved_game (saved_game);

        add_action_entries (action_entries, this);
        add_action (settings.create_action ("theme"));

        set_accels_for_action ("app.solve",         {        "<Control>h"       });
        set_accels_for_action ("app.new-game",      {        "<Control>n"       });
        set_accels_for_action ("app.pause",         {        "<Control>p",
                                                                      "Pause"   });
        set_accels_for_action ("app.move-up-l",     {        "<Control>Up"      });
        set_accels_for_action ("app.move-down-l",   {        "<Control>Down"    });
        set_accels_for_action ("app.move-left-l",   {        "<Control>Left"    });
        set_accels_for_action ("app.move-right-l",  {        "<Control>Right"   });
        set_accels_for_action ("app.move-up-r",     { "<Shift><Control>Up"      });
        set_accels_for_action ("app.move-down-r",   { "<Shift><Control>Down"    });
        set_accels_for_action ("app.move-left-r",   { "<Shift><Control>Left"    });
        set_accels_for_action ("app.move-right-r",  { "<Shift><Control>Right"   });
        set_accels_for_action ("app.undo",          {        "<Control>z"       });
        set_accels_for_action ("app.redo",          { "<Shift><Control>z"       });
        set_accels_for_action ("app.reload",        { "<Shift><Control>r"       });
        set_accels_for_action ("app.help",          {                 "F1"      });
        set_accels_for_action ("app.quit",          {        "<Control>q"       });
        set_accels_for_action ("window.close",      { "<Primary>w"              });
    }

    private void create_window () {
        string history_path;
        if (colors == 10)
            history_path = Path.build_filename (Environment.get_user_data_dir (), "gnome-tetravex", "history");
        else
            history_path = Path.build_filename (Environment.get_user_data_dir (), "gnome-tetravex", "history-" + colors.to_string ());
        history = new History (history_path);

        view = new PuzzleView ();
        view_click_controller = new GestureClick ();
        view_click_controller.set_button (/* all buttons */ 0);
        view_click_controller.released.connect (on_release_on_view);
        view.add_controller (view_click_controller);
        settings.bind ("theme", view, "theme-id", SettingsBindFlags.GET | SettingsBindFlags.NO_SENSITIVITY);

        settings.bind ("mouse-use-extra-buttons",   view,
                       "mouse-use-extra-buttons",   SettingsBindFlags.GET | SettingsBindFlags.NO_SENSITIVITY);
        settings.bind ("mouse-back-button",         view,
                       "mouse-back-button",         SettingsBindFlags.GET | SettingsBindFlags.NO_SENSITIVITY);
        settings.bind ("mouse-forward-button",      view,
                       "mouse-forward-button",      SettingsBindFlags.GET | SettingsBindFlags.NO_SENSITIVITY);

        new TetravexWindow (this, view);
        settings.bind ("window-width", active_window, "default-width", SettingsBindFlags.DEFAULT);
        settings.bind ("window-height", active_window, "default-height", SettingsBindFlags.DEFAULT);
        settings.bind ("window-is-maximized", active_window, "maximized", SettingsBindFlags.DEFAULT);

        key_controller = new EventControllerKey ();
        key_controller.key_pressed.connect (on_key_pressed);
        ((Widget) active_window).add_controller (key_controller);

        if (game_size != int.MIN)
            settings.set_int ("grid-size", game_size);
        else
            game_size = settings.get_int ("grid-size");
        ((SimpleAction) lookup_action ("size")).set_state ("%d".printf (game_size));

        undo_action   = (SimpleAction) lookup_action ("undo");
        redo_action   = (SimpleAction) lookup_action ("redo");
        pause_action  = (SimpleAction) lookup_action ("pause");
        solve_action  = (SimpleAction) lookup_action ("solve");
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

    protected override void shutdown ()
    {
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

    protected override void activate ()
    {
        if (active_window == null)
            create_window ();

        active_window.present ();
    }

    private Variant saved_game;
    private bool can_restore = false;

    private void new_game (Variant? saved_game = null, int? given_size = null)
    {
        pause_action.set_enabled (true);
        solve_action.set_enabled (true);
        finish_action.set_enabled (false);

        if (puzzle_init_done)
            SignalHandler.disconnect_by_func (puzzle, null, this);

        if (saved_game == null)
        {
            int size;
            if (given_size == null)
                size = settings.get_int ("grid-size");
            else
                size = (!) given_size;
            puzzle = new Puzzle ((uint8) size, (uint8) colors);
        }
        else
        {
            puzzle = new Puzzle.restore ((!) saved_game);
            if (puzzle.is_solved_right)
                solved_right_cb ();
        }
        puzzle_init_done = true;
        puzzle.paused_changed.connect (paused_changed_cb);
        puzzle.solved.connect (solved_cb);
        puzzle.notify ["is-solved-right"].connect (solved_right_cb);
        puzzle.notify ["can-undo"].connect (() =>
            undo_action.set_enabled (puzzle.can_undo && !puzzle.is_solved && !puzzle.paused));
        puzzle.notify ["can-redo"].connect (() =>
            redo_action.set_enabled (puzzle.can_redo && !puzzle.is_solved && !puzzle.paused));
        puzzle.show_end_game.connect (show_end_game_cb);
        ((TetravexWindow) active_window).new_game (puzzle);
        view.puzzle = puzzle;

        if (start_paused)
        {
            puzzle.paused = true;
            start_paused = false;
        }
        else if (saved_game != null)
            puzzle.paused = true;
        else
            view.grab_focus ();
    }

    private void paused_changed_cb () {
        undo_action.set_enabled (puzzle.can_undo && !puzzle.is_solved && !puzzle.paused);
        redo_action.set_enabled (puzzle.can_redo && !puzzle.is_solved && !puzzle.paused);

        if (puzzle.is_solved_right)
        {
            solve_action.set_enabled (false);
            finish_action.set_enabled (!puzzle.paused && !view.tile_selected);
        }
        else
        {
            solve_action.set_enabled (!puzzle.paused && !view.tile_selected);
            finish_action.set_enabled (false);
        }

        if (!puzzle.paused)
            view.grab_focus ();
    }

    private void solved_cb (Puzzle puzzle)
    {
        undo_action.set_enabled (false);
        redo_action.set_enabled (false);
        pause_action.set_enabled (false);
        solve_action.set_enabled (false);
        finish_action.set_enabled (false);
    }

    private void solved_right_cb ()
    {
        if (puzzle.is_solved_right)
        {
            solve_action.set_enabled (false);
            finish_action.set_enabled (/* should never happen */ !puzzle.paused);
        }
        else
        {
            solve_action.set_enabled (/* should never happen */ !puzzle.paused);
            finish_action.set_enabled (false);
        }
    }

    private void show_end_game_cb (Puzzle puzzle)
    {
        DateTime date = new DateTime.now_local ();
        last_history_entry = new HistoryEntry (date, puzzle.size, puzzle.elapsed, /* old history format */ false);
        history.add (last_history_entry);

        scores_cb ();
    }

    private void new_game_cb ()
    {
        int size = settings.get_int ("grid-size");
        if (puzzle.game_in_progress && !puzzle.is_solved)
        {
            MessageDialog dialog = new MessageDialog (active_window,
                                                      DialogFlags.MODAL | DialogFlags.DESTROY_WITH_PARENT,
                                                      MessageType.QUESTION,
                                                      ButtonsType.NONE,
        /* Translators: popup dialog main text; appearing when user clicks "New Game" from the hamburger menu, while a game is started; possible answers are "Keep playing"/"Start New Game"; the %d are both replaced with  */
                                                      _("Are you sure you want to start a new %u × %u game?").printf (size, size));

        /* Translators: popup dialog possible answer (with a mnemonic that appears pressing Alt); appearing when user clicks "New Game" from the hamburger menu; other possible answer is "_Start New Game" */
            dialog.add_buttons (_("_Keep Playing"),   ResponseType.REJECT,

        /* Translators: popup dialog possible answer (with a mnemonic that appears pressing Alt); appearing when user clicks "New Game" from the hamburger menu; other possible answer is "_Keep Playing" */
                                _("_Start New Game"), ResponseType.ACCEPT);

            dialog.response.connect ((_dialog, response) => {
                    _dialog.destroy ();
                    if (response == ResponseType.ACCEPT)
                        new_game (/* saved game */ null, size);
                });
            dialog.present ();
            return;
        }
        new_game (/* saved game */ null, size);
    }

    private HistoryEntry? last_history_entry = null;
    private bool scores_dialog_visible = false; // security for #5
    private void scores_cb (/* SimpleAction action, Variant? variant */)
    {
        if (scores_dialog_visible)
            return;
        scores_dialog_visible = true;

        Dialog dialog;
        if (history.is_empty ())
            dialog = new MessageDialog (active_window,
                                        DialogFlags.MODAL | DialogFlags.DESTROY_WITH_PARENT,
                                        MessageType.INFO,
                                        ButtonsType.CLOSE,
            /* Translators: popup dialog main text; appearing when user clicks the "Scores" entry of the hamburger menu, while not having finished any game yet */
                                        _("Looks like you haven’t finished a game yet.\n\nMaybe try a 2 × 2 grid, they are easy. 🙂️"));
        else
        {
            dialog = new ScoreDialog (history, puzzle.size, puzzle.is_solved ? last_history_entry : null);
            dialog.set_modal (true);
            dialog.set_transient_for (active_window);
        }

        dialog.close_request.connect (() => {
                scores_dialog_visible = false;

                return /* do your usual stuff */ false;
            });
        dialog.present ();
    }

    private void solve_cb ()
    {
        if (puzzle.elapsed < 0.2)   // security against multi-click on new-game button
            return;

        if (puzzle.game_in_progress)
        {
            MessageDialog dialog = new MessageDialog (active_window,
                                                      DialogFlags.MODAL | DialogFlags.DESTROY_WITH_PARENT,
                                                      MessageType.QUESTION,
                                                      ButtonsType.NONE,
            /* Translators: popup dialog main text; appearing when user clicks the "Give up" button in the bottom bar; possible answers are "Keep playing"/"Give up" */
                                                      _("Are you sure you want to give up and view the solution?"));

            /* Translators: popup dialog possible answer (with a mnemonic that appears pressing Alt); appearing when user clicks the "Give up" button in the bottom bar; other possible answer is "_Give Up" */
            dialog.add_buttons (_("_Keep Playing"), ResponseType.REJECT,

            /* Translators: popup dialog possible answer (with a mnemonic that appears pressing Alt); appearing when user clicks the "Give up" button in the bottom bar; other possible answer is "_Keep Playing" */
                                _("_Give Up"),      ResponseType.ACCEPT);

            dialog.response.connect ((_dialog, response) => {
                    _dialog.destroy ();
                    if (response == ResponseType.ACCEPT)
                        puzzle.solve ();
                });
            dialog.present ();
            return;
        }
        puzzle.solve ();
    }

    private void finish_cb ()
    {
        view.finish ();
    }

    private void size_changed (SimpleAction action, Variant variant)
    {
        int size = int.parse (variant.get_string ());
        if (size < 2 || size > 6)
            assert_not_reached ();

        if (size == settings.get_int ("grid-size"))
            return;
        settings.set_int ("grid-size", size);
        action.set_state (variant);
        new_game_cb ();
    }

    private void move_up_l ()     { view.move_up    (/* left board */ true);  }
    private void move_down_l ()   { view.move_down  (/* left board */ true);  }
    private void move_left_l ()
    {
        if (!puzzle.is_solved_right)
            view.move_left (/* left board */ true);
        else if (!puzzle.paused && !view.tile_selected)
            finish_cb ();
    }
    private void move_right_l ()  { view.move_right (/* left board */ true);  }
    private void move_up_r ()     { view.move_up    (/* left board */ false); }
    private void move_down_r ()   { view.move_down  (/* left board */ false); }
    private void move_left_r ()   { view.move_left  (/* left board */ false); }
    private void move_right_r ()  { view.move_right (/* left board */ false); }

    private void undo_cb ()
    {
        if (view.tile_selected)
            view.release_selected_tile ();
        else
            view.undo ();
    }

    private void redo_cb ()
    {
        if (view.tile_selected)
            view.release_selected_tile ();
        else
            view.redo ();
    }

    private void reload_cb ()
    {
        if (view.tile_selected)
            view.release_selected_tile ();
        else
            view.reload ();
    }

    private void pause_cb ()
    {
        puzzle.paused = !puzzle.paused;
    }

    private EventControllerKey key_controller;    // for keeping in memory
    private inline bool on_key_pressed (EventControllerKey _key_controller, uint keyval, uint keycode, Gdk.ModifierType state)
    {
        string name = (!) (Gdk.keyval_name (keyval) ?? "");

        if (name == "Escape" && !puzzle.is_solved)
        {
            if (puzzle.paused)
            {
                pause_cb ();
                return true;
            }
            else if (view.tile_selected)
            {
                view.release_selected_tile ();
                return true;
            }
        }
        return false;
    }

    private GestureClick view_click_controller;
    private inline void on_release_on_view (GestureClick _view_click_controller, int n_press, double event_x, double event_y)
    {
        /* Cancel pause on click */
        if (puzzle.paused)
            puzzle.paused = false;
    }

    /*\
    * * help/about
    \*/

    private void help_cb ()
    {
        show_uri (active_window, "help:gnome-tetravex", Gdk.CURRENT_TIME);
    }

    private void about_cb ()
    {
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
