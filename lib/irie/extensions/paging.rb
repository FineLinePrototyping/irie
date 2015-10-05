module Irie
  module Extensions
    # Allows paging of results.
    module Paging
      extend ::ActiveSupport::Concern
      ::Irie.available_extensions[:paging] = '::' + Paging.name

      included do
        include ::Irie::ParamAliases

        class_attribute(:number_of_records_in_a_page, instance_writer: true) unless self.respond_to? :number_of_records_in_a_page

        self.number_of_records_in_a_page = ::Irie.number_of_records_in_a_page
      end

      def index(options={}, &block)
        ::Irie.logger.debug("[Irie] Irie::Extensions::Paging.index") if ::Irie.debug?
        return super(options, &block) unless aliased_param_present?(:page_count)
        @page_count = (collection.count.to_f / self.number_of_records_in_a_page.to_f).ceil
        return respond_to?(:autorender_page_count, true) ? autorender_page_count(options, &block) : super(options, &block)
      end

      protected

      def collection
        ::Irie.logger.debug("[Irie] Irie::Extensions::Paging.collection") if ::Irie.debug?
        object = super
        page_param_value = aliased_param(:page)
        unless page_param_value.nil?
          page = page_param_value.to_i
          page = 1 if page < 1
          ::Irie.logger.debug
          ::Irie.logger.debug("[Irie] Irie::Extensions::Paging.collection: aliased_params: before offset and limit with object=#{object.inspect}") if ::Irie.verbose?
          object = object.offset(self.number_of_records_in_a_page.to_i * (page - 1))
          ::Irie.logger.debug("[Irie] Irie::Extensions::Paging.collection: aliased_params: after offset/before limit with object=#{object.inspect}") if ::Irie.verbose?
          object = object.limit(self.number_of_records_in_a_page.to_i)
          begin
            ::Irie.logger.debug("[Irie] Irie::Extensions::Paging.collection: aliased_params: after offset and limit with object=#{object.inspect}") if ::Irie.verbose?
          rescue => e
            binding.pry
          end
        end

        ::Irie.logger.debug("[Irie] Irie::Extensions::Paging.collection: relation.to_sql so far: #{object.to_sql}") if ::Irie.debug? && object.respond_to?(:to_sql)

        set_collection_ivar object
      end

    end
  end
end
