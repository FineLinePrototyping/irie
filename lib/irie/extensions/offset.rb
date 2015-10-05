module Irie
  module Extensions
    # Allowing offsetting (skipping) records that would be returned by the index query.
    module Offset
      extend ::ActiveSupport::Concern
      ::Irie.available_extensions[:offset] = '::' + Offset.name

      included do
        include ::Irie::ParamAliases
      end

      protected

      def collection
        ::Irie.logger.debug("[Irie] Irie::Extensions::Offset.collection") if ::Irie.debug?
        object = super
        ::Irie.logger.debug("[Irie] Irie::Extensions::Offset.collection starting after super with object=#{object.inspect}") if ::Irie.verbose?
        offset_params = aliased_params(:offset)
        ::Irie.logger.debug("[Irie] Irie::Extensions::Offset.collection: offset_params=#{offset_params.inspect}") if ::Irie.debug?
        offset_params.each {|param_value| object = object.offset(param_value.to_i)}
        ::Irie.logger.debug("[Irie] Irie::Extensions::Offset.collection: after offsets object=#{object.inspect}") if ::Irie.verbose?

        ::Irie.logger.debug("[Irie] Irie::Extensions::Offset.collection: relation.to_sql so far: #{object.to_sql}") if ::Irie.debug? && object.respond_to?(:to_sql)

        set_collection_ivar object
      end
    end
  end
end
