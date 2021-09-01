# frozen_string_literal: true

require_relative '../db/schema'
require 'erb'

def database
  ENV['DB'] ||= 'postgresql'
end

log = Logger.new('tmp/db.log')
log.sev_threshold = Logger::DEBUG
ActiveRecord::Base.logger = log
ActiveRecord::Migration.verbose = false

database_yml_path = File.expand_path(File.join(File.dirname(__FILE__), '..', 'db', 'database.yml'))
ActiveRecord::Base.configurations = YAML.safe_load(ERB.new(File.read(database_yml_path)).result, [], [], true)

def database_config
  if ActiveRecord.version >= Gem::Version.new("6.1") # See https://github.com/rails/rails/pull/38256
    ActiveRecord::Base.configurations.configs_for(env_name: database).first.configuration_hash.stringify_keys
  else
    ActiveRecord::Base.configurations[database].stringify_keys
  end
end

def restored_database_config
  database_config.merge('database' => "#{database_config['database']}_restored")
end

def create_database_and_schema!(config)
  case database
  when 'sqlite'
    File.unlink(config['database']) if config['database'] != ':memory:' && File.exist?(config['database'])
    ActiveRecord::Base.establish_connection(database.to_sym)
  when 'mysql'
    ActiveRecord::Base.establish_connection(config.merge('database' => nil))
    ActiveRecord::Base.connection.recreate_database(config['database'], charset: 'utf8', collation: 'utf8_unicode_ci')
  when 'postgresql'
    ActiveRecord::Base.establish_connection(config.merge('database' => 'postgres', 'schema_search_path' => 'public'))
    ActiveRecord::Base.connection.recreate_database(config['database'], config.merge('encoding' => 'utf8'))
  end
  ActiveRecord::Base.establish_connection(config)
  create_schema!
  ActiveRecord::Base.connection.disconnect!
end

create_database_and_schema!(restored_database_config)
create_database_and_schema!(database_config)
ActiveRecord::Base.establish_connection(database_config)

require_relative '../db/models'
require_relative '../db/seeds'
