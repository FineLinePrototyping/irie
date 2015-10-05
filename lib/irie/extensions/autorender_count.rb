module Irie
  module Extensions
    # Standard rendering of index page count in all formats except html so you don't need views for them.
    module AutorenderCount
      extend ::ActiveSupport::Concern
      ::Irie.available_extensions[:autorender_count] = '::' + AutorenderCount.name

      protected
      
      def autorender_count(options={}, &block)
        ::Irie.logger.debug("[Irie] Irie::Extensions::AutorenderCount.autorender_count: count: #{@count}") if ::Irie.debug?
        result = render(request.format.symbol => { count: @count }, status: 200, layout: false)
        ::Irie.logger.debug("[Irie] Irie::Extensions::AutorenderCount.autorender_count: result: #{result.inspect}") if ::Irie.verbose?
        result
      end
      
    end
  end
end
