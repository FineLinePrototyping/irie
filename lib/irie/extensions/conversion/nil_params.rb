module Irie
  module Extensions
    module Conversion
      # Converts the following filter request param values to nil: 'NULL', 'null', 'nil'
      module NilParams
        extend ::ActiveSupport::Concern
        ::Irie.available_extensions[:nil_params] = '::' + NilParams.name

        NILS = ['NULL'.freeze, 'null'.freeze, 'nil'.freeze].to_set

        protected

        # Converts request param value(s) 'NULL', 'null', and 'nil' to nil.
        def convert_param(param_name, param_value_or_values)
          ::Irie.logger.debug("[Irie] Irie::Extensions::Conversion::NilParams.convert_param(#{param_name.inspect}, #{param_value_or_values.inspect})") if ::Irie.debug?
          param_value_or_values = super if defined?(super)
          if param_value_or_values.is_a? Array
            result = param_value_or_values.map{|v| v && NILS.include?(v) ? nil : v }
          else
            result = param_value_or_values && NILS.include?(param_value_or_values) ? nil : param_value_or_values
          end
          ::Irie.logger.debug("[Irie] Irie::Extensions::Conversion::NilParams.convert_param: result: #{result.inspect}") if ::Irie.verbose?
          result
        end
      
      end
    end
  end
end
