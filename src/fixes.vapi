[CCode (cprefix = "G", gir_namespace = "Gio", gir_version = "2.0", lower_case_cprefix = "g_")]
namespace GLib2 {
	[CCode (cheader_filename = "gio/gio.h", cname = "GApplication")]
	public class Application : GLib.Object, GLib.ActionGroup, GLib2.ActionMap {
		[CCode (has_construct_function = false)]
		public Application (string application_id, GLib.ApplicationFlags flags);
		[NoWrapper]
		public virtual void add_platform_data (GLib.VariantBuilder builder);
		[NoWrapper]
		public virtual void after_emit (GLib.Variant platform_data);
		[NoWrapper]
		public virtual void before_emit (GLib.Variant platform_data);
		public unowned string get_application_id ();
		public GLib.ApplicationFlags get_flags ();
		public uint get_inactivity_timeout ();
		public bool get_is_registered ();
		public bool get_is_remote ();
		public void hold ();
		public static bool id_is_valid (string application_id);
		[NoWrapper]
		public virtual bool local_command_line ([CCode (array_length = false, array_null_terminated = true)] ref unowned string[] arguments, out int exit_status);
		[CCode (cname = "g_application_quit_with_data")]
		public bool quit (GLib.Variant? platform_data = null);
		[NoWrapper]
		public virtual void quit_mainloop ();
		public bool register (GLib.Cancellable? cancellable = null) throws GLib.Error;
		public void release ();
		public int run ([CCode (array_length_pos = 0.9)] string[]? argv = null);
		[NoWrapper]
		public virtual void run_mainloop ();
		public void set_action_group (GLib.ActionGroup action_group);
		public void set_application_id (string application_id);
		public void set_flags (GLib.ApplicationFlags flags);
		public void set_inactivity_timeout (uint inactivity_timeout);
		public GLib.ActionGroup action_group { set; }
		public string application_id { get; set construct; }
		public GLib.ApplicationFlags flags { get; set; }
		public uint inactivity_timeout { get; set; }
		public bool is_registered { get; }
		public bool is_remote { get; }
		[HasEmitter]
		public virtual signal void activate ();
		public virtual signal int command_line (GLib.ApplicationCommandLine command_line);
		[HasEmitter]
		public virtual signal void open (GLib.File[] files, string hint);
		public virtual signal void shutdown ();
		public virtual signal void startup ();
	}
	[CCode (cheader_filename = "gio/gio.h")]
	public interface ActionMap : GLib.ActionGroup, GLib.Object {
		public abstract void add_action (GLib.Action action);
		public void add_action_entries (GLib.ActionEntry[] entries);
		public abstract GLib.Action lookup_action (string action_name);
		public abstract void remove_action (string action_name);
	}
	[CCode (cheader_filename = "gio/gio.h")]
	public class Menu : GLib2.MenuModel {
		[CCode (has_construct_function = false)]
		public Menu ();
		public void append (string label, string detailed_action);
		public void append_item (GLib2.MenuItem item);
		public void append_section (string label, GLib2.MenuModel section);
		public void append_submenu (string label, GLib2.MenuModel submenu);
		public void freeze ();
		public void insert (int position, string label, string detailed_action);
		public void insert_item (int position, GLib2.MenuItem item);
		public void insert_section (int position, string label, GLib2.MenuModel section);
		public void insert_submenu (int position, string label, GLib2.MenuModel submenu);
		public static unowned GLib.HashTable markup_parser_end (GLib.MarkupParseContext context);
		public static unowned GLib2.Menu markup_parser_end_menu (GLib.MarkupParseContext context);
		public static void markup_parser_start (GLib.MarkupParseContext context, string domain, GLib.HashTable objects);
		public static void markup_parser_start_menu (GLib.MarkupParseContext context, string domain, GLib.HashTable objects);
		public static void markup_print_stderr (GLib2.MenuModel model);
		public static unowned GLib.StringBuilder markup_print_string (GLib.StringBuilder str, GLib2.MenuModel model, int indent, int tabstop);
		public void prepend (string label, string detailed_action);
		public void prepend_item (GLib2.MenuItem item);
		public void prepend_section (string label, GLib2.MenuModel section);
		public void prepend_submenu (string label, GLib2.MenuModel submenu);
		public void remove (int position);
	}
	[CCode (cheader_filename = "gio/gio.h")]
	public class MenuAttributeIter : GLib.Object {
		[CCode (has_construct_function = false)]
		protected MenuAttributeIter ();
		public unowned string get_name ();
		public virtual bool get_next (string out_name, out unowned GLib.Variant value);
		public GLib.Variant get_value ();
		public bool next ();
	}
	[CCode (cheader_filename = "gio/gio.h")]
	public class MenuItem : GLib.Object {
		[CCode (has_construct_function = false)]
		public MenuItem (string label, string detailed_action);
		[CCode (has_construct_function = false)]
		public MenuItem.section (string label, GLib2.MenuModel section);
		public void set_action_and_target (string action, string format_string);
		public void set_action_and_target_value (string action, GLib.Variant target_value);
		public void set_attribute (string attribute, string format_string);
		public void set_attribute_value (string attribute, GLib.Variant value);
		public void set_detailed_action (string detailed_action);
		public void set_label (string label);
		public void set_link (string link, GLib2.MenuModel model);
		public void set_section (GLib2.MenuModel section);
		public void set_submenu (GLib2.MenuModel submenu);
		[CCode (has_construct_function = false)]
		public MenuItem.submenu (string label, GLib2.MenuModel submenu);
	}
	[CCode (cheader_filename = "gio/gio.h")]
	public class MenuLinkIter : GLib.Object {
		[CCode (has_construct_function = false)]
		protected MenuLinkIter ();
		public unowned string get_name ();
		public virtual bool get_next (string out_link, out unowned GLib2.MenuModel value);
		public GLib2.MenuModel get_value ();
		public bool next ();
	}
	[CCode (cheader_filename = "gio/gio.h")]
	public class MenuModel : GLib.Object {
		[CCode (has_construct_function = false)]
		protected MenuModel ();
		public bool get_item_attribute (int item_index, string attribute, string format_string);
		public virtual GLib.Variant get_item_attribute_value (int item_index, string attribute, GLib.VariantType expected_type);
		[NoWrapper]
		public virtual void get_item_attributes (int item_index, GLib.HashTable attributes);
		public virtual GLib2.MenuModel get_item_link (int item_index, string link);
		[NoWrapper]
		public virtual void get_item_links (int item_index, GLib.HashTable links);
		public virtual int get_n_items ();
		public virtual bool is_mutable ();
		public virtual GLib2.MenuAttributeIter iterate_item_attributes (int item_index);
		public virtual GLib2.MenuLinkIter iterate_item_links (int item_index);
		[HasEmitter]
		public virtual signal void items_changed (int p0, int p1, int p2);
	}
}

[CCode (cprefix = "Gtk", gir_namespace = "Gtk", gir_version = "3.0", lower_case_cprefix = "gtk_")]
namespace Gtk3 {
	[CCode (cheader_filename = "gtk/gtk.h")]
	public class Application : GLib2.Application, GLib.ActionGroup, GLib2.ActionMap {
		[CCode (has_construct_function = false)]
		public Application (string application_id, GLib.ApplicationFlags flags);
		public void add_accelerator (string accelerator, string action_name, GLib.Variant parameter);
		public void add_window (Gtk.Window window);
		public unowned GLib2.MenuModel get_app_menu ();
		public unowned GLib2.MenuModel get_menubar ();
		public unowned GLib.List<weak Gtk.Window> get_windows ();
		public void remove_accelerator (string action_name, GLib.Variant parameter);
		public void remove_window (Gtk.Window window);
		public void set_app_menu (GLib2.MenuModel model);
		public void set_menubar (GLib2.MenuModel model);
		public GLib2.MenuModel app_menu { get; set; }
		public GLib2.MenuModel menubar { get; set; }
		public virtual signal void window_added (Gtk.Window window);
		public virtual signal void window_removed (Gtk.Window window);
	}
}
