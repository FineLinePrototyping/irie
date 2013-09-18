module Actionizer
  module Actions
    module Edit
      extend ::ActiveSupport::Concern

      included do
        include ::Actionizer::Actions::Base
        include ::Actionizer::Actions::Common::Finders
      end

      # The controller's edit method (e.g. used for edit record in html format).
      def edit
        return catch(:action_break) do
          render_edit perform_edit(params_for_edit)
        end || @action_result
      end

      def params_for_edit
        @aparams = params
      end

      def perform_edit(aparams)
        record = find_model_instance!(aparams)
        instance_variable_set(@model_at_singular_name_sym, record)
      end

      def render_edit(record)
        respond_with record, (render_edit_options(record) || {}).merge(self.action_to_valid_render_options[:edit] || {})
      end

      def render_edit_options(record)
        {}
      end
    end
  end
end