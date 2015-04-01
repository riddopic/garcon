module Konstruktor
  module AutoInject
    module ClassMethods
      def look_in_modules(*modules)
        search_modules.concat(modules)
      end

      def search_modules
        @search_modules ||= []
      end
    end

    def self.included(klass)
      klass.extend ClassMethods
    end

    def method_missing(name, *args, &block)
      auto_injector.get_by_class_name(name)
    end

    def respond_to_missing?(name, include_private = false)
      auto_injector.class_exists?(name)
    end

    def inject(klass, overrides = {})
      injector = Konstruktor::CustomizedInjector.new(auto_injector, overrides)
      instantiator = Konstruktor::Instantiator.new(injector, dependency_names)
      instantiator.instantiate(klass)
    end

    private

    def auto_injector
      @auto_injector ||= Konstruktor::AutoInjector.new(self, dependency_names, self.class.search_modules)
    end

    def dependency_names
      @dependency_names ||= Konstruktor::DependencyNamesCache.new
    end

  end

end

