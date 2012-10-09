bin_PROGRAMS = gnome-tetravex

gnome_tetravex_SOURCES = \
	config.vapi \
	gnome-tetravex.vala \
	history.vala \
	puzzle.vala \
	puzzle-view.vala \
	theme.vala

gnome_tetravex_VALAFLAGS = \
	--pkg posix \
	--pkg gtk+-3.0

gnome_tetravex_CFLAGS = \
	-DVERSION=\"$(VERSION)\" \
	-DGETTEXT_PACKAGE=\"$(GETTEXT_PACKAGE)\" \
	-DDATA_DIRECTORY=\"$(datadir)/gnome-tetravex\" \
	-DLOCALEDIR=\"$(datadir)/locale\" \
	$(GNOME_TETRAVEX_CFLAGS) \
	-Wno-unused

gnome_tetravex_LDADD = \
	$(GNOME_TETRAVEX_LIBS)

CLEANFILES = \
	$(patsubst %.vala,%.c,$(filter %.vala, $(SOURCES))) \
	*_vala.stamp

-include $(top_srcdir)/git.mk
