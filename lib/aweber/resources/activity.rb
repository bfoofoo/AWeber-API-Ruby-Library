module AWeber
  module Resources
    class Activity < Resource
      basepath '/activity'

      api_attr :type
      api_attr :event_time
      api_attr :subscriber_link
    end
  end
end
