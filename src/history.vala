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

    internal signal void entry_added (HistoryEntry entry);

    internal History (string filename)
    {
        Object (filename: filename);
        load ();
    }

    internal void add (HistoryEntry entry)
    {
        entries.append (entry);
        entry_added (entry);
    }

    internal void load ()
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

            DateTime? date = parse_date (tokens[0]);
            if (date == null)
                continue;

            int size = int.parse (tokens[1]);
            int duration = int.parse (tokens[2]);

            // FIXME use try_parse

            add (new HistoryEntry (date, size, duration));
        }
    }

    internal void save ()
    {
        string contents = "";

        foreach (HistoryEntry entry in entries)
        {
            string line = "%s %u %u\n".printf (entry.date.to_string (), entry.size, entry.duration);
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

    private DateTime? parse_date (string date)
    {
        if (date.length < 19 || date[4] != '-' || date[7] != '-' || date[10] != 'T' || date[13] != ':' || date[16] != ':')
            return null;

        // FIXME use try_parse

        int year        = int.parse (date.substring (0, 4));
        int month       = int.parse (date.substring (5, 2));
        int day         = int.parse (date.substring (8, 2));
        int hour        = int.parse (date.substring (11, 2));
        int minute      = int.parse (date.substring (14, 2));
        int seconds     = int.parse (date.substring (17, 2));
        string timezone = date.substring (19);

        return new DateTime (new TimeZone (timezone), year, month, day, hour, minute, seconds);
    }
}

private class HistoryEntry : Object // TODO make struct? needs using HistoryEntry? for the List...
{
    [CCode (notify = false)] public DateTime date { internal get; protected construct; }
    [CCode (notify = false)] public uint size     { internal get; protected construct; }
    [CCode (notify = false)] public uint duration { internal get; protected construct; }

    internal HistoryEntry (DateTime date, uint size, uint duration)
    {
        Object (date: date, size: size, duration: duration);
    }
}
