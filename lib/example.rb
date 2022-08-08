module Parser
  class Example
    def self.run
      while true
        instagram_actions

        O14::ProjectLogger.get_logger.debug "Sleep #{O14::Config.get_config.sleeping_minutes} minutes"
        sleep O14::Config.get_config.sleeping_minutes * 60
      end
    end

    def self.instagram_actions
      O14::ProjectLogger.get_logger.debug 'start instagram_actions'
      @driver = O14::WebBrowser.get_driver

      @driver.navigate.to 'https://instagram.com'
      sleep 4
      dialog_process

      login if need_login?

      @accs_for_view_stories = []

      # actions_by_hashtag
      # actions_by_account_list
      actions_by_followers

      sleep 60
      O14::WebBrowser.quit_browser
    end

    def self.actions_by_hashtag
      O14::ProjectLogger.get_logger.debug 'start instagram actions by hashtag'

      O14::Config.get_config.actions['like_comment']['hashtags'].each do |hashtag|
        O14::ProjectLogger.get_logger.debug "hashtag: ##{hashtag}"
        @driver.navigate.to "https://www.instagram.com/explore/tags/#{hashtag}/"
        sleep 5
        set_likes_comments
        view_all_stories
      end
    end

    def self.actions_by_account_list
      O14::ProjectLogger.get_logger.debug 'start instagram actions by account list'

      O14::Config.get_config.actions['like_comment']['nicknames'].each do |nickname|
        O14::ProjectLogger.get_logger.debug "nickname: ##{nickname}"
        @driver.navigate.to "https://www.instagram.com/#{nickname}/"
        sleep 5
        view_current_stories
        set_likes_comments
      end
    end

    def self.actions_by_followers
      @driver.navigate.to "https://www.instagram.com/#{O14::Config.get_config.login_data['login']}/followers/"
      sleep 5
      followers = @driver.find_elements(css: "div[role='dialog'] span>a[role='link']").map { |f| f['href'] }
      followers.each do |follower|
        @driver.navigate.to follower
        sleep 5
        view_current_stories
        set_likes_comments
      end
    end

    def self.set_likes_comments
      O14::ProjectLogger.get_logger.debug 'set_likes_comments function start'
      posts = @driver.find_elements(css: 'main article div._aabd') rescue []
      O14::ProjectLogger.get_logger.debug "Posts found: #{posts.count}"

      posts.first(O14::Config.get_config.count_last_posts_process).each do |post|
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
        comment_input.send_keys get_comment_message#, :return
        sleep 3
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

    def self.get_comment_message
      comment_parts = O14::Config.get_config.comment_text_parts
      comment_text = comment_parts.map{ |part| part.split('|').sample }.join.strip

      comment_text
    end

    def self.login
      dialog_process

      login_input = @driver.find_element(css: 'input[name=\'username\'')
      login_input.click
      sleep 1

      login_input.send_keys O14::Config.get_config.login_data['login']
      sleep 1

      password_input = @driver.find_element(css: 'input[name=\'password\'')
      password_input.click
      sleep 1

      password_input.send_keys O14::Config.get_config.login_data['password']
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

    def self.send_direct_message nickname
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
