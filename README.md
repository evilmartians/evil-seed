# Evil::Seed

Welcome to your new gem! In this directory, you'll find the files you need to be able to package up your Ruby library into a gem. Put your Ruby code in the file `lib/evil/seed`. To experiment with that code, run `bin/console` for an interactive prompt.

TODO: Delete this and the text above, and describe your gem

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
  # First, you should specify +root models+ and constraints to limit the dumping quantity:
  # This is like Forum.where(featured: true).all
  config.root('Forum', featured: true) do |r|
    # It's possible to remove some associations from dumping with pattern of association path to exclude
    #
    # Association path is a dot-delimited string of association chain starting from model itself:
    # example: "forum.users.questions"
    r.exclude(/\btracking_pixels\b/, 'forum.popular_questions')

    # It's possible to limit number of associated records to be included into dump for all associations
    r.limit_associations_size(100)

    # Or for certain association only
    r.limit_associations_size(10, 'forum.questions')
  end

  config.root("Role") do |r|
    # Exclude everything
    r.exclude(/.*/)
  end
```

### Making dump

Just call `dump` method!

```ruby
EvilSeed.dump('path/to/new_dump.sql')
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake test` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/palkan/evil-seed.


## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).
