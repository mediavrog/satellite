module Satellite
  module Adapters
    class GoogleAnalytics

      attr_accessor :debug, :user_agent, :accept_language

      def initialize(params, use_ssl=false)
        self.utm_params = extend_with_default_params(params)
        self.utm_location = (use_ssl ? 'https://ssl' : 'http://www') + UTM_GIF_LOCATION
      end

      def track
        utm_url = tracking_url

        #if (debug == true)
          puts "--------sending request to GA-----------------------"
          puts utm_params.inspect
          puts utm_url
        #end

        # actually send request
        open(utm_url, { "User-Agent" => 'Satellite/0.1.1', "Accept-Language" => utm_params[:utmul] || 'de' })

        # reset events / custom variables here
        utm_params.delete(:utme)
        true
      end

      def tracking_url
        utm_location + "?" + utm_params.to_query
      end

      def track_event(category, action, label=nil, value=nil)
        utm_params[:utme].set_event(category, action, label, value)
        track
      end

      def track_page_view(path=nil)
        utm_params.merge({ :utmp => path }) if path
        track
      end

      def set_custom_variable(index, name, value, scope=nil)
        utm_params[:utme].set_custom_variable(index, name, value, scope)
      end

      def unset_custom_variable(index)
        utm_params[:utme].unset_custom_variable(index)
      end

      def []=(key, value)
        value = Utme.parse(value) if key.to_s == 'utme'
        utm_params[key] = value
      end

      def [](key)
        utm_params[key]
      end

      class << self
        attr_accessor :account_id
      end

      protected

      attr_accessor :utm_params, :utm_location

      private

      # seems to be the current version
      # search for 'utmwv' in http://www.google-analytics.com/ga.js
      VERSION = "4.4sh" #"5.1.5"
      UTM_GIF_LOCATION = ".google-analytics.com/__utm.gif"

      # adds default params
      def extend_with_default_params(params)
        utme = params.delete(:utme)
        {
            :utmac => self.class.account_id,
            :utmcc => '__utma%3D999.999.999.999.999.1%3B', # stub for non-existent cookie,
            :utmcs => 'UTF-8',
            :utme => Utme.parse(utme),
            :utmhid => rand(0x7fffffff).to_s,
            :utmn => rand(0x7fffffff).to_s,
            :utmvid => rand(0x7fffffff).to_s,
            :utmwv => VERSION,
            # should get configured when initializing
            #:utmhn => 'google-analytics.satellite.local',
            #:utmr => 'https://rubygems.org/gems/satellite',
            #:utmp => '/google-analytics',
            #:utmip => '127.0.0.1',
        }.merge(params)
      end

    end
  end
end

module Satellite
  module Adapters
    class GoogleAnalytics::Utme

      def initialize
        @custom_variables = CustomVariables.new
      end

      def set_event(category, action, label=nil, value=nil)
        @event = Event.new(category, action, label, value)
        self
      end

      def set_custom_variable(slot, name, value, scope=nil)
        @custom_variables.set_custom_variable(slot, CustomVariable.new(name, value, scope))
        self
      end

      def unset_custom_variable(slot)
        @custom_variables.unset_custom_variable(slot)
        self
      end

      def to_s
        @event.to_s + @custom_variables.to_s
      end

      alias_method :to_param, :to_s

      class << self

        @@regex_event = /5\((\w+)\*(\w+)(\*(\w+))?\)(\((\d+)\))?/
        @@regex_custom_variables = /8\(([^\)]*)\)9\(([^\)]*)\)(11\(([^\)]*)\))?/
        @@regex_custom_variable_value = /((\d)!)?([^\(\*]+)/

        def parse(args)
          return self.new if args.nil?
          case args
            when String
              return self.from_string(args.dup)
            when self
              return args
            else
              raise ArgumentError, "Could parse argument neither as String nor GATracker::Utme"
          end
        end

        def from_string(str)
          utme = self.new

          # parse event
          str.gsub!(@@regex_event) do |match|
            utme.set_event($1, $2, $4, $6)
            ''
          end

          # parse custom variables
          str.gsub!(@@regex_custom_variables) do |match|
            custom_vars = { }
            match_names, match_values, match_scopes = $1, $2, $4

            names = match_names.to_s.split('*')
            values = match_values.to_s.split('*')
            scopes = match_scopes.to_s.split('*')

            raise ArgumentError, "Each custom variable must have a value defined." if names.length != values.length

            names.each_with_index do |raw_name, i|
              match_data = raw_name.match(@@regex_custom_variable_value)
              slot, name = (match_data[2] || i+1).to_i, match_data[3]
              custom_vars[slot] = { :name => name }
            end

            values.each_with_index do |raw_value, i|
              match_data = raw_value.match(@@regex_custom_variable_value)
              slot, value = (match_data[2] || i+1).to_i, match_data[3]
              custom_vars[slot][:value] = value
            end

            scopes.each_with_index do |raw_scope, i|
              match_data = raw_scope.match(@@regex_custom_variable_value)
              slot, scope = (match_data[2] || i+1).to_i, match_data[3]
              # silently ignore scope if there's no corresponding custom variable
              custom_vars[slot][:scope] = scope if custom_vars[slot]
            end

            # finally set all the gathered custom vars
            custom_vars.each do |key, custom_var|
              utme.set_custom_variable(key, custom_var[:name], custom_var[:value], custom_var[:scope])
            end
            ''
          end

          utme
        end
      end

      private

      Event = Struct.new(:category, :action, :opt_label, :opt_value) do
        def to_s
          output = "5(#{category}*#{action}"
          output += "*#{opt_label}" if opt_label
          output += ")"
          output += "(#{opt_value})" if opt_value
          output
        end
      end

      CustomVariable = Struct.new(:name, :value, :opt_scope)

      class CustomVariables

        @@valid_keys = 1..5

        def initialize
          @contents = { }
        end

        def set_custom_variable(slot, custom_variable)
          raise ArgumentError, "Cannot set a slot other than #{@@valid_keys}. Given #{slot}" if not @@valid_keys.include?(slot)
          @contents[slot] = custom_variable
        end

        def unset_custom_variable(slot)
          raise ArgumentError, "Cannot unset a slot other than #{@@valid_keys}. Given #{slot}" if not @@valid_keys.include?(slot)
          @contents.delete(slot)
        end

        # follows google custom variable format
        #
        # 8(NAMES)9(VALUES)11(SCOPES)
        #
        # best explained by examples
        #
        # 1)
        # pageTracker._setCustomVar(1,"foo", "val", 1)
        # ==> 8(foo)9(bar)11(1)
        #
        # 2)
        # pageTracker._setCustomVar(1,"foo", "val", 1)
        # pageTracker._setCustomVar(2,"bar", "vok", 3)
        # ==> 8(foo*bar)9(val*vok)11(1*3)
        #
        # 3)
        # pageTracker._setCustomVar(1,"foo", "val", 1)
        # pageTracker._setCustomVar(2,"bar", "vok", 3)
        # pageTracker._setCustomVar(4,"baz", "vol", 1)
        # ==> 8(foo*bar*4!baz)9(val*vak*4!vol)11(1*3*4!1)
        #
        # 4)
        # pageTracker._setCustomVar(4,"foo", "bar", 1)
        # ==> 8(4!foo)9(4!bar)11(4!1)
        #
        def to_s
          return '' if @contents.empty?

          ordered_keys = @contents.keys.sort
          names = values = scopes = ''

          ordered_keys.each do |slot|
            custom_variable = @contents[slot]
            predecessor = @contents[slot-1]

            has_predecessor = !!predecessor
            has_scoped_predecessor = !!(predecessor.try(:opt_scope))

            star = names.empty? ? '' : '*'
            bang = (slot == 1 || has_predecessor) ? '' : "#{slot}!"

            scope_star = scopes.empty? ? '' : '*'
            scope_bang = (slot == 1 || has_scoped_predecessor) ? '' : "#{slot}!"

            names += "#{star}#{bang}#{custom_variable.name}"
            values += "#{star}#{bang}#{custom_variable.value}"
            scopes += "#{scope_star}#{scope_bang}#{custom_variable.opt_scope}" if custom_variable.opt_scope
          end

          output = "8(#{names})9(#{values})"
          output += "11(#{scopes})" if not scopes.empty?
          output
        end

      end
    end
  end
end