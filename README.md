# EvilSeed

Gem for creating partial anonymized dumps of your database using your app model relations.

<a href="https://evilmartians.com/">
<img src="https://evilmartians.com/badges/sponsored-by-evil-martians.svg" alt="Sponsored by Evil Martians" width="236" height="54"></a>

It pretends to be very useful in case of debugging intricate production bug when you absolutely need the production data to investigate it and create a fix.

Because production database can be extremely large and it just can't be dumped and restored in reasonable time.

And because sometimes you don't have a right to even see production data because of sensitive information in it (personal data and etc).

So, all you need to debug is “all orders for today with names of created them guys being replaced with anything”.

EvilSeed aims to make such dumps for you.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'evil-seed'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install evil-seed

## Usage

### Configuration

```ruby
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
  config.customize("User") do |user_attributes|
    # Reset password for all users to the same for ease of debugging on developer's machine
    u["encrypted_password"] = encrypt("qwerty")
    u["created_at"]         =
    # Please note that there you have only hash of record attributes, not the record itself!
  end

  # Anonymization is a handy DSL for transformations allowing you to transform model attributes in declarative fashion
  # Please note that model setters will NOT be called: results of the blocks will be assigned to
  config.anonymize("User")
    name  { Faker::Name.name }
    email { Faker::Internet.email }
  end
```

### Creating dump

Just call `dump` method with path where you want SQL dump file to appear!

```ruby
EvilSeed.dump('path/to/new_dump.sql')
```

### Caveats, tips, and tricks

 1. Specify `root`s for any dictionaries and system-wide models like `Role` at the top without constraints and with all associations excluded. Most probably you want all dictionaries to be present but don't want to see all the records referencing them.

 2. Use method `exclude` aggressively. You will be amazed, how much your app's model association graph is connected. This, in conjuction with the fact that this gem traverses associations in deep-first fashion, sometimes will lead to unwanted results: some records will get into dump even if you don't want them.

 3. Look at resulted dump: there is debug comments with traversed association path. They will help you to understand which associations should be excluded.

## Database compatibility

This gem works with and tested against:

 - PostgreSQL: any version that works with ActiveRecord should work
 - MySQL: any version that works with ActiveRecord should work
 - SQLite: 3.7.11 or newer is required (with support of inserting multiple rows at a time)


## FIXME (help wanted)

 1. `has_and_belongs_to_many` associations are traversed in a bit nonintuitive way for end user:

    Association path for `User.has_and_belongs_to_many :roles` is `user.users_roles.role`, but should be `user.roles`

 2. Test coverage is poor

 3. Some internal refactoring is required


## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake test` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).


## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/palkan/evil-seed.


## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).
