# frozen_string_literal: true

module HTTP
  class Request
    class Body
      def initialize(body)
        @body = body

        validate_body_type!
      end

      # Returns size which should be used for the "Content-Length" header.
      #
      # @return [Integer]
      def size
        if @body.is_a?(String)
          @body.bytesize
        elsif @body.respond_to?(:read)
          raise RequestError, "IO object must respond to #size" unless @body.respond_to?(:size)
          @body.size
        elsif @body.nil?
          0
        else
          raise RequestError, "cannot determine size of body: #{@body.inspect}"
        end
      end

      # Yields chunks of content to be streamed to the request body.
      #
      # @yieldparam [String]
      def each
        if @body.is_a?(String)
          yield @body
        elsif @body.respond_to?(:read)
          IO.copy_stream(@body, BlockIO.new(Proc.new))
        elsif @body.is_a?(Enumerable)
          @body.each { |chunk| yield chunk }
        end
      end

      private

      def validate_body_type!
        return if @body.is_a?(String)
        return if @body.respond_to?(:read)
        return if @body.is_a?(Enumerable)
        return if @body.nil?

        raise RequestError, "body of wrong type: #{@body.class}"
      end

      class BlockIO
        def initialize(block)
          @block = block
        end

        def write(data)
          @block.call(data)
          data.bytesize
        end
      end
    end
  end
end
