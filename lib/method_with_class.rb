class MethodWithClass
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

  private

  def first_begin_for_node(tree)
    tree.children.find{|n| n.respond_to?(:type) && n.type == :begin}
  end
end