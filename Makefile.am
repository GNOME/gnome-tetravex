sharedpixmapdir = $(datadir)/pixmaps
Gamesdir = $(datadir)/applications

INCLUDES = 			\
	-I$(top_srcdir)/libgames-support \
	$(GNOME_GAMES_CFLAGS)	\
	-DGNOMELOCALEDIR=\""$(datadir)/locale"\" \
	-DDATADIR=\""$(datadir)"\"		   \
	-DG_DISABLE_DEPRECATED -DGDK_DISABLE_DEPRECATED \
	-DGTK_DISABLE_DEPRECATED -DGNOME_DISABLE_DEPRECATED

bin_PROGRAMS = gnotravex

gnotravex_SOURCES =	\
	gnotravex.c

gnotravex_LDADD = \
	$(GNOME_GAMES_LIBS) \
	../libgames-support/libgames-support.la \
	$(INTLLIBS) 

sharedpixmap_DATA = gnome-gnotravex.png

Games_in_files = gnotravex.desktop.in
Games_DATA = $(Games_in_files:.desktop.in=.desktop)
@INTLTOOL_DESKTOP_RULE@

EXTRA_DIST = README gnotravex.desktop.in $(sharedpixmap_DATA)

CLEANFILES = $(Games_DATA)

SUBDIRS = help

install-data-local:
	-$(mkinstalldirs) $(DESTDIR)$(scoredir)
	-for i in 2 3 4 5 6 ; do \
	   touch $(DESTDIR)$(scoredir)/gnotravex.$$ix$$i.scores; \
	   chown $(scores_user).$(scores_group) $(DESTDIR)$(scoredir)/gnotravex.$$ix$$i.scores; \
	   chmod 664 $(DESTDIR)$(scoredir)/gnotravex.$$ix$$i.scores; \
	 done
	-if test "x$(setgid)" = "xtrue"; then chgrp $(scores_group) $(DESTDIR)$(bindir)/gnotravex && chmod 2555 $(DESTDIR)$(bindir)/gnotravex ; fi
