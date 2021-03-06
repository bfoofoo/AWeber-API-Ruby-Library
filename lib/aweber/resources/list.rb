module AWeber
  module Resources
    class List < Resource
      basepath "/lists"
      
      FOLLOWUP_TYPE_LINK  = File.join(AWeber.api_url, "#followup_campaign")
      BROADCAST_TYPE_LINK = File.join(AWeber.api_url, "#broadcast_campaign")
      
      api_attr :name
      api_attr :unique_list_id

      api_attr :campaigns_collection_link
      api_attr :subscribers_collection_link
      api_attr :web_forms_collection_link
      api_attr :web_form_split_tests_collection_link
      api_attr :custom_fields_collection_link
      
      has_many :campaigns
      has_many :custom_fields
      has_many :subscribers
      has_many :web_forms
      has_many :web_form_split_tests
      
      def initialize(*args)
        super(*args)
        @followups  = nil
        @broadcasts = nil
      end

      def broadcasts(status)
        return @broadcasts if @broadcasts

        response = client.get("#{self_link}/broadcasts?status=#{CGI.escape(status)}").merge(parent: self)
        Collection.new(client, Broadcast, response)
      end

      def broadcast(id)
        response = client.get("#{self_link}/broadcasts/#{CGI.escape(id)}").merge(parent: self)
        Broadcast.new(client, response)
      end

      def search_broadcast_campaigns
        return @broadcast_campaigns if @broadcast_campaigns

        response = client.get("#{self_link}/campaigns?campaign_type=b").merge(parent: self)
        Collection.new(client, Campaign, response)
      end

      def find_subscribers(attrs={})
        params = attrs.merge("ws.op" => "find")
        if params.has_key?('custom_fields')
          if params['custom_fields'].is_a?(Hash)
            params['custom_fields'] = params['custom_fields'].to_json
          end
        end

        uri      = "#{self_link}/subscribers?#{params.to_query}"
        response = client.get(uri).merge(:parent => self)
        raise AWeber::NotFoundError unless response['entries']
        response["total_size"] ||= response["entries"].size

        Collection.new(client, Subscriber, response)
      end

      def followups
        return @followups if @followups

        @followups = AWeber::Collection.new(client, Campaign, :parent => self)
        @followups.entries = Hash[campaigns.select { |id, c| c.is_followup? }]
        @followups
      end
    end
  end
end
