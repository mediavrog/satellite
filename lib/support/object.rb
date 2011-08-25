unless Object.const_defined?("ActiveSupport")
  class Object
    def to_query(key)
      require 'cgi' unless defined?(CGI) && defined?(CGI::escape)
      "#{CGI.escape(key.to_s).gsub(/%(5B|5D)/n) { [$1].pack('H*') }}=#{CGI.escape(to_param.to_s)}"
    end

    def to_param
      to_s
    end

    def try(method, *args, &block)
      begin
        send(method, *args, &block)
      rescue
        nil
      end
    end
  end

  class Hash
    def to_param(namespace = nil)
      collect do |key, value|
        value.to_query(namespace ? "#{namespace}[#{key}]" : key)
      end.sort * '&'
    end

    alias_method :to_query, :to_param
  end
end