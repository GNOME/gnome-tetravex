bin_PROGRAMS = gnotravex

gnotravex_SOURCES = \
	gnotravex.c

gnotravex_CPPFLAGS = \
	-I$(top_srcdir) \
	$(AM_CPPFLAGS)

gnotravex_CFLAGS = \
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
