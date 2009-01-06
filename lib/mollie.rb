# mollie.rb: Library for sending SMS using the mollie.nl API
# author: Tom-Eric Gerritsen <tomeric@i76.nl>
# additional functions: Maran Hidskes <maran@noxa.nl>

require 'rubygems'
require 'uri'
require 'net/http'
require 'hpricot'

module Mollie
  ##
  # == SMS
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
	#
	# # sending a timed message 
	# sms = Mollie::SMS.new('username', 'password')
	# sms.orginator = '0612345678'
	# sms.send("0687654321", "This is a message from the past!", {:delivery_date => "20090202120200", :reference => "scarymessage"})
	#
	# # cancelling a message
	# sms = Mollie::SMS.new('username', 'password')
	# sms.orginator = '0612345678'
	# sms.cancel("scarymessage")
	
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
		
		# Send a message through mollie. Takes two obligatory arguments and one optional options hash.
		# The options hash can include a reference and delivery_date for timed messages
    def send(recipients, message, options = {})
 			unless options[:delivery_date].blank?
				raise DeliveryDateButNoReferenceException if options.include?(:delivery_date) && !options.include?(:reference)
	 			raise WrongDateFormatException	if options[:delivery_date].size < 14 || (options[:delivery_date].match(/\D+/) != nil)
			end

      uri = prepare_send_uri(recipients, message, options)
      res = Net::HTTP.get_response(uri)   	
			parse_response_code(res)
    end
  	
		# Cancels a timed message through the reference
		def cancel(reference)
				raise NoReferenceException if reference.blank?
				self.gateway = "http://www.mollie.nl/xml/sms_cancel/"
	      arguments = {
	        :username   => self.username,
	        :password   => self.password,
	        :reference => reference
	      }
	
				uri = parse_uri(arguments)
	      res = Net::HTTP.get_response(uri)
				parse_response_code(res, false)
		end


  private

		def parse_response_code(res, send = true)
			if res.code.to_i == 200
        doc = Hpricot(res.body)

        resultcode = (doc/"resultcode").inner_html.to_i

        if resultcode == 10
          return true
        else
					if send == true
          	raise MollieException.by_cancel_code(resultcode)          
					else
						raise MollieException.by_send_code(resultcode)          
					end
          return false
        end
      else
        raise MollieException
        return false
      end
		end
		
    def prepare_send_uri(recipients, message, options = {})
      recipients = [recipients] unless recipients.is_a?(Array)
    
      arguments = {
        :recipients => recipients.join(','),
        :username   => self.username,
        :password   => self.password,
        :originator => self.originator,
        :message    => message	
      }

			if options.include?(:delivery_date)
				arguments[:deliverydate] = options[:delivery_date]
				arguments[:reference] = options[:reference]
			end
			
			return parse_uri(arguments)
 
    end

		def parse_uri(arguments)
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
  
    @resultcode = -10
    
    class << self
			def by_cancel_code(code)
				case code.to_i
        when 20
          NoUserNameException
        when 21
          NoPasswordException
        when 22
          NoReferenceException
        when 30
          AuthenticationException
				when 40
					ReferencedMessageNotFound
				end
			end
			
      def by_send_code(code)
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

	# Mollie cancelled errors
	class NoReferenceException < MollieException; @resultcode = 22; end
	class ReferencedMessageNotFound < MollieException; @resultcode = 40; end
	
	# Self proclaimed errors
	class WrongDateFormatException < MollieException; @resultcode = -2; end
	class DeliveryDateButNoReferenceException < MollieException; @resultcode = -1; end
	
	# Mollie send errors
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