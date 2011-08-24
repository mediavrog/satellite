module Satellite
  module Controllers
    class GoogleAnalyticsController

      def tracker
        @tracker ||= Satellite.get_tracker(:google_analytics, ga_params)
      end

      protected

      def ga_visitor_id
        "#{request.env["HTTP_USER_AGENT"]}#{rand(0x7fffffff).to_s}"
      end

      def ga_params
        # domain specific stuff
        domain_name = (request.env["SERVER_NAME"].nil? || request.env["SERVER_NAME"].blank?) ? "" : request.env["SERVER_NAME"]
        referral = request.env['HTTP_REFERER'] || ''
        path = request.env["REQUEST_URI"] || ''

        # Capture the first three octects of the IP address and replace the forth
        # with 0, e.g. 124.455.3.123 becomes 124.455.3.0
        remote_address = request.env["REMOTE_ADDR"].to_s
        ip = (remote_address.nil? || remote_address.blank?) ? '' : remote_address.gsub!(/([^.]+\.[^.]+\.[^.]+\.)[^.]+/, "\\1") + "0"

        visitor_uuid = Digest::MD5.hexdigest(ga_visitor_id)

        {
            :utmhn => CGI.escape(domain_name),
            :utmr => CGI.escape(referral),
            :utmp => CGI.escape(path),
            :utmip => ip,
            :utmcc => '__utma%3D999.999.999.999.999.1%3B',
            :utmvid => visitor_uuid
        }
      end
    end
  end
end