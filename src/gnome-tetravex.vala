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

private class Tetravex : Gtk.Application
{
    /* Translators: name of the program, as seen in the headerbar, in GNOME Shell, or in the about dialog */
    private const string PROGRAM_NAME = _("Tetravex");

    private static bool start_paused = false;
    private static bool restore_on_start = false;
    private static int game_size = int.MIN;
    private static int colors = 10;
    private static string? cli = null;

    private GLib.Settings settings;

    private Puzzle puzzle;
    private bool puzzle_init_done = false;
    private Label clock_label;
    private Box clock_box;
    private History history;

    private PuzzleView view;

    private Button pause_button;
    private Button new_game_button;

    private ApplicationWindow window;
    private int window_width;
    private int window_height;
    private bool window_is_maximized;
    private bool window_is_fullscreen;
    private bool window_is_tiled;

    private Stack new_game_solve_stack;
    private Stack play_pause_stack;

    private SimpleAction undo_action;
    private SimpleAction redo_action;
    private SimpleAction pause_action;
    private SimpleAction solve_action;
    private SimpleAction finish_action;

    private ScoreOverlay score_overlay;

    private MenuButton hamburger_button;

    private static string? [] remaining = new string? [1];
    private const OptionEntry [] option_entries =
    {
        /* Translators: command-line option description, see 'gnome-tetravex --help' */
        { "cli", 0,       OptionFlags.OPTIONAL_ARG, OptionArg.CALLBACK, (void*) _cli,   N_("Play in the terminal (see “--cli=help”)"),

        /* Translators: in the command-line options description, text to indicate the user should give a command after '--cli' for playing in the terminal, see 'gnome-tetravex --help' */
                                                                                        N_("COMMAND") },

        /* Translators: command-line option description, see 'gnome-tetravex --help' */
        { "colors",  'c', OptionFlags.NONE, OptionArg.INT,  ref colors,                 N_("Set number of colors (2-10)"),

        /* Translators: in the command-line options description, text to indicate the user should specify colors number, see 'gnome-tetravex --help' */
                                                                                        N_("NUMBER") },

        /* Translators: command-line option description, see 'gnome-tetravex --help' */
        { "paused",  'p', OptionFlags.NONE, OptionArg.NONE, null,                       N_("Start the game paused"),            null },

        /* Translators: command-line option description, see 'gnome-tetravex --help' */
        { "restore", 'r', OptionFlags.NONE, OptionArg.NONE, null,                       N_("Restore last game, if any"),        null },

        /* Translators: command-line option description, see 'gnome-tetravex --help' */
        { "size",    's', OptionFlags.NONE, OptionArg.INT,  ref game_size,              N_("Set size of board (2-6)"),

        /* Translators: in the command-line options description, text to indicate the user should specify size, see 'gnome-tetravex --help' */
                                                                                        N_("SIZE") },

        /* Translators: command-line option description, see 'gnome-tetravex --help' */
        { "version", 'v', OptionFlags.NONE, OptionArg.NONE, null,                       N_("Print release version and exit"),   null },

        { OPTION_REMAINING, 0, OptionFlags.NONE, OptionArg.STRING_ARRAY, ref remaining, "args", null },
        {}
    };

    private bool _cli (string? option_name, string? val)
    {
        cli = option_name == null ? "" : (!) option_name;  // TODO report bug: should probably be val...
        return true;
    }

    private const GLib.ActionEntry[] action_entries =
    {
        { "new-game",       new_game_cb     },
        { "pause",          pause_cb        },
        { "solve",          solve_cb        },
        { "finish",         finish_cb       },
        { "scores",         scores_cb       },
        { "quit",           quit            },
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
        { "hamburger",      hamburger_cb    }
    };

    private static int main (string[] args)
    {
        Intl.setlocale (LocaleCategory.ALL, "");
        Intl.bindtextdomain (GETTEXT_PACKAGE, LOCALEDIR);
        Intl.bind_textdomain_codeset (GETTEXT_PACKAGE, "UTF-8");
        Intl.textdomain (GETTEXT_PACKAGE);

        Environment.set_application_name (PROGRAM_NAME);
        Environment.set_prgname ("org.gnome.Tetravex");
        Window.set_default_icon_name ("org.gnome.Tetravex");

        Tetravex app = new Tetravex ();
        return app.run (args);
    }

    private Tetravex ()
    {
        Object (application_id: "org.gnome.Tetravex", flags: ApplicationFlags.FLAGS_NONE);

        add_main_option_entries (option_entries);
    }

    protected override int handle_local_options (GLib.VariantDict options)
    {
        if (options.contains ("version")
         || remaining [0] != null && (!) remaining [0] == "version")
        {
            /* NOTE: Is not translated so can be easily parsed */
            stderr.printf ("%1$s %2$s\n", "gnome-tetravex", VERSION);
            return Posix.EXIT_SUCCESS;
        }

        if (options.contains ("paused"))
            start_paused = true;

        if (options.contains ("restore"))
            restore_on_start = true;

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

        if (remaining [0] != null)
        {
            /* Translators: command-line error message, displayed for an invalid CLI command; see 'gnome-tetravex --cli new A1b2' */
            stderr.printf (_("Failed to parse command-line arguments.") + "\n");
            return Posix.EXIT_FAILURE;
        }

        if (cli != null)
        {
            if ((!) cli == "help" || (!) cli == "HELP")
            {
                string help_string = ""
                /* Translators: command-line help message, seen when running `gnome-tetravex --cli help`; introduction of a list of options */
                    + "\n" + _("To play GNOME Tetravex in command-line:")

                /* Translators: command-line help message, seen when running `gnome-tetravex --cli help`; description of the action of the “--cli A1b2” command */
                    + "\n" + "  --cli A1b2    " + _("Invert two tiles, the one in A1, and the one in b2.")

                /* Translators: command-line help message, seen when running `gnome-tetravex --cli help`; explanation of the behavior of the “--cli A1b2” command; the meanings of a lowercase and of the digits are explained after */
                    + "\n" + "                " + _("An uppercase targets a tile from the initial board.")

                /* Translators: command-line help message, seen when running `gnome-tetravex --cli help`; explanation of the behavior of the “--cli A1b2” command; the meanings of an uppercase and of the digits are explained before and after */
                    + "\n" + "                " + _("A lowercase targets a tile in the left/final board.")

                /* Translators: command-line help message, seen when running `gnome-tetravex --cli help`; explanation of the behavior of the “--cli A1b2” command; the meanings of uppercases and lowercases are explained before */
                    + "\n" + "                " + _("Digits specify the rows of the two tiles to invert.")
                    + "\n"
                /* Translators: command-line help message, seen when running `gnome-tetravex --cli help`; description of the action of the “--cli” or “--cli show” or “--cli status” commands */
                    + "\n" + "  --cli         " + _("Show the current puzzle. Alias: “status” or “show”.")

                /* Translators: command-line help message, seen when running `gnome-tetravex --cli help`; description of the action of the “--cli new” command */
                    + "\n" + "  --cli new     " + _("Create a new puzzle; for changing size, use --size.")

                /* Translators: command-line help message, seen when running `gnome-tetravex --cli help`; description of the action of the “--cli solve” command */
                    + "\n" + "  --cli solve   " + _("Give up with current puzzle, and view the solution.")
                    + "\n"
                /* Translators: command-line help message, seen when running `gnome-tetravex --cli help`; description of the action of the “--cli finish” or “--cli end” commands */
                    + "\n" + "  --cli finish  " + _("Finish current puzzle, automatically. Alias: “end”.")

                /* Translators: command-line help message, seen when running `gnome-tetravex --cli help`; explanation of the behavior of the “--cli finish” command; the command does something in two situations: if the puzzle has been solved in the right part of the board, and if there is only one tile remaining (“left”) on the right part of the board that could be moved automatically */
                    + "\n" + "                " + _("Works for puzzles solved right or if one tile left.")
                    + "\n"
                /* Translators: command-line help message, seen when running `gnome-tetravex --cli help`; description of the action of the “--cli up” command */
                    + "\n" + "  --cli up      " + _("Move all left-board tiles up by one.")

                /* Translators: command-line help message, seen when running `gnome-tetravex --cli help`; description of the action of the “--cli down” command */
                    + "\n" + "  --cli down    " + _("Move all left-board tiles down by one.")

                /* Translators: command-line help message, seen when running `gnome-tetravex --cli help`; description of the action of the “--cli left” command */
                    + "\n" + "  --cli left    " + _("Move all left-board tiles left by one.")

                /* Translators: command-line help message, seen when running `gnome-tetravex --cli help`; description of the action of the “--cli right” command */
                    + "\n" + "  --cli right   " + _("Move all left-board tiles right by one.")
                    + "\n"
                /* Translators: command-line help message, seen when running `gnome-tetravex --cli help`; description of the action of the “--cli r-up” command */
                    + "\n" + "  --cli r-up    " + _("Move all right-board tiles up by one.")

                /* Translators: command-line help message, seen when running `gnome-tetravex --cli help`; description of the action of the “--cli r-down” command */
                    + "\n" + "  --cli r-down  " + _("Move all right-board tiles down by one.")

                /* Translators: command-line help message, seen when running `gnome-tetravex --cli help`; description of the action of the “--cli r-left” command */
                    + "\n" + "  --cli r-left  " + _("Move all right-board tiles left by one.")

                /* Translators: command-line help message, seen when running `gnome-tetravex --cli help`; description of the action of the “--cli r-right” command */
                    + "\n" + "  --cli r-right " + _("Move all right-board tiles right by one.")
                    + "\n\n";
                stdout.printf (help_string);
                return Posix.EXIT_SUCCESS;
            }
            return CLI.play_cli ((!) cli, "org.gnome.Tetravex", out settings, out saved_game, out can_restore, out puzzle, ref colors, ref game_size);
        }

        /* Activate */
        return -1;
    }

    protected override void startup ()
    {
        base.startup ();

        settings = new GLib.Settings ("org.gnome.Tetravex");

        saved_game = settings.get_value ("saved-game");
        can_restore = Puzzle.is_valid_saved_game (saved_game, /* restore finished game */ false);

        add_action_entries (action_entries, this);
        add_action (settings.create_action ("theme"));

        set_accels_for_action ("app.solve",         {        "<Primary>h"       });
        set_accels_for_action ("app.scores",        {        "<Primary>i"       });
        set_accels_for_action ("app.new-game",      {        "<Primary>n"       });
        set_accels_for_action ("app.pause",         {        "<Primary>p",
                                                                      "Pause"   });
        set_accels_for_action ("app.quit",          {        "<Primary>q"       });
        set_accels_for_action ("app.move-up-l",     {        "<Primary>Up"      });
        set_accels_for_action ("app.move-down-l",   {        "<Primary>Down"    });
        set_accels_for_action ("app.move-left-l",   {        "<Primary>Left"    });
        set_accels_for_action ("app.move-right-l",  {        "<Primary>Right"   });
        set_accels_for_action ("app.move-up-r",     { "<Shift><Primary>Up"      });
        set_accels_for_action ("app.move-down-r",   { "<Shift><Primary>Down"    });
        set_accels_for_action ("app.move-left-r",   { "<Shift><Primary>Left"    });
        set_accels_for_action ("app.move-right-r",  { "<Shift><Primary>Right"   });
        set_accels_for_action ("app.undo",          {        "<Primary>z"       });
        set_accels_for_action ("app.redo",          { "<Shift><Primary>z"       });
        set_accels_for_action ("app.reload",        { "<Shift><Primary>r"       });
        set_accels_for_action ("app.hamburger",     {                 "F10"     });
        // F1 and friends are managed manually
    }

    private void create_window () {
        Builder builder = new Builder.from_resource ("/org/gnome/Tetravex/gnome-tetravex.ui");

        string history_path;
        if (colors == 10)
            history_path = Path.build_filename (Environment.get_user_data_dir (), "gnome-tetravex", "history");
        else
            history_path = Path.build_filename (Environment.get_user_data_dir (), "gnome-tetravex", "history-" + colors.to_string ());
        history = new History (history_path);

        CssProvider css_provider = new CssProvider ();
        css_provider.load_from_resource ("/org/gnome/Tetravex/tetravex.css");
        Gdk.Screen? gdk_screen = Gdk.Screen.get_default ();
        if (gdk_screen != null) // else..?
            StyleContext.add_provider_for_screen ((!) gdk_screen, css_provider, STYLE_PROVIDER_PRIORITY_APPLICATION);

        window = (ApplicationWindow) builder.get_object ("gnome-tetravex-window");
        this.add_window (window);
        key_controller = new EventControllerKey (window);
        key_controller.key_pressed.connect (on_key_pressed);
        window.size_allocate.connect (size_allocate_cb);
        window.window_state_event.connect (window_state_event_cb);
        window.set_default_size (settings.get_int ("window-width"), settings.get_int ("window-height"));
        if (settings.get_boolean ("window-is-maximized"))
            window.maximize ();

        if (game_size != int.MIN)
            settings.set_int (KEY_GRID_SIZE, game_size);
        else
            game_size = settings.get_int (KEY_GRID_SIZE);
        ((SimpleAction) lookup_action ("size")).set_state ("%d".printf (game_size));

        HeaderBar headerbar = new HeaderBar ();
        headerbar.title = PROGRAM_NAME;
        headerbar.show_close_button = true;
        headerbar.show ();
        window.set_titlebar (headerbar);

        Builder menu_builder = new Builder.from_resource ("/org/gnome/Tetravex/app-menu.ui");
        MenuModel appmenu = (MenuModel) menu_builder.get_object ("app-menu");
        hamburger_button = new MenuButton ();
        hamburger_button.set_image (new Image.from_icon_name ("open-menu-symbolic", IconSize.BUTTON));
        ((Widget) hamburger_button).set_focus_on_click (false);
        hamburger_button.valign = Align.CENTER;
        hamburger_button.show ();
        hamburger_button.set_menu_model (appmenu);
        headerbar.pack_end (hamburger_button);

        Button undo_button = new Button.from_icon_name ("edit-undo-symbolic");
        undo_button.set_action_name ("app.undo");
        ((Widget) undo_button).set_focus_on_click (false);
        undo_button.valign = Align.CENTER;
        undo_button.show ();

        Button redo_button = new Button.from_icon_name ("edit-redo-symbolic");
        redo_button.set_action_name ("app.redo");
        ((Widget) redo_button).set_focus_on_click (false);
        redo_button.valign = Align.CENTER;
        redo_button.show ();

        Box undo_redo_box = new Box (Orientation.HORIZONTAL, /* spacing */ 0);
        undo_redo_box.get_style_context ().add_class ("linked");
        undo_redo_box.pack_start (undo_button);
        undo_redo_box.pack_start (redo_button);
        undo_redo_box.show ();

        if (can_restore && !restore_on_start)
        {
            restore_stack = new Stack ();
            restore_stack_created = true;
            restore_stack.hhomogeneous = false;
            restore_stack.add_named (undo_redo_box, "undo-redo-box");

            /* Translator: label of a button displayed in the headerbar at game start, if a previous game was being played while the window was closed; restores the saved game */
            Button restore_button = new Button.with_label (_("Restore last game"));
            restore_button.clicked.connect (restore_game);
            ((Widget) restore_button).set_focus_on_click (false);
            restore_button.valign = Align.CENTER;
            restore_button.show ();

            restore_stack.add (restore_button);
            restore_stack.set_visible_child (restore_button);
            restore_stack.visible = true;
            headerbar.pack_start (restore_stack);
        }
        else
            headerbar.pack_start (undo_redo_box);

        Grid grid = (Grid) builder.get_object ("grid");

        view = new PuzzleView ();
        view.hexpand = true;
        view.vexpand = true;
        view.can_focus = true;
        view.show ();
        view_click_controller = new GestureMultiPress (view);
        view_click_controller.set_button (/* all buttons */ 0);
        view_click_controller.released.connect (on_release_on_view);
        settings.bind ("theme", view, "theme-id", SettingsBindFlags.GET | SettingsBindFlags.NO_SENSITIVITY);

        Overlay overlay = new Overlay ();
        overlay.add (view);
        overlay.show ();

        score_overlay = new ScoreOverlay ();
        overlay.add_overlay (score_overlay);
        overlay.set_overlay_pass_through (score_overlay, true);

        view.bind_property ("boardsize",        score_overlay,  "boardsize",        BindingFlags.DEFAULT | BindingFlags.SYNC_CREATE);
        view.bind_property ("x-offset-right",   score_overlay,  "margin-left",      BindingFlags.DEFAULT | BindingFlags.SYNC_CREATE);
        view.bind_property ("right-margin",     score_overlay,  "margin-right",     BindingFlags.DEFAULT | BindingFlags.SYNC_CREATE);
        view.bind_property ("y-offset",         score_overlay,  "margin-top",       BindingFlags.DEFAULT | BindingFlags.SYNC_CREATE);
        view.bind_property ("y-offset",         score_overlay,  "margin-bottom",    BindingFlags.DEFAULT | BindingFlags.SYNC_CREATE);

        grid.attach (overlay, 0, 0, 3, 1);

        settings.bind ("mouse-use-extra-buttons",   view,
                       "mouse-use-extra-buttons",   SettingsBindFlags.GET | SettingsBindFlags.NO_SENSITIVITY);
        settings.bind ("mouse-back-button",         view,
                       "mouse-back-button",         SettingsBindFlags.GET | SettingsBindFlags.NO_SENSITIVITY);
        settings.bind ("mouse-forward-button",      view,
                       "mouse-forward-button",      SettingsBindFlags.GET | SettingsBindFlags.NO_SENSITIVITY);

        SizeGroup sizegroup = new SizeGroup (SizeGroupMode.BOTH);

        Button play_button      = new BottomButton ("media-playback-start-symbolic",
                                                    "app.pause", /* not a typo */
        /* Translators: tooltip text of the "play"/unpause button, in the bottom bar */
                                                    _("Resume the game"),
                                                    /* align end */ false,
                                                    sizegroup);

        pause_button            = new BottomButton ("media-playback-pause-symbolic",
                                                    "app.pause",
        /* Translators: tooltip text of the pause button, in the bottom bar */
                                                    _("Pause the game"),
                                                    /* align end */ false,
                                                    sizegroup);

        play_pause_stack = new Stack ();
        play_pause_stack.add_named (play_button, "play");
        play_pause_stack.add_named (pause_button, "pause");
        play_pause_stack.show ();
        grid.attach (play_pause_stack, 0, 1, 1, 1);

        new_game_button         = new BottomButton ("view-refresh-symbolic",
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

        new_game_button_click_controller = new GestureMultiPress (new_game_button);
        new_game_button_click_controller.pressed.connect (on_new_game_button_click);
        new_game_solve_stack = new Stack ();
        new_game_solve_stack.add_named (solve_button, "solve");
        new_game_solve_stack.add_named (new_game_button, "new-game");
        new_game_solve_stack.add_named (finish_button, "finish");
        new_game_solve_stack.show ();
        grid.attach (new_game_solve_stack, 2, 1, 1, 1);

        clock_box = new Box (Orientation.HORIZONTAL, /* spacing */ 8);
        Image image = new Image.from_icon_name ("preferences-system-time-symbolic", IconSize.MENU);
        image.show ();
        clock_box.add (image);
        clock_label = new Label ("");
        clock_label.show ();
        clock_box.add (clock_label);
        clock_box.halign = Align.CENTER;
        clock_box.valign = Align.BASELINE;
        clock_box.set_margin_top (20);
        clock_box.set_margin_bottom (20);
        grid.attach (clock_box, 1, 1, 1, 1);

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

        tick_cb ();
        if (can_restore && restore_on_start)
            new_game (saved_game);
        else
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
                    image: _image,
                    focus_on_click: false,
                    visible: true);

            sizegroup.add_widget (this);
        }
    }

    private void size_allocate_cb (Allocation allocation)
    {
        if (window_is_maximized || window_is_tiled || window_is_fullscreen)
            return;
        int? _window_width = null;
        int? _window_height = null;
        window.get_size (out _window_width, out _window_height);
        if (_window_width == null || _window_height == null)
            return;
        window_width = (!) _window_width;
        window_height = (!) _window_height;
    }

    private const Gdk.WindowState tiled_state = Gdk.WindowState.TILED
                                              | Gdk.WindowState.TOP_TILED
                                              | Gdk.WindowState.BOTTOM_TILED
                                              | Gdk.WindowState.LEFT_TILED
                                              | Gdk.WindowState.RIGHT_TILED;
    private bool window_state_event_cb (Gdk.EventWindowState event)
    {
        if ((event.changed_mask & Gdk.WindowState.MAXIMIZED) != 0)
            window_is_maximized = (event.new_window_state & Gdk.WindowState.MAXIMIZED) != 0;

        /* fullscreen: saved as maximized */
        if ((event.changed_mask & Gdk.WindowState.FULLSCREEN) != 0)
            window_is_fullscreen = (event.new_window_state & Gdk.WindowState.FULLSCREEN) != 0;

        /* tiled: not saved, but should not change saved window size */
        if ((event.changed_mask & tiled_state) != 0)
            window_is_tiled = (event.new_window_state & tiled_state) != 0;

        return false;
    }

    protected override void shutdown ()
    {
        base.shutdown ();

        settings.delay ();
        settings.set_int ("window-width", window_width);
        settings.set_int ("window-height", window_height);
        settings.set_boolean ("window-is-maximized", window_is_maximized || window_is_fullscreen);
        if (puzzle_init_done) {
            if (puzzle.game_in_progress)
                settings.set_value ("saved-game", puzzle.to_variant (/* save time */ !puzzle.tainted_by_command_line));
            else if (!can_restore)
                settings.@set ("saved-game", "m(yyda(yyyyyyyy)ua(yyyyu))", null);
        }
        settings.apply ();
    }

    protected override void activate ()
    {
        if (get_active_window () == null)
            create_window ();

        window.present ();
    }

    private Stack restore_stack;
    private Variant saved_game;
    private bool can_restore = false;
    private bool restore_stack_created = false;
    private void restore_game ()
    {
        if (!can_restore)
            assert_not_reached ();

        new_game (saved_game);
        hide_restore_button ();
    }
    private void hide_restore_button ()
    {
        if (!can_restore)
            return;

        if (restore_stack_created)
            restore_stack.set_visible_child_name ("undo-redo-box");
        can_restore = false;
    }

    private void new_game (Variant? saved_game = null, int? given_size = null)
    {
        puzzle_is_finished = false;
        has_been_finished = false;
        has_been_solved = false;
        pause_action.set_enabled (true);
        solve_action.set_enabled (true);
        finish_action.set_enabled (false);
        new_game_solve_stack.set_visible_child_name ("solve");
        score_overlay.hide ();

        bool was_paused;
        if (puzzle_init_done)
        {
            was_paused = puzzle.paused;
            SignalHandler.disconnect_by_func (puzzle, null, this);
            hide_restore_button (); // the Restore button is kept if the user just displays solution for the puzzle, hide it if she then starts a new game
        }
        else
            was_paused = false;

        if (saved_game == null)
        {
            int size;
            if (given_size == null)
                size = settings.get_int (KEY_GRID_SIZE);
            else
                size = (!) given_size;
            puzzle = new Puzzle ((uint8) size, (uint8) colors);
            clock_box.show ();
        }
        else
        {
            puzzle = new Puzzle.restore ((!) saved_game);
            if (puzzle.is_solved_right)
                solved_right_cb ();
            if (puzzle.tainted_by_command_line)
                clock_box.hide ();
        }
        puzzle_init_done = true;
        puzzle.tick.connect (tick_cb);
        puzzle.solved.connect (solved_cb);
        puzzle.notify ["is-solved-right"].connect (solved_right_cb);
        puzzle.notify ["can-undo"].connect (() =>
            undo_action.set_enabled (puzzle.can_undo && !puzzle.is_solved && !puzzle.paused));
        puzzle.notify ["can-redo"].connect (() =>
            redo_action.set_enabled (puzzle.can_redo && !puzzle.is_solved && !puzzle.paused));
        if (can_restore && !restore_on_start)
            puzzle.tile_moved.connect (() => { if (!has_been_solved) hide_restore_button (); });
        puzzle.show_end_game.connect (show_end_game_cb);
        view.puzzle = puzzle;
        tick_cb ();

        if (start_paused)
        {
            puzzle.paused = true;
            start_paused = false;
            pause_button.grab_focus ();
        }
        else if (was_paused && saved_game != null)
        {
            puzzle.paused = true;
            pause_button.grab_focus ();
        }
        else
            view.grab_focus ();
        update_bottom_button_states ();
    }

    private void tick_cb ()
    {
        if (puzzle_init_done && puzzle.tainted_by_command_line)
            return;

        int elapsed = 0;
        if (puzzle_init_done)
            elapsed = (int) puzzle.elapsed; // felt better when + 0.5, but as the clock is still displayed while the score-overlay displays the exact time, that is regularly feeling odd
        int hours = elapsed / 3600;
        int minutes = (elapsed - hours * 3600) / 60;
        int seconds = elapsed - hours * 3600 - minutes * 60;
        if (hours > 0)
            clock_label.set_text ("%02d∶\xE2\x80\x8E%02d∶\xE2\x80\x8E%02d".printf (hours, minutes, seconds));
        else
            clock_label.set_text ("%02d∶\xE2\x80\x8E%02d".printf (minutes, seconds));
    }

    private bool puzzle_is_finished = false;
    private void solved_cb (Puzzle puzzle)
    {
        puzzle_is_finished = true;
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
            new_game_solve_stack.set_visible_child_name ("finish");
        }
        else
        {
            solve_action.set_enabled (/* should never happen */ !puzzle.paused);
            finish_action.set_enabled (false);
            if (!has_been_finished) // keep the "finish" button if clicked (it is replaced after animation by the new-game button anyway)
                new_game_solve_stack.set_visible_child_name ("solve");
        }
    }

    private void show_end_game_cb (Puzzle puzzle)
    {
        if (puzzle.tainted_by_command_line)
        {
            if (!puzzle_is_finished) // Ctrl-n has been hit before the animation finished
                return;

            HistoryEntry? best_score;
            HistoryEntry? second_score;
            HistoryEntry? third_score;
            HistoryEntry? worst_score;
            history.get_fallback_scores (puzzle.size,
                                     out best_score,
                                     out second_score,
                                     out third_score,
                                     out worst_score);
            score_overlay.display_fallback_scores (puzzle.size, best_score, second_score, third_score, worst_score);
        }
        else
        {
            DateTime date = new DateTime.now_local ();
            last_history_entry = new HistoryEntry (date, puzzle.size, puzzle.elapsed, /* old history format */ false);

            if (!puzzle_is_finished) // Ctrl-n has been hit before the animation finished
                return;

            HistoryEntry? other_score_0;
            HistoryEntry? other_score_1;
            HistoryEntry? other_score_2;
            uint position = history.get_place ((!) last_history_entry,
                                               puzzle.size,
                                           out other_score_0,
                                           out other_score_1,
                                           out other_score_2);
            score_overlay.set_score (puzzle.size, position, (!) last_history_entry, other_score_0, other_score_1, other_score_2);
        }

        new_game_solve_stack.set_visible_child_name ("new-game");
        view.hide_right_sockets ();

        score_overlay.show ();
        new_game_button.grab_focus ();
    }

    private void new_game_cb ()
    {
        int size = settings.get_int (KEY_GRID_SIZE);
        if (puzzle.game_in_progress && !puzzle.is_solved)
        {
            MessageDialog dialog = new MessageDialog (window,
                                                      DialogFlags.MODAL | DialogFlags.DESTROY_WITH_PARENT,
                                                      MessageType.QUESTION,
                                                      ButtonsType.NONE,
        /* Translators: popup dialog main text; appearing when user clicks "New Game" from the hamburger menu, while a game is started; possible answers are "Keep playing"/"Start New Game"; the %d are both replaced with  */
                                                      _("Are you sure you want to start a new %u × %u game?").printf (size, size));

        /* Translators: popup dialog possible answer (with a mnemonic that appears pressing Alt); appearing when user clicks "New Game" from the hamburger menu; other possible answer is "_Start New Game" */
            dialog.add_buttons (_("_Keep Playing"),   ResponseType.REJECT,

        /* Translators: popup dialog possible answer (with a mnemonic that appears pressing Alt); appearing when user clicks "New Game" from the hamburger menu; other possible answer is "_Keep Playing" */
                                _("_Start New Game"), ResponseType.ACCEPT);

            int response = dialog.run ();
            dialog.destroy ();

            if (response != ResponseType.ACCEPT)
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
            dialog = new MessageDialog (window,
                                        DialogFlags.MODAL | DialogFlags.DESTROY_WITH_PARENT,
                                        MessageType.INFO,
                                        ButtonsType.CLOSE,
            /* Translators: popup dialog main text; appearing when user clicks the "Scores" entry of the hamburger menu, while not having finished any game yet */
                                        _("Looks like you haven’t finished a game yet.\n\nMaybe try a 2 × 2 grid, they are easy. 🙂️"));
        else
        {
            dialog = new ScoreDialog (history, puzzle.size, puzzle.is_solved ? last_history_entry : null);
            dialog.set_modal (true);
            dialog.set_transient_for (window);
        }

        dialog.run ();
        dialog.destroy ();
        scores_dialog_visible = false;
    }

    private bool has_been_solved = false;
    private void solve_cb ()
    {
        if (!puzzle.tainted_by_command_line && puzzle.elapsed < 0.2)   // security against multi-click on new-game button
            return;

        if (puzzle.game_in_progress)
        {
            MessageDialog dialog = new MessageDialog (window,
                                                      DialogFlags.MODAL | DialogFlags.DESTROY_WITH_PARENT,
                                                      MessageType.QUESTION,
                                                      ButtonsType.NONE,
            /* Translators: popup dialog main text; appearing when user clicks the "Give up" button in the bottom bar; possible answers are "Keep playing"/"Give up" */
                                                      _("Are you sure you want to give up and view the solution?"));

            /* Translators: popup dialog possible answer (with a mnemonic that appears pressing Alt); appearing when user clicks the "Give up" button in the bottom bar; other possible answer is "_Give Up" */
            dialog.add_buttons (_("_Keep Playing"), ResponseType.REJECT,

            /* Translators: popup dialog possible answer (with a mnemonic that appears pressing Alt); appearing when user clicks the "Give up" button in the bottom bar; other possible answer is "_Keep Playing" */
                                _("_Give Up"),      ResponseType.ACCEPT);

            int response = dialog.run ();
            dialog.destroy ();

            if (response != ResponseType.ACCEPT)
                return;
        }

        has_been_solved = true;
        puzzle.solve ();
        new_game_solve_stack.set_visible_child_name ("new-game");
        new_game_button.grab_focus ();
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
        int size = int.parse (variant.get_string ());
        if (size < 2 || size > 6)
            assert_not_reached ();

        if (size == settings.get_int (KEY_GRID_SIZE))
            return;
        settings.set_int (KEY_GRID_SIZE, size);
        action.set_state (variant);
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

    private void pause_cb (/* SimpleAction action, Variant? parameter */)
    {
        puzzle.paused = !puzzle.paused;
        undo_action.set_enabled (puzzle.can_undo && !puzzle.is_solved && !puzzle.paused);
        redo_action.set_enabled (puzzle.can_redo && !puzzle.is_solved && !puzzle.paused);
        update_bottom_button_states ();
        if (puzzle.paused)
            pause_button.grab_focus ();
        else
            view.grab_focus ();
    }

    private void update_bottom_button_states ()
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
        else if (name == "F1")
            return on_f1_pressed (state);   // TODO fix dance done with the F1 & <Primary>F1 shortcuts that show help overlay

        return false;
    }

    private GestureMultiPress new_game_button_click_controller;
    private inline void on_new_game_button_click (GestureMultiPress _new_game_button_click_controller, int n_press, double event_x, double event_y)
    {
        view.disable_highlight ();
    }

    private GestureMultiPress view_click_controller;
    private inline void on_release_on_view (GestureMultiPress _view_click_controller, int n_press, double event_x, double event_y)
    {
        /* Cancel pause on click */
        if (puzzle.paused)
        {
            puzzle.paused = false;
            update_bottom_button_states ();
        }
    }

    /*\
    * * help/about
    \*/

    private bool on_f1_pressed (Gdk.ModifierType state)
    {
        // TODO close popovers
        if ((state & Gdk.ModifierType.CONTROL_MASK) != 0)
            return false;                           // help overlay
        if ((state & Gdk.ModifierType.SHIFT_MASK) == 0)
        {
            help_cb ();
            return true;
        }
        about_cb ();
        return true;
    }

    private void hamburger_cb ()
    {
        hamburger_button.active = !hamburger_button.active;
    }

    private void help_cb ()
    {
        try
        {
            show_uri_on_window (window, "help:gnome-tetravex", get_current_event_time ());
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
