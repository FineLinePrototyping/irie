module Irie
  module Extensions
    # Allows use of a lambda to work with request parameters to filter results.
    module QueryFilter
      extend ::ActiveSupport::Concern
      ::Irie.available_extensions[:query_filter] = '::' + QueryFilter.name

      included do
        include ::Irie::ParamAliases

        class_attribute(:param_to_query, instance_writer: true) unless self.respond_to? :param_to_query
        
        self.param_to_query ||= {}
      end

      module ClassMethods

        protected
        
        # Specify a custom query to filter by if the named request parameter is provided, e.g.
        #   can_filter_by_query status: ->(q, status) { status == 'all' ? q : q.where(:status => status) },
        #                       color: ->(q, color) { color == 'red' ? q.where("color = 'red' or color = 'ruby'") : q.where(:color => color) }
        def can_filter_by_query(*args)
          options = args.extract_options!

          raise ::Irie::ConfigurationError.new "arguments #{args.inspect} are not supported by can_filter_by_query" if args.length > 0

          self.param_to_query = self.param_to_query.deep_dup
          
          options.each do |param_name, proc|
            self.param_to_query[param_name.to_sym] = proc
          end
        end
      end

      protected

      def collection
        ::Irie.logger.debug("[Irie] Irie::Extensions::QueryFilter.collection") if ::Irie.debug?
        object = super
        ::Irie.logger.debug("[Irie] Irie::Extensions::QueryFilter.collection starting after super with object=#{object.inspect}") if ::Irie.verbose?
        # convert to relation if model class because proc expects a relation
        object = object.all unless object.is_a?(ActiveRecord::Relation)

        this_includes = self.action_to_query_includes[params[:action].to_sym] || self.all_action_query_includes
        self.param_to_query.each do |param_name, param_query|
          param_value = params[param_name]
          unless param_value.nil?
            converted_param = convert_param(param_name.to_s, param_value)
            ::Irie.logger.debug("[Irie] Irie::Extensions::QueryFilter.collection: param_to_query: before query call with object=#{object.inspect} and converted_param=#{converted_param.inspect}") if ::Irie.verbose?
            object = param_query.call(object, converted_param)
            ::Irie.logger.debug("[Irie] Irie::Extensions::QueryFilter.collection: param_to_query: after query call with object=#{object.inspect}") if ::Irie.verbose?
          end
        end

        ::Irie.logger.debug("[Irie] Irie::Extensions::QueryFilter.collection: relation.to_sql so far: #{object.to_sql}") if ::Irie.debug? && object.respond_to?(:to_sql)

        set_collection_ivar object
      end
    end
  end
end
