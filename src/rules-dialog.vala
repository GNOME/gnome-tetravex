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

[GtkTemplate (ui = "/org/gnome/Tetravex/ui/rules-dialog.ui")]
public class RulesDialog : Adw.PreferencesDialog {
    [GtkChild]
    private unowned Gtk.Image game_image;

    public RulesDialog () {
        game_image.icon_name = "%s-symbolic".printf (APP_ID);
    }
}
