module AWeber
  module Resources
    class Subscriber < Resource
      basepath "/subscribers"

      api_attr :name,          :writable => true
      api_attr :misc_notes,    :writable => true
      api_attr :email,         :writable => true
      api_attr :status,        :writable => true
      api_attr :custom_fields, :writable => true
      api_attr :ad_tracking,   :writable => true
      api_attr :tags,          :writable => true
      api_attr :last_followup_message_number_sent, :writable => true

      api_attr :ip_address
      api_attr :is_verified
      api_attr :last_followup_sent_at
      api_attr :subscribed_at
      api_attr :subscription_method
      api_attr :subscription_url
      api_attr :unsubscribed_at
      api_attr :verified_at
      api_attr :last_followup_sent_link

      has_one :last_followup_sent

      alias_attribute :is_verified?, :is_verified
      alias_attribute :notes, :misc_notes

      def list=(list)
        client.post(self_link, {
          "ws.op"     => "move",
          "list_link" => list.self_link
        })
        move_to(list)
      end

      def move(list, last_followup_sent=nil)
        move_args = {
                      "ws.op"     => "move",
                      "list_link" => list.self_link
                    }

        if last_followup_sent
          move_args['last_followup_message_number_sent'] = last_followup_sent
        end

        r = client.post(self_link, move_args)
        move_to(list)
      end

      def activity(params = {})
        params   = params.to_query
        uri      = "#{self_link}?ws.op=getActivity&#{params}"
        response = client.get(uri).merge(parent: self)

        Collection.new(client, Activity, response)
      end

      def update(attrs={})
        client.patch(self_link, attrs)
      end

    private

      def move_to(list)
        old_list = self_link.match(%r[lists/(\d+)/])[1]
        client.account.lists[old_list.to_i].subscribers[id] = nil
        list.subscribers[id] = self
      end
    end
  end
end
