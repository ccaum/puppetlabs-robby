class robby (
  $deploy_key,
  $revision = undef,
  $robby_path  = '/opt/robby',
  $robby_home_directory = undef,
  $run_as_user = 'robby',
  $environment = 'production',
) {

  $application_root = "${robby_path}/src"

  if $environment == 'development' {
    $bundler_require = Class['robby::packages','robby::ruby']
    $unicorn_require = [Class['ruby::dev','robby::ruby','robby::user'], Bundler::Install[$application_root]]
  } else {
    $bundler_require = [Class['robby::packages','robby::ruby'], Vcsrepo[$robby_path]]
    $unicorn_require = [Class['ruby::dev','robby::ruby','robby::user'], Vcsrepo[$robby_path], Bundler::Install[$application_root]]

    file { $robby_path:
      ensure  => directory,
      owner   => 'robby',
      group   => 'robby',
      mode    => 0755,
      require => Class['robby::user'],
    }

    vcsrepo { $robby_path:
      ensure   => present,
      provider => git,
      source   => 'git@github.com:puppetlabs/OfficeMap',
      revision => $revision,
      user     => 'robby',
      require  => [File[$robby_path],Class['robby::user']],
    }
  }

  class { 'robby::user':
    ssh_key        => $deploy_key,
    home_directory => $robby_home_directory,
  }

  class { 'robby::ruby': }

  class { 'robby::packages':
    require => Class['robby::ruby'],
  }

  bundler::install { $application_root:
    require => $bundler_require,
  }

  unicorn::app { 'robby':
    approot     => $application_root,
    pidfile     => "${application_root}/unicorn.pid",
    socket      => "${application_root}/unicorn.sock",
    user        => $run_as_user,
    group       => $run_as_user,
    preload_app => true,
    rack_env    => 'production',
    source      => 'bundler',
    require     => $unicorn_require,
  }
}
