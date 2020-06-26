require 'date'
require 'pp'
require 'socket'
require './plugins'

module HttpServer

  class PluginLoader
    attr_accessor :request, :response

    def initialize
      @request = [HTTPServer::Plugins::Index]
      @response = []
    end
  end

  class Server

    def initialize(host, port, outputter=HttpServer::ConsoleOutput.new)
      @host = host
      @port = port
      @outputter = outputter
      @plugins = PluginLoader.new
    end

    def start!
      @server = TCPServer.new @host, @port   

      @outputter.greeting(@host, @port)

      loop do
        Thread.start(@server.accept) do |client|
          @outputter.new_connection(client)
          HttpServer::Request.new(client, @outputter, @plugins).handle
        end
      end
    rescue Errno::EACCES => e
      puts "Couldn't bind to socket"
    end

  end

  class ConsoleOutput
    def greeting(host, port)
      puts "* [ HTTPServe v0.1 ]"
      puts "* Starting HTTP Server (#{host}:#{port})"
    end

    def new_connection(client)
      puts "* New connection from #{client.addr[2]}"
    end

    def log(request, response)
      puts "[#{DateTime.now()}] - #{request.type} #{request.uri} - #{response.response_code}"
    end

    def print(msg)
      puts msg
    end
  end

  class Response

    attr_accessor :response_code, :headers, :content

    def initialize(response_code:, content:)
      @response_code = response_code
      @content = content
    end

    def code_text(number)
      {
        200 => "OK",
        404 => "Not Found"
       }[number]
    rescue StandardError => e
      "Unknown"
    end

    def to_s
      "HTTP/1.0 #{@response_code} #{code_text(@response_code)}\r\n\r\n#{@content}"
    end

  end

  class GetRequest

    def initialize(request:, client:, outputter:)
      @request = request
      @client = client
      @outputter = outputter
    end

    def handle
      file = File.read("public" + @request.uri).to_s
      response = Response.new(response_code: 200, content: file)
      @outputter.log(@request, response)
      @client.puts(response.to_s)
      @client.close
    rescue Errno::ENOENT => e
      response = Response.new(response_code: 404, content: "")
      @outputter.log(@request, response)
      @client.puts(response.to_s)
      @client.close
    end
  end

  class Request

    def initialize(client, outputter, plugins)
      @client = client
      @outputter = outputter
      @plugins = plugins
    end

    def get_request
      req = []
      loop do
        req << @client.gets
        break if req.last == "\r\n"
      end
      req
    end

   def parse_request(raw_request)
     HTTPRequestParser.new(raw_request).parse!
   end

    def handle
      raw_request = get_request
      parsed_request = parse_request(raw_request)

      final_request = @plugins.request.reduce(parsed_request) do |transformed_request, plugin|
        transformed_request = plugin.exec(transformed_request)
      end

      case parsed_request.type
        when "GET"
          GetRequest.new(request: final_request, client: @client, outputter: @outputter).handle
        else
          raise UnsupportedRequestType, "#{parsed_request.type} is not yet supported"
      end
    end
  end

  HTTPRequest = Struct.new(:headers, :uri, :type)

  class HTTPRequestParser

    def initialize(raw_request)
      @raw_request = raw_request
    end

    def parse!
      parse_request_line
      parse_headers
      HTTPRequest.new(@headers, @uri, @type)
    end

    def parse_request_line
     request = @raw_request[0].split(" ")
     @uri = request[1]
     @type = request[0]
    end

    def parse_headers
       @headers = @raw_request[1..@raw_request.size-2].map do |header|
         separator_index = header.index(':')
         [header[0, separator_index], header[separator_index+2, header.size-separator_index-4]]
       end.to_h    
    end

    def to_s
      "* Incoming Request\n\tRequest Type: #{@type}\n\tURI: #{@uri}\n\tHeaders:\n" + @headers.each_pair.map { |k,v| "\t\t#{k} => #{v}" }.join("\n")
    end
  end

end

server = HttpServer::Server.new("localhost", 8000)
server.start!
