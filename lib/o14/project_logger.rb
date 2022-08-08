require 'logger'

module O14
  module ProjectLogger
    def self.get_logger(log_level = 'ERROR', log_filename = nil)
      @logger ||= begin
        logger = log_filename.nil? ? Logger.new($stdout) : Logger.new(File.join(__dir__, '..', 'logs', log_filename), 10, 10_240_000)
        logger.datetime_format = '%Y-%m-%d %H:%M:%S'
        logger.formatter = proc do |severity, datetime, _, msg|
          "#{severity} #{datetime}: #{msg}\n"
        end

        level = get_log_level_by_str log_level
        logger.level = level
        logger
      end
    end

    def self.get_log_level_by_str(log_level)
      level = case log_level
        when 'INFO'
          Logger::INFO
        when 'WARN'
          Logger::WARN
        when 'DEBUG'
          Logger::DEBUG
        else
          Logger::ERROR
        end
      return level
    end
  end
end
