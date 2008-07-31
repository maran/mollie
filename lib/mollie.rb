# mollie.rb: Library for sending SMS using the mollie.nl API
# author: Tom-Eric Gerritsen <tomeric@i76.nl>

require 'uri'
require 'net/http'
require 'hpricot'

module Mollie
  ##
  # == SMS ==
  #
  # The SMS class allows you to send multiple sms messages using a single
  # configuration. As an alternative, you can specify all settings as a hash
  # when initializing an object, or set the different settings after an object
  # is initialized using the setter methods.
  #
  # == Usage
  # require 'mollie'
  #
  # # sending a message to one receiver
  # sms = Mollie::SMS.new('username', 'password')
  # sms.originator = '0612345678'
  # sms.send('0687654321', 'Hello, this is an SMS!')
  #
  # # sending a message to multiple receivers
  # sms = Mollie::SMS.new('username', 'password')
  # sms.originator = '0612345678'
  # sms.send(['0687654321', '0612435687'], 'Hello, these are SMSes!')
  class SMS
    DEFAULT_GATEWAY = "http://www.mollie.nl/xml/sms/"

    attr_accessor :username,   # authentication username
                  :password,   # authentication password
                  :originator, # SMS originator phonenumber, i.e. +31612345678
                  :gateway     # Full URL of the Mollie SMS gateway
                
  
    def initialize(username, password, hash = {})
      self.username   = username
      self.password   = password
      self.originator = hash[:originator] if hash[:originator]
      self.gateway    = hash[:gateway]    if hash[:gateway]
    end
  
    def send(recipients, message)    
      uri = prepare_uri(recipients, message)
      res = Net::HTTP.get_response(uri)
    
      if res.code.to_i == 200
        doc = Hpricot(res.body)
      
        resultcode = (doc/"resultcode").inner_html.to_i

        if resultcode == 10
          return true
        else
          throw MollieException.by_code(resultcode)
          
          return false
        end
      else
        throw MollieException
        
        return false
      end
    end
  
  private
    def prepare_uri(recipients, message)
      recipients = [recipients] unless recipients.is_a?(Array)
    
      arguments = {
        :recipients => recipients.join(','),
        :username   => self.username,
        :password   => self.password,
        :originator => self.originator,
        :message    => message
      }
    
      query = arguments.map do |key, value|
        URI.encode(key.to_s) + "=" + URI.encode(value.to_s) if value      
      end
    
      query.reject! { |v| v.nil? }
    
      uri = URI.parse(self.gateway || DEFAULT_GATEWAY)
      uri.query = query.join('&')
    
      uri    
    end
  end

  class MollieException < Exception
    attr_reader :resultcode
  
    @resultcode = -1
    
    class << self
      def by_code(code)
        case code.to_i
        when 20
          NoUserNameException
        when 21
          NoPasswordException
        when 22
          InvalidOriginatorException
        when 23
          RecipientMissingException
        when 24
          MessageMissingException
        when 25
          InvalidRecipientException
        when 26
          InvalidOriginatorException
        when 27
          InvalidMessageException
        when 29
          ParameterException
        when 30
          AuthenticationException
        when 31
          InsufficientCreditsException
        when 98
          GatewayUnreachableException
        when 99
          UnknownException
        end
      end
    end
  end

  class NoUserNameException < MollieException; @resultcode = 20; end
  class NoPasswordException < MollieException; @resultcode = 21; end
  class InvalidOriginatorException < MollieException; @resultcode = 22; end
  class RecipientMissingException < MollieException; @resultcode = 23; end
  class MessageMissingException < MollieException; @resultcode = 24; end
  class InvalidRecipientException < MollieException; @resultcode = 25; end
  class InvalidOriginatorException < MollieException; @resultcode = 26; end
  class InvalidMessageException < MollieException; @resultcode = 27; end
  class ParameterException < MollieException; @resultcode = 29; end
  class AuthenticationException < MollieException; @resultcode = 30; end
  class InsufficientCreditsException < MollieException; @resultcode = 31; end
  class GatewayUnreachableException < MollieException; @resultcode = 98; end
  class UnknownException < MollieException; @resultcode = 99; end
end