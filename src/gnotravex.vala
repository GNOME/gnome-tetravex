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
    private SimpleAction pause;
    private SimpleAction solve;
    private GnomeGamesSupport.FullscreenAction fullscreen_action;
    private GnomeGamesSupport.PauseAction pause_action;

    private const GLib.ActionEntry[] action_entries =
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

    private const Gtk.ActionEntry actions[] =
    {
        {"NewGame", GnomeGamesSupport.STOCK_NEW_GAME, null, null, N_("Start a new game"), new_game_cb},
        {"Solve", null, N_("Solve"), null, N_("Solve the game"), solve_cb}
    };

    private const string ui_description =
        "<ui>" +
        "    <toolbar name='Toolbar'>" +
        "        <toolitem action='NewGame'/>" +
        "        <toolitem action='Solve'/>" +
        "        <toolitem action='PauseGame'/>" +
        "        <toolitem action='Fullscreen'/>" +
        "    </toolbar>" +
        "</ui>";

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
        GnomeGamesSupport.settings_bind_window_state ("/org/gnome/gnotravex/", window);

        (lookup_action ("size") as SimpleAction).set_state ("%d".printf (settings.get_int (KEY_GRID_SIZE)));

        var grid = new Gtk.Grid ();
        grid.show ();
        window.add (grid);

        var action_group = new Gtk.ActionGroup ("group");
        action_group.set_translation_domain (GETTEXT_PACKAGE);
        action_group.add_actions (actions, this);

        var ui_manager = new Gtk.UIManager ();
        ui_manager.insert_action_group (action_group, 0);
        try
        {
            ui_manager.add_ui_from_string (ui_description, -1);
        }
        catch (Error e)
        {
            warning ("Failed to load UI: %s", e.message);
        }
        action_group.get_action ("NewGame").is_important = true;
        action_group.get_action ("Solve").is_important = true;

        fullscreen_action = new GnomeGamesSupport.FullscreenAction ("Fullscreen", window);
        action_group.add_action_with_accel (fullscreen_action, null);

        pause_action = new GnomeGamesSupport.PauseAction ("PauseGame");
        pause_action.state_changed.connect (pause_cb);
        action_group.add_action_with_accel (pause_action, null);

        var toolbar = (Gtk.Toolbar) ui_manager.get_widget ("/Toolbar");
        toolbar.show_arrow = false;
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

        clock_label = new Gtk.Label ("");
        clock_label.show ();
        time_box.pack_start (clock_label, false, false, 0);
        tick_cb ();

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
        puzzle.tick.connect (tick_cb);
        puzzle.solved.connect (solved_cb);
        view.puzzle = puzzle;

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
        if ((bool) pause.get_state ())
        {
            pause.change_state (false);
            return true;
        }

        return false;
    }

    private void pause_changed (SimpleAction action, Variant state)
    {
        pause_action.set_is_paused ((bool) state);
    }

    private void solve_cb ()
    {
        puzzle.solve ();
    }
    
    private void pause_cb ()
    {
        solve.set_enabled (!pause_action.get_is_paused ());
        puzzle.paused = pause_action.get_is_paused ();
        pause.set_state (pause_action.get_is_paused ());
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
