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
		
		# Send a message through mollie. .
		# Takes two obligatory arguments and one optional options hash.
		# The options hash can include a reference and delivery_date for timed messages
    def send(recipients, message, options = {})
      uri = prepare_send_uri(recipients, message, options)
      res = Net::HTTP.get_response(uri)   	
			parse_response_code(res)
    end
  	
		# Cancels a timed message through the reference
		def cancel(reference)
				self.gateway = "http://www.mollie.nl/xml/sms_cancel/"
	      arguments = {
	        :username   => self.username,
	        :password   => self.password,
	        :reference => reference
	      }
				uri = parse_uri(arguments)
	      res = Net::HTTP.get_response(uri)
				parse_response_code(res)
		end


  private

		def parse_response_code(res)
			# If we got a 200 page found
			if res.code.to_i == 200
				# Get the body
        doc = Hpricot(res.body)				      
				# Look for the success xml tag, everything went great!
				success = (doc/"success").inner_html
				return unless success == "false"

				# If we are here not everything went as smoothly as expected
				# Let's get the error-code + message
				resultcode = (doc/"resultcode").inner_html.to_i
				message = (doc/"resultmessage").inner_html

				error =  MollieError.new(resultcode,message)
				raise error
			else
				raise "Mollie was unbreachable"
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

	
  class MollieError < StandardError
		attr_reader :code, :message
		
		def initialize(code, message)
			@code, @message = code, message
		end
	end
end