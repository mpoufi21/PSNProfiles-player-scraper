require 'json'
require 'time'

class PSNProfiles_player_scraper::Player
  attr_accessor :psn_id, :comment, :level, :level_progress, :next_level_in, :country, 
               :total_trophies, :total_platinums, :total_golds, :total_silvers, :total_bronzes,
               :games_played, :completed_games, :overall_completion, :unearned_trophies,
               :trophies_per_day, :world_rank, :country_rank, :recent_trophies, :recent_games,
               :rarest_trophies, :games_by_platform, :trophies_by_grade, :rarity_breakdown,
               :completion_breakdown, :first_trophy, :latest_trophy, :length_of_service

  @@all = []

  def initialize(player_data)
    player_data.each do |key, value|
      send("#{key}=", value) if respond_to?("#{key}=")
    end

    @@all << self
  end

  def average_rarity
    rarity_breakdown[:average_rarity]
  end

  def trophies_by_rarity
    rarity_breakdown[:trophies_by_rarity]
  end

  def average_completion
    completion_breakdown[:average_completion]
  end

  def games_by_completion
    completion_breakdown[:games_by_completion]
  end

  def self.all
    @@all
  end

  def view(cli)
    view_menu
    cli.main_menu
  end

  def view_menu
    puts "\nWhat data would you like to view?"
    puts "  Enter \"1\" for basics"
    puts "  Enter \"2\" for totals"
    puts "  Enter \"3\" for summaries (number of x by y)"
    puts "  Enter \"4\" for length of service (inc. first/latest trophy)"
    puts "  Enter \"5\" for collections (recent trophies/games and rarest trophies)"
    puts "  Enter \"main\" to return to the main menu"
    puts "\nView the README for more information on each option\n\n"

    choice = ""
    until %w[1 2 3 4 5 main].include?(choice.downcase)
      choice = gets.strip
    end

    case choice.downcase
    when "1" then view_basics
    when "2" then view_totals
    when "3" then view_summaries
    when "4" then view_los
    when "5" then view_collections_menu
    end
  end

  def view_basics
    puts "\n#{psn_id}#{comment ? " ~ #{comment}" : ""}"
    puts "\nLevel: #{level}"
    puts "Level progress: #{level_progress} - next level in #{next_level_in}"
    puts "Rank: #{world_rank} (world) | #{country_rank} (#{country})"
    puts "\nOverall completion rate: #{overall_completion}"
    puts "Average game completion: #{average_completion}"
    puts "Average trophy rarity: #{average_rarity}"
    puts "Trophies per day: #{trophies_per_day}"

    view_menu
  end

  def view_totals
    puts "\nTrophies"
    puts "  Earned: #{total_trophies} | Unearned: #{unearned_trophies}"
    puts "  Platinums: #{total_platinums} | Golds: #{total_golds} | Silvers: #{total_silvers} | Bronzes: #{total_bronzes}"

    puts "\nGames"
    puts "  Completed: #{completed_games} | Played: #{games_played}"

    view_menu
  end

  def view_summaries
    puts "\nTrophies by grade"
    trophies_by_grade.each { |grade_data| puts "  #{grade_data[:grade]}: #{grade_data[:trophies]}" }

    puts "\nTrophies by rarity"
    trophies_by_rarity.each { |rarity_data| puts "  #{rarity_data[:rarity_band]}: #{rarity_data[:trophies]}" }

    puts "\nGames by platform"
    games_by_platform.each { |platform_data| puts "  #{platform_data[:platform]}: #{platform_data[:games]}" }

    puts "\nGames by completion percentage"
    games_by_completion.each { |completion_data| puts "  #{completion_data[:completion_band]}: #{completion_data[:games]}" }

    view_menu
  end

  def view_los
    puts "\nFirst trophy"
    puts "  #{first_trophy[:trophy]} (#{first_trophy[:game]})"
    puts "  #{first_trophy[:description]}"
    puts "\n  Earned: #{self.class.trophy_earned_date(self, 'first')}"

    puts "\nLatest trophy"
    puts "  #{latest_trophy[:trophy]} (#{latest_trophy[:game]})"
    puts "  #{latest_trophy[:description]}"
    puts "\n  Earned: #{self.class.trophy_earned_date(self, 'latest')}"

    puts "\nLength of service: #{length_of_service}"

    view_menu
  end

  def view_collections_menu
    puts "\nWhich collection would you like to view?"
    puts "  Enter \"1\" for recent trophies"
    puts "  Enter \"2\" for recent games"
    puts "  Enter \"3\" for rarest trophies"
    puts "  Enter \"view\" to return to the view menu"
    puts "  Enter \"main\" to return to the main menu\n\n"

    choice = ""
    until %w[1 2 3 view main].include?(choice.downcase)
      choice = gets.strip
    end

    case choice.downcase
    when "1" then view_recent_trophies
    when "2" then view_recent_games
    when "3" then view_rarest_trophies
    when "view" then view_menu
    end
  end

  def view_recent_trophies
    puts "\nRecent trophies"

    recent_trophies.each_with_index do |trophy_data, i|
      puts "\n(#{i + 1})#{i > 8 ? ' ' : '  '}#{trophy_data[:trophy]} (#{trophy_data[:game]})"
      puts "     #{trophy_data[:description]}"
    end

    view_collections_menu
  end

  def view_recent_games
    puts "\nRecent games"

    recent_games.each_with_index do |game_data, i|
      puts "\n(#{i + 1})#{i > 8 ? ' ' : '  '}#{game_data[:game]} (#{game_data[:platform]})"

      if game_data[:PSNProfiles_completion_rarity] && game_data[:PSNProfiles_platinum_rarity]
        puts "     PSNProfiles rarities: #{game_data[:PSNProfiles_completion_rarity]} (completion) | #{game_data[:PSNProfiles_platinum_rarity]} (platinum)"
      elsif game_data[:PSNProfiles_completion_rarity]
        puts "     PSNProfiles completion rarity: #{game_data[:PSNProfiles_completion_rarity]}"
      else
        puts "     PSNProfiles platinum rarity: #{game_data[:PSNProfiles_platinum_rarity]}"
      end

      psnp_platinum = game_data[:PSNProfiles_platinum_rarity] || "not applicable (no platinum)"
      platinumed = if game_data[:platinum] == "0"
                     "no"
                   else
                     game_data[:platinum] ? "yes" : "not applicable (no platinum)"
                   end

      puts "\n     Completion: #{game_data[:completion]}"
      puts "     Platinumed: #{platinumed}"

      if game_data[:speedrun_type]
        speedrun_type = if game_data[:speedrun_type] == "Platinum" && !game_data[:PSNProfiles_completion_rarity]
                          ""
                        elsif !game_data[:PSNProfiles_platinum_rarity]
                          ""
                        else
                          " (#{game_data[:speedrun_type].downcase})"
                        end

        puts "     Speedrun#{speedrun_type}: #{game_data[:speedrun_time]}"
      end

      puts "\n     Golds: #{game_data[:golds]} | Silvers: #{game_data[:silvers]} | Bronzes: #{game_data[:bronzes]}"
      puts "     Trophies earned/available: #{game_data[:earned_trophies]}/#{game_data[:available_trophies]}"

      latest_trophy_date = if game_data[:latest_trophy_date].is_a?(DateTime)
                             game_data[:latest_trophy_date].strftime('%-d %B %Y')
                           else
                             game_data[:latest_trophy_date]
                           end

      puts "     Most recent trophy date: #{latest_trophy_date}"
    end

    view_collections_menu
  end

  def view_rarest_trophies
    puts "\nRarest trophies"

    rarest_trophies.each_with_index do |trophy_data, i|
      puts "\n(#{i + 1})  #{trophy_data[:trophy]} (#{trophy_data[:game]})"
      puts "     #{trophy_data[:grade]} | PSNProfiles rarity: #{trophy_data[:PSNProfiles_rarity]}"
    end

    view_collections_menu
  end

  def export(cli)
    puts "\nWhere would you like to export the data to?"

    directory = gets.strip
    until Dir.exist?(directory)
      puts "\nDirectory not found. Please enter a valid filepath"
      directory = gets.strip
    end

    directory = directory.gsub("\\", "/")
    directory += "/" unless directory.end_with?("/")

    puts "\nWhat format: XML or JSON?"

    format = ""
    until %w[xml json].include?(format.downcase)
      format = gets.strip
      puts "\nInvalid format. Please enter \"XML\" or \"JSON\"" unless %w[xml json].include?(format.downcase)
    end

    filename = "#{directory}PSNProfiles_data_#{psn_id}.#{format.downcase}"

    if File.exist?(filename)
      i = 2
      filename = filename.gsub(".#{format.downcase}", " (#{i}).#{format.downcase}")

      while File.exist?(filename)
        filename = filename.gsub("(#{i}).", "(#{i += 1}).")
      end
    end

    case format.downcase
    when "xml"
      File.write(filename, hash.to_xml)
    when "json"
      File.write(filename, JSON.pretty_generate(hash))
    end

    puts "\nData successfully exported to \"#{filename}\"!\n"

    cli.main_menu
  end

  def hash
    instance_variables.each_with_object({}) do |variable, hash|
      key = variable.to_s.delete("@").to_sym
      hash[key] = instance_variable_get(variable)
    end
  end

  def self.compare(player_one, player_two, cli)
    puts "\n#{player_one.psn_id} vs #{player_two.psn_id}"

    puts "\nLevel: #{player_one.level} | #{player_two.level}"

    if player_one.country == player_two.country
      puts "#{player_one.country} rank: #{player_one.country_rank} | #{player_two.country_rank}"
    end

    puts "World rank: #{player_one.world_rank} | #{player_two.world_rank}"

    puts "\nOverall completion rate: #{player_one.overall_completion} | #{player_two.overall_completion}"
    puts "Average game completion: #{player_one.average_completion} | #{player_two.average_completion}"
    puts "Average trophy rarity: #{player_one.average_rarity} | #{player_two.average_rarity}"
    puts "Trophies per day: #{player_one.trophies_per_day} | #{player_two.trophies_per_day}"
    puts "Rarest trophy (PSNProfiles rarity): #{player_one.rarest_trophies[0][:PSNProfiles_rarity]} | #{player_two.rarest_trophies[0][:PSNProfiles_rarity]}"

    puts "\nTrophies"
    puts "  Earned: #{player_one.total_trophies} | #{player_two.total_trophies}"
    puts "  Unearned: #{player_one.unearned_trophies} | #{player_two.unearned_trophies}"
    puts "  Platinums: #{player_one.total_platinums} | #{player_two.total_platinums}"
    puts "  Golds: #{player_one.total_golds} | #{player_two.total_golds}"
    puts "  Silvers: #{player_one.total_silvers} | #{player_two.total_silvers}"
    puts "  Bronzes: #{player_one.total_bronzes} | #{player_two.total_bronzes}"

    puts "\nGames"
    puts "  Completed: #{player_one.completed_games} | #{player_two.completed_games}"
    puts "  Played: #{player_one.games_played} | #{player_two.games_played}"

    puts "\nFirst trophy earned: #{trophy_earned_date(player_one, 'first')} | #{trophy_earned_date(player_two, 'first')}"
    puts "Latest trophy earned: #{trophy_earned_date(player_one, 'latest')} | #{trophy_earned_date(player_two, 'latest')}"
    puts "Length of service: #{player_one.length_of_service} | #{player_two.length_of_service}"

    cli.main_menu
  end

  def self.trophy_earned_date(player, first_or_latest)
    time = player.send("#{first_or_latest}_trophy")[:time]

    if time.is_a?(DateTime)
      time.strftime('%H:%M:%S on %-d %B %Y')
    else
      time
    end
  end
end