require "parser/current"
require 'fileutils'
require 'active_support'
require 'active_support/inflector'
require 'rails-auto-refactor/method_descriptor'
require 'rails-auto-refactor/refactor_pickers/long_picker'
require 'rails-auto-refactor/refactorers/interactor_creator'
require 'pry'

module RailsAutoRefactor
  
  def self.start(controller_dir, services_output_dir, service_object_type)

    skipped_methods = []

    puts "Searching #{controller_dir} for controller files"
    files = controller_files(controller_dir)
    
    refactor_picker = RailsAutoRefactor::RefactorPickers::LongPicker
    writer = RailsAutoRefactor::Refactorers::InteractorCreator

    puts "Found #{files.length} controller files."

    files.each do |file|
      file_str = File.read(file)
      tree = Parser::CurrentRuby.parse(file_str)
      method_descriptors = refactor_picker.extract_refactorable_methods(tree)

      writer.call(services_output_dir, method_descriptors)

    end

  end

  def self.controller_files(base_dir)
    files = []
    base_dir += "/" if base_dir.chars.last != '/'
    Dir.glob("#{base_dir}*_controller.rb") do |file|
      puts "Parsing '#{file}'"
      files << file
    end
    files
  end

end

