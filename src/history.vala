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
        entries.insert_sorted (entry, HistoryEntry.compare_entries);
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
        best_time_item = best_time_item.next;
        return entries.position (best_time_item);
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

            if (!uint64.try_parse (tokens [2], out test))
                continue;
            if (test > uint.MAX)
                continue;
            uint duration = (uint) test;

            entries.prepend (new HistoryEntry ((!) date, size, duration));
        }
        entries.sort (HistoryEntry.compare_entries);
    }

    /*\
    * * saving
    \*/

    private inline void save ()
    {
        string contents = "";

        foreach (HistoryEntry entry in entries)
        {
            string line = "%s %hu %u\n".printf (entry.date.to_string (), entry.size, entry.duration);
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
}

private class HistoryEntry : Object // TODO make struct? needs using HistoryEntry? for the List...
{
    [CCode (notify = false)] public DateTime date { internal get; protected construct; }
    [CCode (notify = false)] public uint8 size    { internal get; protected construct; }
    [CCode (notify = false)] public uint duration { internal get; protected construct; }

    internal HistoryEntry (DateTime date, uint8 size, uint duration)
    {
        Object (date: date, size: size, duration: duration);
    }

    /*\
    * * utilities
    \*/

    internal static string get_duration_string (uint duration)
    {
        if (duration >= 3600)
            /* Translators: that is the duration of a game, as seen in the Scores dialog, if game has taken one hour or more; the %u are replaced by the hours (h), minutes (m) and seconds (s); as an example, you might want to use "%u:%.2u:%.2u", that is quite international (the ".2" meaning "two digits, padding with 0") */
            return _("%uh %um %us").printf (duration / 3600, (duration / 60) % 60, duration % 60);

        if (duration >= 60)
            /* Translators: that is the duration of a game, as seen in the Scores dialog, if game has taken between one minute and one hour; the %u are replaced by the minutes (m) and seconds (s); as an example, you might want to use "%.2u:%.2u", that is quite international (the ".2" meaning "two digits, padding with 0") */
            return _("%um %us").printf (duration / 60, duration % 60);

        else
            /* Translators: that is the duration of a game, as seen in the Scores dialog, if game has taken less than one minute; the %u is replaced by the number of seconds (s) it has taken; as an example, you might want to use "00:%.2u", that is quite international (the ".2" meaning "two digits, padding with 0") */
            return _("%us").printf (duration);
    }

    internal static int compare_entries (HistoryEntry a, HistoryEntry b)
    {
        if (a.size != b.size)
            return (int) a.size - (int) b.size;
        if (a.duration != b.duration)
            return (int) a.duration - (int) b.duration;
        else
            return a.date.compare (b.date);
    }
}
