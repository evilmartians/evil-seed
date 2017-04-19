# frozen_string_literal: true

require 'test_helper'

module EvilSeed
  class DumperTest < Minitest::Test
    def test_it_dumps_tree_structures_with_foreign_keys
      configuration = EvilSeed::Configuration.dup
      configuration.root('Forum', name: 'Descendant forum') do |root|
        root.exclude(/parent.children/)
      end
      dumper = EvilSeed::Dumper.new(configuration)
      io = StringIO.new
      dumper.call(io)
      result = io.string
      File.write(File.join('tmp', "#{__method__}.sql"), result)
      assert io.closed?
      assert_match(/'Descendant forum'/, result)
      assert_match(/'One'/, result)
      refute_match(/'Two'/, result)
      assert_match(/'johndoe'/, result)
      refute_match(/'janedoe'/, result)
      assert result.index(/'One'/) < result.index(/'Descendant forum'/)
    end
  end
end
