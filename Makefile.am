scoredir=$(localstatedir)/games
pixmapdir=$(datadir)/pixmaps/gnotravex
Gamesdir=$(datadir)/gnome/apps/Games

INCLUDES = 			\
	-DGNOMELOCALEDIR=\""$(datadir)/locale"\" \
	-I$(includedir) $(GNOME_INCLUDEDIR)

bin_PROGRAMS = gnotravex

gnotravex_SOURCES =	\
	gnotravex.c

gnotravex_LDADD = \
	$(GNOME_LIBDIR)	\
	$(GNOMEUI_LIBS)	\
	$(INTLLIBS) 

pixmap_DATA = gnotravex.png gnome-gnotravex.png

Games_DATA = gnotravex.desktop

EXTRA_DIST = README gnotravex.desktop $(pixmap_DATA)

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
	-chgrp games $(DESTDIR)$(bindir)/gnotravex && chmod 2111 $(DESTDIR)$(bindir)/gnotravex
