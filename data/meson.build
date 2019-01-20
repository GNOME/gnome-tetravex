foreach size: [ '16x16', '22x22', '24x24', '32x32', '48x48']
    install_data (join_paths ('icons', 'hicolor', size, project_id + '.png'),
                  install_dir: join_paths (datadir, 'icons', 'hicolor', size, 'apps'))
endforeach
install_data (join_paths ('icons', 'hicolor', 'scalable', project_id + '.svg'),
              install_dir: join_paths (datadir, 'icons', 'hicolor', 'scalable', 'apps'))
install_data (join_paths ('icons', 'hicolor', 'scalable', project_id + '-symbolic.svg'),
              install_dir: join_paths (datadir, 'icons', 'hicolor', 'scalable', 'apps'))

install_data (project_id + '.gschema.xml',
              install_dir: join_paths (datadir, 'glib-2.0', 'schemas'))


i18n.merge_file ('desktop-file',
                 input: project_id + '.desktop.in',
                 output: project_id + '.desktop',
                 install: true,
                 install_dir: join_paths (datadir, 'applications'),
                 po_dir: '../po',
                 type: 'desktop')

i18n.merge_file ('appdata-file',
                 input: project_id + '.appdata.xml.in',
                 output: project_id + '.appdata.xml',
                 install: true,
                 install_dir: join_paths (datadir, 'metainfo'),
                 po_dir: '../po')

install_man ('gnome-tetravex.6')
