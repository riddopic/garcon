# Garcon

A collection of methods helpful in writing complex cookbooks that are
impossible to comprehend.

Hipster, hoodie ninja cool awesome.

## Requirements

### Cookbooks:

* chef_handler (~> 1.1.6)
* build-essential (>= 2.1.2)

## Attributes

Attribute | Default | Description | Choices
----------|---------|-------------|--------

## Recipes

* garcon::default

## Development and Testing

### Source Code

### Rake

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
