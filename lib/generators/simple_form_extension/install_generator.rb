module SimpleFormExtension
  module Generators
    class InstallGenerator < Rails::Generators::Base
      desc "Copy SimpleFormExtension files"
      source_root File.expand_path('../templates', __FILE__)
    
      def copy_config
        template "config/initializers/simple_form_extension.rb"
      end
    end
  end
end
