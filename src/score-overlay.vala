/* -*- Mode: vala; tab-width: 4; indent-tabs-mode: nil; c-basic-offset: 4 -*-

   This file is part of GNOME Tetravex.

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

[GtkTemplate (ui = "/org/gnome/Tetravex/ui/score-overlay.ui")]
private class ScoreOverlay : Grid
{
    [CCode (notify = true)] internal uint boardsize
    {
        internal set
        {
            if (value < 250 && value != 0)
                add_css_class ("small-window");
            else
                remove_css_class ("small-window");
        }
    }

    /*\
    * * updating labels
    \*/

    [GtkChild] private unowned ScoreOverlayEntry score_0;
    [GtkChild] private unowned ScoreOverlayEntry score_1;
    [GtkChild] private unowned ScoreOverlayEntry score_2;
    [GtkChild] private unowned ScoreOverlayEntry score_3;

    internal void set_score (uint8          puzzle_size,
                             uint /* [1[ */ position,
                             HistoryEntry   entry,
                             HistoryEntry?  other_entry_0,
                             HistoryEntry?  other_entry_1,
                             HistoryEntry?  other_entry_2)
    {
        switch (position)
        {
            case 1:
                /* Translators: text of the score overlay, displayed after a puzzle is complete; appears if the player has been the fastest for a puzzle of this size; introduces the game time */
                score_0.set_place_label (_("New best time!"));
                score_0.set_value_label (HistoryEntry.get_duration_string (entry), true);

                /* Translators: text of the score overlay, displayed after a puzzle is complete; appears if the player has been the fastest for a puzzle of this size; introduces the old best time */
                score_1.set_place_label (_("Second:"));
                if (other_entry_0 != null)
                    score_1.set_value_label (HistoryEntry.get_duration_string ((!) other_entry_0));
                else
                    score_1.set_value_label (null);

                /* Translators: text of the score overlay, displayed after a puzzle is complete; appears if the player has been the fastest for a puzzle of this size; introduces the old second best time */
                score_2.set_place_label (_("Third:"));
                if (other_entry_1 != null)
                    score_2.set_value_label (HistoryEntry.get_duration_string ((!) other_entry_1));
                else
                    score_2.set_value_label (null);

                /* Translators: text of the score overlay, displayed after a puzzle is complete; appears if the player has been the fastest for a puzzle of this size; introduces the old third best time */
                score_3.set_place_label (_("Out of podium:"));
                if (other_entry_2 != null)
                    score_3.set_value_label (HistoryEntry.get_duration_string ((!) other_entry_2));
                else
                    score_3.set_value_label (null);
                break;

            case 2:
                if (other_entry_0 == null)
                    assert_not_reached ();
                /* Translators: text of the score overlay, displayed after a puzzle is complete; appears if the player has made the second best time for a puzzle of this size; introduces the best time ever */
                score_0.set_place_label (_("Best time:"));
                score_0.set_value_label (HistoryEntry.get_duration_string ((!) other_entry_0));

                /* Translators: text of the score overlay, displayed after a puzzle is complete; appears if the player has made the second best time for a puzzle of this size; introduces the game time */
                score_1.set_place_label (_("Your time:"));
                score_1.set_value_label (HistoryEntry.get_duration_string (entry), true);

                /* Translators: text of the score overlay, displayed after a puzzle is complete; appears if the player has made the second best time for a puzzle of this size; introduces the old second best time */
                score_2.set_place_label (_("Third:"));
                if (other_entry_1 != null)
                    score_2.set_value_label (HistoryEntry.get_duration_string ((!) other_entry_1));
                else
                    score_2.set_value_label (null);

                /* Translators: text of the score overlay, displayed after a puzzle is complete; appears if the player has made the second best time for a puzzle of this size; introduces the old third best time */
                score_3.set_place_label (_("Out of podium:"));
                if (other_entry_2 != null)
                    score_3.set_value_label (HistoryEntry.get_duration_string ((!) other_entry_2));
                else
                    score_3.set_value_label (null);
                break;

            default:
                if (other_entry_0 == null || other_entry_1 == null)
                    assert_not_reached ();
                /* Translators: text of the score overlay, displayed after a puzzle is complete; appears if the player has not made the first or second best time for a puzzle of this size; introduces the best time ever */
                score_0.set_place_label (_("Best time:"));
                score_0.set_value_label (HistoryEntry.get_duration_string ((!) other_entry_0));

                if (position == 3)
                /* Translators: text of the score overlay, displayed after a puzzle is complete; appears if the player has not made the first or second best time for a puzzle of this size; introduces the second best time */
                    score_1.set_place_label (_("Second:"));

                else if (position == 4)
                /* Translators: text of the score overlay, displayed after a puzzle is complete; appears if the player has not made the first or second best time for a puzzle of this size; introduces the third best time */
                    score_1.set_place_label (_("Third:"));

                else
                /* Translators: text of the score overlay, displayed after a puzzle is complete; appears if the player has not made the first or second best time for a puzzle of this size; the %u is replaced by the rank before the one of the game played */
                    score_1.set_place_label (_("Place %u:").printf (position - 1));
                score_1.set_value_label (HistoryEntry.get_duration_string ((!) other_entry_1));

                /* Translators: text of the score overlay, displayed after a puzzle is complete; appears if the player has not made the first or second best time for a puzzle of this size; introduces the game time */
                score_2.set_place_label (_("Your time:"));
                score_2.set_value_label (HistoryEntry.get_duration_string (entry), true);

                /* Translators: text of the score overlay, displayed after a puzzle is complete; appears if the player has not made the first or second best time for a puzzle of this size; the %u is replaced by the rank after the one of the game played */
                score_3.set_place_label (_("Place %u:").printf (position + 1));
                if (other_entry_2 != null)
                    score_3.set_value_label (HistoryEntry.get_duration_string ((!) other_entry_2));
                else
                    score_3.set_value_label (null);
                break;
        }
    }
}

[GtkTemplate (ui = "/org/gnome/Tetravex/ui/score-overlay-entry.ui")]
private class ScoreOverlayEntry : Grid
{
    [GtkChild] private unowned Label place_label;
    [GtkChild] private unowned Label value_label;

    internal void set_place_label (string label)
    {
        place_label.set_label (label);
    }

    internal void set_value_label (string? label, bool bold_label = false)
    {
        if (label != null)
        {
            value_label.set_label ((!) label);
            value_label.remove_css_class ("italic-label");
        }
        else
        {
            /* Translators: text of the score overlay, displayed after a puzzle is complete; appears if the player has made one of the worst scores for a game of this size; says that the rank after the one of the game is "free", inviting to do worse */
            value_label.set_label (_("Free!"));
            value_label.add_css_class ("italic-label");
        }

        if (bold_label)
            value_label.add_css_class ("bold-label");
        else
            value_label.remove_css_class ("bold-label");
    }
}
