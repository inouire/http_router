require 'set'
require 'rack'
require 'http_router/node'
require 'http_router/request'
require 'http_router/response'
require 'http_router/route'
require 'http_router/path'
require 'http_router/regex_route'
require 'http_router/optional_compiler'

class HttpRouter
  
  attr_reader :root, :routes, :known_methods, :named_routes
  attr_accessor :default_app

  UngeneratableRouteException = Class.new(RuntimeError)
  InvalidRouteException       = Class.new(RuntimeError)
  MissingParameterException   = Class.new(RuntimeError)

  def initialize(opts = nil, &blk)
    reset!
    @ignore_trailing_slash = opts && opts.key?(:ignore_trailing_slash) ? opts[:ignore_trailing_slash] : true
    @handle_unavailable_route  = Proc.new{ raise UngeneratableRouteException }
    instance_eval(&blk) if blk
  end

  def add(path, opts = {}, &app)
    route = case path
    when Regexp
      RegexRoute.new(self, path, opts)
    else
      Route.new(self, path, opts)
    end
    @routes << route
    route.to(app) if app
    route
  end

  def add_with_request_method(path, method, opts = {}, &app)
    route = add(path, opts).send(method.to_sym)
    route.to(app) if app
    route
  end

  [:post, :get, :delete, :put, :head].each do |rm|
    class_eval "def #{rm}(path, opts = {}, &app); add_with_request_method(path, #{rm.inspect}, opts, &app); end", __FILE__, __LINE__
  end

  def recognize(env)
    call(env, false)
  end

  def call(env, perform_call = true)
    rack_request = Rack::Request.new(env)
    request = Request.new(rack_request.path_info, rack_request, perform_call)
    response = catch(:success) {
      @root[request]
    }
    response = request.matched_paths if !perform_call && !request.matched_paths.empty?
    if !response && env['router.request_miss']
      supported_methods = (@known_methods - [env['REQUEST_METHOD']]).select do |m| 
        test_env = Rack::Request.new(rack_request.env.clone)
        test_env.env['REQUEST_METHOD'] = m
        request = Request.new(test_env.path_info, Rack::Request.new(test_env), false)
        @root[request]
        request.matched_paths
      end
      [405, {'Allow' => supported_methods.sort.join(", ")}, []]
    elsif response
      response
    else
      @default_app.call(env)
    end
  end
  
  def reset!
    @root = Node.new(self)
    @default_app = Proc.new{ |env| Rack::Response.new("Your request couldn't be found", 404).finish }
    @routes = []
    @named_routes = {}
    @known_methods = Set.new
  end

  def url(route, *args)
    case route
    when Symbol then url(@named_routes[route], *args)
    when Route  then route.url(*args)
    end
  end

  def ignore_trailing_slash?
    @ignore_trailing_slash
  end

  def append_querystring(uri, params)
    if params && !params.empty?
      uri_size = uri.size
      params.each do |k,v|
        case v
        when Array
          v.each { |v_part| uri << '&' << ::Rack::Utils.escape(k.to_s) << '%5B%5D=' << ::Rack::Utils.escape(v_part.to_s) }
        else
          uri << '&' << ::Rack::Utils.escape(k.to_s) << '=' << ::Rack::Utils.escape(v.to_s)
        end
      end
      uri[uri_size] = ??
    end
    uri
  end
end
