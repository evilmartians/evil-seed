# frozen_string_literal: true

require 'test_helper'

module EvilSeed
  class RecordDumperTest < Minitest::Test
    class RelationDumperStub
      def loaded_map
        @loaded_map ||= Hash.new { |h, k| h[k] = Set.new }
      end

      def association_path
        'does not matter anymore'
      end
    end

    def setup
      @relation_dumper = RelationDumperStub.new
      @configuration = EvilSeed::Configuration.new
      @configuration.customize('User') do |attributes|
        attributes['password'] = '12345678'
      end
      @configuration.anonymize('User') do
        email { 'user@example.com' }
        login { |login| login+'-test' }
      end
    end

    def test_it_dumps_provided_records
      rd = RecordDumper.new(User, @configuration, @relation_dumper)
      rd.call('id' => 1, 'login' => 'randall',  'password' => 'correcthorsebatterystaple', 'email' => 'xkcd@xkcd.com')
      rd.call('id' => 2, 'login' => 'jcdenton', 'password' => 'amihuman', 'email' => 'jcd@daedalus.net')
      result = rd.result.tap(&:rewind).read
      assert_match(/'randall-test'/,  result)
      assert_match(/'jcdenton-test'/, result)
    end

    def test_it_does_not_dump_already_dumped_records
      rd = RecordDumper.new(User, @configuration, @relation_dumper)
      rd.call('id' => 1, 'login' => 'randall',  'password' => 'correcthorsebatterystaple', 'email' => 'xkcd@xkcd.com')
      rd.call('id' => 1, 'login' => 'randall',  'password' => 'correcthorsebatterystaple', 'email' => 'xkcd@xkcd.com')
      assert_equal 1, rd.result.tap(&:rewind).read.scan('randall').size
    end

    def test_it_applies_transformations
      rd = RecordDumper.new(User, @configuration, @relation_dumper)
      rd.call('id' => 2, 'login' => 'jcdenton', 'password' => 'amihuman', 'email' => 'jcd@daedalus.net')
      result = rd.result.tap(&:rewind).read
      refute_match(/'jcdenton'/, result)
      assert_match(/'jcdenton-test'/, result)
      refute_match(/'amihuman'/, result)
      assert_match(/'12345678'/, result)
      refute_match(/'jcd@daedalus.net'/, result)
      assert_match(/'user@example.com'/, result)
    end
  end
end
