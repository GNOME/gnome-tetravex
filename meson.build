project ('gnome-tetravex', ['vala', 'c'],
         version: '3.38.3',
         license: 'GPLv2+',
         default_options: [
             'warning_level=1',
             'buildtype=debugoptimized',
         ],
         meson_version: '>= 0.59.0')

project_id      = 'org.gnome.Tetravex'
cli_project_id  = 'org.gnome.TetravexCli'

# used to install help
if get_option('build_gui')
  gnome = import('gnome')
endif
# used for internationalization
i18n = import('i18n')

# Paths
mandir      = join_paths (get_option ('prefix'), get_option ('mandir'))
localedir   = join_paths (get_option ('prefix'), get_option ('localedir'))
datadir     = join_paths (get_option ('prefix'), get_option ('datadir'))
bindir      = join_paths (get_option ('prefix'), get_option ('bindir'))

# Dependencies
gio_dep     = dependency ('gio-2.0',    version: '>= 2.42.0')
glib_dep    = dependency ('glib-2.0',   version: '>= 2.42.0')
if get_option('build_gui')
  gtk_dep   = dependency ('gtk+-3.0',   version: '>= 3.22.23')
endif

if get_option('build_gui')
  appstreamcli          = find_program('appstreamcli',          required: false)
  desktop_file_validate = find_program('desktop-file-validate', required: false)
endif
glib_compile_schema     = find_program('glib-compile-schemas',  required: true) # useful?

cc = meson.get_compiler('c')
libm_dep = cc.find_library('m')

subdir ('po')
subdir ('data')
if get_option('build_gui')
  subdir ('help')
endif
subdir ('src')

gnome.post_install(
  gtk_update_icon_cache: true,
  update_desktop_database: true,
  glib_compile_schemas: true,
)
