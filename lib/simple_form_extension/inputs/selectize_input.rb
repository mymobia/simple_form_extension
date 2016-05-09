module SimpleFormExtension
  module Inputs
    class SelectizeInput < SimpleForm::Inputs::Base
      include SimpleFormExtension::Translations

      # This field only allows local select options (serialized into JSON)
      # Searching for remote ones will be implemented later.
      #
      # Data attributes that may be useful :
      #
      #   :'search-url' => search_url,
      #   :'search-param' => search_param,
      #   :'preload' => preload,
      #
      def input(wrapper_options = {})
        @attribute_name = foreign_key if relation?
        input_html_options[:data] ||= {}

        input_html_options[:data].merge!(
          :'selectize'       => true,
          :'value'           => serialized_value,
          :'creatable'       => creatable?,
          :'collection'      => collection,
          :'max-items'       => max_items,
          :'sort-field'      => sort_field,
          :'search-url'      => search_url,
          :'search-param'    => search_param,
          :'escape'          => escape
        )

        if multi?
          input_html_options[:multiple] = true
        end

        if creatable?
          input_html_options[:'add-translation'] = _translate('selectize.add')
        end

        @builder.hidden_field attribute_name, input_html_options
      end

      def search_param
        options[:search_param] ||= 'q'
      end

      def search_url
        options[:search_url]
      end

      def creatable?
        !!options[:creatable]
      end

      def escape
        options[:escape]
      end

      def multi?
        (options.key?(:multi) && !!options[:multi]) ||
          enumerable?(value)
      end

      def max_items
        options[:max_items]
      end

      def sort_field
        options[:sort_field] ||= 'text'
      end

      def collection
        return if search_url

        if (collection = options[:collection])
          if enumerable?(collection)
            collection.map(&method(:serialize_option))
          else
            (object.send(collection) || []).map(&method(:serialize_option))
          end
        elsif relation?
          reflection.klass.all.map(&method(:serialize_option))
        else
          []
        end
      end

      def serialized_value
        return input_html_options[:data][:value] if input_html_options[:data][:value]

        if multi?
          if relation?
            value.map do |item|
              if (resource = relation.find { |resource| resource.id == item.to_i }) && (text = text_from(resource))
                serialize_value(item, text)
              else
                serialize_value(item)
              end
            end
          else
            value.map(&method(:serialize_value))
          end
        else
          if relation? && relation && (text = text_from(relation))
            serialize_value(value, text)
          else
            serialize_value(value)
          end
        end
      end

      def value
        @value ||= options_fetch(:value) { object.send(attribute_name) }
      end

      def serialize_value(value, text = nil)
        { text: (text || value), value: value }
      end

      private

      def serialize_option(option)
        if option.kind_of?(Hash) && option.key?(:text) && option.key?(:value)
          option
        elsif option.kind_of?(ActiveRecord::Base)
          { text: name_for(option), value: option.id }
        elsif !option.kind_of?(Hash)
          { text: option.to_s, value: option }
        else
          raise ArgumentError.new "The individual collection items should " \
            "either be single items or a hash with :text and :value fields"
        end
      end

      def options_fetch(key, &block)
        [options, input_html_options].each do |hash|
          return hash[key] if hash.key?(key)
        end

        # Return default block value or nil if no block was given
        block ? block.call : nil
      end

      def enumerable?(object)
        object.class.include?(Enumerable) || ActiveRecord::Relation === object
      end

      def name_for(option)
        option.try(:name) || option.try(:title) || option.to_s
      end

      def relation
        @relation ||= object.send(reflection.name) if relation?
      end

      def relation?
        !!reflection
      end

      def reflection
        @reflection ||= if object.class.respond_to?(:reflect_on_association)
          object.class.reflect_on_association(attribute_name)
        end
      end

      def foreign_key
        @foreign_key ||= case reflection.macro
        when :belongs_to then reflection.foreign_key
        when :has_one then :"#{ reflection.name }_id"
        when :has_many then :"#{ reflection.name.to_s.singularize }_ids"
        end
      end

      def text_from(resource)
        resource.try(:title) || resource.try(:name)
      end
    end
  end
end
