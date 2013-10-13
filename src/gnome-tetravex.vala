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
        headerbar.show ();
        window.set_titlebar (headerbar);

        var grid = builder.get_object ("grid") as Gtk.Grid;

        view = new PuzzleView ();
        view.hexpand = true;
        view.vexpand = true;
        view.button_press_event.connect (view_button_press_event);
        view.show ();
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
        new_game_button.show_all ();
        size.add_widget (new_game_button);
        grid.attach (new_game_button, 0, 1, 1, 1);

        pause_button = new Gtk.ToggleButton ();
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
        pause_button.show_all ();
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
        solve_button.show_all ();
        size.add_widget (solve_button);
        grid.attach (solve_button, 2, 1, 1, 1);

        clock_label = new Gtk.Label ("");
        clock_label.show ();
        tick_cb ();
        grid.attach (clock_label, 1, 2, 1, 1);

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
    }

    private void tick_cb ()
    {
        var elapsed = 0;
        if (puzzle != null)
            elapsed = (int) (puzzle.elapsed + 0.5);
        var hours = elapsed / 3600;
        var minutes = (elapsed - hours * 3600) / 60;
        var seconds = elapsed - hours * 3600 - minutes * 60;
        clock_label.set_text ("%02d:%02d:%02d".printf (hours, minutes, seconds));
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
        var license = "Tetravex is free software; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation; either version 2 of the License, or (at your option) any later version.\n\nTetravex is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.\n\nYou should have received a copy of the GNU General Public License along with Tetravex; if not, write to the Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA";
        Gtk.show_about_dialog (window,
                               "program-name", _("Tetravex"),
                               "version", VERSION,
                               "comments",
                               _("Position pieces so that the same numbers are touching each other\n\nTetravex is a part of GNOME Games."),
                               "copyright",
                               "Copyright \xc2\xa9 1999-2008 Lars Rydlinge",
                               "license", license,
                               "wrap-license", true,
                               "authors", authors,
                               "documenters", documenters,
                               "translator-credits", _("translator-credits"),
                               "logo-icon-name", "gnome-tetravex",
                               "website", "http://www.gnome.org/projects/gnome-games",
                               "website-label", _("GNOME Games web site"),
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

public class ScoreDialog : Gtk.Dialog
{
    private History history;
    private HistoryEntry? selected_entry = null;
    private Gtk.ListStore size_model;
    private Gtk.ListStore score_model;
    private Gtk.ComboBox size_combo;

    public ScoreDialog (History history, HistoryEntry? selected_entry = null, bool show_quit = false)
    {
        this.history = history;
        history.entry_added.connect (entry_added_cb);
        this.selected_entry = selected_entry;

        if (show_quit)
        {
            add_button (_("Quit"), Gtk.ResponseType.CLOSE);
            add_button (_("New Game"), Gtk.ResponseType.OK);
        }
        else
            add_button (_("OK"), Gtk.ResponseType.DELETE_EVENT);
        set_size_request (200, 300);

        var vbox = new Gtk.Box (Gtk.Orientation.VERTICAL, 5);
        vbox.border_width = 6;
        vbox.show ();
        get_content_area ().pack_start (vbox, true, true, 0);

        var hbox = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6);
        hbox.show ();
        vbox.pack_start (hbox, false, false, 0);

        var label = new Gtk.Label (_("Size:"));
        label.show ();
        hbox.pack_start (label, false, false, 0);

        size_model = new Gtk.ListStore (2, typeof (string), typeof (int));

        size_combo = new Gtk.ComboBox ();
        size_combo.changed.connect (size_changed_cb);
        size_combo.model = size_model;
        var renderer = new Gtk.CellRendererText ();
        size_combo.pack_start (renderer, true);
        size_combo.add_attribute (renderer, "text", 0);
        size_combo.show ();
        hbox.pack_start (size_combo, true, true, 0);

        var scroll = new Gtk.ScrolledWindow (null, null);
        scroll.shadow_type = Gtk.ShadowType.ETCHED_IN;
        scroll.set_policy (Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC);
        scroll.show ();
        vbox.pack_start (scroll, true, true, 0);

        score_model = new Gtk.ListStore (3, typeof (string), typeof (string), typeof (int));

        var scores = new Gtk.TreeView ();
        renderer = new Gtk.CellRendererText ();
        scores.insert_column_with_attributes (-1, _("Date"), renderer, "text", 0, "weight", 2);
        renderer = new Gtk.CellRendererText ();
        renderer.xalign = 1.0f;
        scores.insert_column_with_attributes (-1, _("Time"), renderer, "text", 1, "weight", 2);
        scores.model = score_model;
        scores.show ();
        scroll.add (scores);

        foreach (var entry in history.entries)
            entry_added_cb (entry);
    }

    public void set_size (uint size)
    {
        score_model.clear ();

        var entries = history.entries.copy ();
        entries.sort (compare_entries);

        foreach (var entry in entries)
        {
            if (entry.size != size)
                continue;

            var date_label = entry.date.format ("%d/%m/%Y");

            var time_label = "%us".printf (entry.duration);
            if (entry.duration >= 60)
                time_label = "%um %us".printf (entry.duration / 60, entry.duration % 60);

            int weight = Pango.Weight.NORMAL;
            if (entry == selected_entry)
                weight = Pango.Weight.BOLD;

            Gtk.TreeIter iter;
            score_model.append (out iter);
            score_model.set (iter, 0, date_label, 1, time_label, 2, weight);
        }
    }

    private static int compare_entries (HistoryEntry a, HistoryEntry b)
    {
        if (a.size != b.size)
            return (int) a.size - (int) b.size;
        if (a.duration != b.duration)
            return (int) a.duration - (int) b.duration;
        return a.date.compare (b.date);
    }

    private void size_changed_cb (Gtk.ComboBox combo)
    {
        Gtk.TreeIter iter;
        if (!combo.get_active_iter (out iter))
            return;

        int size;
        combo.model.get (iter, 1, out size);
        set_size ((uint) size);
    }

    private void entry_added_cb (HistoryEntry entry)
    {
        /* Ignore if already have an entry for this */
        Gtk.TreeIter iter;
        var have_size_entry = false;
        if (size_model.get_iter_first (out iter))
        {
            do
            {
                int size, height, n_mines;
                size_model.get (iter, 1, out size, 2, out height, 3, out n_mines);
                if (size == entry.size)
                {
                    have_size_entry = true;
                    break;
                }
            } while (size_model.iter_next (ref iter));
        }

        if (!have_size_entry)
        {
            var label = "%u × %u".printf (entry.size, entry.size);

            size_model.append (out iter);
            size_model.set (iter, 0, label, 1, entry.size);
    
            /* Select this entry if don't have any */
            if (size_combo.get_active () == -1)
                size_combo.set_active_iter (iter);

            /* Select this entry if the same category as the selected one */
            if (selected_entry != null && entry.size == selected_entry.size)
                size_combo.set_active_iter (iter);
        }
    }
}
