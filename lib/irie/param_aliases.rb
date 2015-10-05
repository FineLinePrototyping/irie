module Irie
  module ParamAliases
    extend ::ActiveSupport::Concern

    protected

    # Looks at ::Irie.function_param_names to get the proper request params
    # to check for for the provided param name in params, then returns an array of all
    # values for all matching defined request params. Does *not* convert param
    # value with convert_param(...).
    def aliased_params(function_sym)
      ::Irie.logger.debug("[Irie] Irie::ParamAliases.aliased_params(#{function_sym.inspect})") if ::Irie.debug?
      if self.function_param_names.key?(function_sym)
        self.function_param_names[function_sym].select {|v| params.key?(v)}.collect {|param_name| params[param_name]}
      else
        params.key?(function_sym) ? Array.wrap(params[function_sym]) : []
      end
    end

    def aliased_param_present?(function_sym)
      ::Irie.logger.debug("[Irie] Irie::ParamAliases.aliased_param_key?(#{function_sym.inspect})") if ::Irie.debug?
      if self.function_param_names.key?(function_sym)
        self.function_param_names[function_sym].select {|v| params.key?(v)}.any? {|param_name| params.key?(param_name)}
      else
        params.key?(function_sym)
      end
    end

    # Same as aliased_params(function_sym).first.
    def aliased_param(function_sym)
      ::Irie.logger.debug("[Irie] Irie::ParamAliases.aliased_param(#{function_sym.inspect})") if ::Irie.debug?
      aliased_params(function_sym).first
    end

  end
end
