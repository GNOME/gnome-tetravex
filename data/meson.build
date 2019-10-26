# Install icons
foreach size: [ '16x16', '22x22', '24x24', '32x32', '48x48']
    install_data (join_paths ('icons', 'hicolor', size, project_id + '.png'),
                  install_dir: join_paths (datadir, 'icons', 'hicolor', size, 'apps'))
endforeach
install_data (join_paths ('icons', 'hicolor', 'scalable', project_id + '.svg'),
              install_dir: join_paths (datadir, 'icons', 'hicolor', 'scalable', 'apps'))
install_data (join_paths ('icons', 'hicolor', 'scalable', project_id + '-symbolic.svg'),
              install_dir: join_paths (datadir, 'icons', 'hicolor', 'scalable', 'apps'))

# Install gschema
install_data (project_id + '.gschema.xml',
              install_dir: join_paths (datadir, 'glib-2.0', 'schemas'))

# Make D-Bus activatable
service_conf = configuration_data()
service_conf.set('bindir', bindir)

service = project_id + '.service'

configure_file(
  input: service + '.in',
  output: service,
  install: true,
  install_dir: join_paths(datadir, 'dbus-1', 'services'),
  configuration: service_conf
)

# Desktop file
desktop_file = i18n.merge_file ('desktop-file',
                 input: project_id + '.desktop.in',
                 output: project_id + '.desktop',
                 install: true,
                 install_dir: join_paths (datadir, 'applications'),
                 po_dir: '../po',
                 type: 'desktop')

# Validate desktop file
if desktop_file_validate.found()
  test(
    'validate-desktop',
    desktop_file_validate,
    args: [
      desktop_file.full_path()
    ]
  )
endif

# AppData file
appdata_file = i18n.merge_file ('appdata-file',
                 input: project_id + '.appdata.xml.in',
                 output: project_id + '.appdata.xml',
                 install: true,
                 install_dir: join_paths (datadir, 'metainfo'),
                 po_dir: '../po')

# Validate AppData file
if appstream_util.found()
  test(
    'validate-appdata', appstream_util,
    args: [
      'validate', '--nonet', appdata_file.full_path()
    ]
  )
endif

# Install man page
install_man ('gnome-tetravex.6')
