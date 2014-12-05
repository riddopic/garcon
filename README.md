# Garcon

A collection of methods helpful in writing complex cookbooks that are
impossible to comprehend.

Hipster, hoodie ninja cool awesom.

## Requirements

### Cookbooks:

* chef_handler (~> 1.1.6)
* build-essential (>= 2.1.2)

## Attributes

Attribute | Default | Description | Choices
----------|---------|-------------|--------
`node[:garcon][:thread_pool][:min_pool_size]` | `"8"` |  |
`node[:garcon][:thread_pool][:max_pool_size]` | `"120"` |  |
`node[:garcon][:thread_pool][:max_queue_size]` | `"0"` |  |
`node[:garcon][:thread_pool][:idletime]` | `"120"` |  |
`node[:garcon][:thread_pool][:overflow_policy]` | `":abort"` |  |

## Recipes

* garcon::default

## Development and Testing

### Source Code

The [**chef-garcon**](https://github.com/riddopic/garcon.git)
is hosted on the Git.
To clone the project run

````bash
$ git clone https://github.com/riddopic/garcon.git
````

### Rake

Run `rake -T` to see all Rake tasks.

````
rake all                          # Run all tasks
rake doc                          # Build documentation
rake foodcritic                   # Lint Chef cookbooks
rake kitchen:all                  # Run all test instances
rake kitchen:default-centos-65    # Run default-centos-65 test instance
rake kitchen:default-ubuntu-1404  # Run default-ubuntu-1404 test instance
rake kitchen:default-w2k8r1-vbox  # Run Windows 2008 R1 test instance
rake kitchen:default-w2k8r2-vbox  # Run Windows 2008 R2 test instance
rake kitchen:default-w2k12r1-vbox # Run Windows 2012 R2 test instance
rake readme                       # Generate README.md from _README.md.erb
rake rubocop                      # Run RuboCop
rake rubocop:auto_correct         # Auto-correct RuboCop offenses
rake spec                         # Run RSpec code examples
rake test                         # Run kitchen integration tests
rake yard                         # Generate YARD Documentation
````

### Thor

Run `thor -T` to see all Thor tasks.

### Guard

Guard tasks have been separated into the following groups:

- `doc`
- `lint`
- `unit`
- `integration`

By default, Guard will generate documentation, lint, and run unit tests.
The integration group must be selected manually with `guard -g integration`.

## License

Copyright (C) 2014 Stefano Harding

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
