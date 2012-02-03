bin_PROGRAMS = gnotravex

gnotravex_SOURCES = \
	config.vapi \
	gnotravex.vala \
	puzzle.vala \
	puzzle-view.vala \
	theme.vala

gnotravex_VALAFLAGS = \
	--pkg posix \
	--pkg gtk+-3.0 \
	--vapidir $(top_srcdir)/libgames-support \
	--pkg GnomeGamesSupport-1.0

gnotravex_CFLAGS = \
	-I$(top_srcdir)/libgames-support \
	-DVERSION=\"$(VERSION)\" \
	-DGETTEXT_PACKAGE=\"$(GETTEXT_PACKAGE)\" \
	-DDATA_DIRECTORY=\"$(datadir)/gnotravex\" \
	-DLOCALEDIR=\"$(datadir)/locale\" \
	$(GTK_CFLAGS) \
	$(AM_CFLAGS) \
	-Wno-unused

gnotravex_LDADD =	\
	$(top_builddir)/libgames-support/libgames-support.la \
	$(GTK_LIBS)	\
	$(INTLLIBS)

if HAVE_RSVG
gnotravex_CFLAGS += $(RSVG_CFLAGS)
gnotravex_LDADD += $(RSVG_LIBS)
endif

install-exec-hook:
	-if test "$(setgid)" = "true"; then \
	  chgrp $(scores_group) $(DESTDIR)$(bindir)/gnotravex && chmod 2555 $(DESTDIR)$(bindir)/gnotravex ;\
	fi

CLEANFILES = \
	$(patsubst %.vala,%.c,$(filter %.vala, $(SOURCES))) \
	*_vala.stamp

-include $(top_srcdir)/git.mk
