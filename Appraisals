appraise 'activerecord-4-2' do
  gem 'activerecord', '~> 4.2.0'

  platforms :mri do
    gem 'pg', '~> 0.20'
    gem 'mysql2', '~> 0.3.18'
  end

  platforms :jruby do
    gem 'activerecord-jdbcpostgresql-adapter', '~> 1.3.25'
    gem 'activerecord-jdbcmysql-adapter', '~> 1.3.25'
    gem 'activerecord-jdbcsqlite3-adapter', '~> 1.3.25'
  end
end

appraise 'activerecord-5-0' do
  gem 'activerecord', '~> 5.0.0'

  platforms :mri do
    gem 'pg', '~> 0.20'
    gem 'mysql2', '~> 0.4.4'
  end
end

appraise 'activerecord-5-1' do
  gem 'activerecord', '~> 5.1.0'

  platforms :mri do
    gem 'mysql2', '~> 0.4.4'
  end
end

appraise 'activerecord-5-2' do
  gem 'activerecord', '~> 5.2.0'

  platforms :mri do
    gem 'mysql2', '~> 0.4.4'
  end
end

appraise 'activerecord-master' do
  gem 'activerecord', git: 'https://github.com/rails/rails.git'
end
