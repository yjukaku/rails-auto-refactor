module RailsAutoRefactor
  class MethodDescriptor
    attr_accessor :class_name, :method, :method_name
    def initialize(method, class_name)
      self.class_name, self.method = class_name, method
      self.method_name = method.loc.name.source
    end

    def to_s
      "#{class_name}##{method_name}"
    end

    def method_body
      first_begin_for_node(method).location.expression.source
    end

    def assumed_instance_variables
      assigned_instance_variables
      used_instance_variables = find_all_used_instance_variables(first_begin_for_node(method), [])
      # If we assign the @var, and then use it later, don't count it here. (get rid of the ones we created ourselves)
      used_instance_variables - assigned_instance_variables
    end

    def assigned_instance_variables
      assigned_vars = find_all_assigned_instance_variables(method, [])
    end

    private

    def first_begin_for_node(tree)
      tree.children.find{|n| n.respond_to?(:type) && n.type == :begin}
    end

    def find_all_used_instance_variables(tree, found_variables)
      tree.children.each do |child|
        next if !child.is_a?(Parser::AST::Node)
        if child.type == :ivar
          var_name = child.location.name.source
          if !found_variables.include?(var_name)
            found_variables << var_name
          end
        else
          find_all_used_instance_variables(child, found_variables)
        end
      end
      found_variables
    end

    def find_all_assigned_instance_variables(tree, found_variables)
      tree.children.each do |child|
        next if !child.is_a?(Parser::AST::Node)
        if child.type == :ivasgn
          var_name = child.location.name.source
          if !found_variables.include?(var_name)
            found_variables << var_name
          end
        else
          find_all_assigned_instance_variables(child, found_variables)
        end
      end
      found_variables

    end

  end
end