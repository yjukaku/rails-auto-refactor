module RailsAutoRefactor
  module Refactorers
    class FlashRewriter <  Parser::Rewriter

      attr_reader :nodes_to_replace_map

      def initialize(nodes_to_replace_map)
        @nodes_to_replace_map = nodes_to_replace_map
      end

      def on_send(node)
        if nodes_to_replace_map[node]
          replace(node.location.expression, nodes_to_replace_map[node])
        end
        super
      end
    end
  end
end