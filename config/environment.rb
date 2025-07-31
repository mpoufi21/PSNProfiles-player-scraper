require 'bundler/setup'
Bundler.require(:default)

module PSNProfiles_player_scraper
end

require_relative 'lib/psnprofiles_player_scraper/version'
require_relative 'lib/psnprofiles_player_scraper/scraper'
require_relative 'lib/psnprofiles_player_scraper/player'
require_relative 'lib/psnprofiles_player_scraper/command_line_interface'