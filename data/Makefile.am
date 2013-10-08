SUBDIRS = icons

desktop_in_files = gnome-tetravex.desktop.in
desktopdir = $(datadir)/applications
desktop_DATA = $(desktop_in_files:.desktop.in=.desktop)
@INTLTOOL_DESKTOP_RULE@

appdatadir = $(datadir)/appdata
appdata_in_files = gnome-tetravex.appdata.xml.in
appdata_DATA = $(appdata_in_files:.xml.in=.xml)
@INTLTOOL_XML_RULE@

gsettings_SCHEMAS = org.gnome.tetravex.gschema.xml
@GSETTINGS_RULES@

man_MANS = gnome-tetravex.6

EXTRA_DIST = \
	$(appdata_in_files) \
	$(desktop_in_files) \
	$(gsettings_SCHEMAS) \
	$(man_MANS)
    
CLEANFILES = \
	$(appdata_DATA) \
	$(desktop_DATA)

check-local: $(appdata_DATA) $(desktop_DATA)
	$(APPDATA_VALIDATE) $(appdata_DATA)
	$(DESKTOP_FILE_VALIDATE) $(desktop_DATA)

-include $(top_srcdir)/git.mk
