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
	$(GNOMEUI_LIBS)					
#	$(INTLLIBS) 

pixmap_DATA = gnotravex.png

Games_DATA = gnotravex.desktop

EXTRA_DIST = README gnotravex.desktop $(pixmap_DATA)

install-data-local:
	-$(mkinstalldirs) $(scoredir)
	-touch $(scoredir)/gnotravex.2x2.scores
	-chown games.games $(scoredir)/gnotravex.2x2.scores
	-chmod 664 $(scoredir)/gnotravex.2x2.scores
	-touch $(scoredir)/gnotravex.3x3.scores
	-chown games.games $(scoredir)/gnotravex.3x3.scores
	-chmod 664 $(scoredir)/gnotravex.3x3.scores
	-touch $(scoredir)/gnotravex.4x4.scores
	-chown games.games $(scoredir)/gnotravex.4x4.scores
	-chmod 664 $(scoredir)/gnotravex.4x4.scores
	-touch $(scoredir)/gnotravex.5x5.scores
	-chown games.games $(scoredir)/gnotravex.5x5.scores
	-chmod 664 $(scoredir)/gnotravex.5x5.scores
	-touch $(scoredir)/gnotravex.6x6.scores
	-chown games.games $(scoredir)/gnotravex.6x6.scores
	-chmod 664 $(scoredir)/gnotravex.6x6.scores
	-chgrp games $(bindir)/gnotravex && chmod 2111 $(bindir)/gnotravex
