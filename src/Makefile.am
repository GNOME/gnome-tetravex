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

if ENABLE_SETGID
gnotravex_VALAFLAGS += -D ENABLE_SETGID
endif

gnotravex_CFLAGS = \
	-I$(top_srcdir)/libgames-support \
	-DVERSION=\"$(VERSION)\" \
	-DGETTEXT_PACKAGE=\"$(GETTEXT_PACKAGE)\" \
	$(GTK_CFLAGS)	\
	$(AM_CFLAGS)

gnotravex_LDADD =	\
	$(top_builddir)/libgames-support/libgames-support.la \
	$(GTK_LIBS)	\
	$(INTLLIBS)

if HAVE_GNOME
gnotravex_CFLAGS += $(GNOME_CFLAGS)
gnotravex_LDADD += $(GNOME_LIBS)
endif

if HAVE_RSVG
gnotravex_CFLAGS += $(RSVG_CFLAGS)
gnotravex_LDADD += $(RSVG_LIBS)
endif

if WITH_GTHREAD
gnotravex_CFLAGS += $(GHTREAD_CFLAGS)
gnotravex_LDADD += $(GTHREAD_LIBS)
endif

install-exec-hook:
	-if test "$(setgid)" = "true"; then \
	  chgrp $(scores_group) $(DESTDIR)$(bindir)/gnotravex && chmod 2555 $(DESTDIR)$(bindir)/gnotravex ;\
	fi

-include $(top_srcdir)/git.mk
