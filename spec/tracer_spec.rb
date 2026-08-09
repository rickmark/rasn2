# frozen_string_literal: true

require 'spec_helper'

# rubocop:disable Metrics/BlockLength,Layout/ClosingParenthesisIndentation
module RASN1 # rubocop:disable Metrics/ModuleLength
  module TestTrace
    DER_SEQUENCE = "\x30\x08\x02\x01\x01\x04\x03abc".b.freeze
    TRACE_SEQUENCE = <<~ENDOFTRACE
      [ 16 ] SEQUENCE (0x30), len: 8 (0x08)
        [ 2 ] INTEGER (0x02), len: 1 (0x01)    1 (0x01)
        [ 4 ] OCTET STRING (0x04), len: 3 (0x03)
          0000  61 62 63                                         abc
    ENDOFTRACE

    DER_EXPLICIT_SEQUENCE = "\xa4\x0a\x30\x08\x02\x01\x01\x04\x03abc".b.freeze
    TRACE_EXPLICIT_SEQUENCE = <<~ENDOFTRACE
      [ CONTEXT 4 ] EXPLICIT SEQUENCE (0xa4), len: 10 (0x0a)
        [ 16 ] SEQUENCE (0x30), len: 8 (0x08)
          [ 2 ] INTEGER (0x02), len: 1 (0x01)    1 (0x01)
          [ 4 ] OCTET STRING (0x04), len: 3 (0x03)
            0000  61 62 63                                         abc
    ENDOFTRACE
  end

  describe Tracer do
    let(:io) { StringIO.new }
    subject(:tracer) { described_class.new(io) }

    it 'puts on given iostream' do
      tracer.trace('test')
      expect(io.string).to eq("test\n")
    end
  end

  describe '.trace' do
    let(:io) { StringIO.new }

    context 'with color enabled' do
      around :example do |example|
        RASN1.trace(io, color: true) do
          example.call
        end
        puts(io.string)
      end

      def colorize(input)
        Rainbow.new.wrap(input)
      end

      include RASN1::Helpers::Colorize

      it 'traces a PRIMITIVE parsing' do
        Types::Integer.new.parse!("\x02\x01\x01".b)
        expect(io.string).to eq("#{colorize_id(2)} #{colorize_class('INTEGER',2)}, #{length_specifier(1, 1)}    #{int_with_hex(1)}\n")
      end

      it 'traces an EXPLICIT PRIMITIVE parsing' do
        Types::Integer.new(explicit: 8).parse!("\x88\x03\x02\x01\x01".b)
        expect(io.string).to eq(<<~ENDOFTRACE
          #{colorize_id(8, 'CONTEXT')} #{colorize_attribute('EXPLICIT')} #{colorize_class('INTEGER', 0x88)}, #{length_specifier(3)}
            0000  02 01 01                                         ...
            #{colorize_id(2)} #{colorize_class('INTEGER', 0x02)}, #{length_specifier(1)}    #{int_with_hex(1)}
        ENDOFTRACE
        )
      end

      it 'traces an IMPLICIT PRIMITIVE parsing' do
        Types::Integer.new(implicit: 7, class: :application).parse!("\x47\x01\x01".b)

        expect(io.string).to eq(<<~ENDOFTRACE
          #{colorize_id(7, 'APPLICATION')} #{colorize_attribute('IMPLICIT')} #{colorize_class('INTEGER', 0x47)}, #{length_specifier(1)}    #{int_with_hex(1)}
        ENDOFTRACE
                             )
      end

      it 'traces a ANY parsing' do
        Types::Any.new.parse!("\x02\x01\x01".b)

        expect(io.string).to eq("#{colorize_class('ANY')}\n  0000  02 01 01                                         ...\n")
      end

      it 'traces an OPTIONAL ANY parsing' do
        Types::Any.new(optional: true).parse!('')
        Types::Any.new(optional: true).parse!("\x02\x01\x01".b)
        expect(io.string).to eq(<<~ENDOFTRACE
          #{colorize_class('ANY')} #{colorize_attribute('OPTIONAL')} #{colorize_nil('NONE')}
          #{colorize_class('ANY')} #{colorize_attribute('OPTIONAL')}
            0000  02 01 01                                         ...
        ENDOFTRACE
                             )
      end

      it 'traces a CONSTRUCTED parsing' do
        seq = Types::Sequence.new(value: [ Types::Integer.new, Types::OctetString.new ])
        seq.parse!(TestTrace::DER_SEQUENCE)
        expect(io.string).to eq(<<~ENDOFDATA
            #{colorize_id(16)} #{colorize_class('SEQUENCE', 0x30)}, #{length_specifier(8)}
              #{colorize_id(2)} #{colorize_class('INTEGER', 0x02)}, #{length_specifier(1)}    #{int_with_hex(1)}
              #{colorize_id(4)} #{colorize_class('OCTET STRING', 0x04)}, #{length_specifier(3)}
                0000  61 62 63                                         abc
          ENDOFDATA
        )
      end

      it 'traces an EXPLICIT CONSTRUCTED parsing' do
        seq = Types::Sequence.new(explicit: 4, value: [ Types::Integer.new, Types::OctetString.new ])
        seq.parse!(TestTrace::DER_EXPLICIT_SEQUENCE)
        expect(io.string).to eq(<<~ENDOFTRACE
            #{colorize_id(4, 'CONTEXT')} #{colorize_attribute('EXPLICIT')} #{colorize_class('SEQUENCE', 0xa4)}, #{length_specifier(10)}
              #{colorize_id(16)} #{colorize_class('SEQUENCE', 0x30)}, #{length_specifier(8)}
                #{colorize_id(2)} #{colorize_class('INTEGER', 2)}, #{length_specifier(1)}    #{int_with_hex(1)}
                #{colorize_id(4)} #{colorize_class('OCTET STRING', 4)}, #{length_specifier(3)}
                  0000  61 62 63                                         abc
          ENDOFTRACE
       )
      end

      it 'traces a CONSTRUCTED parsing containing an OPTIONAL element' do
        seq = Types::Sequence.new(value: [ Types::Integer.new(optional: true), Types::OctetString.new ])
        seq.parse!("\x30\x05\x04\x03def".b)
        seq.parse!("\x30\x08\x02\x01\x01\x04\x03abc".b)
        expect(io.string).to eq(<<~ENDOFTRACE
          #{colorize_id(16)} #{colorize_class('SEQUENCE', 0x30)}, #{length_specifier(5)}
            #{colorize_id(2)} #{colorize_class('INTEGER')} #{colorize_attribute('OPTIONAL')} #{colorize_nil}
            #{colorize_id(4)} #{colorize_class('OCTET STRING', 0x04)}, #{length_specifier(3)}
              0000  64 65 66                                         def
          #{colorize_id(16)} #{colorize_class('SEQUENCE', 0x30)}, #{length_specifier(8)}
            #{colorize_id(2)} #{colorize_class('INTEGER')} #{colorize_attribute('OPTIONAL')} #{parens_hex(2)}, #{length_specifier(1)}    #{int_with_hex(1)}
            #{colorize_id(4)} #{colorize_class('OCTET STRING', 4)}, #{length_specifier(3)}
              0000  61 62 63                                         abc
        ENDOFTRACE
                             )
      end

      it 'traces a CONSTRUCTED parsing containing an DEFAULT element' do
        seq = Types::Sequence.new(name: 'seq', value: [ Types::Integer.new(default: 42), Types::OctetString.new ])
        seq.parse!("\x30\x05\x04\x03def".b)
        seq.parse!("\x30\x08\x02\x01\x01\x04\x03abc".b)
        expect(io.string).to eq(<<~ENDOFTRACE
            #{colorize_name('seq')} #{colorize_id(16)} #{colorize_class('SEQUENCE', 0x30)}, #{length_specifier(5)}
              #{colorize_id(2)} #{colorize_class('INTEGER')} #{colorize_attribute('DEFAULT VALUE')} #{colorize_default(42)}
              #{colorize_id(4)} #{colorize_class('OCTET STRING', 4)}, #{length_specifier(3)}
                0000  64 65 66                                         def
            #{colorize_name('seq')} #{colorize_id(16)} #{colorize_class('SEQUENCE', 0x30)}, #{length_specifier(8)}
              #{colorize_id(2)} #{colorize_class('INTEGER', 2)}, #{length_specifier(1)}    #{int_with_hex(1)}
              #{colorize_id(4)} #{colorize_class('OCTET STRING', 4)}, #{length_specifier(3)}
                0000  61 62 63                                         abc
          ENDOFTRACE
        )
      end

      it 'traces a CHOICE parsing' do
        choice = Types::Choice.new(value: [ Types::Integer.new, Types::OctetString.new ])
        choice.parse!("\x02\x01\xff".b)
        choice.parse!("\x04\x03abc".b)
        expect(io.string).to eq(<<~ENDOFTRACE
            #{colorize_class('CHOICE')}
            #{colorize_id(2)} #{colorize_class('INTEGER', 0x02)}, #{length_specifier(1)}    #{int_with_hex(-1, 0xff)}
            #{colorize_class('CHOICE')}
            #{colorize_id(4)} #{colorize_class('OCTET STRING', 0x04)}, #{length_specifier(3)}
              0000  61 62 63                                         abc
          ENDOFTRACE
        )
      end

      it 'traces MODEL parsing' do
        model = TestModel::OfModel.new
        model.parse!("\x30\x12\x30\x06\x02\x01\x0f\x80\x01\x02\x30\x08\x02\x01\x10\x81\x03\x02\x01\x03".b)
        expect(io.string).to eq(<<~ENDOFDATA
          #{colorize_name('seqof')} #{colorize_id(16)} #{colorize_class('SEQUENCE OF', 0x30)}, #{length_specifier(18)}
            #{colorize_name('record')} #{colorize_id(16)} #{colorize_class('SEQUENCE', 0x30)}, #{length_specifier(6)}
              #{colorize_name('id')} #{colorize_id(2)} #{colorize_class('INTEGER', 2)}, #{length_specifier(1)}    #{int_with_hex(15)}
              #{colorize_name('room')} #{colorize_id(0, 'CONTEXT')} #{colorize_attribute('IMPLICIT')} #{colorize_class('INTEGER')} #{colorize_attribute('OPTIONAL')} #{parens_hex(0x80)}, #{length_specifier(1)}    #{int_with_hex(2)}
              #{colorize_name('house')} #{colorize_id(1, 'CONTEXT')} #{colorize_attribute('EXPLICIT')} #{colorize_class('INTEGER')} #{colorize_attribute('DEFAULT VALUE')} #{colorize_default(0)}
            #{colorize_name('record')} #{colorize_id(16)} #{colorize_class('SEQUENCE', 0x30)}, #{length_specifier(8)}
              #{colorize_name('id')} #{colorize_id(2)} #{colorize_class('INTEGER', 2)}, #{length_specifier(1)}    #{int_with_hex(16)}
              #{colorize_name('room')} #{colorize_id(0, 'CONTEXT')} #{colorize_attribute('IMPLICIT')} #{colorize_class('INTEGER')} #{colorize_attribute('OPTIONAL')} #{colorize_nil}
              #{colorize_name('house')} #{colorize_id(1, 'CONTEXT')} #{colorize_attribute('EXPLICIT')} #{colorize_class('INTEGER', 0x81)}, #{length_specifier(3)}
                0000  02 01 03                                         ...
                #{colorize_name('house')} #{colorize_id(2)} #{colorize_class('INTEGER', 0x02)}, #{length_specifier(1)}    #{int_with_hex(3)}
        ENDOFDATA
                             )
      end

      it 'traces wrapped MODEL parsing' do
        model = TestModel::ModelWithImplicitWrapper.new
        model.parse!("\x30\x0d\xa5\x0b\x02\x01\x10\x80\x01\x07\x81\x03\x02\x01\x03".b)
        expect(io.string).to eq(<<~ENDOFDATA
            #{colorize_name('seq')} #{colorize_id(16)} #{colorize_class('SEQUENCE', 0x30)}, #{length_specifier(13)}
              #{colorize_name('a_record')} #{colorize_id(5, 'CONTEXT')} #{colorize_attribute('IMPLICIT')} #{colorize_class('SEQUENCE', 0xa5)}, #{length_specifier(11)}
                #{colorize_name('id')} #{colorize_id(2)} #{colorize_class('INTEGER', 2)}, #{length_specifier(1)}    #{int_with_hex(16)}
                #{colorize_name('room')} #{colorize_id(0, 'CONTEXT')} #{colorize_attribute('IMPLICIT')} #{colorize_class('INTEGER')} #{colorize_attribute('OPTIONAL')} #{parens_hex(0x80)}, #{length_specifier(1)}    #{int_with_hex(7)}
                #{colorize_name('house')} #{colorize_id(1, 'CONTEXT')} #{colorize_attribute('EXPLICIT')} #{colorize_class('INTEGER', 0x81)}, #{length_specifier(3)}
                  0000  02 01 03                                         ...
                  #{colorize_name('house')} #{colorize_id(2)} #{colorize_class('INTEGER', 2)}, #{length_specifier(1)}    #{int_with_hex(3)}
          ENDOFDATA
        )
      end

      it 'traces RASN1.parse' do
        RASN1.parse(TestTrace::DER_SEQUENCE)
        expect(io.string).to eq(<<~ENDOFDATA
            #{colorize_id(16)} #{colorize_class('SEQUENCE', 0x30)}, #{length_specifier(8)}
              #{colorize_id(2)} #{colorize_class('INTEGER', 0x02)}, #{length_specifier(1)}    #{int_with_hex(1)}
              #{colorize_id(4)} #{colorize_class('OCTET STRING', 0x04)}, #{length_specifier(3)}
                0000  61 62 63                                         abc
          ENDOFDATA
        )
      end

      it 'traces RASN1.parse (explicit element)' do
        RASN1.parse(TestTrace::DER_EXPLICIT_SEQUENCE)
        expect(io.string).to eq(<<~ENDOFDATA
          #{colorize_id(4, 'CONTEXT')} #{colorize_class('BASE', 0xa4)}, #{length_specifier(10)}
            0000  30 08 02 01 01 04 03 61 62 63                    0......abc
        ENDOFDATA
                             )
      end

      it 'traces long length' do
        os = Types::OctetString.new(value: 'a' * 256)

        RASN1.parse(os.to_der)

        expect(io.string).to eq(<<~ENDOFDATA
          #{colorize_id(4)} #{colorize_class('OCTET STRING', 0x04)}, #{length_specifier(256, 0x820100)}
            0000  61 61 61 61 61 61 61 61 61 61 61 61 61 61 61 61  aaaaaaaaaaaaaaaa
            0010  61 61 61 61 61 61 61 61 61 61 61 61 61 61 61 61  aaaaaaaaaaaaaaaa
            0020  61 61 61 61 61 61 61 61 61 61 61 61 61 61 61 61  aaaaaaaaaaaaaaaa
            0030  61 61 61 61 61 61 61 61 61 61 61 61 61 61 61 61  aaaaaaaaaaaaaaaa
            0040  61 61 61 61 61 61 61 61 61 61 61 61 61 61 61 61  aaaaaaaaaaaaaaaa
            0050  61 61 61 61 61 61 61 61 61 61 61 61 61 61 61 61  aaaaaaaaaaaaaaaa
            0060  61 61 61 61 61 61 61 61 61 61 61 61 61 61 61 61  aaaaaaaaaaaaaaaa
            0070  61 61 61 61 61 61 61 61 61 61 61 61 61 61 61 61  aaaaaaaaaaaaaaaa
            0080  61 61 61 61 61 61 61 61 61 61 61 61 61 61 61 61  aaaaaaaaaaaaaaaa
            0090  61 61 61 61 61 61 61 61 61 61 61 61 61 61 61 61  aaaaaaaaaaaaaaaa
            00a0  61 61 61 61 61 61 61 61 61 61 61 61 61 61 61 61  aaaaaaaaaaaaaaaa
            00b0  61 61 61 61 61 61 61 61 61 61 61 61 61 61 61 61  aaaaaaaaaaaaaaaa
            00c0  61 61 61 61 61 61 61 61 61 61 61 61 61 61 61 61  aaaaaaaaaaaaaaaa
            00d0  61 61 61 61 61 61 61 61 61 61 61 61 61 61 61 61  aaaaaaaaaaaaaaaa
            00e0  61 61 61 61 61 61 61 61 61 61 61 61 61 61 61 61  aaaaaaaaaaaaaaaa
            00f0  61 61 61 61 61 61 61 61 61 61 61 61 61 61 61 61  aaaaaaaaaaaaaaaa
        ENDOFDATA
                             )
      end

      it 'colorizes long id' do
        os = Types::OctetString.new(implicit: 128, value: 'a')
        RASN1.parse(os.to_der)
        expect(io.string).to eq(<<~ENDOFDATA
            #{colorize_id(128, 'CONTEXT')} #{colorize_class('BASE', 0x9f8100)}, #{length_specifier(1)}
              0000  61                                               a
          ENDOFDATA
        )
      end
    end

    context 'without color enabled' do
      around :example do |example|
        RASN1.trace(io, color: false) do
          example.call
        end
        puts(io.string)
      end

      it 'traces a PRIMITIVE parsing' do
        Types::Integer.new.parse!("\x02\x01\x01".b)
        expect(io.string).to eq("[ 2 ] INTEGER (0x02), len: 1 (0x01)    1 (0x01)\n")
      end

      it 'traces an EXPLICIT PRIMITIVE parsing' do
        Types::Integer.new(explicit: 8).parse!("\x88\x03\x02\x01\x01".b)
        expect(io.string).to eq(<<~ENDOFTRACE
          [ CONTEXT 8 ] EXPLICIT INTEGER (0x88), len: 3 (0x03)
            0000  02 01 01                                         ...
            [ 2 ] INTEGER (0x02), len: 1 (0x01)    1 (0x01)
        ENDOFTRACE
                             )
      end

      it 'traces an IMPLICIT PRIMITIVE parsing' do
        Types::Integer.new(implicit: 7, class: :application).parse!("\x47\x01\x01".b)
        expect(io.string).to eq(<<~ENDOFTRACE
          [ APPLICATION 7 ] IMPLICIT INTEGER (0x47), len: 1 (0x01)    1 (0x01)
        ENDOFTRACE
                             )
      end

      it 'traces a ANY parsing' do
        Types::Any.new.parse!("\x02\x01\x01".b)
        expect(io.string).to eq("ANY\n  0000  02 01 01                                         ...\n")
      end

      it 'traces an OPTIONAL ANY parsing' do
        Types::Any.new(optional: true).parse!('')
        Types::Any.new(optional: true).parse!("\x02\x01\x01".b)
        expect(io.string).to eq(<<~ENDOFTRACE
          ANY OPTIONAL NONE
          ANY OPTIONAL
            0000  02 01 01                                         ...
        ENDOFTRACE
                             )
      end

      it 'traces a CONSTRUCTED parsing' do
        seq = Types::Sequence.new(value: [ Types::Integer.new, Types::OctetString.new ])
        seq.parse!(TestTrace::DER_SEQUENCE)
        expect(io.string).to eq(TestTrace::TRACE_SEQUENCE)
      end

      it 'traces an EXPLICIT CONSTRUCTED parsing' do
        seq = Types::Sequence.new(explicit: 4, value: [ Types::Integer.new, Types::OctetString.new ])
        seq.parse!(TestTrace::DER_EXPLICIT_SEQUENCE)
        expect(io.string).to eq(TestTrace::TRACE_EXPLICIT_SEQUENCE)
      end

      it 'traces a CONSTRUCTED parsing containing an OPTIONAL element' do
        seq = Types::Sequence.new(value: [ Types::Integer.new(optional: true), Types::OctetString.new ])
        seq.parse!("\x30\x05\x04\x03def".b)
        seq.parse!("\x30\x08\x02\x01\x01\x04\x03abc".b)
        expect(io.string).to eq(<<~ENDOFTRACE
          [ 16 ] SEQUENCE (0x30), len: 5 (0x05)
            [ 2 ] INTEGER OPTIONAL NONE
            [ 4 ] OCTET STRING (0x04), len: 3 (0x03)
              0000  64 65 66                                         def
          [ 16 ] SEQUENCE (0x30), len: 8 (0x08)
            [ 2 ] INTEGER OPTIONAL (0x02), len: 1 (0x01)    1 (0x01)
            [ 4 ] OCTET STRING (0x04), len: 3 (0x03)
              0000  61 62 63                                         abc
        ENDOFTRACE
                             )
      end

      it 'traces a CONSTRUCTED parsing containing an DEFAULT element' do
        seq = Types::Sequence.new(name: 'seq', value: [ Types::Integer.new(default: 42), Types::OctetString.new ])
        seq.parse!("\x30\x05\x04\x03def".b)
        seq.parse!("\x30\x08\x02\x01\x01\x04\x03abc".b)
        expect(io.string).to eq(<<~ENDOFTRACE
          seq [ 16 ] SEQUENCE (0x30), len: 5 (0x05)
            [ 2 ] INTEGER DEFAULT VALUE 42
            [ 4 ] OCTET STRING (0x04), len: 3 (0x03)
              0000  64 65 66                                         def
          seq [ 16 ] SEQUENCE (0x30), len: 8 (0x08)
            [ 2 ] INTEGER (0x02), len: 1 (0x01)    1 (0x01)
            [ 4 ] OCTET STRING (0x04), len: 3 (0x03)
              0000  61 62 63                                         abc
        ENDOFTRACE
                             )
      end

      it 'traces a CHOICE parsing' do
        choice = Types::Choice.new(value: [ Types::Integer.new, Types::OctetString.new ])
        choice.parse!("\x02\x01\xff".b)
        choice.parse!("\x04\x03abc".b)
        expect(io.string).to eq(<<~ENDOFTRACE
          CHOICE
          [ 2 ] INTEGER (0x02), len: 1 (0x01)    -1 (0xff)
          CHOICE
          [ 4 ] OCTET STRING (0x04), len: 3 (0x03)
            0000  61 62 63                                         abc
        ENDOFTRACE
                             )
      end

      it 'traces MODEL parsing' do
        model = TestModel::OfModel.new

        model.parse!("\x30\x12\x30\x06\x02\x01\x0f\x80\x01\x02\x30\x08\x02\x01\x10\x81\x03\x02\x01\x03".b)

        expect(io.string).to eq(<<~ENDOFDATA
          seqof [ 16 ] SEQUENCE OF (0x30), len: 18 (0x12)
            record [ 16 ] SEQUENCE (0x30), len: 6 (0x06)
              id [ 2 ] INTEGER (0x02), len: 1 (0x01)    15 (0x0f)
              room [ CONTEXT 0 ] IMPLICIT INTEGER OPTIONAL (0x80), len: 1 (0x01)    2 (0x02)
              house [ CONTEXT 1 ] EXPLICIT INTEGER DEFAULT VALUE 0
            record [ 16 ] SEQUENCE (0x30), len: 8 (0x08)
              id [ 2 ] INTEGER (0x02), len: 1 (0x01)    16 (0x10)
              room [ CONTEXT 0 ] IMPLICIT INTEGER OPTIONAL NONE
              house [ CONTEXT 1 ] EXPLICIT INTEGER (0x81), len: 3 (0x03)
                0000  02 01 03                                         ...
                house [ 2 ] INTEGER (0x02), len: 1 (0x01)    3 (0x03)
        ENDOFDATA
                             )
      end

      it 'traces wrapped MODEL parsing' do
        model = TestModel::ModelWithImplicitWrapper.new

        model.parse!("\x30\x0d\xa5\x0b\x02\x01\x10\x80\x01\x07\x81\x03\x02\x01\x03".b)

        expect(io.string).to eq(<<~ENDOFDATA
          seq [ 16 ] SEQUENCE (0x30), len: 13 (0x0d)
            a_record [ CONTEXT 5 ] IMPLICIT SEQUENCE (0xa5), len: 11 (0x0b)
              id [ 2 ] INTEGER (0x02), len: 1 (0x01)    16 (0x10)
              room [ CONTEXT 0 ] IMPLICIT INTEGER OPTIONAL (0x80), len: 1 (0x01)    7 (0x07)
              house [ CONTEXT 1 ] EXPLICIT INTEGER (0x81), len: 3 (0x03)
                0000  02 01 03                                         ...
                house [ 2 ] INTEGER (0x02), len: 1 (0x01)    3 (0x03)
        ENDOFDATA
                             )
      end

      it 'traces RASN1.parse' do
        RASN1.parse(TestTrace::DER_SEQUENCE)

        expect(io.string).to eq(TestTrace::TRACE_SEQUENCE)
      end

      it 'traces RASN1.parse (explicit element)' do

        RASN1.parse(TestTrace::DER_EXPLICIT_SEQUENCE)

        expect(io.string).to eq(<<~ENDOFDATA
          [ CONTEXT 4 ] BASE (0xa4), len: 10 (0x0a)
            0000  30 08 02 01 01 04 03 61 62 63                    0......abc
        ENDOFDATA
                             )
      end

      it 'traces long length' do
        os = Types::OctetString.new(value: 'a' * 256)

        RASN1.parse(os.to_der)

        expect(io.string).to eq(<<~ENDOFDATA
          [ 4 ] OCTET STRING (0x04), len: 256 (0x820100)
            0000  61 61 61 61 61 61 61 61 61 61 61 61 61 61 61 61  aaaaaaaaaaaaaaaa
            0010  61 61 61 61 61 61 61 61 61 61 61 61 61 61 61 61  aaaaaaaaaaaaaaaa
            0020  61 61 61 61 61 61 61 61 61 61 61 61 61 61 61 61  aaaaaaaaaaaaaaaa
            0030  61 61 61 61 61 61 61 61 61 61 61 61 61 61 61 61  aaaaaaaaaaaaaaaa
            0040  61 61 61 61 61 61 61 61 61 61 61 61 61 61 61 61  aaaaaaaaaaaaaaaa
            0050  61 61 61 61 61 61 61 61 61 61 61 61 61 61 61 61  aaaaaaaaaaaaaaaa
            0060  61 61 61 61 61 61 61 61 61 61 61 61 61 61 61 61  aaaaaaaaaaaaaaaa
            0070  61 61 61 61 61 61 61 61 61 61 61 61 61 61 61 61  aaaaaaaaaaaaaaaa
            0080  61 61 61 61 61 61 61 61 61 61 61 61 61 61 61 61  aaaaaaaaaaaaaaaa
            0090  61 61 61 61 61 61 61 61 61 61 61 61 61 61 61 61  aaaaaaaaaaaaaaaa
            00a0  61 61 61 61 61 61 61 61 61 61 61 61 61 61 61 61  aaaaaaaaaaaaaaaa
            00b0  61 61 61 61 61 61 61 61 61 61 61 61 61 61 61 61  aaaaaaaaaaaaaaaa
            00c0  61 61 61 61 61 61 61 61 61 61 61 61 61 61 61 61  aaaaaaaaaaaaaaaa
            00d0  61 61 61 61 61 61 61 61 61 61 61 61 61 61 61 61  aaaaaaaaaaaaaaaa
            00e0  61 61 61 61 61 61 61 61 61 61 61 61 61 61 61 61  aaaaaaaaaaaaaaaa
            00f0  61 61 61 61 61 61 61 61 61 61 61 61 61 61 61 61  aaaaaaaaaaaaaaaa
        ENDOFDATA
                             )
      end

      it 'traces long id' do
        os = Types::OctetString.new(implicit: 128, value: 'a')

        RASN1.parse(os.to_der)

        expect(io.string).to eq(<<~ENDOFDATA
          [ CONTEXT 128 ] BASE (0x9f8100), len: 1 (0x01)
            0000  61                                               a
        ENDOFDATA
                             )
      end
    end

  end

  module Types
    describe Boolean do
      let(:io) { StringIO.new }

      include Helpers::Colorize

      context 'without color' do
      around :example do |example|
        RASN1.trace(io) do
          example.run
        end
      end

      it 'traces with Boolean format' do
        RASN1.parse("\x01\x01\xff")
        RASN1.parse("\x01\x01\x01", ber: true)
        RASN1.parse("\x01\x01\x00")

        expect(io.string).to eq(<<~ENDOFDATA
          [ 1 ] BOOLEAN (0x01), len: 1 (0x01)    TRUE (0xff)
          [ 1 ] BOOLEAN (0x01), len: 1 (0x01)    TRUE (0x01)
          [ 1 ] BOOLEAN (0x01), len: 1 (0x01)    FALSE (0x00)
        ENDOFDATA
                             )
      end
      end

      context 'with color' do
        around :example do |example|
          RASN1.trace(io, color: true) do
            example.run
          end
        end

        def colorize(input)
          Rainbow.new.wrap(input)
        end

        it 'traces with Boolean format' do
          RASN1.parse("\x01\x01\xff")
          RASN1.parse("\x01\x01\x01", ber: true)
          RASN1.parse("\x01\x01\x00")

          expect(io.string).to eq(<<~ENDOFDATA
            #{colorize_id(1)} #{colorize_class('BOOLEAN', 1)}, #{length_specifier(1)}    #{colorize_bool(true, 0xff)}
            #{colorize_id(1)} #{colorize_class('BOOLEAN', 1)}, #{length_specifier(1)}    #{colorize_bool(true, 0x01)}
            #{colorize_id(1)} #{colorize_class('BOOLEAN', 1)}, #{length_specifier(1)}    #{colorize_bool(false, 0x00)}
          ENDOFDATA
                               )
        end
      end
    end

    [ Enumerated, Integer ].each do |klass|
      describe klass do
        let(:io) { StringIO.new }
        subject { klass.new(enum: { 'ONE' => 1, 'TWO' => 2 }) }

        context 'without color' do
          around :example do |example|
            RASN1.trace(io, color: false) do
              example.call
            end
            puts(io.string)
          end


          it 'traces with enum format (enum key exists)' do
            id = klass::ID

            subject.parse!("#{id.chr}\x01\x01")
            subject.parse!("#{id.chr}\x01\x02")

            expect(io.string).to eq(<<~ENDOFDATA
              [ #{id} ] #{klass.type} (0x#{'%02x' % id}), len: 1 (0x01)    ONE (0x01)
              [ #{id} ] #{klass.type} (0x#{'%02x' % id}), len: 1 (0x01)    TWO (0x02)
            ENDOFDATA
                                 )
          end

          it 'traces with enum format (enum key does not exist)' do
            id = klass::ID

            expect { subject.parse!("#{id.chr}\x01\xfe") }.to raise_error(EnumeratedError)
            expect(io.string).to eq(<<~ENDOFDATA
              [ #{id} ] #{klass.type} (0x#{'%02x' % id}), len: 1 (0x01)    -2 (0xfe)
            ENDOFDATA
                                 )
          end
        end


        context 'with color' do
          around :example do |example|
            RASN1.trace(io, color: true) do
              example.call
            end
            puts(io.string)
          end

          def colorize(input)
            Rainbow.new.wrap(input)
          end

          include Helpers::Colorize


          it 'traces with enum format (enum key exists)' do
            id = klass::ID
            klass_name = id == 2 ? 'INTEGER' : 'ENUMERATED'

            subject.parse!("#{id.chr}\x01\x01")
            subject.parse!("#{id.chr}\x01\x02")

            expect(io.string).to eq(<<~ENDOFDATA
              #{colorize_id(id)} #{colorize_class(klass_name, id)}, #{length_specifier(1)}    #{colorize_enum('ONE', 1)}
              #{colorize_id(id)} #{colorize_class(klass_name, id)}, #{length_specifier(1)}    #{colorize_enum('TWO', 2)}
            ENDOFDATA
                                 )
          end

          it 'traces with enum format (enum key does not exist)' do
            id = klass::ID
            klass_name = id == 2 ? 'INTEGER' : 'ENUMERATED'

            expect { subject.parse!("#{id.chr}\x01\xfe") }.to raise_error(EnumeratedError)
            expect(io.string).to eq(<<~ENDOFDATA
              #{colorize_id(id)} #{colorize_class(klass_name, id)}, #{length_specifier(1)}    #{colorize_enum('-2', 0xfe)}
            ENDOFDATA
                                 )
          end
        end
      end
      end

    describe GeneralizedTime do
      let(:io) { StringIO.new }

      include Helpers::Colorize

      context 'without color' do

      around :example do |example|
        RASN1.trace(io, color: false) do
          example.call
        end
        puts(io.string)
      end

      it 'traces with Time format' do
        gt = GeneralizedTime.new(value: Time.utc(2022, 11, 23, 10, 54, 33))

        RASN1.parse(gt.to_der)

        expect(io.string).to eq("[ 24 ] GeneralizedTime (0x18), len: 15 (0x0f)    2022-11-23 10:54:33 UTC\n")
      end

      it 'traces an explicit tag' do
        gt = GeneralizedTime.new(value: Time.utc(2022, 11, 23, 10, 54, 33), explicit: 1, name: 'dueTime')

        gt.parse!(gt.to_der)

        expect(io.string).to eq(<<~ENDOFDATA
          dueTime [ CONTEXT 1 ] EXPLICIT GeneralizedTime (0x81), len: 17 (0x11)
            0000  18 0f 32 30 32 32 31 31 32 33 31 30 35 34 33 33  ..20221123105433
            0010  5a                                               Z
            dueTime [ 24 ] GeneralizedTime (0x18), len: 15 (0x0f)    2022-11-23 10:54:33 UTC
        ENDOFDATA
        )
      end

      end

      context 'with color' do

        around :example do |example|
          RASN1.trace(io, color: true) do
            example.call
          end
        end

        def colorize(input)
          Rainbow.new.wrap(input)
        end

        it 'traces with Time format' do
          gt = GeneralizedTime.new(value: Time.utc(2022, 11, 23, 10, 54, 33))

          RASN1.parse(gt.to_der)

          time = +'    ' << colorize(Time.parse('2022-11-23 10:54:33 UTC')).dark.green

          expect(io.string).to eq("#{colorize_id(24)} #{colorize_class('GeneralizedTime')} #{parens_hex(0x18)}, #{length_specifier(15)}#{time}\n")
        end

        it 'traces an explicit tag' do
          gt = GeneralizedTime.new(value: Time.utc(2022, 11, 23, 10, 54, 33), explicit: 1, name: 'dueTime')

          gt.parse!(gt.to_der)
          time = +'    ' << colorize(Time.parse('2022-11-23 10:54:33 UTC')).dark.green

          expect(io.string).to eq(<<~ENDOFDATA
            #{colorize_name('dueTime')} #{colorize_id(1, 'CONTEXT')} #{colorize_attribute('EXPLICIT')} #{colorize_class('GeneralizedTime', 0x81)}, #{length_specifier(17)}
              0000  18 0f 32 30 32 32 31 31 32 33 31 30 35 34 33 33  ..20221123105433
              0010  5a                                               Z
              #{colorize_name('dueTime')} #{colorize_id(24)} #{colorize_class('GeneralizedTime')} #{parens_hex(0x18)}, #{length_specifier(15)}#{time}
            ENDOFDATA
          )
        end

      end
    end

    describe UtcTime do
      let(:io) { StringIO.new }

      around :example do |example|
        RASN1.trace(io) do
          example.run
        end
      end

      it 'traces with Time format' do
        ut = UtcTime.new(value: Time.utc(2022, 11, 23, 10, 54, 33))

        RASN1.parse(ut.to_der)

        expect(io.string).to eq("[ 23 ] UTCTime (0x17), len: 13 (0x0d)    221123105433Z\n")
      end

      it 'traces an explicit tag' do
        ut = UtcTime.new(value: Time.utc(2022, 11, 23, 10, 54, 33), explicit: 2, name: 'dueTime')

        ut.parse!(ut.to_der)

        expect(io.string).to eq(<<~ENDOFDATA
          dueTime [ CONTEXT 2 ] EXPLICIT UTCTime (0x82), len: 15 (0x0f)
            0000  17 0d 32 32 31 31 32 33 31 30 35 34 33 33 5a     ..221123105433Z
            dueTime [ 23 ] UTCTime (0x17), len: 13 (0x0d)    221123105433Z
        ENDOFDATA
                             )
      end
    end
  end
end

# rubocop:enable Metrics/BlockLength,Layout/ClosingParenthesisIndentation
