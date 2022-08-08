require 'elasticsearch'

module O14
  module EsClient
    def self.get_es_client config = nil
      if config
        @@es_client = Elasticsearch::Client.new host: "#{config[:host]}:#{config[:port]}"
      end

      @@es_client
    end
  end # EsClient
end # O14
