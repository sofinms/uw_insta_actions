require 'sequel'

module O14
    module DB
        def self.get_db
            @@db ||= begin
                config = O14::Config.get_config
                db = Sequel.connect(
                    adapter: :mysql2,
                    host: config.db['host'],
                    port: config.db['port'],
                    database: config.db['database'],
                    username: config.db['username'],
                    password: config.db['password'],
                    max_connections: 10,
                    encoding: 'utf8'
              )

              db.extension(:connection_validator)

              at_exit { disconnect }

              db
            end
        end

        def self.disconnect
            @@db.disconnect rescue nil
        end
    end
end
