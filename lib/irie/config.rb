module Irie

  CONTROLLER_OPTIONS = [
    :autoincludes,
    :available_actions,
    :available_extensions,
    :can_filter_by_default_using,
    :debug,
    :function_param_names,
    :id_is_primary_key_param,
    :number_of_records_in_a_page,
    :predicate_prefix,
    :extension_include_order
  ]

  class << self
    CONTROLLER_OPTIONS.each{|name|attr_accessor name; define_method("#{name}?") { !!public_send(name) } }
    def configure(&blk); class_eval(&blk); end

    # Adds to extension_include_order and extension_include_order, e.g.
    #   ::Irie.register_extension :boolean_params, '::Focal::Irie::BooleanParams'
    # Is equivalent to:
    #   ::Irie.available_extensions[:boolean_params] = '::Focal::Irie::BooleanParams'
    #   ::Irie.extension_include_order << extension_sym
    # Allowed options are `:include`, `:after`, and `:before`. Some examples:
    #   ::Irie.register_extension :boolean_params, '::Example::BooleanParams', include: :last  # the default, so unnecessary
    #   ::Irie.register_extension :boolean_params, '::Example::BooleanParams', include: :first # includes module after all others registered at this point
    #   ::Irie.register_extension :boolean_params, '::Example::BooleanParams', after: :nil_params # includes after :nil_params
    #   ::Irie.register_extension :boolean_params, '::Example::BooleanParams', before: :nil_params # includes after :nil_params
    def register_extension(extension_sym, extension_class_name, options = {})
      raise ::Irie::ConfigurationError.new "Irie.register_extension must provide an extension symbol as the first argument" unless extension_sym
      raise ::Irie::ConfigurationError.new "Irie.register_extension must provide an extension class name (string) as the second argument" unless extension_sym
      raise ::Irie::ConfigurationError.new "Irie.register_extension can only provide a single option: :include, :after, or :before" if options.size > 1
      initial_opts = options.dup
      include_opt, after_opt, before_opt = *[:include, :after, :before].collect{|opt_name| options.delete(opt_name)}
      include_opt = :last unless include_opt || after_opt || before_opt
      raise ::Irie::ConfigurationError.new "Irie.register_extension unrecognized options: #{options.inspect}" if options.size > 0

      ::Irie.extension_include_order.delete(extension_sym)

      before_or_after_opt_value = before_opt || after_opt
      if include_opt == :first
        ::Irie.extension_include_order.unshift extension_sym
      elsif include_opt == :last
        ::Irie.extension_include_order << extension_sym
      elsif before_or_after_opt_value
        ind = ::Irie.extension_include_order.index(before_or_after_opt_value)
        raise ::Irie::ConfigurationError.new "Irie.register_extension cannot insert #{before_opt ? 'before' : 'after'} #{before_or_after_opt_value.inspect}, because #{before_or_after_opt_value.inspect} was not yet registered. A possible workaround for deferred registration may be to require the code that does the prerequisite registration."
        ::Irie.extension_include_order.insert(ind + (after_opt ? 1 : 0), extension_sym)
      else
        raise ::Irie::ConfigurationError.new "Irie.register_extension unsupported options: #{initial_opts.inspect}"
      end

      ::Irie.available_extensions[extension_sym] = extension_class_name
    end
  end

end

::Irie.configure do
  
  # Default for :using in can_filter_by.
  self.can_filter_by_default_using = [:eq]

  # Use one or more alternate request parameter names for functions, e.g.
  # `self.function_param_names = {distinct: :very_distinct, limit: [:limit, :limita]}`
  self.function_param_names = {}
  
  # Delimiter for ARel predicate in the request parameter name.
  self.predicate_prefix = '.'

  # You'd set this to false if id is used for something else other than primary key.
  self.id_is_primary_key_param = true

  # Used when paging is enabled.
  self.number_of_records_in_a_page = 15

  # When you include the defined action module, it includes the associated modules.
  # If value or value array contains symbol it will look up symbol in 
  # ::Irie.available_extensions in the controller (which is defaulted to 
  # `::Irie.available_extensions`). If value is String will assume String is the
  # fully-qualified module name to include, e.g. `index: '::My::Module'`, If constant,
  # it will just include constant (module), e.g. `index: ::My::Module`.
  self.autoincludes = {
    create: [:smart_layout, :query_includes],
    destroy: [:smart_layout, :query_includes],
    edit: [:smart_layout, :query_includes],
    index: [:smart_layout, :index_query, :order, :param_filters, :params_to_joins, :query_filter, :query_includes],
    new: [:smart_layout],
    show: [:smart_layout, :query_includes],
    update: [:smart_layout, :query_includes]
  }

  # This ensures the correct order of includes via the extensions method. It bears no
  # relevance on whether the include is included or not. Since many includes call
  # super in their methods, the order may seem partially reversed, but this is the actual
  # include order. If extensions are not listed here, they will not be included by
  # the extensions method.
  self.extension_include_order = [
    :smart_layout,
    :autorender_page_count,
    :autorender_count,
    :count,
    :paging,
    :order,
    :offset,
    :limit,
    :param_filters,
    :query_filter,
    :params_to_joins,
    :query_includes,
    :index_query,
    :nil_params
  ]

  # Extensions to actions that you can implement in the controller via
  # `include_extensions`, e.g. `include_extensions :count, :paging`
  # Each is added as each file is required when the gem is loaded, so for a full list,
  # check `::Irie.available_extensions` in rails console.
  # You shouldn't have to worry about configuring this typically.
  self.available_extensions = {}

  # If true, will logger.debug in instance methods to help with execution tracing at
  # runtime.
  self.debug = false
end
