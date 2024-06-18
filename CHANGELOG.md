# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.6.0] - 2024-06-18

### Added

 - Association inclusion option. [@gazay] ([#13](https://github.com/evilmartians/evil-seed/pull/13))
 - Option to limit association depth. [@gazay] ([#13](https://github.com/evilmartians/evil-seed/pull/13))
 - Option to ignore `default_scope` in models. [@gazay] ([#13](https://github.com/evilmartians/evil-seed/pull/13))
 - Option to disable nullifying of foreign keys. [@gazay] ([#13](https://github.com/evilmartians/evil-seed/pull/13))

## [0.5.0] - 2023-02-16

### Added

 - Option to ignore columns from a given model. [@nhocki] ([#17](https://github.com/evilmartians/evil-seed/pull/17))

## [0.4.0] - 2022-12-07

### Fixed

 - Ignore generated database columns. [@cmer] ([#16](https://github.com/evilmartians/evil-seed/pull/16))

## [0.3.0] - 2022-03-14

### Added

 - Passing attribute value to anonymizer block (to partially modify it). [@Envek]

## [0.2.0] - 2022-03-10

### Fixed

 - Ignore virtual ActiveRecord attributes. [@Envek]

### Removed

 - Support for ActiveRecord 4.2

## [0.1.3] - 2021-09-02

### Fixed

 - Compatibility with Ruby 3.0 and ActiveRecord 6.x.

## [0.1.2] - 2018-03-27

### Fixed

 - Bug with unwanted pseudo columns in dump when dumping HABTM join table without one side.

## [0.1.1] - 2017-05-15

### Fixed

 - ActiveRecord 4.2 support by backporting of `ActiveRecord::Relation#in_batches`
 - Dumping of the whole model without constraints

## [0.1.0] - 2017-05-09

Initial release. [@palkan], [@Envek]

[@Envek]: https://github.com/Envek "Andrey Novikov"
[@palkan]: https://github.com/palkan "Vladimir Dementyev"
[@cmer]: https://github.com/cmer "Carl Mercier"
[@nhocki]: https://github.com/nhocki "Nicolás Hock-Isaza"
[@gazay]: https://github.com/gazay "Alex Gaziev"
