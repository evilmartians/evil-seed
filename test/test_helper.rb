# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)
require 'evil_seed'

require 'minitest/autorun'

require_relative 'support/database.rb'

puts "Using #{database}"

# Temporarily reconnects whole ActiveRecord to DB for testing dump restoration
def with_restored_db
  original_connection = ActiveRecord::Base.remove_connection
  ActiveRecord::Base.establish_connection(restored_database_config)
  yield
ensure
  ActiveRecord::Base.establish_connection(original_connection)
end

# Helper method to execute +sql+ with multiple statements in it (there are caveats)
# @param sql [String]
def execute_batch(sql)
  connection = ActiveRecord::Base.connection
  case database
  when 'sqlite'
    connection.raw_connection.execute_batch(sql)
  when 'mysql'
    connection.execute(sql)
    # Hack for MySQL2
    connection.raw_connection.store_result while connection.raw_connection.next_result
  else
    connection.execute(sql)
  end
end
