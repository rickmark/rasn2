module RASN1
  module Helpers
    module Colorize
      def parens_hex(input, padding=2)
        input = input.is_a?(Integer) ? ("0x%0#{padding}x")% input : "0x#{input}"
        "#{colorize('(').webgray}#{colorize(input).blue}#{colorize(')').webgray}"
      end

      def int_with_hex(input)
        "#{colorize(input).blue} #{parens_hex(input)}"
      end

      def brace_surround(input)
        "#{colorize('[').webgray} #{input} #{colorize(']').webgray}"
      end

      def colorize_class(name, tag_id=nil)
        if tag_id
          "#{colorize(name).bold.yellow} #{parens_hex(tag_id)}"
          else
        colorize(name).bold.yellow
        end
      end

      def colorize_id(id, tag_class=nil)
        id = id.strip if id.is_a? String
        tag_class = tag_class.strip if tag_class.is_a? String
        if tag_class && tag_class != ''
          brace_surround("#{colorize_class(tag_class)} #{colorize(id).bold.green}")
        else
          brace_surround(colorize(id).bold.green)
        end

      end

      def length_specifier(data_length, encoded_length = nil)
        encoded_length = data_length if encoded_length.nil?
        "#{colorize('len:').gray} #{colorize(data_length).blue} #{parens_hex(encoded_length)}"
      end

      def colorize_name(name)
        colorize(name).bold.white
      end

      def colorize_attribute(attribute)
        colorize(attribute).bold.magenta
      end

      def colorize_nil(name = 'NONE')
        colorize(name).red.bold
      end

      def colorize_enum(name, raw_value)
        raw_value = raw_value.unpack1('H*') if raw_value.is_a?(String)
        "#{colorize_class(name)} #{parens_hex(raw_value)}"
      end

      def colorize_bool(value, raw_value)
        if value
          "#{colorize('TRUE').bold.green} #{parens_hex(raw_value)}"
        else
          "#{colorize('FALSE').bold.red} #{parens_hex(raw_value)}"
        end
      end
    end
  end
end