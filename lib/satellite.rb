require 'open-uri'

# stub some ActiveSupport functionality
unless Object.const_defined?("ActiveSupport")
  Dir.glob(File.dirname(__FILE__) + '/support/*') { |file| require file }
end

# load tracking adapters
Dir.glob(File.dirname(__FILE__) + '/satellite/adapters/*') { |file| require file }

module Satellite

  class NoAdapterError < NameError
  end

  class TrackerInterface
    def initialize(adapter)
      @adapter = adapter
    end

    def track_page_view(path=nil)
      @adapter.track_page_view(path)
    end

    def track_event(category, action, label=nil, value=nil)
      @adapter.track_event(category, action, label, value)
    end

    def set_custom_variable(slot, name, value, scope=nil)
      @adapter.set_custom_variable(slot, name, value, scope)
    end

    def unset_custom_variable(slot)
      @adapter.unset_custom_variable(slot)
    end

    def []=(key, value)
      @adapter[key] = value
    end

    def [](key)
      @adapter[key]
    end
  end

  def self.get_tracker(type, params = { })
    begin
      tracker_klass = "Satellite::Adapters::#{type.to_s.camelcase}".constantize
    rescue
      raise NoAdapterError, "There is no such adapter like 'Satellite::Adapters::#{type.to_s.camelcase}'"
    end

    TrackerInterface.new(tracker_klass.new(params))
  end

end