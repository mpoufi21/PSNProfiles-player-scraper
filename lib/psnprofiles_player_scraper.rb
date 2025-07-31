# lib/psnprofiles_player_scraper.rb

require_relative 'psnprofiles_player_scraper/version'

module PSNProfiles_player_scraper
  autoload :Scraper, 'psnprofiles_player_scraper/scraper'
  autoload :Player, 'psnprofiles_player_scraper/player'
  autoload :CommandLineInterface, 'psnprofiles_player_scraper/command_line_interface'

  # Optional: You can add configuration here if needed
  class << self
    attr_accessor :configuration

    def configure
      self.configuration ||= Configuration.new
      yield(configuration) if block_given?
    end

    class Configuration
      attr_accessor :timeout, :max_retries, :verbose

      def initialize
        @timeout = 30
        @max_retries = 3
        @verbose = false
      end
    end
  end
end

# Optional: Auto-configure with default settings
PSNProfiles_player_scraper.configure