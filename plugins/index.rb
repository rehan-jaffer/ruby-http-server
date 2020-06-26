module HTTPServer

  module Plugins
    
    class Index
      def self.exec(req)

        if req.uri == "/"
          req.uri = "/index.html"
        end
        req

      end
    end

  end

end
