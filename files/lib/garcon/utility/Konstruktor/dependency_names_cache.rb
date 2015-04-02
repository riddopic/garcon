module Konstruktor
  class DependencyNamesCache
    def initialize
      @konstruktor_params = {}
    end

    def for_class(klass)
      @konstruktor_params[klass] ||= get_konstruktor_params(klass)
    end

    private

    def get_konstruktor_params(klass)
      params = klass.instance_method(:initialize).parameters
      params.select{|type, name| type == :req}.map{|type, name| name}
    end
  end
end
