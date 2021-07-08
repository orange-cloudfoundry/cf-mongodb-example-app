require 'mongo'
require 'forwardable'

InvalidMongodbCredentialsException = Class.new(Exception)
MongodbUnavailableException = Class.new(Exception)
InvalidTableName = Class.new(Exception)
InvalidDatabaseName = Class.new(Exception)
CollectionDoesNotExistException = Class.new(Exception)
KeyNotFoundException = Class.new(Exception)

class MongodbClient < SimpleDelegator
  def initialize(args)
    @connection_details = args.fetch(:connection_details)
  end

  def create_collection(collection_name, require_collection = true)
    begin
      client = Mongo::Client.new(uri)
      #client = Mongo::Client.new("mongodb://<login>:<password>@<ip>/admin", direct_connection: true)
      #client = Mongo::Client.new("mongodb://<login>:<password>@<ip>/admin?directConnection=true")
      client[collection_name].create
    rescue Mongo::ConnectionFailure
      app.bind_mongodb_service_to_app_instructions
    ensure
      client.close if client
    end
  end

  def drop_collection(collection_name, require_collection = true)
    begin
      client = Mongo::Client.new(uri)
      #client = Mongo::Client.new("mongodb://<login>:<password>@<ip>/admin", direct_connection: true)
      #client = Mongo::Client.new("mongodb://<login>:<password>@<ip>/admin?directConnection=true")
      client[collection_name].drop
    rescue Mongo::ConnectionFailure
      app.bind_mongodb_service_to_app_instructions
    ensure
      client.close if client
    end
  end

  private

  attr_reader :connection_details

  def uri
    connection_details.fetch('uri')
  end

  def remapped_connection_details
    {
        uri: uri,
    }
  end
end
