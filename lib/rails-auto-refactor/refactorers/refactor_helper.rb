module RailsAutoRefactor
  module Refactorers
    module RefactorHelper

      RESOURCE_METHOD_NAMES = [
        "index",
        "show",
        "new",
        "create",
        "edit",
        "update",
        "destroy"
      ]


      class SuggestedOutput
        attr_accessor :file_name, :service_class_name
        
        def initialize(file_name, service_class_name)
          self.file_name = file_name
          self.service_class_name = service_class_name
        end

        def file_name_with_extension
          "#{self.file_name}.rb"
        end
      end

      class FlashNode
        attr_accessor :flash_message, :flash_type, :node
        def initialize(flash_type, flash_message, node)
          self.flash_type = flash_type
          self.flash_message = flash_message
          self.node = node
        end
      end

      def suggested_output(method_descriptor)
        method = method_descriptor.method
        controller_class_name = method_descriptor.class_name
        method_name = method.loc.name.source
        service_class_name = method_name.camelize
        file_name = "#{method_name}"

        output = SuggestedOutput.new(file_name, service_class_name)

        # These are very generic methods whose names are probably repeated across many controllers
        # so let's add the controller name to disambiguate them
        if RESOURCE_METHOD_NAMES.include?(method_name)
          output = resourcify_names(output, controller_class_name)
        end

        output
      end

      def extract_method_to_service(method_descriptor)
        FileUtils::mkdir_p SERVICES_DIR
        
        file_path = File.join(SERVICES_DIR, file_name)
        if File.exists?(file_path)
          raise ExtractException, "Couldn't extract method #{method_name} to a service. File '#{file_path}' already exists."
        end
        puts "\t Creating Service Object Class named '#{service_class_name}' in file '#{file_path}'"

        service_writer = InteractorCreator
        File.open(file_path, 'w') do |f|
          service_writer.write_to_file(service_class_name, method_descriptor, f)
        end

      end

      def resourcify_names(suggested_output, controller_class_name)
        resource_name = controller_class_name.gsub("Controller", "").singularize
        service_class_name = "#{suggested_output.service_class_name}#{resource_name}"
        file_name = "#{suggested_output.file_name}_#{resource_name.underscore}"
        suggested_output = SuggestedOutput.new(file_name, service_class_name)
      end


      def flash_nodes(method_tree)
        nodes = []
        find_flash_nodes(method_tree.children.last, nodes)
      end

      def find_flash_nodes(tree, nodes)
        return [] if tree.children.empty?
        tree.children.each do |child_tree|
          next unless child_tree.respond_to?(:type)
          type = child_tree.type
          if type == :send && child_tree.children.last == :flash
            # the last thing sent to the parent node is the flash message
            message = tree.children.last
            # The [2] sent to the parent node is the key in the hash access call ([:key])
            nodes << FlashNode.new(tree.children[2].loc.expression.source.gsub(/"|'|:/, ''), , tree)
            nodes << child_tree
          else
            find_flash_nodes(child_tree, nodes)
          end
        end
        nodes
      end

    end
  end
end