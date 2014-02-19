
class remctl::server (
    $debug              = $remctl::params::debug,
    $disable            = $remctl::params::disable,
    $krb5_service       = undef,
    $krb5_keytab        = $remctl::params::krb5_keytab,
    $port               = $remctl::params::port,
    $user               = 'root',
    $group              = 'root',
    $manage_user        = false,
    $manage_group       = false,
    $confdir            = $remctl::params::confdir,
    $conffile           = $remctl::params::conffile,
    $acldir             = $remctl::params::acldir,
    $server_bin         = $remctl::params::server_bin,
    $only_from          = [ '0.0.0.0' ]
) inherits remctl::params {

    require stdlib
    include xinetd
    include remctl

    validate_bool($debug)
    validate_bool($disable)
    validate_bool($manage_user)
    validate_bool($manage_group)
    validate_string($krb5_service)
    validate_string($krb5_keytab)
    validate_string($server_bin)
    validate_re($port, '^\d+$')
    validate_array($only_from)

    if $debug {
        $_debug = "-d "
    }
    else {
        $_debug = ""
    }

    if $krb5_service {
        $_krb5_service = "-s ${krb5_service} "
    }
    else {
        $_krb5_service = ""
    }

    if $conffile {
        $_conffile = "-f ${conffile}"
    }
    else {
        $_conffile = ""
    }

    if $only_from {
        $_only_from = join($only_from, " ")
    }
    else {
        $_only_from = undef
    }

    if $disable {
        $_disable = "yes"
    }
    else {
        $_disable = "no"
    }

    if $manage_group {
        if $group != "root" {
            group { $group:
                ensure      => present,
                notify      => User[$user]
            }
        }
    }

    if $manage_user {
        if $user != "root" {
            user { $user:
                ensure      => present,
                comment     => 'remctl user',
                gid         => $group,
                notify      => Package[$package_name]
            }
        }
    }

    file { $confdir:
        ensure      => directory,
        mode        => '0750',
        owner       => $user,
        group       => $group
    }

    ->

    file { $acldir:
        ensure      => directory,
        mode        => '0750',
        owner       => $user,
        group       => $group
    }

    ->

    file { $conffile:
        ensure      => file,
        content     => template("remctl/remctl.conf"),
        mode        => '0640',
        owner       => $user,
        group       => $group,
    }

    ->

    augeas { 'remctl_etc_services':
        context     => '/files/etc/services',
        changes     => [
            'set service-name[.="remctl"] remctl',
            "set service-name[.='remctl']/port $port",
            'set service-name[.="remctl"]/protocol tcp',
            'set service-name[.="remctl"]/#comment "remote authenticated command execution"'
        ]
    }

    ->

    xinetd::service { 'remctl':
        port        => $port, # Dupplicate with /etc/services info
        server      => $server_bin,
        server_args => "${_debug}${_krb5_service}${_conffile}",
        disable     => $_disable,
        protocol    => 'tcp',
        socket_type => 'stream',
        user        => $user,
        group       => $group,
        only_from   => $_only_from
    }
}
