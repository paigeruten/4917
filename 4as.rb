#!/usr/local/bin/ruby

module FourNineOneSeven
  extend self

  class AssemblyError < StandardError; end
  class AssemblyOperandError < AssemblyError; end
  class AssemblySyntaxError < AssemblyError; end
  class AssemblyOverflowError < AssemblyError; end
  class AssemblyUndefinedSymbolError < AssemblyError; end

  module Opcode
    HALT = 0
    ADD = 1
    SUB = 2
    INC_R0 = 3
    INC_R1 = 4
    DEC_R0 = 5
    DEC_R1 = 6
    BELL = 7
    PRINT = 8
    LOAD_R0 = 9
    LOAD_R1 = 10
    STORE_R0 = 11
    STORE_R1 = 12
    JUMP = 13
    JUMP_ZERO = 14
    JUMP_NOT_ZERO = 15
  end

  def assemble(infile, outfile)
    if infile
      source = File.read(infile)
    else
      source = STDIN.read
    end

    assembler = Assembler.new(source)
    program = assembler.assemble

    File.open(outfile, "w") do |f|
      f << program.to_s
    end
  end

  class Program < Array
    attr_reader :code_index, :data_index, :size

    def initialize(size)
      @code_index = 0
      @data_index = size - 1
      @symbols = {}
      @size = size

      super(@size, 0)
    end

    def insert_code(code)
      if @code_index < @size
        self[idx = @code_index] = code
        @code_index += 1
        idx
      else
        raise AssemblyOverflowError, "not enough memory for all of your program instructions"
      end
    end

    def insert_data(data)
      if @data_index >= 0
        self[idx = @data_index] = data
        @data_index -= 1
        idx
      else
        raise AssemblyOverflowError, "not enough memory for all of your .data directives"
      end
    end

    def add_symbol(symbol, value)
      @symbols[symbol.to_sym] = value
    end

    def overlapping?
      @code_index - 1 >= @data_index + 1
    end

    def overflowing?(max_value)
      (self + @symbols.values).any? { |val| val.is_a?(Integer) && val > max_value }
    end

    def resolve_symbols
      collect! do |cell|
        if cell.is_a? Symbol
          if value = @symbols[cell]
            value
          else
            raise AssemblyUndefinedSymbolError, "trying to use undefined symbol or label"
          end
        else
          cell
        end
      end
    end

    def to_s
      join(" ")
    end
  end

  class Instruction
    attr_reader :name, :expected_operands, :assemble

    def initialize(name, *expected_operands, &assemble)
      @name = name.to_sym
      @expected_operands = expected_operands
      @assemble = assemble
    end
  end

  class Operand
    attr_reader :type, :value

    def initialize(type, value)
      @type = type
      @value = value
    end

    def is_expected?(expected_operand)
      expected_operand == :register_or_number || expected_operand == self.type
    end

    def self.parse(op)
      case op
      when /^%[rR]([01])$/
        Operand.new(:register, $1.to_i)
      when /^\$(\d+)$/
        Operand.new(:number, $1.to_i)
      when /^\$?(\w+)$/
        Operand.new(:number, $1.to_sym)
      else
        raise AssemblySyntaxError, "syntax error, a register or other operand may be misspelled"
      end
    end
  end

  class Assembler
    BYTE_LENGTH = 4
    BYTE_LIMIT = (1 << BYTE_LENGTH) - 1
    MEMORY_LENGTH = 16

    def self.instruction(name, *expected_operands)
      if name.is_a? Hash
        opcode = name.values.first
        name = name.keys.first
        assemble = lambda { |*| opcode }
      end

      if expected_operands.last.is_a? Hash
        assemble = expected_operands.pop[:assemble]
      end

      (@@instructions ||= []) << Instruction.new(name, *expected_operands, &assemble)
    end

    instruction :halt => Opcode::HALT
    instruction :add => Opcode::ADD
    instruction :sub => Opcode::SUB
    instruction :inc, :register, :assemble => lambda { |reg, _|
      if reg.value == 0
        Opcode::INC_R0
      elsif reg.value == 1
        Opcode::INC_R1
      end
    }
    instruction :dec, :register, :assemble => lambda { |reg, _|
      if reg.value == 0
        Opcode::DEC_R0
      elsif reg.value == 1
        Opcode::DEC_R1
      end
    }
    instruction :bell => Opcode::BELL
    instruction :prnt, :register_or_number, :assemble => lambda { |op, prog|
      if op.type == :number
        [Opcode::PRINT, op.value]
      else
        if op.value == 0
          store_op = Opcode::STORE_R0
        elsif op.value == 1
          store_op = Opcode::STORE_R1
        end
        [store_op, prog.code_index + 3, Opcode::PRINT, 0]
      end
    }
    instruction :mov, :register_or_number, :register_or_number, :assemble => lambda { |src, dest, _|
      if src.type == dest.type
        raise AssemblyOperandError, "operands to mov can't both be #{src.type}s"
      end

      if src.type == :register
        if src.value == 0
          [Opcode::STORE_R0, dest.value]
        elsif src.value == 1
          [Opcode::STORE_R1, dest.value]
        end
      else
        if dest.value == 0
          [Opcode::LOAD_R0, src.value]
        elsif dest.value == 1
          [Opcode::LOAD_R1, src.value]
        end
      end
    }
    instruction :jmp, :number, :assemble => lambda { |target, _| [Opcode::JUMP, target.value] }
    instruction :jz, :number, :assemble => lambda { |target, _| [Opcode::JUMP_ZERO, target.value] }
    instruction :jnz, :number, :assemble => lambda { |target, _| [Opcode::JUMP_NOT_ZERO, target.value] }

    def initialize(source)
      @source = source
      @program = Program.new(MEMORY_LENGTH)
    end

    def assemble
      line_num = 0
      @source.lines.each.with_index do |line, line_num|
        command = parse_line(line)

        case command[:type]
        when :empty
          next
        when :data
          mem_location = @program.insert_data(command[:data])
          @program.add_symbol(command[:symbol], mem_location)
        when :label
          @program.add_symbol(command[:label], @program.code_index)
        when :instruction
          if instruction = @@instructions.find { |instruct| instruct.name == command[:name] }
            operands = command[:operands].map { |op| Operand.parse(op) }

            assemble_instruction(instruction, *operands)
          else
            raise AssemblySyntaxError, "syntax error, an instruction may be misspelled"
          end
        end

        check_for_errors
      end

      @program.resolve_symbols
      @program
    rescue AssemblyError => e
      puts "#{e.class}:#{line_num + 1}: #{e.message}"
      exit
    end

    def parse_line(line)
      line = line.sub(/#.*$/, '').strip

      if line.empty?
        { :type => :empty }
      elsif line[0] == '.' and line =~ /^\.data\s+(\w+)\s*,\s*(\d+)$/
        { :type => :data, :symbol => $1.to_sym, :data => $2.to_i }
      elsif line =~ /^(\w+):$/
        { :type => :label, :label => $1.to_sym }
      else
        instruct, *operands = line.split(/[\s,]+/)
        { :type => :instruction, :name => instruct.to_sym, :operands => operands }
      end
    end

    def assemble_instruction(instruction, *operands)
      if instruction.expected_operands.length != operands.length
        raise AssemblyOperandError, "#{instruction.name} expects #{instruction.expected_operands.length} operands, got #{operands.length}"
      end

      operands.each.with_index do |operand, idx|
        if !operand.is_expected?(instruction.expected_operands[idx])
          raise AssemblyOperandError, "#{instruction.name} expects a #{expected_operands[idx]} for operand #{idx + 1}"
        end
      end

      Array(instruction.assemble.call(*operands, @program)).each do |code|
        @program.insert_code(code)
      end
    end

    def check_for_errors
      if @program.overlapping?
        raise AssemblyOverflowError, "code and data sections are overlapping"
      end

      if @program.overflowing?(BYTE_LIMIT)
        raise AssemblyOverflowError, "used a value outside of machine's range (0..#{BYTE_LIMIT})"
      end
    end
  end
end

if __FILE__ == $0
  infile, outfile = ARGV

  FourNineOneSeven.assemble(infile, outfile || "out.4")
end
