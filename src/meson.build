resources = gnome.compile_resources ('resources', 'gnome-tetravex.gresource.xml',
                                     source_dir: '.',
                                     c_name: 'resources')

sources = files (
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

gnome_tetravex = executable (
    'gnome-tetravex',
     sources + resources,
     dependencies: [ glib_dep,
                     gtk_dep,
                     libm_dep ],
     vala_args: [ '--pkg=posix',
                  '--enable-experimental-non-null' ],
     c_args: [ '-DVERSION="@0@"'.format (meson.project_version ()),
               '-DGETTEXT_PACKAGE="gnome-tetravex"',
               '-DLOCALEDIR="@0@"'.format (localedir) ],
     install: true
 )
