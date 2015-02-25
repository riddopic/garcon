# encoding: utf-8

name             'garcon'
maintainer       'Stefano Harding'
maintainer_email 'riddopic@gmail.com'
license          'Apache 2.0'
description      'Collection of utility helpers and methods.'
long_description IO.read(File.join(File.dirname(__FILE__), 'README.md'))
version          '0.8.5'

depends 'chef_handler',    '>= 1.1.6'
depends 'build-essential', '>= 2.1.3'
depends 'yum',             '>= 3.5.1'
