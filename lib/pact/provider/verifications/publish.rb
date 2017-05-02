require 'json'
require 'pact/errors'

module Pact
  module Provider
    module Verifications

      class PublicationError < Pact::Error; end

      class Publish

        def self.call pact_source, verification
          new(pact_source, verification).call
        end

        def initialize pact_source, verification
          @pact_source = pact_source
          @verification = verification
        end

        def call
          if Pact.configuration.provider.publish_verifications?
            if publication_url
              publish
            else
              puts "WARNING: Cannot publish verification for #{consumer_name} as there is no link named pb:publish-verification in the pact JSON. If you are using a pact broker, please upgrade to version 2.0.0 or later."
            end
          end
        end

        private

        def publication_url
          @publication_url ||= pact_source.pact_hash.fetch('_links', {}).fetch('pb:publish-verification', {})['href']
        end

        def publish
          #TODO https
          #TODO username/password
          uri = URI(publication_url)
          request = build_request(uri)
          response = nil
          begin
            response = Net::HTTP.start(uri.host, uri.port) do |http|
              http.request request
            end
          rescue StandardError => e
            error_message = "Failed to publish verification due to: #{e.class} #{e.message}"
            raise PublicationError.new(error_message)
          end

          unless response.code.start_with?("2")
            raise PublicationError.new("Error returned from verification publication #{response.code} #{response.body}")
          end
        end

        def build_request uri
          request = Net::HTTP::Post.new(uri.path)
          request['Content-Type'] = "application/json"
          request.body = verification.to_json
          debug_uri = uri
          if pact_source.uri.basic_auth?
            request.basic_auth pact_source.uri.username, pact_source.uri.password
            debug_uri = URI(uri.to_s).tap { |x| x.userinfo="#{pact_source.uri.username}:*****"}
          end
          puts "Publishing verification #{verification.to_json} to #{debug_uri}"
          request
        end

        def consumer_name
          pact_source.pact_hash['consumer']['name']
        end

        attr_reader :pact_source, :verification
      end
    end
  end
end
