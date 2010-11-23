#!/usr/local/bin/ruby

# Take an operand, return its type and extracted info
def parse_op(want, op, line_no)
  want << :symbol if want.include? :number

  if op.nil?
    fail "operand missing. (line #{line_no})"
  end

  if op =~ /^%[rR]([01])$/
    oper = [:register, $1.to_i]
  elsif op =~ /^\$(\d+)$/
    number = $1.to_i
    if number > 15
      fail "operand '#{op}' is too large for 4-bit machine. (line #{line_no})"
    end
    oper = [:number, number]
  elsif op =~ /^\$?(\w+)$/
    oper = [:symbol, $1.to_sym]
  else
    fail "invalid operand '#{op}'. (line #{line_no})"
  end

  if want.include? oper.first
    return oper
  else
    fail "instruction does not accept #{oper.first}s. (line #{line_no})"
  end
end

program = Array.new(16, 0)
symbols = {}

i = 0
data_i = 15
while gets
  break if $_.nil?

  line = $_.sub(/#.*$/, '').strip

  next if line.empty?

  if line[0] == '.'
    if line =~ /^\.data\s+(\w+)\s*,\s*(\d+)$/
      symbol = $1.to_sym
      data = $2.to_i

      if data > 15
        fail "data is too large for a 4-bit machine. (line #$.)"
      end

      program[data_i] = data
      symbols[symbol] = data_i
      data_i -= 1
    else
      fail "invalid assembler directive. (line #$.)"
    end

    next
  end

  if line =~ /^(\w+):$/
    symbols[$1.to_sym] = i

    next
  end

  instruct, *operands = line.split(/[\s,]+/)

  operand = operands[0]
  operand2 = operands[1]

  instruction = instruct.downcase.to_sym

  case instruction
  when :halt
    program[i] = 0
    i += 1
  when :add
    program[i] = 1
    i += 1
  when :sub
    program[i] = 2
    i += 1
  when :inc
    _, r = parse_op([:register], operand, $.)

    if r == 0
      program[i] = 3
      i += 1
    elsif r == 1
      program[i] = 4
      i += 1
    end
  when :dec
    _, r = parse_op([:register], operand, $.)

    if r == 0
      program[i] = 5
      i += 1
    elsif r == 1
      program[i] = 6
      i += 1
    end
  when :bell
    program[i] = 7
    i += 1
  when :prnt
    type, info = parse_op([:register, :number], operand, $.)

    if type == :register
      program[i] = (info == 0) ? 11 : 12
      i += 1
      program[i] = i + 2
      i += 1
      program[i] = 8
      i += 1
      program[i] = 0
      i += 1
    else
      program[i] = 8
      i += 1
      program[i] = info
      i += 1
    end
  when :mov
    type1, info1 = parse_op([:register, :number], operand, $.)
    type2, info2 = parse_op((type1 == :register) ? [:number] : [:register], operand2, $.)

    if type1 == :register
      program[i] = 11 + info1
      i += 1
      program[i] = info2
      i += 1
    else
      program[i] = 9 + info2
      i += 1
      program[i] = info1
      i += 1
    end
  when :jmp, :jz, :jnz
    _, value = parse_op([:number], operand, $.)

    program[i] = { :jmp => 13, :jz => 14, :jnz => 15 }[instruction]
    i += 1
    program[i] = value
    i += 1
  else
    fail "invalid instruction '#{instruction}'. (line #$.)"
  end
end

if program.length != 16
  fail "program is #{program.length-16} bytes too large."
end

if i - 1 >= data_i + 1
  fail "data and text sections are overlapping."
end

program.collect! do |data|
  if data.is_a? Symbol
    if value = symbols[data]
      if value > 15
        fail "symbol '#{data}' resolves to value too large for a 4-bit machine."
      end
    else
      fail "undefined symbol '#{data}'."
    end
  else
    value = data
  end

  value
end

prog = program.join ' '

File.open("out.4", "w") do |f|
  f << prog
end

