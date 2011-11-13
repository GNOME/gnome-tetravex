SUBDIRS = pixmaps

if BUILD_HELP
SUBDIRS += help
endif

EXTRA_DIST = \
	README

SCOREFILES = 2 3 4 5 6

install-scorefiles-local:
	-$(mkinstalldirs) $(DESTDIR)$(scoredir)
	-for i in ${SCOREFILES} ; do \
	   touch $(DESTDIR)$(scoredir)/gnotravex."$$i"x"$$i".scores; \
	   chown $(scores_user):$(scores_group) $(DESTDIR)$(scoredir)/gnotravex."$$i"x"$$i".scores; \
	   chmod 664 $(DESTDIR)$(scoredir)/gnotravex."$$i"x"$$i".scores; \
	 done

install-data-local: install-scorefiles-local

-include $(top_srcdir)/git.mk
