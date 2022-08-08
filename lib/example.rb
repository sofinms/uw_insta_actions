module Parser
  class Example
    def self.run (log_level = 'ERROR', log_filename = nil)
      @driver = O14::WebBrowser.get_driver

      @driver.navigate.to 'https://instagram.com'
      sleep 4
      dialog_process

      login if need_login?

      settings = O14::Config.get_config.settings_data

      settings['stories'].each { |nickname| view_stories nickname }
      settings['direct'].each { |nickname| send_direct_message nickname }
      settings['like_comment'].each { |nickname| like_comment nickname }

      sleep 60
    end

    def self.login
      dialog_process

      login_input = @driver.find_element(css: 'input[name=\'username\'')
      login_input.click
      sleep 1

      login_input.send_keys O14::Config.get_config.insta['login']
      sleep 1

      password_input = @driver.find_element(css: 'input[name=\'password\'')
      password_input.click
      sleep 1

      password_input.send_keys O14::Config.get_config.insta['password']
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

    def self.view_stories nickname
      @driver.navigate.to "https://www.instagram.com/#{nickname}/"
      sleep 4

      stories_btn = @driver.find_element(css: 'main[role=\'main\'] div[role=\'button\']') rescue nil

      return false if stories_btn.nil?

      stories_btn.click
      sleep 15

      @driver.find_element(css: 'svg[aria-label=\'Close\']')&.click
      sleep 3
    end

    def self.like_comment nickname
      @driver.navigate.to "https://www.instagram.com/#{nickname}/"
      sleep 4

      last_post = @driver.find_elements(css: 'main article div._aabd').first rescue nil
      if last_post.nil?
        puts 'Dont find last post!'
        return false
      end

      last_post.click
      sleep 3
      @driver.find_elements(css: 'section._aamu button').first.click
      sleep 1
      comment_input = @driver.find_element(css: 'form._aao9>textarea')
      comment_input.click
      comment_input = @driver.find_element(css: 'form._aao9>textarea')
      comment_input.send_keys 'You are amazing!', :return
      sleep 3
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
