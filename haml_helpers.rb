module Haml
  module Helpers
    def number_format(number)
      number.to_s.reverse.scan(/\d{1,3}/).join(".").reverse
    end
  end
end
