require_relative File.join('lib', 'gem')

def load_from_file(*args)
  original_file = File.expand_path(File.join('..', 'templates', *args), __FILE__)
  File.read(original_file)
end

def copy_from_file(*args)
  create_file File.join(*args), load_from_file(*args)
end

# Gems I use

# For managing ENV variables
gem 'dotenv-rails', groups: %i(development test)

gem 'slim-rails'

gem_group :development, :test do
  gem 'rspec-rails'
  gem 'pry-byebug'
  gem 'pry-stack_explorer'
  gem 'rubocop'
  gem 'rubocop-rspec'
  gem 'slim_lint'
  gem 'simplecov'
  gem 'simplecov-console'
  gem 'awesome_print', require: false
  gem 'factory_bot'
end

gem_group :development do
  gem 'pry-rails'
  gem 'better_errors'
  gem 'binding_of_caller'
  gem 'meta_request'
end

gem_group :test do
  gem 'database_cleaner'
end

# Update list of gems
run 'bundle'

# Generate an rspec helper
run 'rails g rspec:install'

# Make SLIM default Application Layout
remove_file 'app/views/layouts/application.html.erb'
copy_from_file('app', 'views', 'layouts', 'application.html.slim')
copy_from_file('spec', 'support', 'coverage.rb')
copy_from_file('spec', 'support', 'factory_bot.rb')
copy_from_file('lib', 'tasks', 'factory_bot.rake')
copy_from_file '.rubocop.yml'
copy_from_file '.slim-lint.yml'

inject_into_file 'spec/rails_helper.rb', after: "require 'rspec/rails'\n" do
  load_from_file('spec', 'rails_helper.rb')
end

inject_into_file 'Rakefile', after: "Rails.application.load_tasks\n" do
  load_from_file 'Rakefile'
end

append_file '.gitignore' do
  load_from_file '.gitignore'
end

gsub_file 'config/database.yml', /username.*$/, "username: <%= ENV['DB_USER'] %>"
gsub_file 'Gemfile', /gem 'coffee.*$/, ''
gsub_file 'Gemfile', /# Use CoffeeScript.*$/, ''

# Generate a controller and static_pages
generate(:controller, 'home', 'index', '--no-assets', '--no-helper')
copy_from_file 'spec', 'routing', 'home_routing_spec.rb'

# Default route
route "root to: 'home#index'"

# Finally, generate a database
rake 'db:create db:migrate'

run 'bundle exec rubocop -a'

# Put everything under revision control
git :init
git add: '.'
git commit: %( -m 'Initial commit' )

# Add to Github? This is what needs the first part
puts "\n"
if yes? 'Would you like to push the project to github?'.cyan
  repo = RailsTemplate::GitHub.new.create_repo(app_name)
  git remote: "add Github #{repo.ssh_url}"
  git push: '-u Github master'
end
