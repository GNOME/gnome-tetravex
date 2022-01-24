# Install icons
if get_option('build_gui')
  install_data (join_paths ('icons', 'hicolor', 'scalable', project_id + '.svg'),
                install_dir: join_paths (datadir, 'icons', 'hicolor', 'scalable', 'apps'))
  install_data (join_paths ('icons', 'hicolor', 'symbolic', project_id + '-symbolic.svg'),
                install_dir: join_paths (datadir, 'icons', 'hicolor', 'scalable', 'apps'))
endif

# Install gschema
if get_option('build_gui')
  install_data (project_id + '.gschema.xml',
                install_dir: join_paths (datadir, 'glib-2.0', 'schemas'))
endif
if get_option('build_cli')
  install_data (cli_project_id + '.gschema.xml',
                install_dir: join_paths (datadir, 'glib-2.0', 'schemas'))
endif

# Make D-Bus activatable
if get_option('build_gui')
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
endif

# Desktop file
if get_option('build_gui')
  desktop_file = i18n.merge_file (
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
endif

# AppData file
if get_option('build_gui')
  appdata_file = i18n.merge_file (
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
endif

# Install man pages
if get_option('build_gui')
  install_man('gnome-tetravex.6')
endif
if get_option('build_cli')
  install_man('gnome-tetravex-cli.6')
endif
