module Irie
  module Extensions
    # Allowing setting `@count` with the count of the records in the index query.
    module Count
      extend ::ActiveSupport::Concern
      ::Irie.available_extensions[:count] = '::' + Count.name

      included do
        include ::Irie::ParamAliases
      end
      
      def index(options={}, &block)
        ::Irie.logger.debug("[Irie] Irie::Extensions::Count.index") if ::Irie.debug?
        return super(options, &block) unless aliased_param_present?(:count)
        @count = collection.count

        ::Irie.logger.debug("[Irie] Irie::Extensions::Count.index: count: #{@count}") if ::Irie.debug?

        result = respond_to?(:autorender_count, true) ? autorender_count(options, &block) : super(options, &block)
        ::Irie.logger.debug("[Irie] Irie::Extensions::Count.index: result: #{result.inspect}") if ::Irie.verbose?
        result
      end

    end
  end
end
