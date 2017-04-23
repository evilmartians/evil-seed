# frozen_string_literal: true

require 'test_helper'

class EvilSeedTest < Minitest::Test
  def setup
    EvilSeed.configure do |config|
      config.root('User', 'created_at > ?', Time.current - 1.day) do |root|
        root.exclude(/.*/)
      end
    end
  end

  def test_that_it_has_a_version_number
    refute_nil ::EvilSeed::VERSION
  end

  def test_it_dumps_something_into_file
    file = Tempfile.new([__method__.to_s, '.sql'])
    EvilSeed.dump(file.path)
    result = File.read(file.path)
    assert_match 'INSERT INTO', result
    assert_match "'johndoe'",   result
  end

  def test_it_dumps_something_into_io
    io = StringIO.new
    EvilSeed.dump(io)
    result = io.string
    assert_match 'INSERT INTO', result
    assert_match "'johndoe'",   result
  end
end
