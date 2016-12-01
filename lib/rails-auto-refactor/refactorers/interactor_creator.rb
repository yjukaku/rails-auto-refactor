require 'rails-auto-refactor/extract_exception'
require_relative 'refactor_helper'

module RailsAutoRefactor
  module Refactorers
    class InteractorCreator

      extend RefactorHelper

      class FlashRewriter <  Parser::Rewriter
        def on_send
          
        end
      end

      def self.call(output_dir, method_descriptors)
        skipped_methods = []
        method_descriptors.each do |md|
          begin
            suggested_output = suggested_output(md)

            FileUtils::mkdir_p output_dir

            output_path = File.join(output_dir, suggested_output.file_name)
            output_path += ".rb"
            File.open(output_path, 'w') do |file|
              file_str = generate_file(md, suggested_output.service_class_name)
              file.write(file_str)
            end
          rescue RailsAutoRefactor::ExtractException => e
            puts "WARNING! Failed to extract #{md} to a separate class. (#{e}) Skipping..."
            skipped_methods << md
          end
        end

        skipped_methods
      end

      def self.generate_file(method_descriptor, service_class_name)
        assumed_instance_var_strings_asserts = method_descriptor.assumed_instance_variables.map do |ivar|
          context_ivar_name = ivar.gsub(/^@/,"")
          "context.fail!(error: \"#{context_ivar_name}\" is required) if context.#{context_ivar_name}.nil?"
        end.join("\n\t\t")

        assumed_instance_var_assignments = method_descriptor.assumed_instance_variables.map do |ivar|
          context_ivar_name = ivar.gsub(/^@/,"")
          "@#{context_ivar_name} = context.#{context_ivar_name}"
        end.join("\n\t\t")

        returned_instance_var_strings = method_descriptor.assigned_instance_variables.map do |ivar|
          context_ivar_name = ivar.gsub(/^@/,"")
          "context.#{context_ivar_name} = #{ivar}"
        end.join("\n\t\t")

        convert_flash_messages(method_descriptor)

        file_str = <<-TEMP
    # Extracted from #{method_descriptor.class_name}##{method_descriptor.method_name}
    class #{service_class_name}
      include Interactor

      before do
        context.fail!(error: "params is required") if params.nil?
        #{assumed_instance_var_strings_asserts}
      end

      def call
        # Things the context is expected to have
        params = context.params
        #{assumed_instance_var_assignments}

        #{method_descriptor.method_body}

        # Things the context must return
        #{returned_instance_var_strings}
      end
    end
        TEMP
        file_str
      end

      def self.convert_flash_messages(method_descriptor)
        method = method_descriptor.method
        flash_nodes = flash_nodes(method)
        flash_nodes.each do |flash_node|
          if flash_node.flash_type == "error"
            
          end
        end
      end

      def self.exception_raiser(msg)
        return "context.fail!(error: msg)"
      end

    end
  end
end