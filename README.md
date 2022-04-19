[![Gem Version](https://badge.fury.io/rb/evil-seed.svg)](https://rubygems.org/gems/evil-seed)
[![Build Status](https://travis-ci.org/evilmartians/evil-seed.svg?branch=master)](https://travis-ci.org/evilmartians/evil-seed)
[![Cult of Martians](http://cultofmartians.com/assets/badges/badge.svg)](http://cultofmartians.com/tasks/evil-seed.html)

# EvilSeed

EvilSeed is a tool for creating partial anonymized dump of your database based on your app models.

<a href="https://evilmartians.com/">
<img src="https://evilmartians.com/badges/sponsored-by-evil-martians.svg" alt="Sponsored by Evil Martians" width="236" height="54"></a>

## Motivation

Using production-like data in your staging environment could be very useful, especially for debugging intricate production bugs.

The easiest way to achieve this is to use production database backups. But that's not an option for rather large applications for two reasons: 

- production dump can be extremely large, and it just can't be dumped and restored in a reasonable time

- you should care about sensitive data (anonymization).

EvilSeed aims to solve these problems.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'evil-seed', require: false
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install evil-seed

## Usage

### Configuration

```ruby
require 'evil_seed'

EvilSeed.configure do |config|
  # First, you should specify +root models+ and their +constraints+ to limit the number of dumped records:
  # This is like Forum.where(featured: true).all
  config.root('Forum', featured: true) do |root|
    # It's possible to remove some associations from dumping with pattern of association path to exclude
    #
    # Association path is a dot-delimited string of association chain starting from model itself:
    # example: "forum.users.questions"
    root.exclude(/\btracking_pixels\b/, 'forum.popular_questions')

    # It's possible to limit the number of included into dump has_many and has_one records for every association
    # Note that belongs_to records for all not excluded associations are always dumped to keep referential integrity.
    root.limit_associations_size(100)

    # Or for certain association only
    root.limit_associations_size(10, 'forum.questions')
  end

  # Everything you can pass to +where+ method will work as constraints:
  config.root('User', 'created_at > ?', Time.current.beginning_of_day - 1.day)

  # For some system-wide models you may omit constraints to dump all records
  config.root("Role") do |root|
    # Exclude everything
    root.exclude(/.*/)
  end

  # Transformations allows you to change dumped data e. g. to hide sensitive information
  config.customize("User") do |u|
    # Reset password for all users to the same for ease of debugging on developer's machine
    u["encrypted_password"] = encrypt("qwerty")
    # Reset or mutate other attributes at your convenience
    u["metadata"].merge!("foo" => "bar")
    u["created_at"] = Time.current
    # Please note that there you have only hash of record attributes, not the record itself!
  end

  # Anonymization is a handy DSL for transformations allowing you to transform model attributes in declarative fashion
  # Please note that model setters will NOT be called: results of the blocks will be assigned to
  config.anonymize("User") do
    name  { Faker::Name.name }
    email { Faker::Internet.email }
    login { |login| "#{login}-test" }
  end
```

### Creating dump

Just call the `#dump` method and pass a path where you want your SQL dump file to appear!

```ruby
require 'evil_seed'
EvilSeed.dump('path/to/new_dump.sql')
```

### Caveats, tips, and tricks

 1. Specify `root`s for dictionaries and system-wide models like `Role` at the top without constraints and with all associations excluded.

 2. Use `exclude` aggressively. You will be amazed, how much your app's models graph is connected. This, in conjunction with the fact that this gem traverses associations in deep-first fashion, sometimes leads to unwanted results: some records will get into dump even if you don't want them.

 3. Look at the resulted dump: there are some useful debug comments.

## Database compatibility

This gem has been tested against:

 - PostgreSQL: any version that works with ActiveRecord should work
 - MySQL: any version that works with ActiveRecord should work
 - SQLite: 3.7.11 or newer is required (with support for inserting multiple rows at a time)


## FIXME (help wanted)

 1. `has_and_belongs_to_many` associations are traversed in a bit nonintuitive way for end user:

    Association path for `User.has_and_belongs_to_many :roles` is `user.users_roles.role`, but should be `user.roles`

 2. Test coverage is poor

 3. Some internal refactoring is required


## Standalone usage

If you want to use it as a standalone application, you can place exerything in a single file like this:

```ruby
#!/usr/bin/env ruby

require 'bundler/inline'

gemfile do
  source 'https://rubygems.org'
  gem 'activerecord'
  gem 'evil-seed'
  gem 'mysql2'
end

# Describe your database layout with ActiveRecord models.
# See http://guides.rubyonrails.org/active_record_basics.html

class Category < ActiveRecord::Base
  has_many :translations, class_name: "Category::Translation"
end

class Category::Translation < ActiveRecord::Base
  belongs_to :category, inverse_of: :translations
end

# Configure evil-seed itself
EvilSeed.configure do |config|
  config.root("Category", "id < ?", 1000)
end

# Connect to your database.
# See http://guides.rubyonrails.org/configuring.html#configuring-a-database)
ActiveRecord::Base.establish_connection(ENV.fetch("DATABASE_URL"))

# Create dump in dump.sql file in the same directory as this script
EvilSeed.dump(File.join(__dir__, "dump.sql").to_s)
```

And launch it like so:

```sh
DATABASE_URL=mysql2://user:pass@host/db ruby path/to/your/script.rb
```


## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake test` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).


## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/palkan/evil-seed.


## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).
