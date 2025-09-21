gnome_tetravex = executable (
  meson.project_name(),
  resources + files(
    'config.vapi',
    'gnome-tetravex.vala',
    'history.vala',
    'puzzle.vala',
    'puzzle-view.vala',
    'rules-dialog.vala',
    'score-dialog.vala',
    'theme-extrusion.vala',
    'theme-neoretro.vala',
    'theme-nostalgia.vala',
    'theme-synesthesia.vala',
    'window.vala',
  ),
  dependencies: [
    gio_dep,
    glib_dep,
    gtk_dep,
    adwaita_dep,
    libm_dep,
  ],
  vala_args: [
    '--pkg=posix',
    '--enable-experimental-non-null'
  ],
  c_args: [
    '-DAPP_ID="@0@"'.format(app_id),
    '-DVERSION="@0@"'.format(meson.project_version()),
    '-DGETTEXT_PACKAGE="@0@"'.format(meson.project_name()),
    '-DLOCALEDIR="@0@"'.format(localedir),
    '-w'
  ],
  install: true
)
