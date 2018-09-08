module AWeber
  module Resources
    class Activity < Resource
      basepath '/activity'

      api_attr :type
      api_attr :event_time
      api_attr :subscriber_link

      def event
        return nil unless %w(open click).include?(type)
        response = client.get(self_link)

        type_class = AWeber::Resources.const_get(type.classify)
        type_class.new(client, response)
      end

      def message
        match = self_link.match(/^(.*?)messages\/\d+/)
        return nil unless match
        url = match[0]
        response = client.get(url)
        Message.new(client, response)
      end

      def campaign
        match = self_link.match(/^(.*?)campaigns\/[bf]\d+/)
        return nil unless match
        url = match[0]
        response = client.get(url)
        Campaign.new(client, response)
      end
    end
  end
end
