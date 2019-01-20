project ('gnome-tetravex', ['vala', 'c'],
         version: '3.31.3',
         license: 'GPLv2+',
         default_options: [
             'warning_level=1',
             'buildtype=debugoptimized',
         ],
         meson_version: '>= 0.37.1')

project_id = 'org.gnome.Tetravex'

gnome = import ('gnome')
i18n = import ('i18n')

# Paths
mandir = join_paths (get_option ('prefix'), get_option ('mandir'))
localedir = join_paths (get_option ('prefix'), get_option ('localedir'))
datadir = join_paths (get_option ('prefix'), get_option ('datadir'))

# Dependencies
glib_dep = dependency ('glib-2.0', version: '>= 2.40.0')
gtk_dep = dependency ('gtk+-3.0', version: '>= 3.14')

subdir ('po')
subdir ('data')
subdir ('help')
subdir ('src')
