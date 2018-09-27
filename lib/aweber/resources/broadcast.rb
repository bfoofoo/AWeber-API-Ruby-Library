module AWeber
  module Resources
    class Broadcast < Resource
      basepath "/broadcasts"
      
      api_attr :sent_at
      api_attr :body_text
      api_attr :body_html
      api_attr :broadcast_id
      api_attr :archive_link
      api_attr :notify_on_send
      api_attr :include_lists
      api_attr :exclude_lists
      api_attr :stats
      api_attr :scheduled_for
      api_attr :status
      api_attr :self_link
      api_attr :subject
      api_attr :is_archived
      api_attr :click_tracking_enabled
      api_attr :created_at

      alias_attribute :is_archived?, :is_archived
      alias_attribute :is_click_tracking_enabled?, :click_tracking_enabled

      def id
        matches = self_link.match(/broadcasts\/(\d+)\Z/)
        matches[1] if matches
      end

      def list_ids
        include_lists.map do |list|
          matches = list.match(/lists\/(\d+)\Z/)
          matches[1] if matches
        end.compact
      end

      def detailed
        response = client.get(self_link)
        Broadcast.new(client, response)
      end
    end
  end
end
