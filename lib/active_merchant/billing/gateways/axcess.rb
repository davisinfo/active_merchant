module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class AxcessGateway < Gateway
      self.test_url = 'https://test.ctpe.net/frontend/payment.prc'
      self.live_url = 'https://ctpe.net/frontend/payment.prc'

      self.supported_countries = ['GB']
      self.default_currency = 'GBP'
      self.supported_cardtypes = [:visa, :master, :american_express, :discover]

      self.homepage_url = 'http://www.axcessms.com/'
      self.display_name = 'Axcess'

      def initialize(options={})
        requires!(options, :sender, :channel, :login, :password)
        super
      end

      def purchase(money, payment, options={})
        post = {}
        add_merchant(post,options)
        add_invoice(post, money, options)
        add_payment(post, payment)
        add_address(post, payment, options)
        add_customer_data(post, options)

        commit('sale', post)
      end

      def authorize(money, payment, options={})
        post = {}
        add_invoice(post, money, options)
        add_payment(post, payment)
        add_address(post, payment, options)
        add_customer_data(post, options)

        commit('authonly', post)
      end

      def capture(money, authorization, options={})
        commit('capture', post)
      end

      def refund(money, authorization, options={})
        commit('refund', post)
      end

      def void(authorization, options={})
        commit('void', post)
      end

      private

      def add_merchant(post,options)
        post['SECURITY.SENDER'] = @options[:sender]
        post['USER.LOGIN'] = @options[:login]
        post['USER.PWD'] = @options[:password]

        post['TRANSACTION.CHANNEL'] = @options[:channel]
      end

      def add_customer_data(post, options)
        post['NAME.GIVEN'] = options[:billing_address][:first_name]
        post['NAME.FAMILY'] = options[:billing_address][:last_name]
        post['NAME.SALUTATION'] = options[:billing_address][:salutation] || ''
        post['NAME.TITLE'] = options[:billing_address][:title] || ''
        post['NAME.COMPANY'] = options[:billing_address][:company_name] || ''

        post['CONTACT.EMAIL'] = options[:email] || ''
        post['CONTACT.PHONE'] = options[:phone] || ''
        post['CONTACT.MOBILE'] = options[:mobile] || ''
        post['CONTACT.IP'] = options[:ip] || ''
      end

      def add_address(post, creditcard, options)
        post['ADDRESS.STREET'] = options[:billing_address][:address_1]
        post['ADDRESS.ZIP'] = options[:billing_address][:postcode]
        post['ADDRESS.CITY'] = options[:billing_address][:city]
        post['ADDRESS.STATE'] = options[:billing_address][:county]
        post['ADDRESS.COUNTRY'] = options[:billing_address][:country]
      end

      def add_invoice(post, money, options)
        post['IDENTIFICATION.TRANSACTIONID'] = @options[:order_id]
        post['PRESENTATION.USAGE'] = "Order Number #{options[:order_id]}"
        post['PAYMENT.CODE'] = 'CC.DB'
        post['PRESENTATION.CURRENCY'] = (options[:currency] || currency(money))
        post['PRESENTATION.AMOUNT'] = amount(money)
      end

      def add_payment(post, creditcard)
        post['ACCOUNT.HOLDER'] = creditcard.name
        post['ACCOUNT.NUMBER'] = creditcard.number
        post['ACCOUNT.BRAND'] = creditcard.brand.upcase
        post['ACCOUNT.EXPIRY_MONTH'] = creditcard.month
        post['ACCOUNT.EXPIRY_YEAR'] = creditcard.year
        post['ACCOUNT.VERIFICATION'] = creditcard.verification_value
      end

      def parse(body)
        fields = split(body)

        results = {
            :response_code => fields['PROCESSING.RETURN.CODE'].to_i,
            :response_reason_code => fields['PROCESSING.REASON.CODE'],
            :response_reason_text => fields['PROCESSING.REASON'],
            :transaction_id => fields['IDENTIFICATION.UNIQUEID'],
            :card_code => fields['PROCESSING.CODE'],
            :authorization_code => fields['IDENTIFICATION.UNIQUEID'],
        }.merge(:response_data => fields)
        results
      end

      def split(body)
        params = {}
        _data = {}
        body.strip.split('&').each{|item|
          key, value = *item.scan( %r{^([A-Za-z0-9_.]+)\=(.*)$} ).flatten
          _data[key] = CGI.unescape(value)
        }

        _data
      end

      def commit(action, parameters)
        url = (test? ? test_url : live_url)
        response = parse(ssl_post(url, post_data(action, parameters)))

        Response.new(
          success_from(response),
          message_from(response),
          response,
          authorization: authorization_from(response),
          test: test?
        )
      end

      def success_from(response)
        response[:response_data]['PROCESSING.RESULT'] == 'ACK'
      end

      def message_from(response)
        response[:response_data]['PROCESSING.RETURN']
      end

      def authorization_from(response)
        response[:response_data]['IDENTIFICATION.UNIQUEID']
      end

      def post_data(action, parameters = {})
        post = {}

        post['REQUEST.VERSION'] = '1.0'
        post['TRANSACTION.MODE'] = (test?)?'INTEGRATOR_TEST':'LIVE'
        post['TRANSACTION.RESPONSE'] = 'SYNC'

        request = post.merge(parameters).collect { |key, value| "#{key}=#{CGI.escape(value.to_s)}" }.join("&")
        request
      end
    end
  end
end
