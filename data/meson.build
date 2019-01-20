foreach size: [ '16x16', '22x22', '24x24', '32x32', '48x48']
    install_data (join_paths ('icons', 'hicolor', size, '@0@.png'.format(project_id)),
                  install_dir: join_paths (datadir, 'icons', 'hicolor', size, 'apps'))
endforeach
install_data (join_paths ('icons', 'hicolor', 'scalable', '@0@.svg'.format(project_id)),
              install_dir: join_paths (datadir, 'icons', 'hicolor', 'scalable', 'apps'))
install_data (join_paths ('icons', 'hicolor', 'scalable', '@0@-symbolic.svg'.format(project_id)),
              install_dir: join_paths (datadir, 'icons', 'hicolor', 'scalable', 'apps'))

install_data ('@0@.gschema.xml'.format(project_id),
              install_dir: join_paths (datadir, 'glib-2.0', 'schemas'))
meson.add_install_script ('meson_compile_gschema.py')

i18n.merge_file ('desktop-file',
                 input: '@0@.desktop.in'.format(project_id),
                 output: '@0@.desktop'.format(project_id),
                 install: true,
                 install_dir: join_paths (datadir, 'applications'),
                 po_dir: '../po',
                 type: 'desktop')

i18n.merge_file ('appdata-file',
                 input: '@0@.appdata.xml.in'.format(project_id),
                 output: '@0@.appdata.xml'.format(project_id),
                 install: true,
                 install_dir: join_paths (datadir, 'metainfo'),
                 po_dir: '../po')

install_man ('gnome-tetravex.6')
