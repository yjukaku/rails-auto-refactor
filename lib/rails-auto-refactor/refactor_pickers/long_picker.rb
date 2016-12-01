require "parser/current"

module RailsAutoRefactor
  module RefactorPickers
    ##
    # Picks out methods with a high number of lines
    #
    class LongPicker
      
      def self.extract_refactorable_methods(class_tree)

        if class_tree.type != :class
          raise "The root node must be a Class"
        end
        class_begin = first_begin_for_node(class_tree)
        method_descriptors = find_long_methods(class_begin || class_tree, class_tree.loc.name.source)

        method_descriptors = filter_unwanted_methods(method_descriptors)

        method_descriptors
      end

      def self.filter_unwanted_methods(method_descriptors)
        method_descriptors = method_descriptors.select do |method_descriptor|
          # Method names typically associated with HTTP GET.
          # These are usually retrieving data and likely wouldn't benefit
          # from ServiceObject extraction.
          # TODO Maybe load the routes and remove any actions via :get? Seems difficult + error prone, though.
          get_method_names = [
            "index",
            "show",
            "new",
            "edit",
          ]
        
          method = method_descriptor.method
          method_name = method.loc.name.source

          if get_method_names.include?(method_name)
            puts "Skipping method '#{method_name}' because it is likely a GET related action"
            false
          else
            true
          end
        end
        method_descriptors
      end

      def self.find_long_methods(tree, controller_class_name)
        min_num_lines = 10
        methods = find_all_methods(tree)
        methods = methods.select do |method|
          loc_info = method.loc
          num_lines = loc_info.last_line - loc_info.first_line
          # Don't count the 'end' line
          num_lines -= 1
          num_lines > 10
        end
        if methods.empty?
          puts "Skipping."
          return methods
        end
        puts "\tFound #{methods.length} methods with over #{min_num_lines} lines."
        puts methods.map{|m| "\t#{m.loc.name.source} had #{m.loc.last_line - m.loc.first_line} lines"}
        methods.map{ |m|
          MethodDescriptor.new(m, controller_class_name)
        }
      end


      def self.find_all_methods(tree)
        defs = tree.children.select{|n|
          n.type == :def
        }
        defs
      end

    end
  end
end