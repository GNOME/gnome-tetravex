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
    private const string KEY_GRID_SIZE = "grid-size";

    private static bool start_paused = false;
    private static int game_size = 0;

    private GLib.Settings settings;

    private Puzzle puzzle;
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

    private const OptionEntry[] option_entries =
    {
        { "version", 'v', 0, OptionArg.NONE, null, N_("Print release version and exit"), null },
        { "paused", 'p', 0, OptionArg.NONE, null, N_("Start the game paused"), null },
        { "size", 's', 0, OptionArg.INT, null, N_("Set size of board (2-6)"), null },
        { null }
    };

    private const GLib.ActionEntry[] action_entries =
    {
        { "new-game",       new_game_cb                                     },
        { "pause",          pause_cb                                        },
        { "solve",          solve_cb                                        },
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

        Environment.set_application_name (_("Tetravex"));
        Window.set_default_icon_name ("org.gnome.Tetravex");

        add_action_entries (action_entries, this);
        set_accels_for_action ("app.new-game",      {"<Primary>n"       });
        set_accels_for_action ("app.pause",         {"<Primary>p",
                                                              "Pause"   });
        set_accels_for_action ("app.help",          {         "F1"      });
        set_accels_for_action ("app.quit",          {"<Primary>q",
                                                     "<Primary>w"       });
        set_accels_for_action ("app.move-up",       {"<Primary>Up"      });
        set_accels_for_action ("app.move-down",     {"<Primary>Down"    });
        set_accels_for_action ("app.move-left",     {"<Primary>Left"    });
        set_accels_for_action ("app.move-right",    {"<Primary>Right"   });

        Builder builder = new Builder.from_resource ("/org/gnome/Tetravex/gnome-tetravex.ui");

        settings = new GLib.Settings ("org.gnome.Tetravex");

        history = new History (Path.build_filename (Environment.get_user_data_dir (), "gnome-tetravex", "history"));

        window = (ApplicationWindow) builder.get_object ("gnome-tetravex-window");
        this.add_window (window);
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
        headerbar.title = _("Tetravex");
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

        Button play_button = new Button ();
        play_button.get_style_context ().add_class ("image-button");
        Image image = new Image.from_icon_name ("media-playback-start-symbolic", IconSize.DND);
        image.margin = 10;
        play_button.add (image);
        play_button.valign = Align.CENTER;
        play_button.halign = Align.START;
        play_button.margin_start = 35;
        play_button.action_name = "app.pause"; /* not a typo */
        play_button.tooltip_text = _("Resume the game");
        sizegroup.add_widget (play_button);

        Button pause_button = new Button ();
        pause_button.get_style_context ().add_class ("image-button");
        image = new Image.from_icon_name ("media-playback-pause-symbolic", IconSize.DND);
        image.margin = 10;
        pause_button.add (image);
        pause_button.valign = Align.CENTER;
        pause_button.halign = Align.START;
        pause_button.margin_start = 35;
        pause_button.action_name = "app.pause";
        pause_button.tooltip_text = _("Pause the game");
        sizegroup.add_widget (pause_button);

        play_pause_stack = new Stack ();
        play_pause_stack.add_named (play_button, "play");
        play_pause_stack.add_named (pause_button, "pause");
        grid.attach (play_pause_stack, 0, 1, 1, 1);

        Button new_game_button = new Button ();
        new_game_button.get_style_context ().add_class ("image-button");
        image = new Image.from_icon_name ("view-refresh-symbolic", IconSize.DND);
        image.margin = 10;
        new_game_button.add (image);
        new_game_button.valign = Align.CENTER;
        new_game_button.halign = Align.END;
        new_game_button.margin_end = 35;
        new_game_button.action_name = "app.new-game";
        new_game_button.tooltip_text = _("Start a new game");
        sizegroup.add_widget (new_game_button);

        Button solve_button = new Button ();
        solve_button.get_style_context ().add_class ("image-button");
        image = new Image.from_icon_name ("dialog-question-symbolic", IconSize.DND);
        image.margin = 10;
        solve_button.add (image);
        solve_button.valign = Align.CENTER;
        solve_button.halign = Align.END;
        solve_button.margin_end = 35;
        solve_button.action_name = "app.solve";
        solve_button.tooltip_text = _("Give up and view the solution");
        sizegroup.add_widget (solve_button);

        new_game_solve_stack = new Stack ();
        new_game_solve_stack.add_named (solve_button, "solve");
        new_game_solve_stack.add_named (new_game_button, "new-game");
        grid.attach (new_game_solve_stack, 2, 1, 1, 1);

        Box box = new Box (Orientation.HORIZONTAL, 8);
        image = new Image.from_icon_name ("preferences-system-time-symbolic", IconSize.MENU);
        box.add (image);
        clock_label = new Label ("");
        box.add (clock_label);
        box.halign = Align.CENTER;
        box.valign = Align.BASELINE;
        box.set_margin_top (20);
        box.set_margin_bottom (20);
        grid.attach (box, 1, 1, 1, 1);

        pause_action = (SimpleAction) lookup_action ("pause");
        solve_action = (SimpleAction) lookup_action ("solve");
        view.tile_selected.connect ((/* bool */ selected) => {
                if (puzzle == null || ((!) puzzle).is_solved)
                    return;
                solve_action.set_enabled (!selected);
            });

        window.show_all ();

        tick_cb ();
        new_game ();
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
        pause_action.set_enabled (true);
        solve_action.set_enabled (true);
        new_game_solve_stack.set_visible_child_name ("solve");

        if (puzzle != null)
            SignalHandler.disconnect_by_func (puzzle, null, this);

        int size = settings.get_int (KEY_GRID_SIZE);
        puzzle = new Puzzle (size);
        puzzle.tick.connect (tick_cb);
        puzzle.solved.connect (solved_cb);
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
        if (puzzle != null)
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
        DateTime date = new DateTime.now_local ();
        uint duration = (uint) (puzzle.elapsed + 0.5);
        HistoryEntry entry = new HistoryEntry (date, puzzle.size, duration);
        history.add (entry);
        history.save ();

        pause_action.set_enabled (false);
        solve_action.set_enabled (false);

        int score_dialog_action = show_scores (entry, true);
        if (score_dialog_action == ResponseType.CLOSE)
            window.destroy ();
        else if (score_dialog_action == ResponseType.OK)
            new_game ();
        else
            new_game_solve_stack.set_visible_child_name ("new-game");
    }

    private bool scores_dialog_visible = false; // security for #5
    private int show_scores (HistoryEntry? selected_entry = null, bool show_quit = false)
    {
        scores_dialog_visible = true;
        ScoreDialog dialog = new ScoreDialog (history, selected_entry, show_quit);
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
                                                  _("Are you sure you want to give up and view the solution?"));

        dialog.add_buttons (_("_Keep Playing"), ResponseType.REJECT,
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
        }
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
        string[] authors = { "Lars Rydlinge", "Robert Ancell", null };
        string[] documenters = { "Rob Bradford", null };
        show_about_dialog (window,
                           "program-name", _("Tetravex"),
                           "version", VERSION,
                           "comments",
                           _("Position pieces so that the same numbers are touching each other"),
                           "copyright",
                           "Copyright © 1999–2008 Lars Rydlinge",
                           "license-type", License.GPL_2_0,
                           "wrap-license", true,
                           "authors", authors,
                           "documenters", documenters,
                           "translator-credits", _("translator-credits"),
                           "logo-icon-name", "org.gnome.Tetravex",
                           "website", "https://wiki.gnome.org/Apps/Tetravex",
                           null);
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
                                                      _("Are you sure you want to start a new game with a different board size?"));
            dialog.add_buttons (_("_Keep Playing"),   ResponseType.REJECT,
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
        solve_action.set_enabled (!puzzle.paused);
        play_pause_stack.set_visible_child_name (puzzle.paused ? "play" : "pause");
    }

    private void radio_cb (SimpleAction action, Variant? parameter)
    {
        action.change_state (parameter);
    }
}
