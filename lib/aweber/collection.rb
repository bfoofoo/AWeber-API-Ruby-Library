module AWeber
  # Collection objects are groups of Resources. Collections imitate
  # regular Hashes in most ways. You can access Resource by +id+ via the
  # +[]+ method.
  #
  #    lists    #=> #<AWeber::Collection ...>
  #    lists[1] #=> #<AWeber::Resources::List @id=1 ...>
  #
  # Also like Hashes, you can iterate over all of it's entries
  #
  #    lists.each { |id, list| puts list.name }
  #
  # Collections support dynamic +find_by_*+ methods, where +*+ is an
  # attribute and the first and only parameter is the value.
  #
  #    lists.find_by_name("testlist")
  #    #=> #<AWeber::Resources::List @id=123, @name="testlist" ...>
  #
  # +find_by_*+ methods will also return a Hash of entries if more than
  # one matches the criteria. The hash will be keyed by resource ID.
  #
  #    messages.find_by_total_opens(0)
  #    #=> { "45697" => #<Message>, "12345" => #<Message> }
  #
  # Collections are paginated in groups of 100.
  #
  class Collection < Resource
    include Enumerable

    attr_accessor :entries
    attr_reader   :next_collection_link
    attr_reader   :prev_collection_link
    attr_reader   :resource_type_link
    attr_reader   :total_size
    attr_reader   :parent

    alias_method :size,   :total_size
    alias_method :length, :total_size

    # @param [AWeber::Base] client    Instance of AWeber::Base
    # @param [Class] klass            Class to create entries of
    # @param [Hash]  data             JSON decoded response data Hash
    #
    def initialize(client, klass, data={})
      super client, data
      @client  = client
      @klass   = klass
      @entries = {}
      create_entries(data["entries"]) if data.include?("entries")
      @_entries = @entries.to_a
    end

    def search(params={})
      if params.has_key?('custom_fields')
        if params['custom_fields'].is_a?(Hash)
          params['custom_fields'] = params['custom_fields'].to_json
        end
      end

      if params.has_key?('tags') && params['tags'].is_a?(Array)
        params['tags'] = params['tags'].to_json
      end

      uri      = "#{path}?ws.op=find&#{params.to_query}"
      response = client.get(uri)

      return response if response.is_a?(Integer)

      if response['entries']
        response.merge!(:parent => parent)
        response["total_size"] ||= response["entries"].size

        self.class.new(client, @klass, response)
      elsif response.dig('error', 'status') == 503
        raise ServiceUnavailableError, response.dig('error', 'message'), caller
      else
        raise UnknownRequestError, response.dig('error', 'message') || response.inspect, caller
      end
    end

    def create(attrs={})
      params = attrs.merge("ws.op" => "create")

      if params.has_key?('custom_fields')
        if params['custom_fields'].is_a?(Hash)
            params['custom_fields'] = params['custom_fields'].to_json
        end
      end

      if params.has_key?('tags')
        if params['tags'].is_a?(Array)
            params['tags'] = params['tags'].to_json
        end
      end

      response = client.post(path, params)

      if response.is_a? Net::HTTPCreated
        resource = get(response["location"]).merge(:parent => self)
        resource = @klass.new(client, resource)

        self[resource.id] = resource
      else
        if response
            raise CreationError, JSON.parse(response.body)['error']['message'], caller
        else
            raise CreationError, "No response received", caller
        end
      end
    end

    def [](id)
      @entries[id] ||= fetch_entry(id)
    end

    def []=(key, resource)
      @entries[key] = resource
    end

    def each
      (1..@total_size).each { |n| yield get_entry(n) }
    end

    def each_page
      current_page = self
      yield(current_page)
      while current_page.next_collection_link
        begin
          retries = 0
          current_page = self.class.new(client, @klass, get(current_page.next_collection_link))
        rescue AWeber::UnknownRequestError => e
          retries += 1
          retry if e.to_s == 'Invalid/used nonce' && retries < 2
        rescue AWeber::ServiceUnavailableError
          retries += 1
          retry if retries < 2
        end
        yield(current_page)
      end
    end

    def inspect
      "#<AW::Collection(#{@klass.to_s}) size=\"#{size}\">"
    end

    def path
      parent and parent.path.to_s + @klass.path.to_s or @klass.path.to_s
    end

  private

    def create_entries(entries)
      entries.each do |entry|
        @entries[entry["id"]] = @klass.new(client, entry.merge(:parent => self))
      end
    end

    def get_entry(n)
      @_entries += fetch_next_group if needs_next_group?(n)
      @_entries[n-1]
    end

    def fetch_entry(id)
      @klass.new(client, get("#{path}/#{id}").merge(:parent => self))
    end

    def fetch_next_group()
      path = "#{ base_path }?ws.start=#{ @_entries.size }"
      self.class.new(client, @klass, get(path)).entries.to_a
    end

    def needs_next_group?(current_index)
      current_index == @_entries.size && current_index != @total_size
    end

    def base_path
      URI.parse(@next_collection_link).path if @next_collection_link
    end

    def find_by(_attr, *args)
      matches = select { |id, e| e.send(_attr) == args.first }
      matches = matches.first.last if matches.size == 1
      matches
    end

    def method_missing(method, *args)
      method.to_s.scan /^find_by_(.+)/ do |_attr|
        return find_by(_attr.first, *args)
      end
      super
    end

    def client
      @client
    end

  end
end
