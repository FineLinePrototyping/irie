module Irie
  module Extensions
    # Allows use of a lambda for the index query.
    module IndexQuery
      extend ::ActiveSupport::Concern
      ::Irie.available_extensions[:index_query] = '::' + IndexQuery.name

      included do
        include ::Irie::ParamAliases

        class_attribute(:custom_index_query, instance_writer: true) unless self.respond_to? :custom_index_query

        self.custom_index_query ||= nil
      end

      module ClassMethods

        protected
        
        # Specify a custom query/additional filtering of the collection, e.g.
        #   index_query ->(q) { q.where(:status_code => 'green') }
        # You could also completely overwrite the collection which would lead
        # to certain peril, as you would need to then ensure all filters
        # are included in the correct order to be executed after the query.
        def index_query(query)
          self.custom_index_query = query
        end
      end

      protected

      def collection
        ::Irie.logger.debug("[Irie] Irie::Extensions::IndexQuery.collection") if ::Irie.debug?
        object = super
        ::Irie.logger.debug("[Irie] Irie::Extensions::IndexQuery.collection starting after super with object=#{object.inspect}") if ::Irie.verbose?
        if self.custom_index_query
          # convert to relation if model class because proc expects a relation
          object = object.all unless object.is_a?(ActiveRecord::Relation)
          a = object.to_s
          ::Irie.logger.debug("[Irie] Irie::Extensions::IndexQuery.collection before custom_index_query with object=#{object.inspect}") if ::Irie.verbose?
          object = self.custom_index_query.call(object)
          ::Irie.logger.debug("[Irie] Irie::Extensions::IndexQuery.collection after custom_index_query with object=#{object.inspect}") if ::Irie.verbose?
        end

        ::Irie.logger.debug("[Irie] Irie::Extensions::IndexQuery.collection: relation.to_sql so far: #{object.to_sql}") if ::Irie.debug? && object.respond_to?(:to_sql)

        set_collection_ivar object
      end
    end
  end
end
