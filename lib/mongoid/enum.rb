require "mongoid/enum/version"
require "mongoid/enum/validators/multiple_validator"
require "mongoid/enum/configuration"

module Mongoid
  module Enum
    extend ActiveSupport::Concern
    module ClassMethods

      def enum(name, values, options = {})
        field_name = :"#{Mongoid::Enum.configuration.field_name_prefix}#{name}"
        options = default_options(values).merge(options)

        set_values_constant name, values

        create_field field_name, options

        create_validations field_name, values, options
        define_value_scopes_and_accessors field_name, values, options
        define_field_accessor name, field_name, options
      end

      private
      def default_options(values)
        {
          :multiple => false,
          :default  => values.first,
          :required => true,
          :validate => true
        }
      end

      def set_values_constant(name, values)
        const_name = name.to_s.upcase
        const_set const_name, values
      end

      def create_field(field_name, options)
        type = options[:multiple] && Array || Symbol
        field field_name, :type => type, :default => options[:default]
      end

      def create_validations(field_name, values, options)
        if options[:multiple] && options[:validate]
          validates field_name, :'mongoid/enum/validators/multiple' => { :in => values.map(&:to_sym), :allow_nil => !options[:required] }
        #FIXME: Shouldn't this be `elsif options[:validate]` ???
        elsif validate
          validates field_name, :inclusion => {:in => values.map(&:to_sym)}, :allow_nil => !options[:required]
        end
      end

      def define_value_scopes_and_accessors(field_name, values, options)
        values.each do |value|
          scope value, ->{ ::Rails.logger.fatal "MONGOID_ENUM_TRACER: Scope `#{self}##{field_name}.#{value}` called from #{::Rails.backtrace_cleaner.clean(caller).presence || caller.first}"; where(field_name => value) }

          if options[:multiple]
            define_array_accessor(field_name, value)
          else
            define_string_accessor(field_name, value)
          end
        end
      end

      def define_field_accessor(name, field_name, options)
        if options[:multiple]
          define_array_field_accessor name, field_name
        else
          define_string_field_accessor name, field_name
        end
      end

      def define_array_field_accessor(name, field_name)
        class_eval "def #{name}=(vals) ::Rails.logger.fatal \"MONGOID_ENUM_TRACER: Array setter `#{self}##{name}.#{field_name}=` called from \#{::Rails.backtrace_cleaner.clean(caller).presence || caller.first}\"; self.write_attribute(:#{field_name}, Array(vals).compact.map(&:to_sym)) end"
        class_eval "def #{name}() ::Rails.logger.fatal \"MONGOID_ENUM_TRACER: Array getter `#{self}##{name}.#{field_name}` called from \#{::Rails.backtrace_cleaner.clean(caller).presence || caller.first}\"; self.read_attribute(:#{field_name}) end"
      end

      def define_string_field_accessor(name, field_name)
        class_eval "def #{name}=(val) ::Rails.logger.fatal \"MONGOID_ENUM_TRACER: Field setter `#{self}##{name}.#{field_name}=` called from \#{::Rails.backtrace_cleaner.clean(caller).presence || caller.first}\"; self.write_attribute(:#{field_name}, val && val.to_sym || nil) end"
        class_eval "def #{name}() ::Rails.logger.fatal \"MONGOID_ENUM_TRACER: Field getter `#{self}##{name}.#{field_name}` called from \#{::Rails.backtrace_cleaner.clean(caller).presence || caller.first}\"; self.read_attribute(:#{field_name}) end"
      end

      def define_array_accessor(field_name, value)
        class_eval "def #{value}?() ::Rails.logger.fatal \"MONGOID_ENUM_TRACER: Array inquirer `#{self}##{field_name}.#{value}?` called from \#{::Rails.backtrace_cleaner.clean(caller).presence || caller.first}\"; self.#{field_name}.include?(:#{value}) end"
        class_eval "def #{value}!() ::Rails.logger.fatal \"MONGOID_ENUM_TRACER: Array value setter `#{self}##{field_name}.#{value}=` called from \#{::Rails.backtrace_cleaner.clean(caller).presence || caller.first}\"; update_attributes! :#{field_name} => (self.#{field_name} || []) + [:#{value}] end"
      end

      def define_string_accessor(field_name, value)
        method_name = value.to_s.gsub('-', '_').to_sym
        class_eval "def #{method_name}?() ::Rails.logger.fatal \"MONGOID_ENUM_TRACER: Field inquirer `#{self}##{field_name}.#{value}?` called from \#{::Rails.backtrace_cleaner.clean(caller).presence || caller.first}\"; self.#{field_name} == :#{value} end"
        class_eval "def #{method_name}!() ::Rails.logger.fatal \"MONGOID_ENUM_TRACER: Field value setter `#{self}##{field_name}.#{value}=` called from \#{::Rails.backtrace_cleaner.clean(caller).presence || caller.first}\"; update_attributes! :#{field_name} => :#{value} end"
      end
    end
  end
end
