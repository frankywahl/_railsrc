# Start is from https://gist.github.com/tomchapin/5541218
module RailsTemplate

  module Gem
    extend self
    def use(name, options={})
      require_path = options[:require] || name
      begin
        require require_path
      rescue LoadError
        system "gem install #{name}"
        ::Gem.clear_paths
        self.use name, options
      end
    end
  end

  class GitHub

    Gem.use 'github_api'
    Gem.use 'highline', require: 'highline/import'
    Gem.use 'colorize'

    def initialize
      @api = login!
      @account = choose_account!
    end

    def create_repo(name)
      options        = { name: name, auto_init: false }
      options[:private] = agree("Make repo private?")
      unless @account == @api.login
        options[:org] = @account
        options[:team_id] = choose_team.id
      end
      @api.repos.create options
    rescue
      puts "repo name taken, try again..."
      create_repo ask "what would you like to name the repo?"
    end

    protected

    def orgs
      @orgs ||= @api.orgs.list.map(&:login)
    end

    def choose_account!
      return @api.login if orgs.size < 1
      HighLine.choose do |menu|
        menu.prompt = "Please choose an account".yellow
        menu.choice @api.login
        menu.choices *orgs
      end
    end

    def teams_for_account
      @teams_for_account ||= @api.orgs.teams.list(@account)
    end

    def choose_team
      name = HighLine.choose do |menu|
        menu.choices *teams_for_account.map(&:name)
      end
      teams_for_account.find { |team| team.name == name }
    end

    def login!
      puts "\n"
      # Get the Gems we need

      # Login
      login    = ask("Enter your github username: ")
      password = ask("Enter your github password: ") { |q| q.echo = '*' }
      gh       = Github.new login: login, password: password

      # Confirm Login
      gh.repos.find('ruby', 'ruby')
      puts "\n"
      gh
    rescue ::Github::Error::Unauthorized
      puts 'Invalid Credentials, try again...'
      return login!
    rescue ::Github::Error::Forbidden
      puts 'Too many attempts, goodbye!'
    end

  end
end

#### End from https://gist.github.com/tomchapin/5541218

######################
# Gems I use

# For managing ENV variables
gem 'dotenv-rails', '~> 1.0', groups: %i(development test)

gem 'slim-rails'

gem_group :development, :test do
  gem 'rspec-rails'
  gem 'pry-byebug'
  gem 'pry-stack_explorer'
  gem 'rubocop'
  gem 'rubocop-rspec'
  gem 'simplecov'
  gem 'simplecov-console'
  gem 'awesome_print', require: false
  gem 'factory_girl_rails'
end

gem_group :development do
  gem 'pry-rails'
  gem 'better_errors'
  gem 'binding_of_caller'
  gem 'meta_request'
end

gem_group :test do
  gem 'database_cleaner'
  gem 'codeclimate-test-reporter', require: nil
end

# Update list of gems
run 'bundle'

# Generate an rspec helper
run 'rails g rspec:install'

# Make SLIM default Application Layout
remove_file 'app/views/layouts/application.html.erb'
create_file 'app/views/layouts/application.html.slim' do
  <<-SLIM.strip_heredoc
    doctype html
    html
      head
        title RailsTest
        = stylesheet_link_tag    'application', media: 'all', 'data-turbolinks-track' => true
        = javascript_include_tag 'application', 'data-turbolinks-track' => true
        = csrf_meta_tags
        = meta name="viewport" content="width=device-width, initial-scale=1"

      body
        = yield
  SLIM
end

create_file 'spec/support/coverage.rb' do
  <<-SUPPORT.strip_heredoc
    require 'simplecov'
    require 'simplecov-console'
    require 'codeclimate-test-reporter'

    CodeClimate::TestReporter.start

    SimpleCov.formatter = SimpleCov::Formatter::MultiFormatter[
      SimpleCov::Formatter::HTMLFormatter,
      SimpleCov::Formatter::Console,
      CodeClimate::TestReporter::Formatter
    ]

    SimpleCov.start :rails do
      add_group 'Workers', 'app/workers'
      add_filter 'bundle'
      SimpleCov.minimum_coverage 100
    end unless ENV.fetch('NO_TEST_COVERAGE', false)
  SUPPORT
end

create_file 'spec/support/factory_girl.rb' do
  <<-FACTORY_GIRL.strip_heredoc
    RSpec.configure do |config|
      # additional factory_girl configuration

      config.before(:suite) do
        begin
          DatabaseCleaner.start
          FactoryGirl.lint
        ensure
          DatabaseCleaner.clean
        end
      end
    end
  FACTORY_GIRL

end

create_file '.rubocop.yml' do
  <<-RUBOCOP.strip_heredoc
    require: rubocop-rspec

    AllCops:
      Exclude:
        - db/migrate/*
        - db/schema.rb
        - bin/**/*
        - tmp/**/*
        - vendor/**/*
        - .bundle/**/*

    Documentation:
      Enabled: false

    LineLength:
      Max: 140
  RUBOCOP
end

  create_file '.ruby-version', RUBY_VERSION

inject_into_file 'spec/rails_helper.rb', after: "require 'rspec/rails'\n" do
  <<-EOF.strip_heredoc
    Dir["\#{File.expand_path('../support', __FILE__)}/**/*.rb"].each { |f| require f }
  EOF
end

inject_into_file 'Rakefile', after: "Rails.application.load_tasks\n" do
  <<-EOF.strip_heredoc
    if %w(development test).include? Rails.env
      require 'rubocop/rake_task'
      RuboCop::RakeTask.new

      task(:default).clear
      task default: %i(spec rubocop)
    end
  EOF
end

append_file '.gitignore' do
  <<-GIT.strip_heredoc
    # Ignore bundler config.
    /.bundle

    # Ignore coverage directory
    /coverage

    # Ignore .env
    .env
  GIT
end

gsub_file 'config/database.yml', /username.*$/, "username: <%= ENV['DB_USER'] %>"

# Generate a controller and static_pages
generate(:controller, "home", "index", "--no-assets", "--no-helper", "--no-view-specs")

# Default route
route "root to: 'home#index'"

# Finally, generate a database
rake "db:create db:migrate"

run 'bundle exec rubocop -a'

# Put everything under revision control
git :init
git add: "."
git commit: %Q{ -m 'Initial commit' }


# Add to Github? This is what needs the first part
puts "\n"
if yes? "Would you like to push the project to github?".cyan
  repo = RailsTemplate::GitHub.new.create_repo(app_name)
  git remote: "add Github #{repo.ssh_url}"
  git push: '-u Github master'
end

