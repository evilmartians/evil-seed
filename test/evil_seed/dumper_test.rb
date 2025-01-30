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
        root.exclude(/\.reactions\b/)
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
      refute_match(/'Oops, I was wrong'/, result)
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

    def test_it_applies_unscoping_and_inclusions
      configuration = EvilSeed::Configuration.new
      configuration.root('Forum', name: 'Descendant forum') do |root|
        root.include(parent: {questions: :answers})
        root.exclude(/.\..+/)
      end
      configuration.unscoped = true

      io = StringIO.new
      EvilSeed::Dumper.new(configuration).call(io)
      result = io.string
      File.write(File.join('tmp', "#{__method__}.sql"), result)
      assert io.closed?
      assert_match(/'Descendant forum'/, result)
      assert_match(/'Oops, I was wrong'/, result)
    end

    def test_it_applies_custom_scopes
      configuration = EvilSeed::Configuration.new
      configuration.root('Forum', name: 'Descendant forum') do |root|
        root.include(parent: {questions: :answers })
        root.include(/\Aforum\.parent\.questions\.answers\.reactions\z/) do
          order(created_at: :desc).limit(2)
        end
        root.exclude(/.\..+/)
      end

      io = StringIO.new
      EvilSeed::Dumper.new(configuration).call(io)
      result = io.string
      File.write(File.join('tmp', "#{__method__}.sql"), result)
      assert io.closed?
      assert_match("':+1:'", result)
      assert_equal(2, result.scan("':+1:'").size)
    end

    def test_it_dumps_included_relations_for_already_loaded_records
      configuration = EvilSeed::Configuration.new
      configuration.root('Forum', name: 'One') do |forum|
        forum.exclude_has_relations
        forum.include(questions: :author) # but not answers
      end
      configuration.root('User', forum: Forum.where(name: 'One')) do |user|
        user.exclude_has_relations
        user.include(:profiles)
      end

      io = StringIO.new
      EvilSeed::Dumper.new(configuration).call(io)
      result = io.string
      File.write(File.join('tmp', "#{__method__}.sql"), result)
      assert io.closed?

      # Expect all profiles of forum One users to be loaded
      assert_match(/'Profile for user 0'/, result)
      refute_match(/'Profile for user 1'/, result)
      assert_match(/'Profile for user 2'/, result)
    end
  end
end
