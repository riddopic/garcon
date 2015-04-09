# encoding: utf-8

name             'garcon'
maintainer       'Stefano Harding'
maintainer_email 'riddopic@gmail.com'
license          'Apache 2.0'
description      'Collection of utility helpers and methods.'
long_description  IO.read(File.join(File.dirname(__FILE__), 'README.md'))
version           '1.1.1'

supports 'centos',      '>= 5.10'
supports 'oracle',      '>= 5.10'
supports 'redhat',      '>= 5.10'
supports 'scientific',  '>= 5.10'

depends 'chef_handler'
depends 'yum-epel'
depends 'yum'
