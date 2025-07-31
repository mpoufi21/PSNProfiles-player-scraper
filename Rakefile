require_relative 'config/environment'

desc "Start an interactive console"
task :console do
  require 'pry'
  ARGV.clear # Clear ARGV so Pry doesn't try to process them as commands
  Pry.start
end