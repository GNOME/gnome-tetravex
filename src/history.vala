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

private class History : Object
{
    [CCode (notify = false)] public string filename { private get; protected construct; }
    internal List<HistoryEntry> entries = new List<HistoryEntry> ();

    /*\
    * * getting
    \*/

    internal signal void entry_added (HistoryEntry entry);

    internal uint get_place (HistoryEntry   entry,
                             uint8          puzzle_size,
                         out HistoryEntry?  other_entry_0,
                         out HistoryEntry?  other_entry_1,
                         out HistoryEntry?  other_entry_2)
    {
        entries.insert_sorted (entry, compare_entries);
        entry_added (entry);
        save ();

        unowned List<HistoryEntry> entry_item = entries.find (entry);
        unowned List<HistoryEntry> best_time_item;
        uint best_position = get_best_time_position (entry_item, out best_time_item);
        uint position = entries.position (entry_item) - best_position + 1;
        switch (position)
        {
            case 1:
                unowned List<HistoryEntry>? tmp_item = entry_item.next;
                if (tmp_item == null || ((!) tmp_item).data.size != puzzle_size)
                {
                    other_entry_0 = null;
                    other_entry_1 = null;
                    other_entry_2 = null;
                    break;
                }
                other_entry_0 = ((!) tmp_item).data;
                tmp_item = ((!) tmp_item).next;
                if (tmp_item == null || ((!) tmp_item).data.size != puzzle_size)
                {
                    other_entry_1 = null;
                    other_entry_2 = null;
                    break;
                }
                other_entry_1 = ((!) tmp_item).data;
                tmp_item = ((!) tmp_item).next;
                if (tmp_item == null || ((!) tmp_item).data.size != puzzle_size)
                    other_entry_2 = null;
                else
                    other_entry_2 = ((!) tmp_item).data;
                break;

            case 2:
                other_entry_0 = best_time_item.data;
                unowned List<HistoryEntry>? tmp_item = entry_item.next;
                if (tmp_item == null || ((!) tmp_item).data.size != puzzle_size)
                {
                    other_entry_1 = null;
                    other_entry_2 = null;
                    break;
                }
                other_entry_1 = ((!) tmp_item).data;
                tmp_item = ((!) tmp_item).next;
                if (tmp_item == null || ((!) tmp_item).data.size != puzzle_size)
                    other_entry_2 = null;
                else
                    other_entry_2 = ((!) tmp_item).data;
                break;

            default:
                other_entry_0 = best_time_item.data;
                other_entry_1 = entry_item.prev.data;
                unowned List<HistoryEntry>? next_entry_item = entry_item.next;
                if (next_entry_item == null || ((!) next_entry_item).data.size != puzzle_size)
                    other_entry_2 = null;
                else
                    other_entry_2 = ((!) next_entry_item).data;
                break;
        }
        return position;
    }

    private uint get_best_time_position (List<HistoryEntry> entry_item, out unowned List<HistoryEntry> best_time_item)
    {
        uint8 puzzle_size = entry_item.data.size;
        best_time_item = entries.first ();
        if (puzzle_size == 2 || entry_item == best_time_item)
            return 0;

        best_time_item = entry_item;
        do { best_time_item = best_time_item.prev; }
        while (best_time_item != entries && best_time_item.data.size == puzzle_size);
        return entries.position (best_time_item);
    }

    internal bool is_empty ()
    {
        unowned List<HistoryEntry>? first_entry = entries.first ();
        return first_entry == null;
    }

    internal void get_fallback_scores (uint8          puzzle_size,
                                   out HistoryEntry?  fallback_score_0,
                                   out HistoryEntry?  fallback_score_1,
                                   out HistoryEntry?  fallback_score_2,
                                   out HistoryEntry?  fallback_score_3)
    {
        unowned List<HistoryEntry>? tmp_item = entries.first ();

        while (tmp_item != null && ((!) tmp_item).data.size < puzzle_size)
        { tmp_item = ((!) tmp_item).next; }

        if (tmp_item == null || ((!) tmp_item).data.size != puzzle_size)
        {
            fallback_score_0 = null;
            fallback_score_1 = null;
            fallback_score_2 = null;
            fallback_score_3 = null;
            return;
        }
        fallback_score_0 = ((!) tmp_item).data;

        tmp_item = ((!) tmp_item).next;
        if (tmp_item == null || ((!) tmp_item).data.size != puzzle_size)
        {
            fallback_score_1 = null;
            fallback_score_2 = null;
            fallback_score_3 = null;
            return;
        }
        fallback_score_1 = ((!) tmp_item).data;

        tmp_item = ((!) tmp_item).next;
        if (tmp_item == null || ((!) tmp_item).data.size != puzzle_size)
        {
            fallback_score_2 = null;
            fallback_score_3 = null;
            return;
        }
        fallback_score_2 = ((!) tmp_item).data;

        tmp_item = ((!) tmp_item).next;
        if (tmp_item == null || ((!) tmp_item).data.size != puzzle_size)
        {
            fallback_score_3 = null;
            return;
        }

        unowned List<HistoryEntry> tmp_item_prev = (!) tmp_item;    // garbage
        do { tmp_item_prev = (!) tmp_item; tmp_item = ((!) tmp_item).next; }
        while (tmp_item != null && ((!) tmp_item).data.size == puzzle_size);
        fallback_score_3 = tmp_item_prev.data;
    }

    /*\
    * * loading
    \*/

    internal History (string filename)
    {
        Object (filename: filename);
        load ();
    }

    private inline void load ()
    {
        string contents = "";
        try
        {
            FileUtils.get_contents (filename, out contents);
        }
        catch (FileError e)
        {
            if (!(e is FileError.NOENT))
                warning ("Failed to load history: %s", e.message);
            return;
        }

        foreach (string line in contents.split ("\n"))
        {
            string [] tokens = line.split (" ");
            if (tokens.length != 3)
                continue;

            DateTime? date = new DateTime.from_iso8601 (tokens [0], /* the entries should have a timezone */ null);
            if (date == null)
                continue;

            uint64 test;
            if (!uint64.try_parse (tokens [1], out test))
                continue;
            if (test < 2 || test > 6)
                continue;
            uint8 size = (uint8) test;

            double duration;
            bool int_duration;
            if (uint64.try_parse (tokens [2], out duration))
                int_duration = true;
            else if (double.try_parse (tokens [2], out duration))
                int_duration = false;
            else
                continue;

            entries.prepend (new HistoryEntry ((!) date, size, duration, int_duration));
        }
        entries.sort (compare_entries);
    }

    /*\
    * * saving
    \*/

    private inline void save ()
    {
        string contents = "";

        foreach (HistoryEntry entry in entries)
        {
            string line;
            if (entry.int_duration)
                line = "%s %hu %u\n".printf (entry.date.to_string (), entry.size, (uint) entry.duration);
            else
                line = "%s %hu %s\n".printf (entry.date.to_string (), entry.size, entry.duration.to_string ());
            contents += line;
        }

        try
        {
            DirUtils.create_with_parents (Path.get_dirname (filename), 0775);
            FileUtils.set_contents (filename, contents);
        }
        catch (FileError e)
        {
            warning ("Failed to save history: %s", e.message);
        }
    }

    /*\
    * * comparing
    \*/

    private static int compare_entries (HistoryEntry a, HistoryEntry b)
    {
        /* in size order, 2 first */
        if (a.size != b.size)
            return (int) a.size - (int) b.size;

        /* not in the same second, easy */
        if ((uint) a.duration < (uint) b.duration)
            return -1;
        if ((uint) a.duration > (uint) b.duration)
            return 1;

        /* old history format after, to renew a bit the challenge (it might logically be more at duration - 0.5) */
        if (a.int_duration && !b.int_duration)
            return 1;
        if (b.int_duration && !a.int_duration)
            return -1;

        /* compare duration */
        if (a.duration < b.duration)
            return -1;
        if (a.duration > b.duration)
            return 1;

        /* newer on the top */
        return -1 * a.date.compare (b.date);
    }
}

private class HistoryEntry : Object // TODO make struct? needs using HistoryEntry? for the List...
{
    [CCode (notify = false)] public DateTime date       { internal get; protected construct; }
    [CCode (notify = false)] public uint8 size          { internal get; protected construct; }
    [CCode (notify = false)] public double duration     { internal get; protected construct; }
    [CCode (notify = false)] public bool int_duration   { internal get; protected construct; }

    internal HistoryEntry (DateTime date, uint8 size, double duration, bool int_duration)
    {
        Object (date: date, size: size, duration: duration, int_duration: int_duration);
    }

    /*\
    * * utilities
    \*/

    internal static string get_duration_string (HistoryEntry entry)
    {
        if (entry.duration >= 3600.0)
            /* Translators: that is the duration of a game, as seen in the Scores dialog, if game has taken one hour or more; the %u are replaced by the hours (h), minutes (m) and seconds (s); as an example, you might want to use "%u:%.2u:%.2u", that is quite international (the ".2" meaning "two digits, padding with 0") */
            return _("%uh %um %us").printf ((uint) entry.duration / 3600, ((uint) entry.duration / 60) % 60, (uint) entry.duration % 60);

        if (entry.duration >= 60.0)
            /* Translators: that is the duration of a game, as seen in the Scores dialog, if game has taken between one minute and one hour; the %u are replaced by the minutes (m) and seconds (s); as an example, you might want to use "%.2u:%.2u", that is quite international (the ".2" meaning "two digits, padding with 0") */
            return _("%um %us").printf ((uint) entry.duration / 60, (uint) entry.duration % 60);

        else if (entry.int_duration)
            /* Translators: that is the duration of a game, as seen in the Scores dialog, if game has taken less than one minute; the %u is replaced by the number of seconds (s) it has taken */
            return _("%us").printf ((uint) entry.duration);

        else if (entry.duration >= 20.0)
            /* Translators: that is the duration of a game, as seen in the Scores dialog, if game has taken less than one minute; the %.0f is replaced by the number of seconds (s) it has taken */
            return _("%.0fs").printf (Math.floor (entry.duration));

        else if (entry.duration >= 10.0)
            /* Translators: that is the duration of a game, as seen in the Scores dialog, if game has taken less than one minute; the %.1f is replaced by the number of seconds (s) it has taken, including deciseconds (1 digits after comma, so the .1) */
            return _("%.1fs").printf (Math.floor (entry.duration * 10.0) / 10.0);

        else if (entry.duration >= 5.0)
            /* Translators: that is the duration of a game, as seen in the Scores dialog, if game has taken less than one minute; the %.2f is replaced by the number of seconds (s) it has taken, including centiseconds (2 digits after comma, so the .2) */
            return _("%.2fs").printf (Math.floor (entry.duration * 100.0) / 100.0);

        else
            /* Translators: that is the duration of a game, as seen in the Scores dialog, if game has taken less than one minute; the %.3f is replaced by the number of seconds (s) it has taken, including milliseconds (3 digits after comma, so the .3) */
            return _("%.3fs").printf (Math.floor (entry.duration * 1000.0) / 1000.0);
    }
}
