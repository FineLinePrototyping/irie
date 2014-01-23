module Irie
  module Extensions
    # Allows ability to do `.includes(...)` on query to avoid n+1 queries.
    module QueryIncludes
      extend ::ActiveSupport::Concern
      ::Irie.available_extensions[:query_includes] = '::' + QueryIncludes.name

      included do
        include ::Irie::ParamAliases

        class_attribute(:action_to_query_includes, instance_writer: true) unless self.respond_to? :action_to_query_includes
        class_attribute(:all_action_query_includes, instance_writer: true) unless self.respond_to? :all_action_query_includes

        self.action_to_query_includes ||= {}
        self.all_action_query_includes ||= []
      end

      module ClassMethods

        protected
        
        # Calls .includes(*args) on all action queries with args provided to query_includes, e.g.:
        #   query_includes :category, :comments
        # or:
        #   query_includes posts: [{comments: :guest}, :tags]
        # Note that query_includes_for overrides includes specified by query_includes.
        def query_includes(*args)
          options = args.extract_options!

          self.all_action_query_includes = self.all_action_query_includes.deep_dup
          old_options = self.all_action_query_includes.extract_options!
          self.all_action_query_includes = (self.all_action_query_includes + args).uniq
          self.all_action_query_includes << old_options.merge(options)
        end

        # Calls .includes(...) only on specified action queries, e.g.:
        #   query_includes_for :create, :update, are: [:category, :comments]
        #   query_includes_for :index, are: [posts: [{comments: :guest}, :tags]]
        def query_includes_for(*args)
          options = args.extract_options!

          opt_are = options.delete(:are)
          raise ::Irie::ConfigurationError.new "options #{options.inspect} not supported by can_filter_by" if options.present?

          self.action_to_query_includes = self.action_to_query_includes.deep_dup

          args.each do |an_action|
            if opt_are
              (self.action_to_query_includes ||= {}).merge!({an_action.to_sym => opt_are})
            else
              raise ::Irie::ConfigurationError.new "#{self.class.name} must supply an :are option with includes_for #{an_action.inspect}"
            end
          end
        end
      end

      protected
      
      def collection
        logger.debug("Irie::Extensions::QueryIncludes.collection") if ::Irie.debug?
        object = super
        
        this_includes = self.action_to_query_includes[params[:action].to_sym] || self.all_action_query_includes
        if this_includes && this_includes.size > 0
          object = object.includes(*this_includes)
        else
          object
        end

        logger.debug("Irie::Extensions::QueryIncludes.collection: relation.to_sql so far: #{object.to_sql}") if ::Irie.debug? && object.respond_to?(:to_sql)

        set_collection_ivar object
      end

      def resource
        cached = get_resource_ivar
        if cached
          logger.debug("Irie::Extensions::QueryIncludes.resource returning cached resource") if ::Irie.debug?
          return cached
        end
        logger.debug("Irie::Extensions::QueryIncludes.resource") if ::Irie.debug?
        this_includes = self.action_to_query_includes[params[:action].to_sym] || self.all_action_query_includes
        if this_includes && this_includes.size > 0
          # can return the model class, so won't call bang (includes!) method
          object = end_of_association_chain.includes(*this_includes)

          logger.debug("Irie::Extensions::QueryIncludes.resource: end_of_association_chain.to_sql: #{object.to_sql}") if ::Irie.debug? && object.respond_to?(:to_sql)

          set_resource_ivar object.send(method_for_find, params[:id])
        else
          super
        end
      end
    end
  end
end
