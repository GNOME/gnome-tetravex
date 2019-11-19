# https://gitlab.gnome.org/Infrastructure/damned-lies/issues/150
i18n.gettext('gnome-tetravex', preset: 'glib', install: false)

if get_option('build_gui')
  i18n.gettext ('gnome-tetravex-gui', preset: 'glib')
endif
if get_option('build_cli')
  i18n.gettext ('gnome-tetravex-cli', preset: 'glib')
endif

podir = meson.current_source_dir ()
