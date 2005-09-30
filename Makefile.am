sharedpixmapdir = $(datadir)/pixmaps
Gamesdir = $(datadir)/applications

schemadir   = @GCONF_SCHEMA_FILE_DIR@
schema_in_files = gnotravex.schemas.in
schema_DATA = $(schema_in_files:.schemas.in=.schemas)
@INTLTOOL_SCHEMAS_RULE@

INCLUDES = 			\
	-I$(top_srcdir)/libgames-support \
	$(GNOME_GAMES_CFLAGS)	\
	-DGNOMELOCALEDIR=\""$(datadir)/locale"\" \
	-DDATADIR=\""$(datadir)"\"

bin_PROGRAMS = gnotravex

gnotravex_SOURCES =	\
	gnotravex.c

gnotravex_LDADD = \
	../libgames-support/libgames-support.la \
	$(GNOME_GAMES_LIBS) \
	$(INTLLIBS) 

sharedpixmap_DATA = gnome-gnotravex.png

Games_in_files = gnotravex.desktop.in
Games_DATA = $(Games_in_files:.desktop.in=.desktop)
@INTLTOOL_DESKTOP_RULE@

EXTRA_DIST = README \
	gnotravex.desktop.in \
	$(sharedpixmap_DATA) \
	$(schema_in_files)

DISTCLEANFILES = $(Games_DATA) $(schema_DATA)

SUBDIRS = help

SCOREFILES = 2 3 4 5 6

install-data-local:
if GCONF_SCHEMAS_INSTALL
	GCONF_CONFIG_SOURCE=$(GCONF_SCHEMA_CONFIG_SOURCE) $(GCONFTOOL) --makefile-install-rule $(top_builddir)/gnotravex/$(schema_DATA)
endif
	-$(mkinstalldirs) $(DESTDIR)$(scoredir)
	-for i in ${SCOREFILES} ; do \
	   touch $(DESTDIR)$(scoredir)/gnotravex."$$i"x"$$i".scores; \
	   chown $(scores_user):$(scores_group) $(DESTDIR)$(scoredir)/gnotravex."$$i"x"$$i".scores; \
	   chmod 664 $(DESTDIR)$(scoredir)/gnotravex."$$i"x"$$i".scores; \
	 done
	-if test "x$(setgid)" = "xtrue"; then chgrp $(scores_group) $(DESTDIR)$(bindir)/gnotravex && chmod 2555 $(DESTDIR)$(bindir)/gnotravex ; fi
