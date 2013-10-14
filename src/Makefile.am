bin_PROGRAMS = gnome-tetravex

BUILT_SOURCES = \
	gnome-tetravex-resources.c

gnome_tetravex_SOURCES = \
	config.vapi \
	gnome-tetravex.vala \
	history.vala \
	puzzle.vala \
	puzzle-view.vala \
	theme.vala \
	score-dialog.vala \
	$(BUILT_SOURCES)

UI_FILES = \
	gnome-tetravex.ui \
	app-menu.ui

gnome_tetravex_VALAFLAGS = \
	--pkg posix \
	--pkg gtk+-3.0 \
    --target-glib 2.36

gnome_tetravex_CFLAGS = \
	-DVERSION=\"$(VERSION)\" \
	-DGETTEXT_PACKAGE=\"$(GETTEXT_PACKAGE)\" \
	-DDATA_DIRECTORY=\"$(datadir)/gnome-tetravex\" \
	-DLOCALEDIR=\"$(datadir)/locale\" \
	$(GNOME_TETRAVEX_CFLAGS) \
	-Wno-unused

gnome_tetravex_LDADD = \
	$(GNOME_TETRAVEX_LIBS) \
	-lm

gnome-tetravex-resources.c: gnome-tetravex.gresource.xml $(shell $(GLIB_COMPILE_RESOURCES) --generate-dependencies gnome-tetravex.gresource.xml)
	$(AM_V_GEN) $(GLIB_COMPILE_RESOURCES) --target=$@ --sourcedir=$(srcdir) --generate-source gnome-tetravex.gresource.xml

EXTRA_DIST = \
	gnome-tetravex.gresource.xml

CLEANFILES = \
	$(patsubst %.vala,%.c,$(filter %.vala, $(SOURCES))) \
	*_vala.stamp

-include $(top_srcdir)/git.mk
