/* -*- Mode: vala; tab-width: 4; indent-tabs-mode: nil; c-basic-offset: 4 -*-

   This file is part of GNOME Tetravex.

   Copyright (C) 2025 Tetravex Contributors

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

[GtkTemplate (ui = "/org/gnome/Tetravex/ui/window.ui")]
public class TetravexWindow : Adw.ApplicationWindow {
    [GtkChild]
    private unowned Adw.ToolbarView toolbar_view;

    [GtkChild]
    private unowned Adw.WindowTitle title_widget;

    [GtkChild]
    private unowned Gtk.MenuButton menu_button;

    [GtkChild]
    private unowned Gtk.Button pause_button;

    [GtkChild]
    private unowned Gtk.Stack game_button_stack;

    private Puzzle? puzzle;

    public TetravexWindow (Gtk.Application application, PuzzleView puzzle_view) {
        Object (application: application);
        toolbar_view.content = puzzle_view;

        var menu_builder = new Gtk.Builder.from_resource (application.resource_base_path + "/ui/menu.ui");
        unowned var menu_model = (MenuModel) menu_builder.get_object ("menu");
        menu_button.menu_model = menu_model;

        if (APP_ID.has_suffix (".Devel"))
            add_css_class ("devel");
    }

    public void new_game (Puzzle puzzle) {
        this.puzzle = puzzle;
        puzzle.paused_changed.connect (paused_changed_cb);
        puzzle.tick.connect (tick_cb);
        puzzle.solved.connect (solved_cb);
        puzzle.solved_right.connect (solved_right_cb);

        solved_right_cb (false);
    }

    private void solved_cb () {
        game_button_stack.visible_child_name = "new-game";
    }

    private void solved_right_cb (bool is_solved_right) {
        if (is_solved_right)
            game_button_stack.visible_child_name = "finish";
        else
            game_button_stack.visible_child_name = "solve";
    }

    private void paused_changed_cb () {
        if (((!) puzzle).paused) {
            title_widget.subtitle = _("Paused");
            pause_button.icon_name = "media-playback-start-symbolic";
            pause_button.tooltip_text = _("Resume Game");
            toolbar_view.content.add_css_class ("dim-label");
            return;
        }

        var size = ((!) puzzle).size;
        title_widget.subtitle = _("%u × %u").printf (size, size);
        pause_button.icon_name = "media-playback-pause-symbolic";
        pause_button.tooltip_text = _("Pause Game");
        toolbar_view.content.remove_css_class ("dim-label");

        Adw.Dialog? dialog = visible_dialog;
        if (dialog != null)
            ((!) dialog).force_close ();
    }

    private void tick_cb () {
        string clock;
        var elapsed = (int) ((!) puzzle).elapsed;
        var hours = elapsed / 3600;
        var minutes = (elapsed - hours * 3600) / 60;
        var seconds = elapsed - hours * 3600 - minutes * 60;
        if (hours > 0)
            clock = "%02d∶\xE2\x80\x8E%02d∶\xE2\x80\x8E%02d".printf (hours, minutes, seconds);
        else
            clock = "%02d∶\xE2\x80\x8E%02d".printf (minutes, seconds);
        title_widget.title = clock;
    }
}
