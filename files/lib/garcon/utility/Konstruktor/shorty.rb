module Konstruktor
  module Shorty
    def takes(*names)
      attr_reader *names
      include Konstruktor::Konstruktor(*names)
      extend Konstruktor::Let
    end
  end
end

class Object
  extend Konstruktor::Shorty
end
