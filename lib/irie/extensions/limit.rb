module Irie
  module Extensions
    # Allows limiting of the number of records returned by the index query.
    module Limit
      extend ::ActiveSupport::Concern
      ::Irie.available_extensions[:limit] = '::' + Limit.name

      included do
        include ::Irie::ParamAliases
      end

      protected

      def collection
        ::Irie.logger.debug("[Irie] Irie::Extensions::Limit.collection") if ::Irie.debug?
        object = super
        ::Irie.logger.debug("[Irie] Irie::Extensions::Limit.collection: starting after super with object=#{object.inspect}") if ::Irie.verbose?
        limit_params = aliased_params(:limit)
        ::Irie.logger.debug("[Irie] Irie::Extensions::Limit.collection: limit_params=#{limit_params.inspect}") if ::Irie.debug?
        limit_params.each {|param_value| object = object.limit(param_value.to_i)}
        ::Irie.logger.debug("[Irie] Irie::Extensions::Limit.collection: after limits with object=#{object.inspect}") if ::Irie.verbose?

        ::Irie.logger.debug("[Irie] Irie::Extensions::Limit.collection: relation.to_sql so far: #{object.to_sql}") if ::Irie.debug? && object.respond_to?(:to_sql)

        set_collection_ivar object
      end
    end
  end
end
