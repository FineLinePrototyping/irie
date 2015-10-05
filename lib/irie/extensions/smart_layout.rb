module Irie
  module Extensions
    # Specify layout: false unless request.format.html?
    module SmartLayout
      extend ::ActiveSupport::Concern
      ::Irie.available_extensions[:smart_layout] = '::' + SmartLayout.name

      included do
        include ::Irie::ParamAliases
      end
      
      def index(options={}, &block)
        if request.format.html?
          ::Irie.logger.debug("[Irie] Irie::Extensions::SmartLayout.index: not merging layout:false into options because not html") if ::Irie.debug?
        else
          ::Irie.logger.debug("[Irie] Irie::Extensions::SmartLayout.index: merging layout:false into options because format.html? is truthy") if ::Irie.debug?
          options.merge!({layout: false}) unless request.format.html?
        end
        super(options, &block)
      end

    end
  end
end
