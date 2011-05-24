SUBDIRS = pixmaps

if BUILD_HELP
SUBDIRS += help
endif

NULL =

bin_PROGRAMS = gnotravex

gnotravex_SOURCES = \
	gnotravex.c \
	$(NULL)

gnotravex_CPPFLAGS = \
	-I$(top_srcdir) \
	$(AM_CPPFLAGS)

gnotravex_CFLAGS = \
	$(GTK_CFLAGS)	\
	$(AM_CFLAGS)

gnotravex_LDADD =	\
	$(top_builddir)/libgames-support/libgames-support.la \
	$(GTK_LIBS)	\
	$(INTLLIBS)	\
	$(NULL)

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

desktop_in_files = gnotravex.desktop.in.in
desktopdir = $(datadir)/applications
desktop_DATA = $(desktop_in_files:.desktop.in.in=.desktop)
@INTLTOOL_DESKTOP_RULE@

gsettings_in_file = org.gnome.gnotravex.gschema.xml.in
gsettings_SCHEMAS = $(gsettings_in_file:.xml.in=.xml)
@INTLTOOL_XML_NOMERGE_RULE@
@GSETTINGS_RULES@

man_MANS = gnotravex.6

EXTRA_DIST = \
	README \
	$(gsettings_in_file) \
	$(man_MANS) \
	$(NULL)

CLEANFILES = $(desktop_DATA) $(gsettings_SCHEMAS)
DISTCLEANFILES = $(desktop_DATA) $(gsettings_SCHEMAS)

SCOREFILES = 2 3 4 5 6

install-scorefiles-local:
	-$(mkinstalldirs) $(DESTDIR)$(scoredir)
	-for i in ${SCOREFILES} ; do \
	   touch $(DESTDIR)$(scoredir)/gnotravex."$$i"x"$$i".scores; \
	   chown $(scores_user):$(scores_group) $(DESTDIR)$(scoredir)/gnotravex."$$i"x"$$i".scores; \
	   chmod 664 $(DESTDIR)$(scoredir)/gnotravex."$$i"x"$$i".scores; \
	 done

install-exec-hook:
	-if test "$(setgid)" = "true"; then \
	  chgrp $(scores_group) $(DESTDIR)$(bindir)/gnotravex && chmod 2555 $(DESTDIR)$(bindir)/gnotravex ;\
	fi

install-data-local: install-scorefiles-local

-include $(top_srcdir)/git.mk
