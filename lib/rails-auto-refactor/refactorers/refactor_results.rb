module RailsAutoRefactor
  module Refactorers
    class RefactorResults
      attr_accessor :skipped_methods, :refactorable_methods
      def initialize(skipped_methods, refactorable_methods)
        self.skipped_methods = skipped_methods
        self.refactorable_methods = refactorable_methods
      end
    end
  end
end