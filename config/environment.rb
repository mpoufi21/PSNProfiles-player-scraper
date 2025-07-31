# config/environment.rb

# Silence all verbose warnings (including Fiddle)
$VERBOSE = nil

# Rest of your environment setup
$LOAD_PATH.unshift(File.expand_path('../../lib', __FILE__))
require 'bundler/setup'
Bundler.require(:default)

require 'psnprofiles_player_scraper/version'
require 'psnprofiles_player_scraper/scraper'
require 'psnprofiles_player_scraper/player'
require 'psnprofiles_player_scraper/command_line_interface'