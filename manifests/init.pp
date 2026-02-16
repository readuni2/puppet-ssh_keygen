# ssh_keygen
#
# @summary Generate ssh keys for a user resource using ssh_keygen.
#
# @example Generate ssh keys for any user using ssh_keygen. The user must exist before using the module
#  ssh_keygen { 'john': }
#
# @example If not using the default `/home/john`
#  ssh_keygen { 'john':
#    home => '/var/home'
#  }
#
# @example The key comment can also be overriden with
#  ssh_keygen { 'john':
#    comment => 'john key'
#  }

# @example Generate a dsa key
#  ssh_keygen { 'john':
#    type => 'dsa'
#  }
#
# @example specify the bit length
#  ssh_keygen { 'john':
#    bits => 4096
#  }
#
# @example Generate new host key
#  ssh_keygen { 'root':
#    filename => '/etc/ssh/ssh_host_rsa_key'
#  }
#
# @param user Username to create key for
# @param type Type of key to create
# @param bits Number of bits in key
# @param home Home directory for user
# @param filename Key filename
# @param comment Key comment
# @param options Additional options to pass on to ssh-keygen
# @param from_master Store key on master server
# @param master_dir Subdirectory of /etc/puppetlabs (/etc/puppet) on server
# @param group Group used for keys on master server 
# @param host_name Hostname used in in comment if is not specified (defaults to fqdn) 
define ssh_keygen (
  Optional[String] $user     = undef,
  Optional[String] $group    = undef,
  Enum['rsa', 'dsa', 'ecdsa', 'ed25519', 'rsa1'] $type   = 'rsa',
  Boolean           $from_master = false,
  String            $master_dir  = 'ssh',
  String            $host_name   = $facts['networking']['fqdn'],
  Optional[Integer] $bits        = 2048,
  Optional[Stdlib::Absolutepath] $home     = undef,
  Optional[Stdlib::Absolutepath] $filename = undef,
  Optional[String] $comment  = undef,
  Optional[Array[String]] $options  = undef,
) {

  Exec { path => '/bin:/usr/bin' }

  $_user = $user ? {
    undef   => $name,
    default => $user,
  }

  $_group = $group ? {
    undef   => $user,
    default => $group,
  }

  $_home = $home ? {
    undef   => $_user ? {
      'root'  => "/${_user}",
      default => "/home/${_user}",
    },
    default => $home,
  }

  $_filename = $filename ? {
    undef   => "${_home}/.ssh/id_${type}",
    default => $filename,
  }

  if  $from_master {
    $_comment = $comment ? {
      undef   => "${_user}@${host_name}",
      default => $comment,
    }

    # Generate RSA keys reliably
    $key_priv = ssh_keygen({
      name => $name,
      type => $type,
      size => $bits,
      comment => $_comment,
      dir => $master_dir,
      public => false
      }) 
    $key_pub  = ssh_keygen({
      name => $name,
      type => $type,
      size => $bits,
      comment => $_comment,
      dir => $master_dir,
      public => true
      }) 

    file { $_filename:
      owner   => $_user,
      group   => $_group,
      mode    => '0600',
      content => $key_priv,
    }

    file { "${_filename}.pub":
      owner   => $_user,
      group   => $_group,
      mode    => '0644',
      content => $key_pub,
    }
  } else {
    $type_opt = shell_join(['-t', $type])

    $bits_opt = $bits ? {
      undef   => undef,
      default => shell_join(['-b', $bits])
    }

    $filename_opt = shell_join(['-f', $_filename])
    $passphrase_opt = shell_join(['-N', ''])

    $comment_opt = $comment ? {
      undef   => undef,
      default => shell_join(['-C', $comment])
    }
  
    $options_opt = $options ? {
      undef   => undef,
      default => shell_join($options),
    }

    $command = delete_undef_values([
      'ssh-keygen',
      $type_opt,
      $bits_opt,
      $filename_opt,
      $passphrase_opt,
      $comment_opt,
      $options_opt,
    ])

    exec { "ssh_keygen-${name}":
      command => join($command, ' '),
      user    => $_user,
      creates => $_filename,
    }
  }
}
