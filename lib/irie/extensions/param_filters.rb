module Irie
  module Extensions
    # Allows filtering of results using ARel predicates.
    module ParamFilters
      extend ::ActiveSupport::Concern
      ::Irie.available_extensions[:param_filters] = '::' + ParamFilters.name

      included do
        include ::Irie::ParamAliases

        class_attribute(:default_filtered_by, instance_writer: true) unless self.respond_to? :default_filtered_by
        class_attribute(:composite_param_to_param_name_and_arel_predicate, instance_writer: true) unless self.respond_to? :composite_param_to_param_name_and_arel_predicate

        self.default_filtered_by ||= {}
        self.composite_param_to_param_name_and_arel_predicate ||= {}
      end

      module ClassMethods

        protected
        
        # A whitelist of filters and definition of filter options related to request parameters.
        #
        # If no options are provided or the :using option is provided, defines attributes that are queryable through the operation(s) already defined in can_filter_by_default_using, or can specify attributes:
        #   can_filter_by :attr_name_1, :attr_name_2 # implied using: [eq] if RestfulJson.can_filter_by_default_using = [:eq] 
        #   can_filter_by :attr_name_1, :attr_name_2, using: [:eq, :not_eq]
        #
        # When :through is specified, it will take the array supplied to through as 0 to many model names following by an attribute name. It will follow through
        # each association until it gets to the attribute to filter by that via ARel joins, e.g. if the model Foobar has an association to :foo, and on the Foo model there is an assocation
        # to :bar, and you want to filter by bar.name (foobar.foo.bar.name):
        #   can_filter_by :my_param_name, through: {foo: {bar: :name}}
        #
        # It also supports param to attribute name/joins via define_params, e.g.
        #   define_params car: :car_attr_name
        #   can_filter_by :car
        def can_filter_by(*args)
          options = args.extract_options!

          opt_using = options.delete(:using)
          opt_through = options.delete(:through)
          opt_split = options.delete(:split)
          raise ::Irie::ConfigurationError.new "options #{options.inspect} not supported by can_filter_by" if options.present?

          self.composite_param_to_param_name_and_arel_predicate = self.composite_param_to_param_name_and_arel_predicate.deep_dup

          # :using is the default action if no options are present
          if opt_using || options.size == 0
            predicates = Array.wrap(opt_using || self.can_filter_by_default_using)
            predicates.each do |predicate|
              predicate_sym = predicate.to_sym
              args.each do |param_name|
                param_name = param_name.to_s
                if predicate_sym == :eq
                  self.composite_param_to_param_name_and_arel_predicate[param_name] = [param_name, :eq, opt_split]
                end

                self.composite_param_to_param_name_and_arel_predicate["#{param_name}#{self.predicate_prefix}#{predicate}"] = [param_name, predicate_sym, opt_split]
              end
            end
          end

          if opt_through
            raise ::Irie::ConfigurationError.new "Must use extension :params_to_joins to use can_order_by :through" unless ancestors.include?(::Irie::Extensions::ParamsToJoins)
            args.each do |through_key|
              # note: handles cloning, etc.
              self.define_params(through_key => opt_through)
            end
          end
        end

        # Specify default filters and predicates to use if no filter is provided by the client with
        # the same param name, e.g. if you have:
        #   default_filter_by :attr_name_1, eq: 5
        #   default_filter_by :production_date, :creation_date, gt: 1.year.ago, lteq: 1.year.from_now
        # and both attr_name_1 and production_date are supplied by the client, then it would filter
        # by the client's attr_name_1 and production_date and filter creation_date by
        # both > 1 year ago and <= 1 year from now.
        def default_filter_by(*args)
          options = args.extract_options!

          self.default_filtered_by = self.default_filtered_by.deep_dup
          
          args.each do |param_name|
            param_name = param_name.to_s
            if self.default_filtered_by[param_name]
              # have merge create new instance to help avoid subclass inheritance related sharing issues.
              self.default_filtered_by[param_name] = self.default_filtered_by[param_name].merge(options)
            else
              self.default_filtered_by[param_name] = options
            end
          end
        end
      end

      IRIE_ARY_PREDICATES = [:not_eq_any, :not_eq_all, :eq_any, :eq_all, :in_any, :in_all, :not_in_any, :not_in_all, :matches_any, :matches_all, :does_not_match_all,
        :gteq_any, :gteq_all, :gt_any, :gt_all, :lt_any, :lt_all, :lteq_any, :lteq_all]

      protected

      def collection
        ::Irie.logger.debug("[Irie] Irie::Extensions::ParamFilters.collection") if ::Irie.debug?
        object = super
        ::Irie.logger.debug("[Irie] Irie::Extensions::ParamFilters.collection starting after super with object=#{object.inspect}") if ::Irie.verbose?
        already_filtered_by_split_param_names = []
        self.composite_param_to_param_name_and_arel_predicate.each do |composite_param, param_name_and_arel_predicate, split|
          if params.key?(composite_param)
            split_param_name, predicate_sym = *param_name_and_arel_predicate
            converted_param_values = converted_param_values.collect{|p| p.split(*split)}.flatten unless split.blank?
            converted_param_values = convert_param(composite_param, params[composite_param])
            # support for named_params/:through renaming of param name
            attr_sym = attr_sym_for_param(split_param_name)
            join_to_apply = join_for_param(split_param_name)
            if join_to_apply
              ::Irie.logger.debug("[Irie] Irie::Extensions::ParamFilters.collection: composite_param_to_param_name_and_arel_predicate: object.joins(#{join_to_apply.inspect})") if ::Irie.debug?
              object = object.joins(join_to_apply)
            end
            # note: we call it column but it is Arel::Attributes::Attribute
            arel_table_column = get_arel_table(split_param_name)[attr_sym]
            raise ::Irie::ConfigurationError.new "can_filter_by/define_params config problem: could not find arel table/column for param name #{split_param_name.inspect} and/or attr_sym #{attr_sym.inspect}" unless arel_table_column
            ::Irie.logger.debug("[Irie] Irie::Extensions::ParamFilters.collection: composite_param_to_param_name_and_arel_predicate: before adding where col=#{arel_table_column.inspect} pred=#{predicate_sym.inspect} equal_to_or_in=#{converted_param_values.inspect} with object=#{object.inspect}") if ::Irie.verbose?
            object = object.where(arel_table_column.send(predicate_sym, converted_param_values))
            ::Irie.logger.debug("[Irie] Irie::Extensions::ParamFilters.collection: composite_param_to_param_name_and_arel_predicate: after adding where col=#{arel_table_column.inspect} pred=#{predicate_sym.inspect} equal_to_or_in=#{converted_param_values.inspect} with object=#{object.inspect}") if ::Irie.verbose?
            already_filtered_by_split_param_names << split_param_name
          end
        end

        self.default_filtered_by.each do |split_param_name, predicates_to_default_values|
          unless already_filtered_by_split_param_names.include?(split_param_name) || predicates_to_default_values.blank?
            attr_sym = attr_sym_for_param(split_param_name)
            join_to_apply = join_for_param(split_param_name)
            if join_to_apply
              ::Irie.logger.debug("[Irie] Irie::Extensions::ParamFilters.collection: default_filtered_by: object.joins(#{join_to_apply.inspect})") if ::Irie.debug?
              object = object.joins(join_to_apply)
            end
            # note: we call it column but it is Arel::Attributes::Attribute
            arel_table_column = get_arel_table(split_param_name)[attr_sym]
            raise ::Irie::ConfigurationError.new "default_filter_by/define_params config problem: could not find arel table/column for param name #{split_param_name.inspect} and/or attr_sym #{attr_sym.inspect}" unless arel_table_column
            predicates_to_default_values.each do |predicate_sym, one_or_more_default_values|
              one_or_more_default_values = Array.wrap(one_or_more_default_values) if IRIE_ARY_PREDICATES.include?(predicate_sym)
              ::Irie.logger.debug("[Irie] Irie::Extensions::ParamFilters.collection: default_filtered_by: before adding where col=#{arel_table_column.inspect} pred=#{predicate_sym.inspect} equal_to_or_in=#{one_or_more_default_values.inspect} with object=#{object.inspect}") if ::Irie.verbose?
              object = object.where(arel_table_column.send(predicate_sym, one_or_more_default_values))
              ::Irie.logger.debug("[Irie] Irie::Extensions::ParamFilters.collection: default_filtered_by: after adding where col=#{arel_table_column.inspect} pred=#{predicate_sym.inspect} equal_to_or_in=#{one_or_more_default_values.inspect} with object=#{object.inspect}") if ::Irie.verbose?
            end
          end
        end

        ::Irie.logger.debug("[Irie] Irie::Extensions::ParamFilters.collection: relation.to_sql so far: #{object.to_sql}") if ::Irie.debug? && object.respond_to?(:to_sql)
        
        set_collection_ivar object
      end

    end
  end
end
