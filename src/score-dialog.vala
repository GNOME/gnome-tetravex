/* -*- Mode: vala; tab-width: 4; indent-tabs-mode: nil; c-basic-offset: 4 -*-
 *
 * Copyright (C) 2010-2013 Robert Ancell
 *
 * This program is free software: you can redistribute it and/or modify it under
 * the terms of the GNU General Public License as published by the Free Software
 * Foundation, either version 2 of the License, or (at your option) any later
 * version. See http://www.gnu.org/copyleft/gpl.html the full text of the
 * license.
 */

using Gtk;

private class ScoreDialog : Dialog
{
    private History history;
    private HistoryEntry? selected_entry = null;
    private Gtk.ListStore size_model;
    private Gtk.ListStore score_model;
    private ComboBox size_combo;
    private TreeView scores;

    internal ScoreDialog (History history, HistoryEntry? selected_entry = null, bool show_quit = false)
    {
        this.history = history;
        history.entry_added.connect (entry_added_cb);
        this.selected_entry = selected_entry;

        if (show_quit)
        {
            /* Translators: label of a button of the Scores dialog, as it is displayed at the end of a game; quits the application */
            add_button (_("Quit"), ResponseType.CLOSE);


            /* Translators: label of a button of the Scores dialog, as it is displayed at the end of a game; starts a new game */
            add_button (_("New Game"), ResponseType.OK);
        }
        else
        {
            /* Translators: label of a button of the Scores dialog, as it is displayed when called from the hamburger menu; closes the dialog */
            add_button (_("OK"), ResponseType.DELETE_EVENT);
        }
        set_size_request (200, 300);

        Box vbox = new Box (Orientation.VERTICAL, 5);
        vbox.border_width = 6;
        vbox.show ();
        get_content_area ().pack_start (vbox, true, true, 0);

        Box hbox = new Box (Orientation.HORIZONTAL, 6);
        hbox.show ();
        vbox.pack_start (hbox, false, false, 0);

        /* Translators: in the Scores dialog, label introducing the combobox that allows showing scores for various sizes */
        Label label = new Label (_("Size:"));
        label.show ();
        hbox.pack_start (label, false, false, 0);

        size_model = new Gtk.ListStore (2, typeof (string), typeof (int));

        size_combo = new ComboBox ();
        size_combo.changed.connect (size_changed_cb);
        size_combo.model = size_model;
        CellRendererText renderer = new CellRendererText ();
        size_combo.pack_start (renderer, true);
        size_combo.add_attribute (renderer, "text", 0);
        size_combo.show ();
        hbox.pack_start (size_combo, true, true, 0);

        ScrolledWindow scroll = new ScrolledWindow (null, null);
        scroll.shadow_type = ShadowType.ETCHED_IN;
        scroll.set_policy (PolicyType.NEVER, PolicyType.AUTOMATIC);
        scroll.show ();
        vbox.pack_start (scroll, true, true, 0);

        score_model = new Gtk.ListStore (3, typeof (string), typeof (string), typeof (int));

        scores = new TreeView ();
        renderer = new CellRendererText ();
        /* Translators: in the Scores dialog, in the scores list, label of the column displaying when games were played */
        scores.insert_column_with_attributes (-1, _("Date"), renderer, "text", 0, "weight", 2);
        renderer = new CellRendererText ();
        renderer.xalign = 1.0f;
        /* Translators: in the Scores dialog, in the scores list, label of the column displaying the duration of played games */
        scores.insert_column_with_attributes (-1, _("Time"), renderer, "text", 1, "weight", 2);
        scores.model = score_model;
        scores.show ();
        scroll.add (scores);

        foreach (HistoryEntry entry in history.entries)
            entry_added_cb (entry);
    }

    internal void set_size (uint8 size)
    {
        score_model.clear ();

        List<unowned HistoryEntry> entries = history.entries.copy ();
        entries.sort (compare_entries);

        foreach (HistoryEntry entry in entries)
        {
            if (entry.size != size)
                continue;

            string date_label = entry.date.format ("%x");

            string time_label;
            if (entry.duration >= 3600)
                /* Translators: that is the duration of a game, as seen in the Scores dialog, if game has taken one hour or more; the %u are replaced by the hours (h), minutes (m) and seconds (s); as an example, you might want to use "%u:%.2u:%.2u", that is quite international (the ".2" meaning "two digits, padding with 0") */
                time_label = _("%uh %um %us").printf (entry.duration / 3600, (entry.duration / 60) % 60, entry.duration % 60);

            else if (entry.duration >= 60)
                /* Translators: that is the duration of a game, as seen in the Scores dialog, if game has taken between one minute and one hour; the %u are replaced by the minutes (m) and seconds (s); as an example, you might want to use "%.2u:%.2u", that is quite international (the ".2" meaning "two digits, padding with 0") */
                time_label = _("%um %us").printf (entry.duration / 60, entry.duration % 60);

            else
                /* Translators: that is the duration of a game, as seen in the Scores dialog, if game has taken less than one minute; the %u is replaced by the number of seconds (s) it has taken; as an example, you might want to use "00:%.2u", that is quite international (the ".2" meaning "two digits, padding with 0") */
                time_label = _("%us").printf (entry.duration);

            int weight = Pango.Weight.NORMAL;
            if (entry == selected_entry)
                weight = Pango.Weight.BOLD;

            TreeIter iter;
            score_model.append (out iter);
            score_model.@set (iter, 0, date_label, 1, time_label, 2, weight);

            if (entry == selected_entry)
            {
                TreeIter piter = iter;
                if (score_model.iter_previous (ref piter))
                {
                    TreeIter ppiter = piter;
                    if (score_model.iter_previous (ref ppiter))
                        piter = ppiter;
                }
                else
                    piter = iter;
                scores.scroll_to_cell (score_model.get_path (piter), null, false, 0, 0);
            }
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

    private void size_changed_cb (ComboBox combo)
    {
        TreeIter iter;
        if (!combo.get_active_iter (out iter))
            return;

        int size;
        combo.model.@get (iter, 1, out size);
        set_size ((uint8) size);
    }

    private void entry_added_cb (HistoryEntry entry)
    {
        /* Ignore if already have an entry for this */
        TreeIter iter;
        bool have_size_entry = false;
        if (size_model.get_iter_first (out iter))
        {
            do
            {
                int size;
                size_model.@get (iter, 1, out size, -1);
                if (size == entry.size)
                {
                    have_size_entry = true;
                    break;
                }
            } while (size_model.iter_next (ref iter));
        }

        if (!have_size_entry)
        {
            /* Translators: this string creates the options of the combobox seen in the Scores dialog; the %u are replaced by the board size; it allows to choose for which board size you want to see the scores, for example between "2 × 2" and "3 × 3" */
            string label = _("%u × %u").printf (entry.size, entry.size);

            size_model.append (out iter);
            size_model.@set (iter, 0, label, 1, entry.size);

            /* Select this entry if don't have any */
            if (size_combo.get_active () == -1)
                size_combo.set_active_iter (iter);

            /* Select this entry if the same category as the selected one */
            if (selected_entry != null && entry.size == ((!) selected_entry).size)
                size_combo.set_active_iter (iter);
        }
    }
}
