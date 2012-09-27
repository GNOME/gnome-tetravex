bin_PROGRAMS = gnotravex

gnotravex_SOURCES = \
	config.vapi \
	gnotravex.vala \
	history.vala \
	puzzle.vala \
	puzzle-view.vala \
	theme.vala

gnotravex_VALAFLAGS = \
	--pkg posix \
	--pkg gtk+-3.0

gnotravex_CFLAGS = \
	-DVERSION=\"$(VERSION)\" \
	-DGETTEXT_PACKAGE=\"$(GETTEXT_PACKAGE)\" \
	-DDATA_DIRECTORY=\"$(datadir)/gnotravex\" \
	-DLOCALEDIR=\"$(datadir)/locale\" \
	$(GTK_CFLAGS) \
	$(RSVG_CFLAGS) \
	$(AM_CFLAGS) \
	-Wno-unused

gnotravex_LDADD = \
	$(GTK_LIBS)	\
	$(RSVG_LIBS) \
	$(INTLLIBS)

CLEANFILES = \
	$(patsubst %.vala,%.c,$(filter %.vala, $(SOURCES))) \
	*_vala.stamp

-include $(top_srcdir)/git.mk
