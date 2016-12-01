require 'rails-auto-refactor/extract_exception'
require_relative 'refactor_helper'
require_relative 'flash_rewriter'

module RailsAutoRefactor
  module Refactorers
    class InteractorCreator

      extend RefactorHelper

      def self.call(output_dir, method_descriptors)
        skipped_methods = []
        method_descriptors.each do |md|
          begin
            suggested_output = suggested_output(md)

            FileUtils::mkdir_p output_dir

            output_path = File.join(output_dir, suggested_output.file_name)
            output_path += ".rb"
            puts "Generating #{output_path}..."
            File.open(output_path, 'w') do |file|
              file_str = generate_file(md, suggested_output.service_class_name)
              file.write(file_str)
            end
            puts "Generated #{output_path}."
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

        method_body = method_descriptor.method_body

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

        #{method_body}

        # Things the context must return
        #{returned_instance_var_strings}
      end
    end
        TEMP
        file_str
      end

      def self.convert_flash_messages(method_descriptor)
        source_code = method_descriptor.method.location.expression.source
        # create a new AST based on this method
        buffer = Parser::Source::Buffer.new('method')
        buffer.source = source_code
        parser = Parser::CurrentRuby.new
        tree = parser.parse(buffer)
        flash_nodes = flash_nodes(tree)
        map = flash_nodes.select{|flash_node| flash_node.flash_type == "error" }.map do |flash_node|
          [flash_node.node, generate_exception_raiser(flash_node.flash_message)]
        end.to_h
        rewriter = FlashRewriter.new(map)
        puts "Would rewrite to: " + rewriter.rewrite(buffer, tree)
      end

      def self.generate_exception_raiser(error_source)
        return "context.fail!(error: #{error_source})"
      end

    end
  end
end