public class Gnotravex : Gtk.Application
{
    private const string KEY_GRID_SIZE = "grid-size";

    private Settings settings;

    private Puzzle puzzle;
    private Gtk.Label clock_label;
    private GnomeGamesSupport.Scores highscores;

    private PuzzleView view;
    private const GnomeGamesSupport.ScoresCategory scorecats[] =
    {
        { "2x2", N_("2×2") },
        { "3x3", N_("3×3") },
        { "4x4", N_("4×4") },
        { "5x5", N_("5×5") },
        { "6x6", N_("6×6") }
    };

    private Gtk.Window window;
    private int window_width;
    private int window_height;
    private bool is_fullscreen;
    private bool is_maximized;

    Gtk.ToolButton pause_button;
    Gtk.ToolButton fullscreen_button;

    private const GLib.ActionEntry[] action_entries =
    {
        { "new-game",      new_game_cb                                            },
        { "pause",         pause_cb,                                              },
        { "fullscreen",    fullscreen_cb                                          },
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

    public Gnotravex ()
    {
        Object (application_id: "org.gnome.gnotravex", flags: ApplicationFlags.FLAGS_NONE);
    }

    protected override void startup ()
    {
        base.startup ();

        Environment.set_application_name (_("Tetravex"));
        GnomeGamesSupport.stock_init ();
        Gtk.Window.set_default_icon_name ("gnotravex");

        add_action_entries (action_entries, this);

        var builder = new Gtk.Builder ();
        try
        {
            builder.add_from_file (Path.build_filename (DATA_DIRECTORY, "gnotravex.ui"));
        }
        catch (Error e)
        {
            error ("Unable to build menus: %s", e.message);
        }
        set_app_menu (builder.get_object ("gnotravex-menu") as MenuModel);

        settings = new Settings ("org.gnome.gnotravex");

        highscores = new GnomeGamesSupport.Scores ("gnotravex", scorecats, null, null, 0, GnomeGamesSupport.ScoreStyle.TIME_ASCENDING);

        window = new Gtk.ApplicationWindow (this);
        window.title = _("Tetravex");
        window.configure_event.connect (window_configure_event_cb);
        window.window_state_event.connect (window_state_event_cb);
        window.set_default_size (settings.get_int ("window-width"), settings.get_int ("window-height"));        
        if (settings.get_boolean ("window-is-fullscreen"))
            window.fullscreen ();
        else if (settings.get_boolean ("window-is-maximized"))
            window.maximize ();

        (lookup_action ("size") as SimpleAction).set_state ("%d".printf (settings.get_int (KEY_GRID_SIZE)));

        var grid = new Gtk.Grid ();
        grid.show ();
        window.add (grid);

        var toolbar = new Gtk.Toolbar ();
        toolbar.show_arrow = false;
        toolbar.get_style_context ().add_class (Gtk.STYLE_CLASS_PRIMARY_TOOLBAR);
        toolbar.show ();
        grid.attach (toolbar, 0, 0, 1, 1);

        var new_game_button = new Gtk.ToolButton.from_stock (GnomeGamesSupport.STOCK_NEW_GAME);
        new_game_button.action_name = "app.new-game";
        new_game_button.is_important = true;
        new_game_button.show ();
        toolbar.insert (new_game_button, -1);

        var solve_button = new Gtk.ToolButton (null, _("Solve"));
        solve_button.action_name = "app.solve";
        solve_button.is_important = true;
        solve_button.show ();
        toolbar.insert (solve_button, -1);

        pause_button = new Gtk.ToolButton.from_stock (GnomeGamesSupport.STOCK_PAUSE_GAME);
        pause_button.action_name = "app.pause";
        pause_button.show ();
        toolbar.insert (pause_button, -1);

        fullscreen_button = new Gtk.ToolButton.from_stock (GnomeGamesSupport.STOCK_FULLSCREEN);
        fullscreen_button.action_name = "app.fullscreen";
        fullscreen_button.show ();
        toolbar.insert (fullscreen_button, -1);

        view = new PuzzleView ();
        view.hexpand = true;
        view.vexpand = true;
        view.button_press_event.connect (view_button_press_event);
        view.show ();
        grid.attach (view, 0, 1, 1, 1);

        var time_item = new Gtk.ToolItem ();
        time_item.set_expand (true);
        time_item.show ();
        toolbar.insert (time_item, -1);

        var time_align = new Gtk.Alignment (1.0f, 0.5f, 0.0f, 0.0f);
        time_align.show ();
        time_item.add (time_align);

        var time_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0);
        time_box.show ();
        time_align.add (time_box);

        clock_label = new Gtk.Label ("");
        clock_label.show ();
        time_box.pack_start (clock_label, false, false, 0);
        tick_cb ();

        new_game ();
    }

    private bool window_configure_event_cb (Gdk.EventConfigure event)
    {
        if (!is_maximized && !is_fullscreen)
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
        if ((event.changed_mask & Gdk.WindowState.FULLSCREEN) != 0)
        {
            is_fullscreen = (event.new_window_state & Gdk.WindowState.FULLSCREEN) != 0;
            if (is_fullscreen)
                fullscreen_button.stock_id = GnomeGamesSupport.STOCK_LEAVE_FULLSCREEN;
            else
                fullscreen_button.stock_id = GnomeGamesSupport.STOCK_FULLSCREEN;
        }
        return false;
    }

    protected override void shutdown ()
    {
        base.shutdown ();

        /* Save window state */
        settings.set_int ("window-width", window_width);
        settings.set_int ("window-height", window_height);
        settings.set_boolean ("window-is-maximized", is_maximized);
        settings.set_boolean ("window-is-fullscreen", is_fullscreen);
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
        highscores.set_category (scorecats[size - 2].key);
        puzzle = new Puzzle (size);
        puzzle.tick.connect (tick_cb);
        puzzle.solved.connect (solved_cb);
        view.puzzle = puzzle;

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
        clock_label.set_text ("%s: %02d:%02d:%02d".printf (_("Time"), hours, minutes, seconds));
    }

    private void solved_cb (Puzzle puzzle)
    {
        var seconds = (int) (puzzle.elapsed + 0.5);
        var pos = highscores.add_time_score ((seconds / 60) * 1.0 + (seconds % 60) / 100.0);

        var scores_dialog = new GnomeGamesSupport.ScoresDialog (window, highscores, _("Tetravex Scores"));
        scores_dialog.set_category_description (_("Size:"));
        scores_dialog.set_hilight (pos);
        if (pos > 0)
            scores_dialog.set_message ("<b>%s</b>\n\n%s".printf (_("Congratulations!"), pos == 1 ? _("Your score is the best!") : _("Your score has made the top ten.")));
        scores_dialog.set_buttons (GnomeGamesSupport.ScoresButtons.QUIT_BUTTON | GnomeGamesSupport.ScoresButtons.NEW_GAME_BUTTON);
        if (scores_dialog.run () == Gtk.ResponseType.REJECT)
            window.destroy ();
        else
            new_game ();
        scores_dialog.destroy ();
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
        var scores_dialog = new GnomeGamesSupport.ScoresDialog (window, highscores, _("Tetravex Scores"));
        scores_dialog.set_category_description (_("Size:"));
        scores_dialog.run ();
        scores_dialog.destroy ();
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
            Gtk.show_uri (window.get_screen (), "help:gnotravex", Gtk.get_current_event_time ());
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
        var license = GnomeGamesSupport.get_license (_("Tetravex"));
        Gtk.show_about_dialog (window,
                               "program-name", _("Tetravex"),
                               "version", VERSION,
                               "comments",
                               _("GNOME Tetravex is a simple puzzle where pieces must be positioned so that the same numbers are touching each other.\n\nTetravex is a part of GNOME Games."),
                               "copyright",
                               "Copyright \xc2\xa9 1999-2008 Lars Rydlinge",
                               "license", license,
                               "wrap-license", true,
                               "authors", authors,
                               "documenters", documenters,
                               "translator-credits", _("translator-credits"),
                               "logo-icon-name", "gnotravex",
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
            pause_button.stock_id = GnomeGamesSupport.STOCK_RESUME_GAME;
        else
            pause_button.stock_id = GnomeGamesSupport.STOCK_PAUSE_GAME;
    }

    private void fullscreen_cb ()
    {
        if (is_fullscreen)
            window.unfullscreen ();
        else
            window.fullscreen ();
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

        GnomeGamesSupport.scores_startup ();
        var app = new Gnotravex ();
        return app.run (args);
    }
}
