module Parser
  class Example
    LIMIT_TIME_ACTIONS = 8*60+59
    SLEEP_AFTER_SESSIONS = 10*60
    BETWEEN_SESSIONS_SLEEP = 8*60

    @logger = O14::ProjectLogger.get_logger

    def self.run
      # @driver = O14::WebBrowser.get_driver
      # @driver.navigate.to 'https://internet.yandex.ru'
      #     sleep 400
      #     exit
      while true
        begin
          instagram_actions
        rescue => e
          O14::ExceptionHandler.log_exception e
        end

        @logger.info 'I sleep 10 min'
        sleep SLEEP_AFTER_SESSIONS
      end
    end

    def self.instagram_actions
      nickname = O14::DB.get_db[:settings].where(:alias => 'login').first[:value]
      password = O14::DB.get_db[:settings].where(:alias => 'password').first[:value]
      O14::ProjectLogger.get_logger.debug 'start instagram_actions'
      @driver = O14::WebBrowser.get_driver

      @driver.navigate.to 'https://instagram.com'
      sleep 4
      dialog_process
      
      login(nickname, password) if need_login?

      @accs_for_view_stories = []

      limit_time_actions() { 
        actions_by_followers nickname
      }
      between_sessions_sleep
      limit_time_actions() { 
        answer_unread_messages
        answer_requests
      }
      between_sessions_sleep
      limit_time_actions() { 
        account_linking
      }
      between_sessions_sleep
      limit_time_actions() { 
        actions_by_account_list
      }
      O14::WebBrowser.quit_browser      
    end

    def self.between_sessions_sleep
      rand_sleep = BETWEEN_SESSIONS_SLEEP + rand(50..59)
      @logger.info "I sleep #{rand_sleep} sec"
      sleep(rand_sleep)
    end

    def self.get_hashtags
      O14::DB.get_db[:settings].where(:alias => 'hashtag').first[:value].split("\n").map{|_e| _e.strip.gsub('#','')}
    end

    def self.get_accounts
      O14::DB.get_db[:settings].where(:alias => 'accounts').first[:value].split("\n").map{|_e| _e.strip}
    end

    def self.get_linking_accounts
      O14::DB.get_db[:settings].where(:alias => 'accounts_2').first[:value].split("\n").map{|_e| _e.strip}
    end

    def self.limit_time_actions &block
      callback = block
      begin
        Timeout.timeout(LIMIT_TIME_ACTIONS) do
          callback.call
        end
      rescue Timeout::Error
        @logger.info "Timeout = #{LIMIT_TIME_ACTIONS}"
      end
    end

    def self.account_linking
      O14::ProjectLogger.get_logger.info 'start actions process for account from first post description'
      get_linking_accounts.shuffle.each do |nickname|
        O14::ProjectLogger.get_logger.debug "Account from which the link will be searched: @#{nickname}"
        @driver.navigate.to "https://www.instagram.com/#{nickname}/"
        sleep 5
        found_links = get_link_from_first_posts
        found_links.each do |found_link|
          if found_link
            @logger.info "Found link: #{found_link}"
            @driver.navigate.to found_link
            sleep 5

            view_current_stories
            set_likes_comments
          else
            @logger.info "Link not found in the post"
          end
        end
      end
    end

    def self.get_link_from_first_posts
      posts = @driver.find_elements(css: 'main article div._aabd') rescue []
      O14::ProjectLogger.get_logger.debug "Posts found: #{posts.count}"
      link_accounts = []

      posts.first(3).each do |post|
        post.click
        sleep 4
        O14::ProjectLogger.get_logger.debug "Current post: #{@driver.current_url}"

        link_accounts_elements = @driver.find_elements(xpath: "//li[@role='menuitem']//a[contains(text(), '@')]") rescue []
        link_accounts_elements.each do |acc_el|
          link_accounts.push acc_el['href']
        end
        O14::ProjectLogger.get_logger.debug "link_accounts count is: #{link_accounts.count}"
        break unless link_accounts.count > 0

        @driver.find_element(css: 'svg[aria-label=\'Close\']')&.click
        sleep 2
      end

      link_accounts
    end

    def self.answer_requests
      O14::ProjectLogger.get_logger.debug 'start auto reply requests in direct'
      
      flag = true
      while flag
        @driver.navigate.to 'https://www.instagram.com/direct/requests/'
        sleep 4
        direct_requests = @driver.find_elements(css: "div._ab8s a[role='link']") rescue []
        if direct_requests.count == 0
          @logger.debug 'No requests'
          flag = false
          next
        end
        all_requests_without_accept_button = true
        direct_requests.each do |request|
          request.click
          sleep 3
          accept_request_button = @driver.find_element(xpath: "//div[contains(@class, '_ac6v')]//div[text()='Accept']") rescue nil
          if accept_request_button
            all_requests_without_accept_button = false
            accept_request_button.click
            sleep 2
            select_folder_button = @driver.find_element(xpath: "//div[@role='dialog']//button[text()='Primary']") rescue nil
            select_folder_button.click unless select_folder_button.nil?
            sleep 4
            send_direct_message get_request_message
            break
          end
        end
        if all_requests_without_accept_button
          @logger.debug 'all_requests_without_accept_button'
          flag = false
          next
        end
      end
    end

    def self.answer_unread_messages
      O14::ProjectLogger.get_logger.debug 'start auto reply direct messages'
      @driver.navigate.to 'https://www.instagram.com/direct/inbox/'
      sleep 4

      unread_messages = @driver.find_elements(css: "div[aria-label='Unread']") rescue []
      unread_messages.each do |msg|
        msg.click
        sleep 3
        send_direct_message get_comment_message
      end
    end

    def self.actions_by_hashtag
      O14::ProjectLogger.get_logger.debug 'start instagram actions by hashtag'
      
      get_hashtags.each do |hashtag|
        O14::ProjectLogger.get_logger.debug "hashtag: ##{hashtag}"
        @driver.navigate.to "https://www.instagram.com/explore/tags/#{hashtag}/"
        sleep 5
        set_likes_comments
        view_all_stories
      end
    end

    def self.actions_by_account_list
      O14::ProjectLogger.get_logger.debug 'start instagram actions by account list'

      get_accounts.shuffle.each do |nickname|
        O14::ProjectLogger.get_logger.debug "nickname: @#{nickname}"
        @driver.navigate.to "https://www.instagram.com/#{nickname}/"
        sleep 5
        view_current_stories
        set_likes_comments
      end
    end

    def self.actions_by_followers nickname
      @driver.navigate.to "https://www.instagram.com/#{nickname}/followers/"
      sleep 5

      scroll_count = 0
      while scroll_count < 4
        @driver.execute_script("document.querySelector('div._aano').scrollTo(0,document.querySelector('div._aano').scrollHeight);")
        # scroll_origin = Selenium::WebDriver::WheelActions::ScrollOrigin.element(followers_wrapper)
        # @driver.action.scroll_from(scroll_origin, 0, 400).perform
        scroll_count += 1
        sleep 2
      end

      followers = @driver.find_elements(css: "div[role='dialog'] span>a[role='link']").map { |f| f['href'] }
      O14::ProjectLogger.get_logger.debug "Found #{followers.count} followers. Get all"

      followers.shuffle.each do |follower|
        @logger.info "Nav to #{follower}"
        @driver.navigate.to follower
        sleep 4
        view_current_stories
        begin
          set_likes_comments
        rescue => e
          O14::ExceptionHandler.log_exception e
        end
      end
    end

    def self.set_likes_comments
      O14::ProjectLogger.get_logger.debug 'set_likes_comments function start'
      posts = @driver.find_elements(css: 'main article div._aabd') rescue []
      posts = [] if posts.nil?
      O14::ProjectLogger.get_logger.debug "Posts found: #{posts.count}"
      post_index = rand(0..posts.count-1)

      O14::ProjectLogger.get_logger.debug "Get random post index = #{post_index}"
      post = posts[post_index]
      post.click
      sleep 4
      O14::ProjectLogger.get_logger.debug "Current post: #{@driver.current_url}"

      unlike_svg = @driver.find_element(css: 'svg[aria-label="Unlike"]') rescue nil # 'Unlike' exist if only post already liked
      if unlike_svg.nil?
        setting_like
        writing_comment

        # This need only for actions_by_hashtag
        account_link = @driver.find_element(css: 'article header div[role=\'button\'] a')['href'] rescue nil
        @accs_for_view_stories.push(account_link) unless account_link.nil?
        # This need only for actions_by_hashtag

      else
        O14::ProjectLogger.get_logger.debug 'Post are already liked'
      end

      @driver.find_element(css: 'svg[aria-label=\'Close\']')&.click
      sleep 3
      
    end

    def self.view_all_stories
      O14::ProjectLogger.get_logger.debug 'view_all_stories function start'
      @accs_for_view_stories = @accs_for_view_stories.uniq
      O14::ProjectLogger.get_logger.debug @accs_for_view_stories
      @accs_for_view_stories.each do |account|
        @driver.navigate.to account
        sleep 4
        view_current_stories
      end
    end

    def self.writing_comment
      O14::ProjectLogger.get_logger.debug 'Write comment'
      begin
        comment_input = @driver.find_element(css: 'form._aao9>textarea')
        comment_input.click
        comment_input = @driver.find_element(css: 'form._aao9>textarea')
        comment_input.send_keys get_comment_message, :return
        sleep 5
      rescue => e
        O14::ProjectLogger.get_logger.error 'Error when comment was writing'
        O14::ProjectLogger.get_logger.error e
      end
    end

    def self.setting_like
      O14::ProjectLogger.get_logger.debug 'Post not liked yet, set like'
      begin
        @driver.find_elements(css: 'section._aamu button').first.click
        sleep 1
      rescue => e
        O14::ProjectLogger.get_logger.error 'Error when like was setting'
        O14::ProjectLogger.get_logger.error e
      end
    end

    def self.get_request_message
      request_parts = O14::Config.get_config.text_parts['request']
      request_text = request_parts.map{ |part| part.split('|').sample }.join.strip

      request_text
    end

    def self.get_comment_message
      comment_parts = O14::Config.get_config.text_parts['comment_and_answer']
      comment_text = comment_parts.map{ |part| part.split('|').sample }.join.strip

      comment_text
    end

    def self.login login, password
      dialog_process

      login_input = @driver.find_element(css: 'input[name=\'username\'')
      login_input.click
      sleep 1

      login_input.send_keys login
      sleep 1

      password_input = @driver.find_element(css: 'input[name=\'password\'')
      password_input.click
      sleep 1

      password_input.send_keys password
      sleep 1

      login_button = @driver.find_element(css: 'button[type=\'submit\'')
      login_button.click
      sleep 4
    end

    def self.need_login?
      login_form_exist = @driver.find_element(css: 'form#loginForm') rescue nil

      !login_form_exist.nil?
    end

    def self.dialog_process
      dialog_block = @driver.find_element(css: 'div[role=\'dialog\']') rescue nil
      if dialog_block.nil?
        return false
      else
        deny_button = @driver.find_element(xpath: '//div[@role=\'dialog\']//button[contains(text(),\'Not Now\')]') rescue nil
        deny_button&.click
        sleep 2
      end
    end

    def self.view_current_stories
      O14::ProjectLogger.get_logger.debug 'view_current_stories function start'
      begin
        stories_btn = @driver.find_element(css: 'main[role=\'main\'] div[role=\'button\']') rescue nil

        if stories_btn.nil?
          O14::ProjectLogger.get_logger.debug 'No found view stories button'
          return false
        end

        stories_btn.click
        sleep 15

        @driver.find_element(css: 'svg[aria-label=\'Close\']')&.click
        sleep 3
      rescue => e
        O14::ProjectLogger.get_logger.error 'Error when stories was viewing'
        O14::ProjectLogger.get_logger.error e
      end
    end

    def self.send_direct_message msg_text
      begin
        message_area = @driver.find_element(css: 'textarea[placeholder=\'Message...\']')
        message_area.click
        message_area.send_keys msg_text, :return
        sleep 3
      rescue => e
        O14::ProjectLogger.get_logger.error 'Error when message in direct trying to send'
        O14::ProjectLogger.get_logger.error e
      end
    end

    def self.find_and_send_direct_message nickname
      @driver.navigate.to 'https://www.instagram.com/direct/inbox/'
      sleep 4
      dialog_process

      new_msg_button = @driver.find_element(xpath: '//button[contains(text(),\'Send message\')]')
      new_msg_button.click
      sleep 4
      search_recipient = @driver.find_element(css: 'input[name=\'queryBox\']')
      search_recipient.click
      sleep 1
      search_recipient.send_keys nickname
      sleep 5

      @driver.find_elements(css: 'div._abm4').first.click
      @driver.find_element(xpath: '//div[contains(text(),\'Next\')]').click
      sleep 7
      message_area = @driver.find_element(css: 'textarea[placeholder=\'Message...\']')
      message_area.click
      message_area.send_keys 'Thats amazing!', :return
      sleep 3
    end
  end # Example
end # Parser
