# frozen_string_literal: true

require_relative 'exchange/configuration'

class Money
  module Fluence
    module Exchange
      extend Configuration
    end
  end
end

require 'money/bank/fluence_exchange'
require 'money/rates_store/fluence'
