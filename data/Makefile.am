imagedir = $(pkgdatadir)/pixmaps
image_DATA = baize.png

desktop_in_files = gnotravex.desktop.in.in
desktopdir = $(datadir)/applications
desktop_DATA = $(desktop_in_files:.desktop.in.in=.desktop)
@INTLTOOL_DESKTOP_RULE@

gsettings_in_file = org.gnome.gnotravex.gschema.xml.in
gsettings_SCHEMAS = $(gsettings_in_file:.xml.in=.xml)
@INTLTOOL_XML_NOMERGE_RULE@
@GSETTINGS_RULES@

man_MANS = gnotravex.6

EXTRA_DIST = \
	$(image_DATA) \
	$(gsettings_in_file) \
	$(man_MANS)
    
CLEANFILES = $(desktop_DATA) $(gsettings_SCHEMAS)
DISTCLEANFILES = $(desktop_DATA) $(gsettings_SCHEMAS)

-include $(top_srcdir)/git.mk
