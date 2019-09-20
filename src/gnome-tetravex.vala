/* -*- Mode: vala; tab-width: 4; indent-tabs-mode: nil; c-basic-offset: 4 -*-
 *
 * Copyright (C) 2010-2013 Robert Ancell
 *
 * This program is free software: you can redistribute it and/or modify it under
 * the terms of the GNU General Public License as published by the Free Software
 * Foundation, either version 2 of the License, or (at your option) any later
 * version. See http://www.gnu.org/copyleft/gpl.html the full text of the
 * license.
 */

using Gtk;

private class Tetravex : Gtk.Application
{
    /* Translators: name of the program, as seen in the headerbar, in GNOME Shell, or in the about dialog */
    private const string PROGRAM_NAME = _("Tetravex");

    private const string KEY_GRID_SIZE = "grid-size";

    private static bool start_paused = false;
    private static int game_size = 0;

    private GLib.Settings settings;

    private Puzzle puzzle;
    private bool puzzle_init_done = false;
    private Label clock_label;
    private History history;

    private PuzzleView view;

    private ApplicationWindow window;
    private int window_width;
    private int window_height;
    private bool is_maximized;
    private bool is_tiled;

    private Stack new_game_solve_stack;
    private Stack play_pause_stack;

    private SimpleAction pause_action;
    private SimpleAction solve_action;
    private SimpleAction finish_action;

    private const OptionEntry [] option_entries =
    {
        /* Translators: command-line option description, see 'gnome-tetravex --help' */
        { "paused",  'p', 0, OptionArg.NONE, null, N_("Start the game paused"),          null },

        /* Translators: command-line option description, see 'gnome-tetravex --help' */
        { "size",    's', 0, OptionArg.INT,  null, N_("Set size of board (2-6)"),        null },

        /* Translators: command-line option description, see 'gnome-tetravex --help' */
        { "version", 'v', 0, OptionArg.NONE, null, N_("Print release version and exit"), null },
        {}
    };

    private const GLib.ActionEntry[] action_entries =
    {
        { "new-game",       new_game_cb                                     },
        { "pause",          pause_cb                                        },
        { "solve",          solve_cb                                        },
        { "finish",         finish_cb                                       },
        { "scores",         scores_cb                                       },
        { "quit",           quit                                            },
        { "move-up",        move_up                                         },
        { "move-down",      move_down                                       },
        { "move-left",      move_left                                       },
        { "move-right",     move_right                                      },
        { "size",           radio_cb,       "s",    "'2'",  size_changed    },
        { "help",           help_cb                                         },
        { "about",          about_cb                                        }
    };

    private static int main (string[] args)
    {
        Intl.setlocale (LocaleCategory.ALL, "");
        Intl.bindtextdomain (GETTEXT_PACKAGE, LOCALEDIR);
        Intl.bind_textdomain_codeset (GETTEXT_PACKAGE, "UTF-8");
        Intl.textdomain (GETTEXT_PACKAGE);

        Tetravex app = new Tetravex ();
        return app.run (args);
    }

    private Tetravex ()
    {
        Object (application_id: "org.gnome.Tetravex", flags: ApplicationFlags.FLAGS_NONE);

        add_main_option_entries (option_entries);
    }

    protected override void startup ()
    {
        base.startup ();

        Environment.set_application_name (PROGRAM_NAME);
        Window.set_default_icon_name ("org.gnome.Tetravex");

        add_action_entries (action_entries, this);
        set_accels_for_action ("app.solve",         {"<Primary>h"       });
        set_accels_for_action ("app.scores",        {"<Primary>i"       });
        set_accels_for_action ("app.new-game",      {"<Primary>n"       });
        set_accels_for_action ("app.pause",         {"<Primary>p",
                                                              "Pause"   });
        set_accels_for_action ("app.quit",          {"<Primary>q"       });
        set_accels_for_action ("app.move-up",       {"<Primary>Up"      });
        set_accels_for_action ("app.move-down",     {"<Primary>Down"    });
        set_accels_for_action ("app.move-left",     {"<Primary>Left"    });
        set_accels_for_action ("app.move-right",    {"<Primary>Right"   });
        // F1 and friends are managed manually

        Builder builder = new Builder.from_resource ("/org/gnome/Tetravex/gnome-tetravex.ui");

        settings = new GLib.Settings ("org.gnome.Tetravex");

        history = new History (Path.build_filename (Environment.get_user_data_dir (), "gnome-tetravex", "history"));

        window = (ApplicationWindow) builder.get_object ("gnome-tetravex-window");
        this.add_window (window);
        window.key_press_event.connect (on_key_press_event);
        window.size_allocate.connect (size_allocate_cb);
        window.window_state_event.connect (window_state_event_cb);
        window.set_default_size (settings.get_int ("window-width"), settings.get_int ("window-height"));
        if (settings.get_boolean ("window-is-maximized"))
            window.maximize ();

        if (game_size != 0)
            settings.set_int (KEY_GRID_SIZE, game_size);
        else
            game_size = settings.get_int (KEY_GRID_SIZE);
        ((SimpleAction) lookup_action ("size")).set_state ("%d".printf (game_size));

        HeaderBar headerbar = new HeaderBar ();
        headerbar.title = PROGRAM_NAME;
        headerbar.show_close_button = true;
        window.set_titlebar (headerbar);

        Builder menu_builder = new Builder.from_resource ("/org/gnome/Tetravex/app-menu.ui");
        MenuModel appmenu = (MenuModel) menu_builder.get_object ("app-menu");
        MenuButton menu_button = new MenuButton ();
        menu_button.set_image (new Image.from_icon_name ("open-menu-symbolic", IconSize.BUTTON));
        menu_button.show ();
        menu_button.set_menu_model (appmenu);
        headerbar.pack_end (menu_button);

        Grid grid = (Grid) builder.get_object ("grid");

        view = new PuzzleView ();
        view.hexpand = true;
        view.vexpand = true;
        view.button_release_event.connect (view_button_release_event);
        grid.attach (view, 0, 0, 3, 1);

        SizeGroup sizegroup = new SizeGroup (SizeGroupMode.BOTH);

        Button play_button      = new BottomButton ("media-playback-start-symbolic",
                                                    "app.pause", /* not a typo */
        /* Translators: tooltip text of the "play"/unpause button, in the bottom bar */
                                                    _("Resume the game"),
                                                    /* align end */ false,
                                                    sizegroup);

        Button pause_button     = new BottomButton ("media-playback-pause-symbolic",
                                                    "app.pause",
        /* Translators: tooltip text of the pause button, in the bottom bar */
                                                    _("Pause the game"),
                                                    /* align end */ false,
                                                    sizegroup);

        play_pause_stack = new Stack ();
        play_pause_stack.add_named (play_button, "play");
        play_pause_stack.add_named (pause_button, "pause");
        grid.attach (play_pause_stack, 0, 1, 1, 1);

        Button new_game_button  = new BottomButton ("view-refresh-symbolic",
                                                    "app.new-game",
        /* Translators: tooltip text of the "restart"/new game button, in the bottom bar */
                                                    _("Start a new game"),
                                                    /* align end */ true,
                                                    sizegroup);

        Button solve_button     = new BottomButton ("dialog-question-symbolic",
                                                    "app.solve",
        /* Translators: tooltip text of the "solve"/give up button, in the bottom bar */
                                                    _("Give up and view the solution"),
                                                    /* align end */ true,
                                                    sizegroup);

        Button finish_button    = new BottomButton ("go-previous-symbolic",
                                                    "app.finish",
        /* Translators: tooltip text of bottom bar button that appears is the puzzle is solved on the right part of the board */
                                                    _("Move all tiles left"),
                                                    /* align end */ true,
                                                    sizegroup);

        new_game_solve_stack = new Stack ();
        new_game_solve_stack.add_named (solve_button, "solve");
        new_game_solve_stack.add_named (new_game_button, "new-game");
        new_game_solve_stack.add_named (finish_button, "finish");
        grid.attach (new_game_solve_stack, 2, 1, 1, 1);

        Box box = new Box (Orientation.HORIZONTAL, 8);
        Image image = new Image.from_icon_name ("preferences-system-time-symbolic", IconSize.MENU);
        box.add (image);
        clock_label = new Label ("");
        box.add (clock_label);
        box.halign = Align.CENTER;
        box.valign = Align.BASELINE;
        box.set_margin_top (20);
        box.set_margin_bottom (20);
        grid.attach (box, 1, 1, 1, 1);

        pause_action  = (SimpleAction) lookup_action ("pause");
        solve_action  = (SimpleAction) lookup_action ("solve");
        finish_action = (SimpleAction) lookup_action ("finish");
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

        window.show_all ();

        tick_cb ();
        new_game ();
    }
    private class BottomButton : Button
    {
        construct
        {
            get_style_context ().add_class ("image-button");
        }

        internal BottomButton (string icon_name, string action_name, string tooltip_text, bool align_end, SizeGroup sizegroup)
        {
            Image _image = new Image.from_icon_name (icon_name, IconSize.DND);
            _image.margin = 10;
            Object (action_name: action_name,
                    tooltip_text: tooltip_text,
                    halign: align_end ? Align.END : Align.START,
                    valign: Align.CENTER,
                    margin_start: 35,
                    margin_end: 35,
                    image: _image);

            sizegroup.add_widget (this);
        }
    }

    private void size_allocate_cb (Allocation allocation)
    {
        if (is_maximized || is_tiled)
            return;
        window.get_size (out window_width, out window_height);
    }

    private bool window_state_event_cb (Gdk.EventWindowState event)
    {
        if ((event.changed_mask & Gdk.WindowState.MAXIMIZED) != 0)
            is_maximized = (event.new_window_state & Gdk.WindowState.MAXIMIZED) != 0;
        /* We don’t save this state, but track it for saving size allocation */
        if ((event.changed_mask & Gdk.WindowState.TILED) != 0)
            is_tiled = (event.new_window_state & Gdk.WindowState.TILED) != 0;
        return false;
    }

    protected override void shutdown ()
    {
        base.shutdown ();

        /* Save window state */
        settings.set_int ("window-width", window_width);
        settings.set_int ("window-height", window_height);
        settings.set_boolean ("window-is-maximized", is_maximized);
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

        if (options.contains ("size"))
        {
            game_size = (int) options.lookup_value ("size", VariantType.INT32);
            if ((game_size < 2) || (game_size > 6))
            {
                /* Translators: command-line error message, displayed on invalid game size request; see 'gnome-tetravex -s 1' */
                stderr.printf (N_("Size could only be from 2 to 6.\n"));
                return Posix.EXIT_FAILURE;
            }
        }

        /* Activate */
        return -1;
    }

    protected override void activate ()
    {
        window.present ();
    }

    private void new_game ()
    {
        has_been_finished = false;
        pause_action.set_enabled (true);
        solve_action.set_enabled (true);
        finish_action.set_enabled (false);
        new_game_solve_stack.set_visible_child_name ("solve");

        if (puzzle_init_done)
            SignalHandler.disconnect_by_func (puzzle, null, this);

        int size = settings.get_int (KEY_GRID_SIZE);
        puzzle = new Puzzle ((uint8) size);
        puzzle_init_done = true;
        puzzle.tick.connect (tick_cb);
        puzzle.solved.connect (solved_cb);
        puzzle.solved_right.connect (solved_right_cb);
        puzzle.show_end_game.connect (show_end_game_cb);
        view.puzzle = puzzle;
        tick_cb ();

        if (start_paused)
        {
            puzzle.paused = true;
            start_paused = false;
        }
        update_button_states ();
    }

    private void tick_cb ()
    {
        int elapsed = 0;
        if (puzzle_init_done)
            elapsed = (int) (puzzle.elapsed + 0.5);
        int hours = elapsed / 3600;
        int minutes = (elapsed - hours * 3600) / 60;
        int seconds = elapsed - hours * 3600 - minutes * 60;
        if (hours > 0)
            clock_label.set_text ("%02d∶\xE2\x80\x8E%02d∶\xE2\x80\x8E%02d".printf (hours, minutes, seconds));
        else
            clock_label.set_text ("%02d∶\xE2\x80\x8E%02d".printf (minutes, seconds));
    }

    private void solved_cb (Puzzle puzzle)
    {
        pause_action.set_enabled (false);
        solve_action.set_enabled (false);
        finish_action.set_enabled (false);
    }

    private void solved_right_cb (Puzzle puzzle, bool is_solved)
    {
        if (is_solved)
        {
            solve_action.set_enabled (false);
            finish_action.set_enabled (/* should never happen */ !puzzle.paused);
            new_game_solve_stack.set_visible_child_name ("finish");
        }
        else
        {
            solve_action.set_enabled (/* should never happen */ !puzzle.paused);
            finish_action.set_enabled (false);
            if (!has_been_finished) // keep the "finish" button if it has been clicked
                new_game_solve_stack.set_visible_child_name ("solve");
        }
    }

    private void show_end_game_cb (Puzzle puzzle)
    {
        DateTime date = new DateTime.now_local ();
        uint duration = (uint) (puzzle.elapsed + 0.5);
        HistoryEntry entry = new HistoryEntry (date, puzzle.size, duration);
        history.add (entry);
        history.save ();

        int score_dialog_action = show_scores (entry, true);
        if (score_dialog_action == ResponseType.CLOSE)
            window.destroy ();
        else if (score_dialog_action == ResponseType.OK)
            new_game ();
        else if (score_dialog_action != ResponseType.REJECT)
            new_game_solve_stack.set_visible_child_name ("new-game");
    }

    private bool scores_dialog_visible = false; // security for #5
    private int show_scores (HistoryEntry? selected_entry = null, bool show_quit = false)
    {
        if (scores_dialog_visible)
            return ResponseType.REJECT;

        scores_dialog_visible = true;
        ScoreDialog dialog = new ScoreDialog (history, puzzle.size, selected_entry, show_quit);
        dialog.modal = true;
        dialog.transient_for = window;

        int result = dialog.run ();
        dialog.destroy ();
        scores_dialog_visible = false;

        return result;
    }

    private void new_game_cb ()
    {
        new_game ();
    }

    private void scores_cb ()
    {
        show_scores ();
    }

    private bool view_button_release_event (Widget widget, Gdk.EventButton event)
    {
        /* Cancel pause on click */
        if (puzzle.paused)
        {
            puzzle.paused = false;
            update_button_states ();
            return true;
        }

        return false;
    }

    private void solve_cb ()
    {
        MessageDialog dialog = new MessageDialog (window,
                                                  DialogFlags.MODAL,
                                                  MessageType.QUESTION,
                                                  ButtonsType.NONE,
        /* Translators: popup dialog main text; appearing when user clicks the "Give up" button in the bottom bar; possible answers are "Keep playing"/"Give up" */
                                                  _("Are you sure you want to give up and view the solution?"));


        /* Translators: popup dialog possible answer (with a mnemonic that appears pressing Alt); appearing when user clicks the "Give up" button in the bottom bar; other possible answer is "_Give Up" */
        dialog.add_buttons (_("_Keep Playing"), ResponseType.REJECT,

        /* Translators: popup dialog possible answer (with a mnemonic that appears pressing Alt); appearing when user clicks the "Give up" button in the bottom bar; other possible answer is "_Keep Playing" */
                            _("_Give Up"),      ResponseType.ACCEPT,
                            null);

        int response = dialog.run ();
        dialog.destroy ();

        if (response == ResponseType.ACCEPT)
        {
            puzzle.solve ();
            new_game_solve_stack.set_visible_child_name ("new-game");
            pause_action.set_enabled (false);
            solve_action.set_enabled (false);
            finish_action.set_enabled (false);
        }
    }

    private bool has_been_finished = false;
    private void finish_cb ()
    {
        finish_action.set_enabled (false);
        has_been_finished = true;
        view.finish ();
    }

    private void size_changed (SimpleAction action, Variant variant)
    {
        int size = ((string) variant)[0] - '0'; // FIXME that... is... horrible

        if (size == settings.get_int (KEY_GRID_SIZE))
            return;
        if (view.game_in_progress)
        {
            MessageDialog dialog = new MessageDialog (window,
                                                      DialogFlags.MODAL,
                                                      MessageType.QUESTION,
                                                      ButtonsType.NONE,
        /* Translators: popup dialog main text; appearing when user changes size from the hamburger menu submenu, while a game is started; possible answers are "Keep playing"/"Start New Game" */
                                                      _("Are you sure you want to start a new game with a different board size?"));

        /* Translators: popup dialog possible answer (with a mnemonic that appears pressing Alt); appearing when user clicks the "Give up" button in the bottom bar; other possible answer is "_Start New Game" */
            dialog.add_buttons (_("_Keep Playing"),   ResponseType.REJECT,

        /* Translators: popup dialog possible answer (with a mnemonic that appears pressing Alt); appearing when user clicks the "Give up" button in the bottom bar; other possible answer is "_Keep Playing" */
                                _("_Start New Game"), ResponseType.ACCEPT,
                                null);

            int response = dialog.run ();
            dialog.destroy ();

            if (response != ResponseType.ACCEPT)
                return;
        }
        settings.set_int (KEY_GRID_SIZE, size);
        game_size = (int) size;
        action.set_state (variant);
        new_game ();
    }

    private void move_up ()     { puzzle.move_up ();    }
    private void move_down ()   { puzzle.move_down ();  }
    private void move_left ()   { puzzle.move_left ();  }
    private void move_right ()  { puzzle.move_right (); }

    private void pause_cb (SimpleAction action, Variant? parameter)
    {
        puzzle.paused = !puzzle.paused;
        update_button_states ();
    }

    private void update_button_states ()
    {
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
        play_pause_stack.set_visible_child_name (puzzle.paused ? "play" : "pause");
    }

    private void radio_cb (SimpleAction action, Variant? parameter)
    {
        action.change_state (parameter);
    }

    /*\
    * * help/about
    \*/

    private bool on_key_press_event (Widget widget, Gdk.EventKey event)
    {
        string name = (!) (Gdk.keyval_name (event.keyval) ?? "");

        if (name == "F1") // TODO fix dance done with the F1 & <Primary>F1 shortcuts that show help overlay
        {
            // TODO close popovers
            if ((event.state & Gdk.ModifierType.CONTROL_MASK) != 0)
                return false;                           // help overlay
            if ((event.state & Gdk.ModifierType.SHIFT_MASK) == 0)
            {
                help_cb ();
                return true;
            }
            about_cb ();
            return true;
        }

        return false;
    }

    private void help_cb ()
    {
        try
        {
            show_uri (window.get_screen (), "help:gnome-tetravex", get_current_event_time ());
        }
        catch (Error e)
        {
            warning ("Failed to show help: %s", e.message);
        }
    }

    private void about_cb ()
    {
        string [] authors = {
        /* Translators: text crediting a game author, seen in the About dialog */
            _("Lars Rydlinge"),


        /* Translators: text crediting a game author, seen in the About dialog */
            _("Robert Ancell")
        };

        /* Translators: text crediting a game documenter, seen in the About dialog */
        string [] documenters = { _("Rob Bradford") };


        /* Translators: short description of the application, seen in the About dialog */
        string comments = _("Position pieces so that the same numbers are touching each other");


        /* Translators: text crediting a maintainer, seen in the About dialog; the %u are replaced with the years of start and end */
        string copyright = _("Copyright \xc2\xa9 %u-%u – Lars Rydlinge").printf (1999, 2008) + "\n" +


        /* Translators: text crediting a maintainer, seen in the About dialog; the %u are replaced with the years of start and end */
                           _("Copyright \xc2\xa9 %u-%u – Arnaud Bonatti").printf (2019, 2020);


        /* Translators: about dialog text; label of the website link */
        string website_label = _("Page on GNOME wiki");

        show_about_dialog (window,
                           "program-name",          PROGRAM_NAME,
                           "version",               VERSION,
                           "comments",              comments,
                           "copyright",             copyright,
                           "license-type",          License.GPL_2_0,
                           "wrap-license",          true,
                           "authors",               authors,
                           "documenters",           documenters,
        /* Translators: about dialog text; this string should be replaced by a text crediting yourselves and your translation team, or should be left empty. Do not translate literally! */
                           "translator-credits",    _("translator-credits"),
                           "logo-icon-name",        "org.gnome.Tetravex",
                           "website",               "https://wiki.gnome.org/Apps/Tetravex",
                           "website-label",         website_label,
                           null);
    }
}
