#!/usr/local/bin/ruby
# -*- coding: utf-8 -*-

# please write "Sample.cgi"'s logic (for using web-application)

module Sample
  class Logic
    def self.get_time
      Time.now
    end
    
    def self.get_day
      Time.now.dayF
    end
  end
end