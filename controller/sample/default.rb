#!/usr/local/bin/ruby
# -*- coding: utf-8 -*-

module Sample
  
  # created when request.params["mode"] is not inputed.
  class Default
    def initialize
    end
    
    def run(request)
      @time = Time.now
    end
    
    def response(request)
      erb = ERB.new(File.open("erb/sample/default.html.erb", "r:utf-8") {|f| f.read}, nil, "-")
      erb.result(binding)
    end
  end
  
  # created when request.params["mode"] is "showday".
  class Showday
    def initialize
    end
    
    def run(request)
      @day = Time.now.day
    end
    
    def response(request)
      erb = ERB.new(File.open("erb/sample/showday.html.erb", "r:utf-8") {|f| f.read}, nil, "-")
      erb.result(binding)
    end
  end
  
end