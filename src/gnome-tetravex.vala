/*
 * Copyright (C) 2010-2013 Robert Ancell
 *
 * This program is free software: you can redistribute it and/or modify it under
 * the terms of the GNU General Public License as published by the Free Software
 * Foundation, either version 2 of the License, or (at your option) any later
 * version. See http://www.gnu.org/copyleft/gpl.html the full text of the
 * license.
 */

public class Tetravex : Gtk.Application
{
    private const string KEY_GRID_SIZE = "grid-size";

    private Settings settings;

    private Puzzle puzzle;
    private Gtk.Label clock_label;
    private History history;

    private PuzzleView view;

    private Gtk.ApplicationWindow window;
    private int window_width;
    private int window_height;
    private bool is_maximized;

    Gtk.Button pause_button;
    Gtk.Image pause_image;
    Gtk.Label pause_label;

    private const GLib.ActionEntry[] action_entries =
    {
        { "new-game",      new_game_cb                                            },
        { "pause",         pause_cb                                               },
        { "solve",         solve_cb                                               },
        { "scores",        scores_cb                                              },
        { "quit",          quit_cb                                                },
        { "move-up",       move_up_cb                                             },
        { "move-down",     move_down_cb                                           },
        { "move-left",     move_left_cb                                           },
        { "move-right",    move_right_cb                                          },
        { "size",          radio_cb,      "s",  "'2'",      size_changed          },
        { "help",          help_cb                                                },
        { "about",         about_cb                                               }
    };

    public Tetravex ()
    {
        Object (application_id: "org.gnome.tetravex", flags: ApplicationFlags.FLAGS_NONE);
    }

    protected override void startup ()
    {
        base.startup ();

        Environment.set_application_name (_("Tetravex"));
        Gtk.Window.set_default_icon_name ("gnome-tetravex");

        add_action_entries (action_entries, this);
        add_accelerator ("<Primary>n", "app.new-game", null);
        add_accelerator ("Pause", "app.pause", null);
        add_accelerator ("F1", "app.help", null);
        add_accelerator ("<Primary>q", "app.quit", null);

        var builder = new Gtk.Builder ();
        try
        {
            builder.add_from_resource ("/org/gnome/tetravex/gnome-tetravex.ui");
            builder.add_from_resource ("/org/gnome/tetravex/app-menu.ui");
        }
        catch (Error e)
        {
            error ("Unable to build menus: %s", e.message);
        }

        set_app_menu (builder.get_object ("gnome-tetravex-menu") as MenuModel);

        settings = new Settings ("org.gnome.tetravex");

        history = new History (Path.build_filename (Environment.get_user_data_dir (), "gnome-tetravex", "history"));
        history.load ();

        window = builder.get_object ("gnome-tetravex-window") as Gtk.ApplicationWindow;
        this.add_window (window);
        window.configure_event.connect (window_configure_event_cb);
        window.window_state_event.connect (window_state_event_cb);
        window.set_default_size (settings.get_int ("window-width"), settings.get_int ("window-height"));        
        if (settings.get_boolean ("window-is-maximized"))
            window.maximize ();

        (lookup_action ("size") as SimpleAction).set_state ("%d".printf (settings.get_int (KEY_GRID_SIZE)));

        var headerbar = new Gtk.HeaderBar ();
        headerbar.title = _("Tetravex");
        headerbar.show_close_button = true;
        window.set_titlebar (headerbar);

        var grid = builder.get_object ("grid") as Gtk.Grid;

        view = new PuzzleView ();
        view.hexpand = true;
        view.vexpand = true;
        view.button_press_event.connect (view_button_press_event);
        grid.attach (view, 0, 0, 3, 1);

        var size = new Gtk.SizeGroup (Gtk.SizeGroupMode.BOTH);

        var new_game_button = new Gtk.Button ();
        var box = new Gtk.Box (Gtk.Orientation.VERTICAL, 2);
        var image = new Gtk.Image.from_icon_name ("view-refresh-symbolic", Gtk.IconSize.DIALOG);
        box.pack_start (image);
        var label = new Gtk.Label.with_mnemonic (_("Play _Again"));
        box.pack_start (label);
        new_game_button.add (box);
        new_game_button.valign = Gtk.Align.CENTER;
        new_game_button.halign = Gtk.Align.CENTER;
        new_game_button.relief = Gtk.ReliefStyle.NONE;
        new_game_button.action_name = "app.new-game";
        size.add_widget (new_game_button);
        grid.attach (new_game_button, 0, 1, 1, 1);

        pause_button = new Gtk.Button ();
        box = new Gtk.Box (Gtk.Orientation.VERTICAL, 2);
        pause_image = new Gtk.Image.from_icon_name ("media-playback-pause-symbolic", Gtk.IconSize.DIALOG);
        box.pack_start (pause_image);
        pause_label = new Gtk.Label.with_mnemonic (_("_Pause"));
        box.pack_start (pause_label);
        pause_button.add (box);
        pause_button.valign = Gtk.Align.CENTER;
        pause_button.halign = Gtk.Align.CENTER;
        pause_button.relief = Gtk.ReliefStyle.NONE;
        pause_button.action_name = "app.pause";
        size.add_widget (pause_button);
        grid.attach (pause_button, 1, 1, 1, 1);

        var solve_button = new Gtk.Button ();
        box = new Gtk.Box (Gtk.Orientation.VERTICAL, 2);
        image = new Gtk.Image.from_icon_name ("dialog-question-symbolic", Gtk.IconSize.DIALOG);
        box.pack_start (image);
        label = new Gtk.Label.with_mnemonic (_("_Resolve"));
        box.pack_start (label);
        solve_button.add (box);
        solve_button.valign = Gtk.Align.CENTER;
        solve_button.halign = Gtk.Align.CENTER;
        solve_button.relief = Gtk.ReliefStyle.NONE;
        solve_button.action_name = "app.solve";
        size.add_widget (solve_button);
        grid.attach (solve_button, 2, 1, 1, 1);

        box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 2);
        box.spacing = 8;
        image = new Gtk.Image.from_icon_name ("preferences-system-time-symbolic", Gtk.IconSize.MENU);
        box.add (image);
        clock_label = new Gtk.Label ("");
        box.add (clock_label);
        box.halign = Gtk.Align.CENTER;
        box.valign = Gtk.Align.BASELINE;
        box.set_margin_top (20);
        box.set_margin_bottom (20);
        grid.attach (box, 0, 2, 3, 1);

        window.show_all ();

        tick_cb ();
        new_game ();
    }

    private bool window_configure_event_cb (Gdk.EventConfigure event)
    {
        if (!is_maximized)
        {
            window_width = event.width;
            window_height = event.height;
        }

        return false;
    }

    private bool window_state_event_cb (Gdk.EventWindowState event)
    {
        if ((event.changed_mask & Gdk.WindowState.MAXIMIZED) != 0)
            is_maximized = (event.new_window_state & Gdk.WindowState.MAXIMIZED) != 0;

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

    protected override void activate ()
    {
        window.present ();
    }

    private void new_game ()
    {
        if (puzzle != null)
            SignalHandler.disconnect_by_func (puzzle, null, this);

        var size = settings.get_int (KEY_GRID_SIZE);
        puzzle = new Puzzle (size);
        puzzle.tick.connect (tick_cb);
        puzzle.solved.connect (solved_cb);
        view.puzzle = puzzle;
        tick_cb ();

        var pause = lookup_action ("pause") as SimpleAction;
        pause.change_state (false);

        update_button_states ();
    }

    private void tick_cb ()
    {
        var elapsed = 0;
        if (puzzle != null)
            elapsed = (int) (puzzle.elapsed + 0.5);
        var hours = elapsed / 3600;
        var minutes = (elapsed - hours * 3600) / 60;
        var seconds = elapsed - hours * 3600 - minutes * 60;
        if (hours > 0)
          clock_label.set_text ("%02d:%02d:%02d".printf (hours, minutes, seconds));
        else
          clock_label.set_text ("%02d:%02d".printf (minutes, seconds));
    }

    private void solved_cb (Puzzle puzzle)
    {
        var date = new DateTime.now_local ();
        var duration = (uint) (puzzle.elapsed + 0.5);
        var entry = new HistoryEntry (date, puzzle.size, duration);
        history.add (entry);
        history.save ();

        if (show_scores (entry, true) == Gtk.ResponseType.CLOSE)
            window.destroy ();
        else
            new_game ();
    }

    private int show_scores (HistoryEntry? selected_entry = null, bool show_quit = false)
    {
        var dialog = new ScoreDialog (history, selected_entry, show_quit);
        dialog.modal = true;
        dialog.transient_for = window;

        var result = dialog.run ();
        dialog.destroy ();

        return result;
    }

    private void new_game_cb ()
    {
        new_game ();
    }

    private void quit_cb ()
    {
        window.destroy ();
    }

    private void scores_cb ()
    {
        show_scores ();    
    }

    private bool view_button_press_event (Gtk.Widget widget, Gdk.EventButton event)
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
        puzzle.solve ();
    }
    
    private void help_cb ()
    {
        try
        {
            Gtk.show_uri (window.get_screen (), "help:gnome-tetravex", Gtk.get_current_event_time ());
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
        Gtk.show_about_dialog (window,
                               "program-name", _("Tetravex"),
                               "version", VERSION,
                               "comments",
                               _("Position pieces so that the same numbers are touching each other\n\nTetravex is a part of GNOME Games."),
                               "copyright",
                               "Copyright © 1999–2008 Lars Rydlinge",
                               "license-type", Gtk.License.GPL_2_0,
                               "wrap-license", true,
                               "authors", authors,
                               "documenters", documenters,
                               "translator-credits", _("translator-credits"),
                               "logo-icon-name", "gnome-tetravex",
                               "website", "https://wiki.gnome.org/Apps/Tetravex",
                               null);
    }

    private void size_changed (SimpleAction action, Variant value)
    {
        var size = ((string) value)[0] - '0';

        if (size == settings.get_int (KEY_GRID_SIZE))
            return;
        settings.set_int (KEY_GRID_SIZE, size);
        action.set_state (value);
        new_game ();
    }

    private void move_up_cb ()
    {
        puzzle.move_up ();
    }

    private void move_left_cb ()
    {
        puzzle.move_left ();
    }

    private void move_right_cb ()
    {
        puzzle.move_right ();
    }

    private void move_down_cb ()
    {
        puzzle.move_down ();
    }

    private void pause_cb (SimpleAction action, Variant? parameter)
    {
        puzzle.paused = !puzzle.paused;
        update_button_states ();
    }

    private void update_button_states ()
    {
        var solve = lookup_action ("solve") as SimpleAction;
        solve.set_enabled (!puzzle.paused);
        if (puzzle.paused)
        {
            if (pause_button.get_direction () == Gtk.TextDirection.RTL)
                pause_image.icon_name = "media-playback-start-rtl-symbolic";
            else
                pause_image.icon_name = "media-playback-start-symbolic";
            pause_label.label = _("Res_ume");
        }
        else
        {
            pause_image.icon_name = "media-playback-pause-symbolic";
            pause_label.label = _("_Pause");
        }
    }

    private void radio_cb (SimpleAction action, Variant? parameter)
    {
        action.change_state (parameter);
    }

    public static int main (string[] args)
    {
        Intl.setlocale (LocaleCategory.ALL, "");
        Intl.bindtextdomain (GETTEXT_PACKAGE, LOCALEDIR);
        Intl.bind_textdomain_codeset (GETTEXT_PACKAGE, "UTF-8");
        Intl.textdomain (GETTEXT_PACKAGE);

        var app = new Tetravex ();
        return app.run (args);
    }
}
