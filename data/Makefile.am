SUBDIRS = icons

uidir = $(datadir)/gnome-tetravex
ui_DATA = gnome-tetravex.ui

desktop_in_files = gnome-tetravex.desktop.in.in
desktopdir = $(datadir)/applications
desktop_DATA = $(desktop_in_files:.desktop.in.in=.desktop)
@INTLTOOL_DESKTOP_RULE@

appdatadir = $(datadir)/appdata
appdata_DATA = gnome-tetravex.appdata.xml

gsettings_in_file = org.gnome.tetravex.gschema.xml.in
gsettings_SCHEMAS = $(gsettings_in_file:.xml.in=.xml)
@INTLTOOL_XML_NOMERGE_RULE@
@GSETTINGS_RULES@

man_MANS = gnome-tetravex.6

EXTRA_DIST = \
	$(appdata_DATA) \
	$(ui_DATA) \
	$(gsettings_in_file) \
	$(man_MANS)
    
CLEANFILES = $(desktop_DATA) $(gsettings_SCHEMAS)
DISTCLEANFILES = $(desktop_DATA) $(gsettings_SCHEMAS)

check-local: $(appdata_DATA) $(desktop_DATA)
	$(APPDATA_VALIDATE) $(appdata_DATA)
	$(DESKTOP_FILE_VALIDATE) $(desktop_DATA)

-include $(top_srcdir)/git.mk
