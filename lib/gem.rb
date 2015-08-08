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
