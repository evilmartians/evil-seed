# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

 - Options to exclude all `has_many` and `has_one` or optional `belongs_to` associations by default. [@Envek]

   ```ruby
   root.exclude_has_relations
   root.exclude_optional_belongs_to
   ```

   Excluded associations can be re-included by `include` with matching pattern.

 - Exclusion and inclusion patterns can be specified as hashes and/or arrays. [@Envek]

   ```ruby
   config.root('Forum', featured: true) do |forum|
     forum.include(parent: {questions: %i[answers votes]})
   end
   ```

   Which is equivalent to:

   ```ruby
   config.root('Forum', featured: true) do |forum|
     forum.include(/\Aforum(\.parent(\.questions(\.answers))?)?)?\z/)
     forum.include(/\Aforum(\.parent(\.questions(\.votes))?)?)?\z/)
   end
   ```

 - Print reason of association exclusion or inclusion in verbose mode. [@Envek]

 - Allow to apply custom scoping to included associations. [@Envek]

   ```ruby
   config.root('Forum', featured: true) do |forum|
     forum.include('questions.answers') do
       order(created_at: :desc)
     end
   end
   ```

### Fixed

 - Bug with null foreign key to back to auxiliary `has_one` association with not matching names. E.g. user has many profiles and has one default profile, profile belongs to user.
 - Ignored columns handling.

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
