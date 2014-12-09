# encoding: utf-8

name             'garcon'
maintainer       'Stefano Harding'
maintainer_email 'riddopic@gmail.com'
license          'Apache 2.0'
description      'Hipster, hoodie ninja cool awesom.'
long_description IO.read(File.join(File.dirname(__FILE__), 'README.md'))
version          '0.7.8'

# Cookbooks we depend on, always version lock!
depends 'chef_handler', '~> 1.1.6'
depends 'build-essential', '>= 2.1.2'
