require 'nokogiri'
require 'open-uri'
require 'mechanize'
require 'time_difference'

class PSNProfiles_player_scraper::Scraper
  BASE_PATH = "https://psnprofiles.com/".freeze

  def self.open(psn_id)
    uri = URI.parse(BASE_PATH + URI::DEFAULT_PARSER.escape(psn_id))
    
    # Add timeout
    Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == 'https', 
                read_timeout: 10, open_timeout: 10) do |http|
      request = Net::HTTP::Get.new(uri)
      response = http.request(request)
      Nokogiri::HTML(response.body)
    end
  rescue Net::ReadTimeout, Net::OpenTimeout => e
    puts "Request timed out: #{e.message}"
    false
  rescue => e
    puts "Network error: #{e.message}"
    false
  end


  def self.valid_profile(psn_id)
    profile = open(psn_id)
    return false unless profile

    # Updated validation checks
    # Check 1: Look for username element (new selector)
    username_element = profile.css('.profile-header__name').first || 
                      profile.css('.username').first
    
    # Check 2: Look for error message (new selector)
    error_message = profile.css('.error-message').first ||
                    profile.css('.message-box').first

    if username_element.nil? || error_message
      false
    else
      profile
    end
  rescue => e
    puts "Validation error: #{e.message}" if ENV['DEBUG']
    false
  end

  def self.scrape(profile_data)
    player = {}

    # get data from top row (including mouseover extras)
    player[:psn_id] = profile_data.at_css("span.username")&.text&.strip
    player[:comment] = profile_data.at_css("span.comment")&.text
    player[:level] = profile_data.at_css("li.icon-sprite.level")&.text
    player[:level_progress] = profile_data.at_css("div.progress-bar.level div")&.[]('style')&.gsub("width: ", "")&.gsub(";", "")
    
    script_content = profile_data.css('script[type="text/javascript"]')[12]&.children&.to_s&.strip
    player[:next_level_in] = script_content&.gsub(/.*( in <b>)/, "")&.gsub("\n", "")&.gsub(/(<\/b>).*/, "") + " points" if script_content

    flag_title = profile_data.at_css("img.round-flags")&.[]('title')
    player[:country] = flag_title&.gsub("<center style='font-size:11px;'>", "")&.gsub("</center>", "") if flag_title

    [:total, :platinum, :gold, :silver, :bronze].each do |trophy_type|
      player[:"total_#{trophy_type}s"] = profile_data.at_css("li.#{trophy_type}")&.text&.strip
    end

    # get data from second row stats
    stats_flex = profile_data.css("span.stat.grow")
    stats_flex_data = stats_flex.map do |stat|
      stat.to_s.gsub(/(<span).*(">)/, "")
            .gsub(/(<span>).*/, "")
            .gsub(/(<a).*(">)/, "")
            .gsub(/(<\/a>)/, "")
            .gsub(/(<\/span>)/, "")
            .strip
    end

    stats_flex_data.delete_at(5) # remove profile views count
    stats_keys = [:games_played, :completed_games, :overall_completion, 
                 :unearned_trophies, :trophies_per_day, :world_rank, :country_rank]
    
    stats_keys.each_with_index do |key, i|
      player[key] = stats_flex_data[i] if stats_flex_data[i]
    end

    # get recent trophies
    player[:recent_trophies] = scrape_recent_trophies(profile_data)
    
    # get recent games
    player[:recent_games] = scrape_recent_games(profile_data)
    
    # get rarest trophies
    player[:rarest_trophies] = scrape_rarest_trophies(profile_data)
    
    # get additional stats data
    if player[:psn_id]
      stats_page = open("#{player[:psn_id]}/stats")
      player.merge!(scrape_stats_page(stats_page))
      
      # get first and latest trophy data
      player.merge!(scrape_trophy_times(player[:psn_id]))
    end

    player
  end

  private

  def self.scrape_recent_trophies(profile_data)
    recent_trophies = []
    profile_data.css("ul.recent-trophies.flex li").each do |trophy|
      recent_trophies << {
        trophy: trophy.at_css("div.ellipsis a.title")&.text&.strip,
        game: trophy.at_css("div.ellipsis span.small_info_green a")&.text&.strip,
        description: trophy.css("div.ellipsis span").first&.text&.strip
      }
    end
    recent_trophies
  end

  def self.scrape_recent_games(profile_data)
    recent_games = []
    profile_data.css('[id="gamesTable"] tr').first(12).each do |game|
      game_data = {
        game: game.at_css("a.title")&.text,
        platform: game.css("span.tag.platform").map(&:text).join("/"),
        platinum: parse_platinum_status(game),
        golds: game.css("div.trophy-count div span")[1]&.text,
        silvers: game.css("div.trophy-count div span")[3]&.text,
        bronzes: game.css("div.trophy-count div span")[5]&.text,
        completion: game.css("div.trophy-count div span")[6]&.text
      }
      
      # Add trophy counts and dates
      add_trophy_counts_and_dates(game, game_data)
      
      # Add completion rates
      add_completion_rates(game, game_data)
      
      recent_games << game_data
    end
    recent_games
  end

  def self.parse_platinum_status(game)
    plat_class = game.at_css("img.icon-sprite")&.[]('class')
    return "not applicable (game has no platinum)" if plat_class&.include?("c")
    plat_class&.end_with?("earned") ? "1" : "0"
  end

  def self.add_trophy_counts_and_dates(game, game_data)
    small_info = game.css("div.small-info")
    if small_info[0]&.text&.strip&.start_with?("All")
      game_data[:earned_trophies] = game.css("div.small-info b")[0]&.text
      game_data[:available_trophies] = game.css("div.small-info b")[0]&.text
    else
      game_data[:earned_trophies] = game.css("div.small-info b")[0]&.text
      game_data[:available_trophies] = game.css("div.small-info b")[1]&.text
    end

    if small_info[1]
      date_text = small_info[1].text.strip.gsub(/\n.*/, "")
      unless date_text == "Missing Timestamp"
        game_data[:latest_trophy_date] = DateTime.parse(date_text) rescue date_text
      end
      
      if small_info[1].css("bullet").any?
        speed_text = small_info[1].text.strip.gsub("\n", "").gsub(/.*(\u2022)/, "").gsub("\t", "").strip
        game_data[:speedrun_type] = speed_text.start_with?("Completed") ? "Completion" : "Platinum"
        game_data[:speedrun_time] = speed_text.gsub(/.* in /, "").gsub(",", " and")
      end
    end
  end

  def self.add_completion_rates(game, game_data)
    game.css("span.separator.completion-status span").each do |rate|
      class_name = rate['class']
      if class_name.start_with?("p")
        game_data[:PSNProfiles_platinum_rarity] = rate.text
      else
        game_data[:PSNProfiles_completion_rarity] = rate.text
      end
    end
  end

  def self.scrape_rarest_trophies(profile_data)
    profile_data.css("div.sidebar.col-xs-4 div.box.no-top-border tr").map do |trophy|
      {
        trophy: trophy.css("td")[1]&.css("a")[0]&.text,
        game: trophy.css("td")[1]&.css("a")[1]&.text,
        PSNProfiles_rarity: trophy.css("td")[2]&.css("span")[0]&.text,
        grade: trophy.css("td")[3]&.css("img")&.[]('title')
      }
    end
  end

  def self.scrape_stats_page(stats_data)
    return {} unless stats_data

    stats = {
      games_by_platform: scrape_games_by_platform(stats_data),
      trophies_by_grade: scrape_trophies_by_grade(stats_data),
      rarity_breakdown: scrape_rarity_breakdown(stats_data),
      completion_breakdown: scrape_completion_breakdown(stats_data)
    }
  end

  def self.scrape_games_by_platform(stats_data)
    stats_data.css("div.col-xs-4")[0]&.css("ul.legend li")&.map do |platform|
      text = platform.text
      {
        platform: text.gsub(/\(.*/, "").strip,
        games: text.gsub(/.*\(/, "").gsub(")", "")
      }
    end || []
  end

  def self.scrape_trophies_by_grade(stats_data)
    grades = [{}, {}, {}, {}]
    stats_data.css("div.col-xs-4")[1]&.css("ul.legend li")&.each_with_index do |grade, i|
      text = grade.text
      grades[i][:grade] = text.gsub(/\(.*/, "").strip
      grades[i][:trophies] = text.gsub(/.*\(/, "").gsub(")", "")
    end
    grades
  end

  def self.scrape_rarity_breakdown(stats_data)
    rarity = { average_rarity: "", trophies_by_rarity: Array.new(5) { {} } }
    
    if col = stats_data.css("div.col-xs-4")[3]
      rarity[:average_rarity] = col.at_css("div.col-xs-6 span.typo-top")&.text
      
      col.css("ul.legend li").each_with_index do |band, i|
        text = band.text
        rarity[:trophies_by_rarity][i][:rarity_band] = case text.gsub(/\(.*/, "").strip
          when "Ultra Rare" then "0 - 4.99% ('Ultra Rare')"
          when "Very Rare" then "5 - 9.99% ('Very Rare')"
          when "Rare" then "10 - 19.99% ('Rare')"
          when "Uncommon" then "20 - 49.99% ('Uncommon')"
          when "Common" then "50 - 100% ('Common')"
          else text.gsub(/\(.*/, "").strip
        end
        rarity[:trophies_by_rarity][i][:trophies] = text.gsub(/.*\(/, "").gsub(")", "")
      end
    end
    
    rarity
  end

  def self.scrape_completion_breakdown(stats_data)
    completion = { average_completion: "", games_by_completion: Array.new(5) { {} } }
    
    if col = stats_data.css("div.col-xs-4")[4]
      completion[:average_completion] = col.at_css("div.col-xs-6 span.typo-top")&.text
      
      col.css("ul.legend li").each_with_index do |band, i|
        text = band.text
        completion[:games_by_completion][i][:completion_band] = text.gsub(/\(.*/, "").strip
        completion[:games_by_completion][i][:games] = text.gsub(/.*\(/, "").gsub(")", "")
      end
    end
    
    completion
  end

  def self.scrape_trophy_times(psn_id)
    result = { first_trophy: {}, latest_trophy: {} }
    
    # First trophy
    first_page = open("#{psn_id}/log?dir=asc")
    if first_page
      result[:first_trophy].merge!(
        trophy: first_page.at_css("a.title")&.text,
        game: first_page.at_css("img.game")&.[]('title'),
        description: first_page.css("td")[2]&.text&.gsub(result[:first_trophy][:trophy], "")&.strip
      )
      
      time_text = first_page.css("td")[5]&.text&.gsub("\n", " ")&.strip&.gsub("\r", "")&.gsub("\t", "")
      result[:first_trophy][:time] = time_text == "Missing Timestamp" ? 
        "unknown (missing timestamp)" : (DateTime.parse(time_text) rescue time_text)
    end
    
    # Latest trophy
    latest_page = open("#{psn_id}/log")
    if latest_page
      result[:latest_trophy].merge!(
        trophy: latest_page.at_css("a.title")&.text,
        game: latest_page.at_css("img.game")&.[]('title'),
        description: latest_page.css("td")[2]&.text&.gsub(result[:latest_trophy][:trophy], "")&.strip
      )
      
      time_text = latest_page.css("td")[5]&.text&.gsub("\n", " ")&.strip&.gsub("\r", "")&.gsub("\t", "")
      result[:latest_trophy][:time] = time_text == "Missing Timestamp" ? 
        "unknown (missing timestamp)" : (DateTime.parse(time_text) rescue time_text)
    end
    
    # Calculate length of service
    if result[:first_trophy][:time] == result[:latest_trophy][:time]
      result[:length_of_service] = "not applicable (only one trophy)"
    elsif result[:first_trophy][:time].is_a?(DateTime) && result[:latest_trophy][:time].is_a?(DateTime)
      result[:length_of_service] = TimeDifference.between(
        result[:first_trophy][:time],
        result[:latest_trophy][:time]
      ).humanize.downcase
    else
      result[:length_of_service] = "unknown (missing timestamp(s))"
    end
    
    result
  end
end