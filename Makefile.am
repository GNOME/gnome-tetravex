scoredir=$(localstatedir)/games
pixmapdir=$(datadir)/pixmaps/gnotravex
sharedpixmapdir=$(datadir)/pixmaps
Gamesdir=$(datadir)/applications

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

pixmap_DATA = gnotravex.png 
sharedpixmap_DATA = gnome-gnotravex.png

Games_in_files = gnotravex.desktop.in
Games_DATA = $(Games_in_files:.desktop.in=.desktop)
@INTLTOOL_DESKTOP_RULE@

EXTRA_DIST = README gnotravex.desktop.in $(pixmap_DATA) $(sharedpixmap_DATA)

CLEANFILES = $(Games_DATA)

SUBDIRS = help

install-data-local:
	-$(mkinstalldirs) $(DESTDIR)$(scoredir)
	-touch $(DESTDIR)$(scoredir)/gnotravex.2x2.scores
	-chown games.games $(DESTDIR)$(scoredir)/gnotravex.2x2.scores
	-chmod 664 $(DESTDIR)$(scoredir)/gnotravex.2x2.scores
	-touch $(DESTDIR)$(scoredir)/gnotravex.3x3.scores
	-chown games.games $(DESTDIR)$(scoredir)/gnotravex.3x3.scores
	-chmod 664 $(DESTDIR)$(scoredir)/gnotravex.3x3.scores
	-touch $(DESTDIR)$(scoredir)/gnotravex.4x4.scores
	-chown games.games $(DESTDIR)$(scoredir)/gnotravex.4x4.scores
	-chmod 664 $(DESTDIR)$(scoredir)/gnotravex.4x4.scores
	-touch $(DESTDIR)$(scoredir)/gnotravex.5x5.scores
	-chown games.games $(DESTDIR)$(scoredir)/gnotravex.5x5.scores
	-chmod 664 $(DESTDIR)$(scoredir)/gnotravex.5x5.scores
	-touch $(DESTDIR)$(scoredir)/gnotravex.6x6.scores
	-chown games.games $(DESTDIR)$(scoredir)/gnotravex.6x6.scores
	-chmod 664 $(DESTDIR)$(scoredir)/gnotravex.6x6.scores
	-chgrp games $(DESTDIR)$(bindir)/gnotravex && chmod 2555 $(DESTDIR)$(bindir)/gnotravex
