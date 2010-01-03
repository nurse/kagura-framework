#!/usr/local/bin/ruby
# -*- coding: utf-8 -*-

require 'cgi'
require 'cgi/session'
require 'erb'
require 'pstore'
require 'logger'

CONTROLLER_DIR = 'controller'
LOGIC_DIR = 'logic'
PSTORE_DIR = 'work'
LOG_DIR = 'log'
NAMEERROR_ERB_PATH = 'erb/nameerror.html.erb'
MAX_LOG_SIZE = 300 * 1024
LOGGER_LEVEL = Object::Logger::DEBUG

#= Kagura Engine Namespace
module Kagura
  BASE_DIR = File.expand_path(File.dirname(__FILE__))
  
  #= Controller class
  class Controller
    def self.get_controller(script_name, controller_name)
      # create logger
      logger = Kagura::Logger.get_logger(script_name)
      logger.info("controller_name : #{controller_name}")
      logger.info("script_name : #{script_name}")
      
      # dynamic load (controller class)
      unless controller_name =~ /\A\w+\Z/
        logger.info("controller_name is bad value : #{controller_name}")
        raise NameError
      end
      
      logger.debug("working directory : #{BASE_DIR}")
      base_path = File.join(BASE_DIR, CONTROLLER_DIR, script_name)
      logger.debug("script controller directory : #{base_path}")
      Dir.foreach(base_path) do |fn|
        next unless File.extname(fn) == '.rb'
        logger.debug("controller file '#{fn}' is loaded")
        require File.join(base_path, fn)
      end
      
      # static load (common logic class)
      common_logic_path = File.join(BASE_DIR, LOGIC_DIR, "common.rb")
      logger.debug("common logic filepath : #{common_logic_path}")
      if File.exist?(common_logic_path)
        Kernel.require(common_logic_path)
      end
      
      # dynamic load (logic class)
      base_path = File.join(BASE_DIR, LOGIC_DIR, script_name)
      logger.debug("script logic directory : #{base_path}")
      if File.directory?(base_path)
        Dir.foreach(base_path) { |fn|
          next unless File.extname(fn) == '.rb'
          logger.debug("logic file '#{fn}' is loaded")
          require File.join(base_path, fn)
        }
      end
      
      # return (target) instance
      class_name = controller_name.camelize
      module_name = script_name.camelize
      logger.info("create instance : #{module_name}::#{class_name}.new")
      Object.const_get(module_name).const_get(class_name).new
    end
  end
  
  #= Request class
  class Request
    def initialize(cgi, session, params, *arg)
      @cgi = cgi
      @session = session
      @params = params
      @logger = Kagura::Logger.new
      
      # create pstore
      if arg[0] == true
        begin
          @temp = PStore.new(File.join(BASE_DIR, "work", @session.session_id + ".dat"))
        rescue
          File.delete(File.join(BASE_DIR, "work", @session.session_id + ".dat"))
          @temp = PStore.new(File.join(BASE_DIR, "work", @session.session_id + ".dat"))
        end
      end
    end
    
    attr_accessor :cgi, :session, :params, :temp
  end
  
  #= Logger class
  class Logger
    def self.get_logger(script_name)
      if File.exist?("#{LOG_DIR}/#{script_name}.log")
        status = File::stat("#{LOG_DIR}/#{script_name}.log")
        if status.size > MAX_LOG_SIZE
          File.rename("#{LOG_DIR}/#{script_name}.log", "#{LOG_DIR}/#{script_name}.bk.log")
        end
      end
      logger = Object::Logger.new("#{LOG_DIR}/#{script_name}.log")
      logger.level = LOGGER_LEVEL
      logger
    end
  end
  
  def self.main
    # initialize session & cgi params
    cgi = CGI.new
    session = CGI::Session.new(cgi)
    params = Hash[*cgi.params.to_a.map{|k, v| [k, v[0].to_s]}.flatten]
    request = Kagura::Request.new(cgi, session, params)
    logger = Kagura::Logger.get_logger(File.basename(cgi.script_name, ".*"))
    
    begin
      # get controller class name
      controller_name = params["mode"] ? params["mode"] : "default"
      # get instance
      action = Kagura::Controller.get_controller(File.basename(cgi.script_name, ".*"), controller_name)
    rescue NameError => evar
      response = String.new
      logger.debug("name error(message) : #{evar.message}")
      logger.debug("name error(backtrace) : #{evar.backtrace.join("\n")}")
      if File.exist?(NAMEERROR_ERB_PATH)
        erb = ERB.new(File.open(NAMEERROR_ERB_PATH, "r:utf-8") {|f| f.read}, nil, "-")
        response = erb.result(binding)
      else
        response << '<html><head><meta http-equiv="Content-Type" content="text/html; charset=UTF-8"><style>body { font-size: 12px; } div{ padding: 5px; }</style><title>Kagura Framework [EMERGENCY ERROR]</title></head><body>'
        response << '<table align="center"><tr><td style="width: 800px;">EMERGENCY ERROR OCCUR!<br><br>'
        response << 'STACKTRACE : <div style="color: #ff0000; border: 1px solid #ff6666">'
        response << ("%s: %s (%s)\n" % [evar.backtrace[0], evar.message, evar.send('class')]) + evar.backtrace[1..-1].join("<br>")
        response << '</td></tr></table></div></body></html>'
      end
      # output
      cgi.out { response }
      return
    end
    
    # action area
    begin
      # check require method
      if action.respond_to?('run') and action.respond_to?('request')
        raise NoMethodError
      end
      # request method execute
      action.run(request)
      # get response
      response = action.response(request)
    rescue => evar
      logger.error("emerge error(message) : #{evar.message}")
      logger.error("emerge error(backtrace) : #{evar.backtrace.join("\n")}")
      response = String.new
      response << '<html><head><meta http-equiv="Content-Type" content="text/html; charset=UTF-8"><style>body { font-size: 12px; } div{ padding: 5px; }</style><title>Kagura Framework [EMERGENCY ERROR]</title></head><body>'
      response << '<table align="center"><tr><td style="width: 800px;">EMERGENCY ERROR OCCUR!<br><br>'
      response << 'STACKTRACE : <div style="color: #ff0000; border: 1px solid #ff6666">'
      response << ("%s: %s (%s)\n" % [evar.backtrace[0], evar.message, evar.send('class')]) + evar.backtrace[1..-1].join("<br>")
      response << '</td></tr></table></div></body></html>'
    end
    
    # output
    cgi.out { response }
  end
  
  def self.run
    begin
      Kagura.main
    rescue => evar
      logger = Kagura::Logger.get_logger(File.basename(__FILE__, ".*"))
      logger.fatal("fatal error(message) : #{evar.message}")
      logger.fatal("fatal error(backtrace) : #{evar.backtrace.join("\n")}")
      puts "content-type: text/html\n\n<plaintext>\n" +
       ("%s: %s (%s)\n" % [evar.backtrace[0], evar.message, evar.send('class')]) +
      evar.backtrace[1..-1].join("<br>")
    end
  end
end

class String
  #= UpperCamelCase given string.
  #
  # Example(1) : sample -> Sample
  #        (2) : z -> Z
  #        (2) : camel_case -> CamelCase
  def self.camelize(str)
    gsub(/(?:\A|_)(\w)/){$1.upcase}
  end
end