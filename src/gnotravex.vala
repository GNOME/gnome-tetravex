public class Gnotravex : Gtk.Window
{
    private const int LONG_COUNT = 15;
    private const int SHORT_COUNT = 5;
    private const int DELAY = 10;

    private const string KEY_GRID_SIZE = "grid-size";
    private const string KEY_CLICK_MOVE = "click-to-move";

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

    const Gtk.RadioActionEntry size_action_entry[] =
    {
        {"Size2x2", null, N_("_2×2"), null, N_("Play on a 2×2 board"), 2},
        {"Size3x3", null, N_("_3×3"), null, N_("Play on a 3×3 board"), 3},
        {"Size4x4", null, N_("_4×4"), null, N_("Play on a 4×4 board"), 4},
        {"Size5x5", null, N_("_5×5"), null, N_("Play on a 5×5 board"), 5},
        {"Size6x6", null, N_("_6×6"), null, N_("Play on a 6×6 board"), 6}
    };

    private Gtk.Action new_game_action;
    private GnomeGamesSupport.PauseAction pause_action;
    private Gtk.Action solve_action;
    private Gtk.Action scores_action;
    private Gtk.Action move_up_action;
    private Gtk.Action move_left_action;
    private Gtk.Action move_right_action;
    private Gtk.Action move_down_action;

    private const string ui_description =
        "<ui>" +
        "    <menubar name='MainMenu'>" +
        "        <menu action='GameMenu'>" +
        "            <menuitem action='NewGame'/>" +
        "            <menuitem action='PauseGame'/>" +
        "            <separator/>" +
        "            <menu action='MoveMenu'>" +
        "                <menuitem action='MoveUp'/>" +
        "                <menuitem action='MoveLeft'/>" +
        "                <menuitem action='MoveRight'/>" +
        "                <menuitem action='MoveDown'/>" +
        "            </menu>" +
        "            <menuitem action='Solve'/>" +
        "            <separator/>" +
        "            <menuitem action='Scores'/>" +
        "            <separator/>" +
        "            <menuitem action='Quit'/>" +
        "        </menu>" +
        "        <menu action='SettingsMenu'>" +
        "            <menuitem action='Fullscreen'/>" +
        "            <menuitem action='ClickToMove'/>" +
        "            <separator/>" +
        "            <menuitem action='Size2x2'/>" +
        "            <menuitem action='Size3x3'/>" +
        "            <menuitem action='Size4x4'/>" +
        "            <menuitem action='Size5x5'/>" +
        "            <menuitem action='Size6x6'/>" +
        "        </menu>" +
        "        <menu action='HelpMenu'>" +
        "            <menuitem action='Contents'/>" +
        "            <menuitem action='About'/>" +
        "        </menu>" +
        "    </menubar>" +
        "  <toolbar name='Toolbar'>" +
        "    <toolitem action='NewGame'/>" +
        "    <toolitem action='PauseGame'/>" +
        "    <toolitem action='LeaveFullscreen'/>" +
        "  </toolbar>" +
        "</ui>";
        
    public Gnotravex ()
    {
        settings = new Settings ("org.gnome.gnotravex");

        highscores = new GnomeGamesSupport.Scores ("gnotravex", scorecats, null, null, 0, GnomeGamesSupport.ScoreStyle.TIME_ASCENDING);

        title = _("Tetravex");
        GnomeGamesSupport.settings_bind_window_state ("/org/gnome/gnotravex/", this);

        var ui_manager = new Gtk.UIManager ();
        var action_group = new Gtk.ActionGroup ("actions");
        action_group.set_translation_domain (GETTEXT_PACKAGE);
        action_group.add_actions (action_entry, this);
        action_group.add_radio_actions (size_action_entry, -1, size_cb);
        action_group.add_toggle_actions (toggles, this);
        ui_manager.insert_action_group (action_group, 0);

        try
        {
            ui_manager.add_ui_from_string (ui_description, -1);
        }
        catch (Error e)
        {
            critical ("Failed to parse UI: %s", e.message);
        }

        new_game_action = action_group.get_action ("NewGame");
        solve_action = action_group.get_action ("Solve");
        scores_action = action_group.get_action ("Scores");
        move_up_action = action_group.get_action ("MoveUp");
        move_left_action = action_group.get_action ("MoveLeft");
        move_right_action = action_group.get_action ("MoveRight");
        move_down_action = action_group.get_action ("MoveDown");
        pause_action = new GnomeGamesSupport.PauseAction ("PauseGame");
        pause_action.is_important = true;
        pause_action.state_changed.connect (pause_cb);
        action_group.add_action_with_accel (pause_action, null);
        var fullscreen_action = new GnomeGamesSupport.FullscreenAction ("Fullscreen", this);
        action_group.add_action_with_accel (fullscreen_action, null);
        var leave_fullscreen_action = new GnomeGamesSupport.FullscreenAction ("LeaveFullscreen", this);
        action_group.add_action_with_accel (leave_fullscreen_action, null);
        var action = (Gtk.ToggleAction) action_group.get_action ("ClickToMove");
        action.active = settings.get_boolean (KEY_CLICK_MOVE);
        var size = settings.get_int (KEY_GRID_SIZE);
        if (size < 2 || size > 6)
            size = 3;
        var size_action = (Gtk.RadioAction) action_group.get_action (size_action_entry[size-2].name);
        size_action.active = true;

        var grid = new Gtk.Grid ();
        grid.show ();
        add (grid);
        
        var toolbar = ui_manager.get_widget ("/Toolbar");
        toolbar.get_style_context ().add_class (Gtk.STYLE_CLASS_PRIMARY_TOOLBAR);
        toolbar.show ();
        grid.attach (toolbar, 0, 0, 1, 1);

        var menubar = ui_manager.get_widget ("/MainMenu");
        menubar.show ();
        grid.attach (menubar, 0, 0, 1, 1);

        view = new PuzzleView ();
        view.hexpand = true;
        view.vexpand = true;
        view.click_to_move = settings.get_boolean (KEY_CLICK_MOVE);
        view.button_press_event.connect (view_button_press_event);
        view.show ();
        grid.attach (view, 0, 1, 1, 1);

        var statusbar = new Gtk.Statusbar ();
        statusbar.show ();
        GnomeGamesSupport.stock_prepare_for_statusbar_tooltips (ui_manager, statusbar);
        grid.attach (statusbar, 0, 2, 1, 1);

        var time_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0);
        time_box.show ();
        statusbar.pack_start (time_box, false, false, 0);

        var time_label = new Gtk.Label (_("Time:"));
        time_label.show ();
        time_box.pack_start (time_label, false, false, 0);

        var label = new Gtk.Label (" ");
        label.show ();
        time_box.pack_start (label, false, false, 0);

        clock = new GnomeGamesSupport.Clock ();
        clock.show ();
        time_box.pack_start (clock, false, false, 0);

        add_accel_group (ui_manager.get_accel_group ());

        new_game ();
    }

    private void new_game ()
    {
        if (puzzle != null)
            SignalHandler.disconnect_by_func (puzzle, null, this);

        pause_action.sensitive = true;

        var size = settings.get_int (KEY_GRID_SIZE);
        if (size < 2 || size > 6)
            size = 3;
        highscores.set_category (scorecats[size - 2].key);
        puzzle = new Puzzle (size);
        puzzle.solved.connect (solved_cb);
        view.puzzle = puzzle;
        view.is_paused = false;

        clock.reset ();
        clock.start ();
    }

    private void solved_cb (Puzzle puzzle)
    {
        clock.stop ();

        var seconds = clock.get_seconds ();
        var pos = highscores.add_time_score ((seconds / 60) * 1.0 + (seconds % 60) / 100.0);

        var scores_dialog = new GnomeGamesSupport.ScoresDialog (this, highscores, _("Tetravex Scores"));
        scores_dialog.set_category_description (_("Size:"));
        scores_dialog.set_hilight (pos);
        scores_dialog.set_message ("<b>%s</b>\n\n%s".printf (_("Congratulations!"), pos == 1 ? _("Your score is the best!") : _("Your score has made the top ten.")));
        scores_dialog.set_buttons (GnomeGamesSupport.ScoresButtons.QUIT_BUTTON | GnomeGamesSupport.ScoresButtons.NEW_GAME_BUTTON);
        if (scores_dialog.run () == Gtk.ResponseType.REJECT)
            Gtk.main_quit ();
        else
            new_game ();
        scores_dialog.destroy ();
    }

    private void new_game_cb (Gtk.Action action)
    {
        new_game ();
    }

    private void quit_cb (Gtk.Action action)
    {
        Gtk.main_quit ();
    }

    private void scores_cb (Gtk.Action action)
    {
        var scores_dialog = new GnomeGamesSupport.ScoresDialog (this, highscores, _("Tetravex Scores"));
        scores_dialog.set_category_description (_("Size:"));
        scores_dialog.run ();
        scores_dialog.destroy ();
    }

    private bool view_button_press_event (Gtk.Widget widget, Gdk.EventButton event)
    {
        /* Cancel pause on click */
        if (view.is_paused)
        {
            toggle_pause ();
            return true;
        }

        return false;
    }

    private void pause_cb (Gtk.Action action)
    {
        toggle_pause ();
    }

    private void toggle_pause ()
    {
        if (view.is_paused)
        {
            pause_action.set_is_paused (false);
            solve_action.sensitive = true;
            clock.start ();
            view.is_paused = false;
        }
        else
        {
            pause_action.set_is_paused (true);
            solve_action.sensitive = false;
            clock.stop ();
            view.is_paused = true;
        }
    }

    private void solve_cb (Gtk.Action action)
    {
        puzzle.solve ();
        clock.stop ();
    }

    private void help_cb (Gtk.Action action)
    {
        GnomeGamesSupport.help_display (this, "gnotravex", null);
    }

    private void about_cb (Gtk.Action action)
    {
        string[] authors = { "Lars Rydlinge", "Robert Ancell", null };
        string[] documenters = { "Rob Bradford", null };
        var license = GnomeGamesSupport.get_license (_("Tetravex"));
        Gtk.show_about_dialog (this,
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
                               "logo-icon-name", "gnome-tetravex",
                               "website", "http://www.gnome.org/projects/gnome-games",
                               "website-label", _("GNOME Games web site"),
                               null);
    }

    private void size_cb (Gtk.Action action)
    {
        var size = ((Gtk.RadioAction) action).get_current_value ();

        if (size == settings.get_int (KEY_GRID_SIZE))
            return;
        settings.set_int (KEY_GRID_SIZE, size);
        new_game ();
    }

    private void clickmove_toggle_cb (Gtk.Action action)
    {
        var click_to_move = ((Gtk.ToggleAction) action).active;

        if (click_to_move == settings.get_boolean (KEY_CLICK_MOVE))
            return;

        settings.set_boolean (KEY_CLICK_MOVE, click_to_move);
        view.click_to_move = click_to_move;
    }

    private void move_up_cb (Gtk.Action action)
    {
        puzzle.move_up ();
    }

    private void move_left_cb (Gtk.Action action)
    {
        puzzle.move_left ();
    }

    private void move_right_cb (Gtk.Action action)
    {
        puzzle.move_right ();
    }

    private void move_down_cb (Gtk.Action action)
    {
        puzzle.move_down ();
    }
   
    private const Gtk.ActionEntry[] action_entry =
    {
        {"GameMenu", null, N_("_Game")},
        {"MoveMenu", null, N_("_Move")},
        {"SettingsMenu", null, N_("_Settings")},
        {"SizeMenu", null, N_("_Size")},
        {"HelpMenu", null, N_("_Help")},
        {"NewGame", GnomeGamesSupport.STOCK_NEW_GAME, null, null, null, new_game_cb},
        {"Solve", Gtk.Stock.REFRESH, N_("Sol_ve"), null, N_("Solve the game"), solve_cb},
        {"Scores", GnomeGamesSupport.STOCK_SCORES, null, null, null, scores_cb},
        {"Quit", Gtk.Stock.QUIT, null, null, null, quit_cb},
        {"MoveUp", Gtk.Stock.GO_UP, N_("_Up"), "<control>Up",  N_("Move the pieces up"), move_up_cb},
        {"MoveLeft", Gtk.Stock.GO_BACK, N_("_Left"), "<control>Left", N_("Move the pieces left"), move_left_cb},
        {"MoveRight", Gtk.Stock.GO_FORWARD, N_("_Right"), "<control>Right", N_("Move the pieces right"), move_right_cb},
        {"MoveDown", Gtk.Stock.GO_DOWN, N_("_Down"), "<control>Down",  N_("Move the pieces down"), move_down_cb},
        {"Contents", GnomeGamesSupport.STOCK_CONTENTS, null, null, null, help_cb},
        {"About", Gtk.Stock.ABOUT, null, null, null, about_cb}
    };
    private const Gtk.ToggleActionEntry toggles[] =
    {
        {"ClickToMove", null, N_("_Click to Move"), null, "Pick up and drop tiles by clicking", clickmove_toggle_cb}
    };

    public static int main (string[] args)
    {
        if (!GnomeGamesSupport.runtime_init ("gnotravex"))
            return Posix.EXIT_FAILURE;

#if ENABLE_SETGID
        GnomeGamesSupport.setgid_io_init ();
#endif

        var context = new OptionContext ("");
        context.set_translation_domain (GETTEXT_PACKAGE);
        context.add_group (Gtk.get_option_group (true));
        try
        {
            context.parse (ref args);
        }
        catch (Error e)
        {
            stderr.printf ("%s\n", e.message);
            return Posix.EXIT_FAILURE;
        }

        Environment.set_application_name (_("Tetravex"));
        GnomeGamesSupport.stock_init ();
        Gtk.Window.set_default_icon_name ("gnome-tetravex");

        var app = new Gnotravex ();
        app.delete_event.connect (window_delete_event_cb);
        app.show ();

        Gtk.main ();

        GnomeGamesSupport.runtime_shutdown ();

        return Posix.EXIT_SUCCESS;
    }

    private static bool window_delete_event_cb (Gtk.Widget widget, Gdk.EventAny event)
    {
        Gtk.main_quit ();
        return false;
    }
}
