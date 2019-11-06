# CLI
if get_option('build_cli')
  cli_sources = files (
    'cli.vala',
    'config.vapi',
    'gnome-tetravex-cli.vala',
    'history.vala',
    'puzzle.vala'
  )

  gnome_tetravex_cli = executable (
    'gnome-tetravex-cli',
    cli_sources,
    dependencies: [ gio_dep,
                    glib_dep,
                    libm_dep ],
    vala_args: [ '--pkg=posix',
                 '--enable-experimental-non-null' ],
    c_args: [ '-DVERSION="@0@"'.format (meson.project_version ()),
              '-DGETTEXT_PACKAGE="gnome-tetravex-cli"',
              '-DLOCALEDIR="@0@"'.format (localedir) ],
    install: true
  )
endif

# GUI
if get_option('build_gui')
  gui_resources = gnome.compile_resources ('resources', 'gnome-tetravex.gresource.xml',
                                           source_dir: '.',
                                           c_name: 'resources')

  gui_sources = files (
    'cli.vala',
    'config.vapi',
    'gnome-tetravex.vala',
    'history.vala',
    'puzzle.vala',
    'puzzle-view.vala',
    'score-dialog.vala',
    'score-overlay.vala',
    'theme-extrusion.vala',
    'theme-neoretro.vala',
    'theme-nostalgia.vala',
    'theme-synesthesia.vala'
  )

  gnome_tetravex_gui = executable (
    'gnome-tetravex',
    gui_sources + gui_resources,
    dependencies: [ gio_dep,
                    glib_dep,
                    gtk_dep,
                    libm_dep ],
    vala_args: [ '--pkg=posix',
                 '--enable-experimental-non-null' ],
    c_args: [ '-DVERSION="@0@"'.format (meson.project_version ()),
              '-DGETTEXT_PACKAGE="gnome-tetravex"',
              '-DLOCALEDIR="@0@"'.format (localedir) ],
    install: true
  )
endif
