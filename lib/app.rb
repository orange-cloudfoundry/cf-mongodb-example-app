require 'sinatra'
require 'mongo'

class MongodbExampleApp < Sinatra::Base
  before do
    content_type "text/plain"

    if mongodb_service_not_bound_to_app?
      halt(500, bind_mongodb_service_to_app_instructions)
    end
  end

  #error do |exception|
  #  halt(500, exception.message)
  #end

  post '/:collection_name' do
    mongodb_client.create_collection(params[:collection_name])
    status 200
  end

  delete '/:collection_name' do
    mongodb_client.drop_collection(params[:collection_name])
    status 200
  end

  private

  def bind_mongodb_service_to_app_instructions
    %{
      You must bind a MongoDB service instance to this application.

      You can run the following commands to create an instance and bind to it:

        $ cf create-service mongodb default mongodb-instance
        $ cf bind-service app-name mongodb-instance
    }
  end

  def mongodb_client
    @mongodb_client ||= begin
      require 'mongodb_client'
      MongodbClient.new(connection_details: mongodb_connection_details)
    end
  end

  def mongodb_connection_details
    @mongodb_connection_details ||= begin
      require "cf-app-utils"
      CF::App::Credentials.find_all_by_all_service_tags(%w[mongodb]).first
    end
  end

  def mongodb_service_not_bound_to_app?
    !mongodb_connection_details
  end
end
