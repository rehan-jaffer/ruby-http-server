require 'pp'
require 'socket'

module HttpServer

  class Server

    def initialize(host, port, outputter=HttpServer::ConsoleOutput.new)
      @host = host
      @port = port
      @outputter = outputter
    end

    def start!
      @server = TCPServer.new @host, @port   

      @outputter.greeting(@host, @port)

      loop do
        Thread.start(@server.accept) do |client|
          @outputter.new_connection(client)
          HttpServer::Request.new(client, @outputter).handle
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

    def print(msg)
      puts msg
    end
  end

  class Response

    attr_accessor :response_code, :headers, :content

    def initialize
    end

    def to_s
      "HTTP/1.1 200 OK\r\n\r\n#{@content}"
    end

  end

  class Request
    def initialize(client, outputter)
      @client = client
      @outputter = outputter
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
     req = HTTPRequest.new(raw_request)
     req.parse!
     req
   end

    def get(request)
      file = File.read("public" + request.uri).to_s
      @client.puts("HTTP/1.1 200 OK\r\n")
      @client.puts("\r\n")
      @client.puts(file)
      @client.close
    end

    def handle
      raw_request = get_request
      parsed_request = parse_request(raw_request)
      case parsed_request.type
        when "GET"
          get(parsed_request)
        else
          raise UnsupportedRequestType, "#{parsed_request.type} is not yet supported"
      end
    end
  end

  class HTTPRequest

    attr_reader :headers, :uri, :type

    def initialize(raw_request)
      @raw_request = raw_request
    end

    def parse!
      parse_request_line
      parse_headers
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
