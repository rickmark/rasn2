# frozen_string_literal: true

module RASN1
  # @private
  class Tracer
    # @return [IO]
    attr_reader :io
    # @return [Integer]
    attr_accessor :tracing_level
    # @return [Boolean]
    attr_reader :color

    TRACED_CLASSES = [Types::Any, Types::Choice, Types::Sequence, Types::SequenceOf, Types::Base].freeze

    # @param [IO] io
    # @param [Boolean] color enable colorized output using pastel gem
    def initialize(io, color: false)
      @io = io
      @tracing_level = 0
      @color = color
      @pastel = nil
      if color
        begin
          require 'pastel'
          @pastel = Pastel.new
        rescue LoadError
          @color = false
        end
      end
    end

    # Puts +msg+ onto {#io}.
    # @param [String] msg
    # @return [void]
    def trace(msg)
      msg = colorize(msg) if @pastel
      @io.puts(indent << msg)
    end

    # Return identation for given +level+. If +nil+, use {#tracing_level}.
    # @param [Integer,nil] level
    # @return [String]
    def indent(level=nil)
      level ||= @tracing_level
      '  ' * level
    end

    private

    # Colorize a trace message using pastel.
    # @param [String] msg
    # @return [String]
    def colorize(msg)
      return msg unless @pastel

      # Colorize hex dump lines (e.g. "  0000  61 62 63 ...")
      if msg.match?(/\A\s*[0-9a-f]{4}\s/)
        return @pastel.blue(msg)
      end

      result = +''

      # Colorize element name prefix (e.g. "seqof ", "id ")
      if msg.match?(/\A(\w+)\s/)
        name_match = msg.match(/\A(\w+)\s/)
        # Only treat it as a name if followed by a tag bracket, type keyword, or known keyword
        if msg.match?(/\A\w+\s+(\[|CHOICE|ANY|EXPLICIT|IMPLICIT)/)
          result << @pastel.cyan.bold(name_match[1]) << ' '
          msg = msg[name_match[0].length..]
        end
      end

      # Colorize tag brackets and content (e.g. "[ 16 ] ", "[ CONTEXT 4 ] ")
      if (tag_match = msg.match(/\A(\[.*?\]\s)/))
        result << @pastel.yellow(tag_match[1])
        msg = msg[tag_match[0].length..]
      end

      # Colorize EXPLICIT/IMPLICIT keywords
      if (mod_match = msg.match(/\A(EXPLICIT|IMPLICIT)\s/))
        result << @pastel.magenta(mod_match[1]) << ' '
        msg = msg[mod_match[0].length..]
      end

      # Colorize type name (e.g. "SEQUENCE", "INTEGER", "OCTET STRING", "BOOLEAN", etc.)
      if (type_match = msg.match(/\A([A-Z][A-Z ]*[A-Z]|ANY|CHOICE)/))
        result << @pastel.green.bold(type_match[1])
        msg = msg[type_match[0].length..]
      end

      # Colorize OPTIONAL keyword
      if (opt_match = msg.match(/\A(\s*OPTIONAL)/))
        result << @pastel.red(opt_match[1])
        msg = msg[opt_match[0].length..]
      end

      # Colorize DEFAULT VALUE
      if (def_match = msg.match(/\A(\s*DEFAULT VALUE\s*\S*)/))
        result << @pastel.red(def_match[1])
        msg = msg[def_match[0].length..]
      end

      # Colorize NONE
      if (none_match = msg.match(/\A(\s*NONE)/))
        result << @pastel.red.dim(none_match[1])
        msg = msg[none_match[0].length..]
      end

      # Append remaining text (encoded id, length, data value)
      result << msg
      result
    end
  end

  # Trace RASN1 parsing to +io+.
  # All parsing methods called in block are traced to +io+. Each ASN.1 element is
  # traced in a line showing element's id, its length and its data.
  # @param [IO] io
  # @param [Boolean] color enable colorized output using pastel gem (requires pastel to be installed)
  # @example
  #   RASN1.trace do
  #     RASN1.parse("\x02\x01\x01")  # puts "INTEGER id: 2 (0x02), len: 1 (0x01), data: 0x01"
  #   end
  #   RASN1.parse("\x01\x01\xff")    # puts nothing onto STDOUT
  # @example with color
  #   RASN1.trace(color: true) do
  #     RASN1.parse("\x02\x01\x01")  # same output but with ANSI colors
  #   end
  # @return [void]
  def self.trace(io=$stdout, color: false)
    @tracer = Tracer.new(io, color: color)
    Tracer::TRACED_CLASSES.each(&:start_tracing)

    begin
      yield @tracer
    ensure
      Tracer::TRACED_CLASSES.reverse.each(&:stop_tracing)
      @tracer.io.flush
      @tracer = nil
    end
  end

  # @private
  def self.tracer
    @tracer
  end

  module Types
    class Base
      class << self
        # @private
        # Patch {#do_parse} to add tracing ability
        def start_tracing
          alias_method :do_parse_without_tracing, :do_parse
          alias_method :do_parse, :do_parse_with_tracing
          alias_method :do_parse_explicit_without_tracing, :do_parse_explicit
          alias_method :do_parse_explicit, :do_parse_explicit_with_tracing
        end

        # @private
        # Unpatch {#do_parse} to remove tracing ability
        def stop_tracing
          alias_method :do_parse, :do_parse_without_tracing
          alias_method :do_parse_explicit, :do_parse_explicit_without_tracing
        end
      end

      # @private
      # Parse +der+ with tracing abillity
      # @see #parse!
      def do_parse_with_tracing(der, ber:)
        ret = do_parse_without_tracing(der, ber: ber)
        RASN1.tracer.trace(self.trace)
        ret
      end

      def do_parse_explicit_with_tracing(data)
        RASN1.tracer.tracing_level += 1
        do_parse_explicit_without_tracing(data)
        RASN1.tracer.tracing_level -= 1
      end
    end

    class Choice
      class << self
        # @private
        # Patch {#parse!} to add tracing ability
        def start_tracing
          alias_method :parse_without_tracing, :parse!
          alias_method :parse!, :parse_with_tracing
        end

        # @private
        # Unpatch {#parse!} to remove tracing ability
        def stop_tracing
          alias_method :parse!, :parse_without_tracing
        end
      end

      # @private
      # Parse +der+ with tracing abillity
      # @see #parse!
      def parse_with_tracing(der, ber: false)
        RASN1.tracer.trace(self.trace)
        parse_without_tracing(der, ber: ber)
      end
    end

    class Sequence
      class << self
        # @private
        # Patch {#der_to_value} to add tracing ability
        def start_tracing
          alias_method :der_to_value_without_tracing, :der_to_value
          alias_method :der_to_value, :der_to_value_with_tracing
        end

        # @private
        # Unpatch {#der_to_value} to remove tracing ability
        def stop_tracing
          alias_method :der_to_value, :der_to_value_without_tracing
        end
      end

      # @private
      # der_to_value +der+ with tracing abillity
      def der_to_value_with_tracing(der, ber: false)
        RASN1.tracer.tracing_level += 1
        der_to_value_without_tracing(der, ber: ber)
        RASN1.tracer.tracing_level -= 1
      end
    end

    class SequenceOf
      class << self
        # @private
        # Patch {#der_to_value} to add tracing ability
        def start_tracing
          alias_method :der_to_value_without_tracing, :der_to_value
          alias_method :der_to_value, :der_to_value_with_tracing
        end

        # @private
        # Unpatch {#der_to_value} to remove tracing ability
        def stop_tracing
          alias_method :der_to_value, :der_to_value_without_tracing
        end
      end

      # @private
      # der_to_value +der+ with tracing abillity
      def der_to_value_with_tracing(der, ber: false)
        RASN1.tracer.tracing_level += 1
        der_to_value_without_tracing(der, ber: ber)
        RASN1.tracer.tracing_level -= 1
      end
    end
  end
end
