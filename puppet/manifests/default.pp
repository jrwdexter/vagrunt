# Setup ruby and sass
class { 'ruby':
  gems_version => 'latest'
}

package { 'sass':
  provider => 'gem',
  require => Class['ruby']
}

package { 'hologram': 
  provider => 'gem',
  require => Class['ruby']
}

# Setup nodejs and grunt/bower
class { 'nodejs':
  version      => 'stable',
  make_install => false
}

package { 'grunt-cli':
  provider => npm,
  require => Class['nodejs']
}

package { 'bower':
  provider => npm,
  require => Class['nodejs']
}