public class Gnotravex : Gtk3.Application
{
    private const string KEY_GRID_SIZE = "grid-size";

    private Settings settings;

    private Puzzle puzzle;
    private GnomeGamesSupport.Clock clock;
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
    private SimpleAction pause;
    private SimpleAction solve;

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
        pause = lookup_action ("pause") as SimpleAction;
        solve = lookup_action ("solve") as SimpleAction;

        try
        {
            var builder = new Gtk.Builder ();
            builder.add_from_string (menu_description, -1);
            app_menu = (GLib2.MenuModel) builder.get_object ("app-menu");
        }
        catch (Error e)
        {
            error ("Unable to build menus: %s", e.message);
        }

        settings = new Settings ("org.gnome.gnotravex");

        highscores = new GnomeGamesSupport.Scores ("gnotravex", scorecats, null, null, 0, GnomeGamesSupport.ScoreStyle.TIME_ASCENDING);

        window = new Gtk3.ApplicationWindow (this);
        window.title = _("Tetravex");
        GnomeGamesSupport.settings_bind_window_state ("/org/gnome/gnotravex/", window);

        (lookup_action ("size") as SimpleAction).set_state ("%d".printf (settings.get_int (KEY_GRID_SIZE)));

        var grid = new Gtk.Grid ();
        grid.show ();
        window.add (grid);

        var toolbar = new Gtk.Toolbar ();
        toolbar.get_style_context ().add_class (Gtk.STYLE_CLASS_PRIMARY_TOOLBAR);
        toolbar.show ();
        grid.attach (toolbar, 0, 0, 1, 1);

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

        var time_label = new Gtk.Label (_("Time:"));
        time_label.show ();
        time_box.pack_start (time_label, false, false, 0);

        var label = new Gtk.Label (" ");
        label.show ();
        time_box.pack_start (label, false, false, 0);
        clock = new GnomeGamesSupport.Clock ();
        clock.show ();
        time_box.pack_start (clock, false, false, 0);

        new_game ();
    }

    protected override void shutdown ()
    {
        base.shutdown ();
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
        puzzle.solved.connect (solved_cb);
        view.puzzle = puzzle;

        pause.change_state (false);
        clock.reset ();
        clock.start ();
    }

    private void solved_cb (Puzzle puzzle)
    {
        clock.stop ();

        var seconds = clock.get_seconds ();
        var pos = highscores.add_time_score ((seconds / 60) * 1.0 + (seconds % 60) / 100.0);

        var scores_dialog = new GnomeGamesSupport.ScoresDialog (window, highscores, _("Tetravex Scores"));
        scores_dialog.set_category_description (_("Size:"));
        scores_dialog.set_hilight (pos);
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
        if ((bool) pause.get_state ())
        {
            pause.change_state (false);
            return true;
        }

        return false;
    }

    private void pause_changed (SimpleAction action, Variant state)
    {
        var paused = (bool) state;
        solve.set_enabled (!paused);
        view.is_paused = paused;

        if (paused)
            clock.stop ();
        else
            clock.start ();

        action.set_state (state);
    }

    private void solve_cb ()
    {
        puzzle.solve ();
        clock.stop ();
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

    private void toggle_cb (SimpleAction action, Variant? parameter)
    {
        action.change_state (!(bool) action.get_state ());
    }

    private void radio_cb (SimpleAction action, Variant? parameter)
    {
        action.change_state (parameter);
    }

    private const GLib2.ActionEntry[] action_entries =
    {
        { "new-game",      new_game_cb                                            },
        { "pause",         toggle_cb,    null, "false",     pause_changed         },
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

    private const string menu_description =
        "<interface>" +
          "<menu id='app-menu'>" +
            "<section>" +
              "<item label='_New Game' action='app.new-game' accel='<Primary>n'/>" +
              "<item label='_Pause' action='app.pause' accel='p'/>" +
              "<item label='_Solve' action='app.solve'/>" +
               "<submenu label='_Move'>" +
                 "<section>" +
                   "<item label='_Up' action='app.move-up' accel='<Primary>Up'/>" +
                   "<item label='_Left' action='app.move-left' accel='<Primary>Left'/>" +
                   "<item label='_Right' action='app.move-right' accel='<Primary>Right'/>" +
                   "<item label='_Down' action='app.move-down' accel='<Primary>Down'/>" +
                 "</section>" +
               "</submenu>" +
              "<item label='_Scores' action='app.scores'/>" +
             "</section>" +
             "<section>" +
               "<submenu label='_Size'>" +
                 "<section>" +
                   "<item label='_2×2' action='app.size' target='2'/>" +
                   "<item label='_3×3' action='app.size' target='3'/>" +
                   "<item label='_4×4' action='app.size' target='4'/>" +
                   "<item label='_5×5' action='app.size' target='5'/>" +
                   "<item label='_6×6' action='app.size' target='6'/>" +
                 "</section>" +
               "</submenu>" +
             "</section>" +
             "<section>" +
               "<item label='_Help' action='app.help'/>" +
               "<item label='_About' action='app.about'/>" +
             "</section>" +
             "<section>" +
               "<item label='_Quit' action='app.quit'/>" +
             "</section>" +
           "</menu>" +
         "</interface>";

    public static int main (string[] args)
    {
        GnomeGamesSupport.scores_startup ();
        var app = new Gnotravex ();
        return app.run (args);
    }
}
