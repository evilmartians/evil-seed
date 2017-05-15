# frozen_string_literal: true

require 'test_helper'

class EvilSeedTest < Minitest::Test
  def setup
    EvilSeed.configure do |config|
      config.root('Forum', name: 'Descendant forum') do |root|
        root.exclude(/parent\.children/)
        root.exclude('forum.users')
        root.exclude(/parent\.users/)
        root.exclude(/role\..+/)
      end
      config.root('Question') do |root|
        root.exclude(/.*/)
      end
      config.root('Role') do |root|
        root.exclude(/\Arole\.(?!roles_users\z)/) # Take only join table and nothing more
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

  def test_it_dumps_and_restores
    io = StringIO.new
    EvilSeed.dump(io)
    result = io.string

    with_restored_db do
      execute_batch(result)
      assert Forum.find_by(name: 'Descendant forum')
      assert Forum.find_by(name: 'One')
      refute Forum.find_by(name: 'Two')
      assert User.find_by(login: 'johndoe')
      refute User.find_by(login: 'janedoe')
      assert User.find_by(login: 'alice')
      assert User.find_by(login: 'bob')
      refute User.find_by(login: 'charlie')
      assert Role.find_by(name: 'User')
      assert Role.find_by(name: 'Superadmin')
      assert Question.find_by(name: 'fourth')
      assert Question.find_by(name: 'fifth')
    end
  end
end
