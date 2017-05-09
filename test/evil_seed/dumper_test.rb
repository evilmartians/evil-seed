# frozen_string_literal: true

require 'test_helper'

module EvilSeed
  class DumperTest < Minitest::Test
    def test_it_dumps_tree_structures_with_foreign_keys
      configuration = EvilSeed::Configuration.new
      configuration.root('Forum', name: 'Descendant forum') do |root|
        root.exclude(/parent\.children/)
        root.exclude('forum.users')
        root.exclude(/parent\.users/)
        root.exclude(/role\..+/)
      end
      configuration.customize('User') do |attributes|
        attributes['password'] = '12345678'
      end
      configuration.anonymize('User') do
        email { 'user@example.com' }
      end
      io = StringIO.new
      EvilSeed::Dumper.new(configuration).call(io)
      result = io.string
      File.write(File.join('tmp', "#{__method__}.sql"), result)
      assert io.closed?
      assert_match(/'Descendant forum'/, result)
      assert_match(/'One'/, result)
      refute_match(/'Two'/, result)
      assert_match(/'johndoe'/, result)
      refute_match(/'janedoe'/, result)
      assert_match(/'alice'/, result)
      assert_match(/'bob'/, result)
      refute_match(/'charlie'/, result)
      assert_match(/'User'/, result)
      assert_match(/'Nobody'/, result)
      refute_match(/'Superadmin'/, result)
      refute_match(/'UFO'/, result)
      assert_match(/'12345678'/, result)
      refute_match(/'realhash'/, result)
      assert_match(/'user@example.com'/, result)
      refute_match(/'alice@yahoo.com'/, result)
      assert_match(/'fourth'/, result)
      assert_match(/'fifth'/, result)
      assert result.index(/'One'/) < result.index(/'Descendant forum'/)
    end

    def test_limits_being_applied
      configuration = EvilSeed::Configuration.new
      configuration.root('Forum', name: 'One') do |root|
        root.exclude('forum.children')
        root.exclude('forum.users')
        root.exclude(/forum\.\w*question.answers/)
        root.limit_associations_size(5, /forum\.\w*questions/)
      end
      io = StringIO.new
      EvilSeed::Dumper.new(configuration).call(io)
      result = io.string
      File.write(File.join('tmp', "#{__method__}.sql"), result)
      assert_match(/'fourth'/, result)
      refute_match(/'fifth'/, result)
    end
  end
end
