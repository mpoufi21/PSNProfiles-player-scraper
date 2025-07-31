class PSNProfiles_player_scraper::CommandLineInterface
  attr_accessor :player, :player_2

  def run
    puts "\nこんにちは！ Welcome to the PSNProfiles player scraper!"
    get_player
    puts "\nさようなら！ Goodbye!\n\n"
  end

  def get_player
    puts "\nPlease enter a PSN ID:"
    self.player = PSNProfiles_player_scraper::Player.new(valid_profile_data)
    puts "\nPlayer successfully scraped!"
    main_menu
  end

  def main_menu
    puts "\nWhat would you like to do?"
    puts "  Enter \"1\" to view player data"
    puts "  Enter \"2\" to export player data"
    puts "  Enter \"3\" to compare with another player"
    puts "  Enter \"4\" to change player"
    puts "  Enter \"exit\" to exit\n\n"

    choice = ""
    until %w[1 2 3 4 exit].include?(choice.downcase)
      choice = gets.strip
    end

    case choice.downcase
    when "1" then player.view(self)
    when "2" then player.export(self)
    when "3" then compare_players
    when "4" then get_player
    when "exit" then return
    end
  end

  private

  def compare_players
    puts "\nEnter the PSN ID of the player you wish to compare with:"
    self.player_2 = PSNProfiles_player_scraper::Player.new(valid_profile_data)
    PSNProfiles_player_scraper::Player.compare(player, player_2, self)
  end

  def valid_profile_data
    loop do
      psn_id = gets.strip
      valid_profile = PSNProfiles_player_scraper::Scraper.valid_profile(psn_id)

      if valid_profile
        return PSNProfiles_player_scraper::Scraper.scrape(valid_profile)
      else
        puts "\nInvalid PSN ID. Please try again or refer to note (1) of the README " \
             "for reasons you might be seeing this error"
      end
    end
  end
end