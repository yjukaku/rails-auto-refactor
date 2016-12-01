require "parser/current"
require 'fileutils'
require 'active_support'
require 'active_support/inflector'
require_relative 'lib/method_with_class'
require_relative 'lib/interactor_creator'

CONTROLLER_DIR = "app/controllers"
SERVICES_DIR = "app/auto_services"


class ExtractException < StandardError; end

def parse_controller(file_str)
  tree = Parser::CurrentRuby.parse(file_str)

  if tree.type != :class
    raise "The root node must be a Class"
  end
  class_begin = first_begin_for_node(tree)
  find_long_methods(class_begin || tree, tree.loc.name.source)
end


def first_begin_for_node(tree)
  tree.children.find{|n| n.type == :begin}
end

def find_long_methods(tree, controller_class_name)
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
    MethodWithClass.new(m, controller_class_name)
  }
end


def find_all_methods(tree)
  defs = tree.children.select{|n|
    n.type == :def
  }
  defs
end

def extract_method_to_service(method_with_class)
  FileUtils::mkdir_p SERVICES_DIR
  method = method_with_class.method
  controller_class_name = method_with_class.class_name
  method_name = method.loc.name.source
  service_class_name = method_name.camelize
  file_name = "#{method_name}"

  # Method names typically associated with HTTP GET.
  # These are usually retrieving data and likely wouldn't benefit
  # from ServiceObject extraction
  get_method_names = [
    "index"
    "show",
    "new",
    "edit",
  ]

  if get_method_names.include?(method_name)
    puts "Skipping method '#{method_name}' because it is likely a GET related action"
    return
  end

  resource_method_names = [
    "index",
    "show",
    "new",
    "create",
    "edit",
    "update",
    "destroy"
  ]


  # These are very generic and repeated across many controllers
  # so let's add the controller name to disambiguate them
  if resource_method_names.include?(method_name)
    resource_name = controller_class_name.gsub("Controller", "").singularize
    service_class_name = "#{service_class_name}#{resource_name}"
    file_name = "#{file_name}_#{resource_name.underscore}"
  end

  file_name = "#{file_name}.rb"
  file_path = File.join(SERVICES_DIR, file_name)
  if File.exists?(file_path)
    raise ExtractException, "Couldn't extract method #{method_name} to a service. File '#{file_path}' already exists."
  end
  puts "\t Creating Service Object Class named '#{service_class_name}' in file '#{file_path}'"

  service_writer = InteractorCreator
  File.open(file_path, 'w') do |f|
    service_writer.write_to_file(service_class_name, method_with_class, f)
  end

end

skipped_methods = []

Dir.glob("#{CONTROLLER_DIR}/*_controller.rb") do |file|
  puts "Parsing '#{file}'"
  file_str = File.read(file)
  methods_with_classes = parse_controller(file_str)
  methods_with_classes.each do |mwc|
    begin
      extract_method_to_service(mwc)
    rescue ExtractException => e
      puts "WARNING! Failed to extract #{mwc} to a separate class. (#{e}) Skipping..."
      skipped_methods << mwc
    end
  end
end

if skipped_methods.any?
  puts "WARNING! Skipped the following methods: #{skipped_methods.map{|mwc| mwc.to_s}}"
end
