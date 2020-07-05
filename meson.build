project ('gnome-tetravex', ['vala', 'c'],
         version: '3.36.4',
         license: 'GPLv2+',
         default_options: [
             'warning_level=1',
             'buildtype=debugoptimized',
         ],
         meson_version: '>= 0.50.0')

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
# TODO build requires vala 0.46.3 for GLib vapi

if get_option('build_gui')
  appstream_util        = find_program('appstream-util',        required: false)
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

meson.add_install_script('build-aux/meson_post_install.py')
