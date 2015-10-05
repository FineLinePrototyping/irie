module Irie
  module Extensions
    # Allows setting of attributes that can be used for ordering, and allows default ordering to be set.
    module Order
      extend ::ActiveSupport::Concern
      ::Irie.available_extensions[:order] = '::' + Order.name

      included do
        include ::Irie::ParamAliases

        class_attribute(:can_be_ordered_by, instance_writer: true) unless self.respond_to? :can_be_ordered_by
        class_attribute(:default_ordered_by, instance_writer: true) unless self.respond_to? :default_ordered_by
        
        self.can_be_ordered_by ||= []
        self.default_ordered_by ||= {}
      end

      module ClassMethods

        protected
        
        # A whitelist of orderable attributes.
        #
        # If no options are provided or the :using option is provided, defines attributes that are orderable through the operation(s) already defined in can_filter_by_default_using, or can specify attributes:
        #   can_order_by :attr_name_1, :attr_name_2
        # So that you could call: http://.../foobars?order=attr_name_1,-attr_name_2
        # to order by attr_name_1 asc then attr_name_2 desc.
        #
        # When :through is specified, it will take the array supplied to through as 0 to many model names following by an attribute name. It will follow through
        # each association until it gets to the attribute to filter by that via ARel joins, e.g. if the model Foobar has an association to :foo, and on the Foo model there is an assocation
        # to :bar, and you want to order by bar.name (foobar.foo.bar.name):
        #  can_order_by :my_param_name, through: {foo: {bar: :name}}
        def can_order_by(*args)
          options = args.extract_options!

          opt_through = options.delete(:through)
          raise ::Irie::ConfigurationError.new "options #{options.inspect} not supported by can_order_by" if options.present?

          self.can_be_ordered_by = self.can_be_ordered_by.deep_dup

          args.each do |arg|
            # store as strings because we have to do a string comparison later to avoid req param symbol attack
            self.can_be_ordered_by << arg.to_s unless self.can_be_ordered_by.include?(arg.to_s)
          end

          if opt_through
            raise ::Irie::ConfigurationError.new "Must use extension :params_to_joins to use can_order_by :through" unless ancestors.include?(::Irie::Extensions::ParamsToJoins)
            args.each do |through_key|
              # note: handles cloning, etc.
              self.define_params(through_key => opt_through)
            end
          end
        end

        # Takes an string, symbol, array, hash to indicate order. If not a hash, assumes is ascending. Is cumulative and order defines order of sorting, e.g:
        #   #would order by foo_color attribute ascending
        #   default_order_by :foo_color
        # or
        #   default_order_by foo_date: :asc, bar_date: :desc
        # or you could be completely insane and do:
        #   default_order_by {foo_date: :asc}, :foo_color, 'foo_name', another_date: :asc, bar_date: :desc
        def default_order_by(*args)
          options = args.extract_options!

          self.default_ordered_by = self.default_ordered_by.deep_dup

          # hash is ordered in recent versions of Ruby we support
          args.flatten.each do |item|
            case item
            when Hash
              # merge hash converting keys to string
              item.each {|param_name, direction| self.default_ordered_by[param_name.to_s] = direction}
            when String, Symbol
              self.default_ordered_by[item.to_s] = :asc
            else
              raise ::Irie::ConfigurationError.new "Can't default_order_by #{item}"
            end
          end

          # merge hash converting keys to string
          options.each {|param_name, direction| self.default_ordered_by[param_name.to_s] = direction}
        end
      end

      protected

      def collection
        ::Irie.logger.debug("[Irie] Irie::Extensions::Order.collection") if ::Irie.debug?
        object = super
        ::Irie.logger.debug("[Irie] Irie::Extensions::Order.collection starting after super with object=#{object.inspect}") if ::Irie.verbose?

        already_ordered_by = []
        aliased_params(:order).collect{|p| p.split(',')}.flatten.collect(&:strip).each do |split_param_name|

          # not using convert_param here.
          # (these should be attribute names, not attribute values.)

          # remove optional preceding - or + to act as directional
          direction = :asc
          if split_param_name[0] == '-'
            direction = :desc
            split_param_name = split_param_name.reverse.chomp('-').reverse
          elsif split_param_name[0] == '+'
            split_param_name = split_param_name.reverse.chomp('+').reverse
          end

          # support for named_params/:through renaming of param name
          attr_sym = attr_sym_for_param(split_param_name)

          # order of logic here is important:
          # do not to_sym the partial param value until passes whitelist to avoid symbol attack.
          # be sure to pass in the same param name as the default param it is trying to override,
          # if there is one.
          if self.can_be_ordered_by.include?(split_param_name) && !already_ordered_by.include?(attr_sym)
            join_to_apply = join_for_param(split_param_name)
            ::Irie.logger.debug("[Irie] Irie::Extensions::Order.collection: can_be_ordered_by: calling joins(#{join_to_apply.inspect})") if ::Irie.verbose?
            object = object.joins(join_to_apply) if join_to_apply
            arel_table_column = get_arel_table(split_param_name)[attr_sym]
            raise ::Irie::ConfigurationError.new "can_order_by/define_params config problem: could not find arel table/column for param name #{split_param_name.inspect} and/or attr_sym #{attr_sym.inspect}" unless arel_table_column
            #TODO: is there a better way? not sure how else to order on joined table columns- no example
            sql_fragment = "#{arel_table_column.relation.name}.#{arel_table_column.name}#{direction == :desc ? ' DESC' : ''}"
            # Important note! the behavior of multiple `order`'s' got reversed between Rails 4.0.0 and 4.0.1:
            # http://weblog.rubyonrails.org/2013/11/1/Rails-4-0-1-has-been-released/
            ::Irie.logger.debug("[Irie] Irie::Extensions::Order.collection: aliased_params: calling order(#{sql_fragment.inspect})") if ::Irie.debug?
            ::Irie.logger.debug("[Irie] Irie::Extensions::Order.collection: aliased_params: before order object=#{object.inspect}") if ::Irie.verbose?
            object = object.order(sql_fragment)
            ::Irie.logger.debug("[Irie] Irie::Extensions::Order.collection: aliased_params: after order object=#{object.inspect}") if ::Irie.verbose?
            already_ordered_by << attr_sym
          end

          set_collection_ivar object

          object
        end

        self.default_ordered_by.each do |split_param_name, direction|
          unless already_ordered_by.include?(split_param_name)
            attr_sym = attr_sym_for_param(split_param_name)
            join_to_apply = join_for_param(split_param_name)
            object = object.joins(join_to_apply) if join_to_apply
            arel_table_column = get_arel_table(split_param_name)[attr_sym]
            raise ::Irie::ConfigurationError.new "default_order_by/define_params config problem: could not find arel table/column for param name #{split_param_name.inspect} and/or attr_sym #{attr_sym.inspect}" unless arel_table_column
            #TODO: is there a better way? not sure how else to order on joined table columns- no example
            sql_fragment = "#{arel_table_column.relation.name}.#{arel_table_column.name}#{direction == :desc ? ' DESC' : ''}"
            ::Irie.logger.debug("[Irie] Irie::Extensions::Order.collection: default_ordered_by: calling order(#{sql_fragment.inspect})") if ::Irie.debug?
            ::Irie.logger.debug("[Irie] Irie::Extensions::Order.collection: default_ordered_by: before order object=#{object.inspect}") if ::Irie.verbose?
            object = object.order(sql_fragment)
            ::Irie.logger.debug("[Irie] Irie::Extensions::Order.collection: default_ordered_by: after order object=#{object.inspect}") if ::Irie.verbose?
            already_ordered_by << attr_sym
          end
        end

        ::Irie.logger.debug("[Irie] Irie::Extensions::Order.collection: relation.to_sql so far: #{object.to_sql}") if ::Irie.debug? && object.respond_to?(:to_sql)

        set_collection_ivar object
      end
    end
  end
end

        