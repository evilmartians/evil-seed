# frozen_string_literal: true

database_folder = "#{File.dirname(__FILE__)}/../db"
database_adapter = ENV['DB'] ||= 'postgresql'

def sqlite?
  ENV['DB'] == 'sqlite'
end

log = Logger.new('tmp/db.log')
log.sev_threshold = Logger::DEBUG
ActiveRecord::Base.logger = log
ActiveRecord::Migration.verbose = false

ActiveRecord::Base.configurations = YAML.safe_load(File.read("#{database_folder}/database.yml"), [], [], true)

config = ActiveRecord::Base.configurations[database_adapter]

begin
  case database_adapter
  when 'sqlite'
    ActiveRecord::Base.establish_connection(database_adapter.to_sym)
  when 'mysql'
    ActiveRecord::Base.establish_connection(config.merge('database' => nil))
    ActiveRecord::Base.connection.recreate_database(config['database'], charset: 'utf8', collation: 'utf8_unicode_ci')
  when 'postgresql'
    ActiveRecord::Base.establish_connection(config.merge('database' => 'postgres', 'schema_search_path' => 'public'))
    ActiveRecord::Base.connection.recreate_database(config['database'], config.merge('encoding' => 'utf8'))
  end
end

ActiveRecord::Base.establish_connection(config)

require "#{database_folder}/schema"
require "#{database_folder}/models"
