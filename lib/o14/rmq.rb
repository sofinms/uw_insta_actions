require 'bunny'
require 'json'
require 'timeout'

module O14
	module RMQ
		def self.get_channel
			@@ch ||= begin
				config = O14::Config.get_config

				conn = Bunny.new host: config.rmq['host'], port: config.rmq['port'], user: config.rmq['username'], pass: config.rmq['password'], vhost: config.rmq['vhost']
				conn.start
				ch = conn.create_channel
				ch.prefetch(1)

		  	at_exit { ch.close rescue nil }

		  	ch
			end
		end
		
		def self.call_api queue_name, options
	      rabbitmq_conf = O14::Config.get_config.rmq
	      conn = Bunny.new host: rabbitmq_conf['host'], port: rabbitmq_conf['port'], user: rabbitmq_conf['username'], pass: rabbitmq_conf['password'], vhost: rabbitmq_conf['vhost']
	      conn.start
	
	      ch       = conn.create_channel
	      client   = TranslaterClient.new(ch, queue_name)
	
	      response = nil
	
          Timeout::timeout(60) {
	          puts options
            response = JSON.parse(client.call(options))
          }
	      ch.close
	      conn.close
	
	      response
	    end
	end # RMQ
	
	class TranslaterClient
	    attr_reader :reply_queue
	    attr_accessor :response, :call_id
	    attr_reader :lock, :condition
	
	    def initialize(ch, server_queue)
	      @ch = ch
	      @x = ch.default_exchange
	
	      @server_queue   = server_queue
	      @reply_queue    = ch.queue('', exclusive: true)
	
	
	      @lock      = Mutex.new
	      @condition = ConditionVariable.new
	      that       = self
	
	      @reply_queue.subscribe do |delivery_info, properties, payload|
	        if properties[:correlation_id] == that.call_id
	          that.response = payload
	          that.lock.synchronize { that.condition.signal }
	        end
	      end
	    end
	
	    def call(options)
	      self.call_id = self.generate_uuid(options[:data][:domain] + '#')
	
	      @x.publish(
	        options.to_json,
	        routing_key: @server_queue,
	        correlation_id: call_id,
	        reply_to: @reply_queue.name)
	
	      lock.synchronize { condition.wait(lock) }
	      response
	    end
	
	    def suggest(options)
	      self.call_id = self.generate_uuid(options['data']['domain'] + '#')
	
	      @x.publish(
	        options.to_json,
	        :routing_key    => @server_queue,
	        :correlation_id => call_id,
	        :reply_to       => @reply_queue.name
	      )
	
	      lock.synchronize { condition.wait(lock) }
	      response
	    end
	
	    protected
	
	    def generate_uuid text
	      Digest::MD5.hexdigest(text)
	    end
	  end # TranslaterClient
end
