class InteractorCreator

  def self.write_to_file(service_class_name, method_with_class, file)
    file_str = <<-TEMP
# Extracted from #{method_with_class.class_name}##{method_with_class.method_name}
class #{service_class_name}
  include Interactor

  before do
    context.fail!(error: "params is required") if params.nil?
  end

  def call
    params = context.params
    #{method_with_class.method_body}
  end
end
    TEMP
    file.write(file_str)
  end

end