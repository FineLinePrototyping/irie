module Irie
  module ClassMethods

    protected

    def extensions(*extension_syms)
      ::Irie::CONTROLLER_OPTIONS.each do |key|
        class_attribute key, instance_writer: true unless respond_to?(key)
        # doing unless self.send(key.to_sym) to ensure parent override of defaults is kept
        self.send("#{key}=".to_sym, ::Irie.send(key)) unless self.send(key.to_sym)
      end

      #raise "self.inherited_resources_defined_actions = #{inherited_resources_defined_actions.inspect}\n\ninstance_methods = #{self.instance_methods.collect(&:to_s).sort.join(', ')}\n\nself.autoincludes = #{self.autoincludes.inspect}" if $gary

      self.autoincludes.keys.each do |action_sym|
        if self.instance_methods.include?(action_sym.to_sym)
          autoloading_extensions = self.autoincludes[action_sym]
          if autoloading_extensions && autoloading_extensions.size > 0
            extension_syms += autoloading_extensions
          end
        end
      end
      
      extensions! extension_syms
    end

    # Load specified extensions in the order defined by self.extension_include_order.
    def extensions!(*extension_syms)
      return extension_syms if extension_syms.length == 0

      extension_syms = extension_syms.flatten.collect {|es| es.to_sym}.compact

      if extension_syms.include?(:all)
        ordered_extension_syms = self.extension_include_order.dup
      else
        extensions_without_defined_order = extension_syms.uniq - self.extension_include_order.uniq
        if extensions_without_defined_order.length > 0
          raise ::Irie::ConfigurationError.new "The following must be added to the self.extension_include_order array in Irie configuration: #{extensions_without_defined_order.collect(&:inspect).join(', ')}"
        else
          ordered_extension_syms = self.extension_include_order & extension_syms
        end
      end

      # load requested extensions
      ordered_extension_syms.each do |arg_sym|
        if module_class_name = self.available_extensions[arg_sym]
          begin
            ::Irie.logger.debug("[Irie] Irie::ClassMethods.extensions! #{self} including #{module_class_name}") if ::Irie.debug?
            include module_class_name.constantize
          rescue NameError => e
            raise ::Irie::ConfigurationError.new "Failed to constantize '#{module_class_name}' with extension key #{arg_sym.inspect} in self.available_extensions. Error: \n#{e.message}\n#{e.backtrace.join("\n")}"
          end      
        else
          raise ::Irie::ConfigurationError.new "#{arg_sym.inspect} isn't defined in self.available_extensions"
        end
      end

      extension_syms
    end
  end
end
