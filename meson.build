project ('gnome-tetravex', ['vala', 'c'],
         version: '3.35.1',
         license: 'GPLv2+',
         default_options: [
             'warning_level=1',
             'buildtype=debugoptimized',
         ],
         meson_version: '>= 0.50.0')

project_id = 'org.gnome.Tetravex'

# used to install help
gnome = import('gnome')
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
gtk_dep     = dependency ('gtk+-3.0',   version: '>= 3.14')
# TODO build requires vala 0.46.3 for GLib vapi

appstream_util          = find_program('appstream-util',        required: false)
desktop_file_validate   = find_program('desktop-file-validate', required: false)
glib_compile_schema     = find_program('glib-compile-schemas',  required: true) # useful?

cc = meson.get_compiler('c')
libm_dep = cc.find_library('m')

subdir ('po')
subdir ('data')
subdir ('help')
subdir ('src')

meson.add_install_script('build-aux/meson_post_install.py')
