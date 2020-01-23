#! //home/stefan/.rvm/rubies/ruby-2.5.3/bin/ruby
#
# === We translate to ===
# 0, 1, -1, D, A, !D, !A, -D, -A, D+1, A+1, D-1, A-1, D+A, D-A, A-D, D&A, D|A
# M, !M, -M, M+1, D+M, D-M, M-D, D&M, D|M
# null, JGT, JEQ, JGE, JLT, JNE, JLE, JMP
# R0, R1, ..., R15, SP, LCL, ARG, THIS, THAT
# SCREEN, KBD
# @x ... value
# (Xxx) Xxx ... set label and label address
#
# === Memory map ===
# 0 ... 15 registers, 16 ... 255 static variables, # 256 ... 2047 Stack
# 2048 ... 16383 Heap, # 16384 ... 24575 I/O

class Parser
  attr_accessor :current_command

  def initialize(file)
    @file_handle = File.open(file, "r")
    @current_command = ""
  end

  def has_more_commands
    !@file_handle.eof?
  end

  def advance
    if has_more_commands
      @current_command = @file_handle.gets.split("//")[0]
    end
  end

  def commandType
    case @current_command
    when ""
      "EMPTY LINE"
    when /\A\/\/.*/
      "COMMENT"
    when /\Apush (?<segment>.+) (?<index>.+)/i
      "C_PUSH"
    when /\Apop (?<segment>.+) (?<index>.+)/i
      "C_POP"
    when /\Aadd/i, /\Asub/i, /\Aor/i, /\Aand/i, /\Aneg/i, /\Anot/i, /\Aeq/i, /\Agt/i, /\Alt/i
      "C_ARITHMETIC"
    when /\Acall/i
      "C_CALL"
    when /\Areturn/i
      "C_RETURN"
    when /\Afunction (?<name>.+) (?<variables_count>.+)/i
      "C_FUNCTION"
    when /\Alabel (?<label>.+)/i
      "C_LABEL"
    when /\Aif-goto (?<label>.+)/i
      "C_IF"
    when /\Agoto (?<label>.+)/i
      "C_GOTO"
    else
      "couldn't parse " + @current_command
    end
  end

  def arg1
    case commandType
    when "C_ARITHMETIC"
      @current_command.split[0]
    when "C_PUSH", "C_POP", "C_CALL", "C_FUNCTION", "C_LABEL", "C_GOTO", "C_IF"
      @current_command.split[1]
    end
  end

  def arg2
    case commandType
    when "C_PUSH", "C_POP", "C_CALL", "C_FUNCTION"
      @current_command.split[2]
    end
  end
end

class CodeWriter
  attr_accessor :current_input_filename, :current_functionname, :label_count

  def initialize(output_filename)
    File.delete(output_filename) if File.exists?(output_filename)
    @file = File.open(output_filename, "a")
    @current_input_filename = ""
    @current_functionname = ""
    @label_count = 1
  end

  def write(parser)
    @file.puts "/// === #{current_input_filename} === ///"
    while parser.has_more_commands
      parser.advance

      case parser.commandType
      when "C_ARITHMETIC"
        write_arithmetic(parser.arg1)
      when "C_PUSH", "C_POP"
        write_push_pop(parser.commandType, parser.arg1, parser.arg2)
      when "C_LABEL"
        write_label(parser.arg1)
      when "C_GOTO"
        write_goto(parser.arg1)
      when "C_IF"
        write_if(parser.arg1)
      when "C_FUNCTION"
        write_function(parser.arg1, parser.arg2.to_i)
      when "C_RETURN"
        write_return()
      when "C_CALL"
        write_call(parser.arg1, parser.arg2)
      end
    end
  end

  def write_arithmetic(command)
    case command
    when "add"
      @file.puts math_asm % "+"
    when "sub"
      @file.puts math_asm % "-"
    when "or"
      @file.puts binary_logic_asm % "|"
    when "and"
      @file.puts binary_logic_asm % "&"
    when "neg"
      @file.puts unary_logic_asm % "-"
    when "not"
      @file.puts unary_logic_asm % "!"
    when "eq"
      @file.puts comp_asm % "JEQ"
    when "gt"
      @file.puts comp_asm % "JGT"
    when "lt"
      @file.puts comp_asm % "JLT"
    end
  end

  def write_push_pop(command_type, segment, value)
    if command_type == "C_PUSH"
      case segment
      when "constant"
        @file.puts push_constant_asm % value
      when "local"
        @file.puts push_relative_asm % [value, "LCL"]
      when "argument"
        @file.puts push_relative_asm % [value, "ARG"]
      when "this"
        @file.puts push_relative_asm % [value, "THIS"]
      when "that"
        @file.puts push_relative_asm % [value, "THAT"]
      when "pointer"
        @file.puts push_pointer_asm % value
      when "temp"
        @file.puts push_indirect_asm % [value, "R5"]
      when "static"
        @file.puts push_static_asm % value
      end
    end

    if command_type == "C_POP"
      case segment
      when "local"
        @file.puts pop_relative_asm % ["LCL", value]
      when "argument"
        @file.puts pop_relative_asm % ["ARG", value]
      when "this"
        @file.puts pop_relative_asm % ["THIS", value]
      when "that"
        @file.puts pop_relative_asm % ["THAT", value]
      when "pointer"
        @file.puts pop_pointer_asm % value
      when "temp"
        @file.puts pop_indirect_asm % [value, "R5"]
      when "static"
        @file.puts pop_static_asm % value
      end
    end
  end

  def push_static_asm
    <<~EOS
      /// push static ///
      @#{current_input_filename}.%s
      D=M
      @SP
      A=M
      M=D
      @SP
      M=M+1
    EOS
  end

  def pop_static_asm
    <<~EOS
      /// pop static ///
      @#{current_input_filename}.%s
      D=A
      @R13
      M=D
      @SP
      AM=M-1
      D=M
      @R13
      A=M
      M=D
    EOS
  end

  def push_constant_asm
    <<~EOS
      /// push_constant ///
      @%s
      D=A
      @SP
      A=M
      M=D
      @SP
      M=M+1
    EOS
  end

  def push_relative_asm
    <<~EOS
      /// push_relative ///
      @%s
      D=A
      @%s
      A=D+M
      D=M
      @SP
      A=M
      M=D
      @SP
      M=M+1
    EOS
  end

  def push_symbol_asm
    <<~EOS
      /// push_symbol ///
      @%s
      D=M
      @SP
      A=M
      M=D
      @SP
      M=M+1
    EOS
  end

  def push_pointer_asm
     label = @label_count
     @label_count += 2
    <<~EOS
      /// push_pointer ///
      @%s
      D=A
      @L#{label}
      D;JEQ
      @THAT
      D=M
      @L#{label + 1}
      0;JMP
      (L#{label})
      @THIS
      D=M
      (L#{label + 1})
      @SP
      A=M
      M=D
      @SP
      M=M+1
    EOS
  end

  def push_indirect_asm
    <<~EOS
      /// push_indirect ///
      @%s
      D=A
      @%s
      A=D+A
      D=M
      @SP
      A=M
      M=D
      @SP
      M=M+1
    EOS
  end

  def pop_relative_asm
    <<~EOS
      /// pop_relative ///
      @%s
      D=M
      @%s
      D=D+A
      @R13
      M=D
      @SP
      AM=M-1
      D=M
      @R13
      A=M
      M=D
    EOS
  end

  def pop_pointer_asm
    label = @label_count
    @label_count += 2
    <<~EOS
      /// pop_pointer ///
      @%s
      D=A
      @L#{label}
      D;JEQ
      @THAT
      D=A
      @L#{label + 1}
      0;JMP
      (L#{label})
      @THIS
      D=A
      (L#{label + 1})
      @R13
      M=D
      @SP
      AM=M-1
      D=M
      @R13
      A=M
      M=D
    EOS
  end

  def pop_indirect_asm
    <<~EOS
      /// pop_indirect ///
      @%s
      D=A
      @%s
      D=D+A
      @R13
      M=D
      @SP
      AM=M-1
      D=M
      @R13
      A=M
      M=D
    EOS
  end

  def math_asm
    <<~EOS
      /// math ///
      @SP
      AM=M-1
      D=M
      A=A-1
      M=M%sD
    EOS
  end

  def binary_logic_asm
    <<~EOS
      /// binary_logic ///
      @SP
      D=M
      AM=D-1
      D=M
      A=A-1
      M=D%sM
    EOS
  end

  def unary_logic_asm
    <<~EOS
      /// unary_logic ///
      @SP
      A=M-1
      D=M
      M=%sD
    EOS
  end

  def comp_asm
    label = @label_count
    @label_count += 2
    <<~EOS
      /// comp ///
      @SP
      AM=M-1
      D=M
      A=A-1
      D=M-D
      @L#{label}
      D;%s
      D=0
      @L#{label + 1}
      0;JMP
      (L#{label})
      D=-1
      (L#{label + 1})
      @SP
      A=M-1
      M=D
    EOS
  end

  def write_label(label_name)
    @file.puts "/// label #{label_name} ///"
    @file.puts "(#{current_functionname}$#{label_name})"
  end

  def write_goto(label_name)
    @file.puts <<~EOS
      /// goto ///
      @#{current_functionname}$#{label_name}
      0;JMP
    EOS
  end

  def write_if(label)
    @file.puts <<~EOS
      /// if ///
      @SP
      AM=M-1
      D=M
      @#{current_functionname}$#{label}
      D;JNE
    EOS
  end

  def write_init
    @file.puts <<~EOS
      /// init ///
      @256
      D=A
      @SP
      M=D
    EOS
    write_call("Sys.init", 0)
  end

  def write_call(function_name, number_of_arguments)
    label = @label_count
    @label_count += 1

    @file.puts <<~EOS

      /// call #{function_name} #{number_of_arguments} ///
      @L#{label}
      /// push return-address ///
      D=A
      @SP
      A=M
      M=D
      @SP
      M=M+1
    EOS

    @file.puts push_symbol_asm % "LCL"
    @file.puts push_symbol_asm % "ARG"
    @file.puts push_symbol_asm % "THIS"
    @file.puts push_symbol_asm % "THAT"

    @file.puts <<~EOS
      /// ARG = SP-#{number_of_arguments}-5 ///
      @SP
      D=M
      @5
      D=D-A
      @#{number_of_arguments}
      D=D-A
      @ARG
      M=D
      /// LCL = SP ///
      @SP
      D=M
      @LCL
      M=D
      /// goto f ///
      @#{function_name}
      0;JMP
      /// return label ///
      (L#{label})
    EOS
  end

  def write_function(function_name, number_of_aguments)
    @file.puts "/// function #{function_name} #{number_of_aguments} ///"
    @file.puts "(#{function_name})"
    number_of_aguments.times do
      @file.puts push_constant_asm % "0"
    end
  end

  def write_return
    @file.puts <<~EOS
      /// return ///
      /// FRAME = LCL ///
      @LCL
      D=M
      @R11
      M=D
      /// RET = *(FRAME-5) ///
      @5
      A=D-A
      D=M
      @R12
      M=D
      /// *ARG = pop() ///
    EOS

    @file.puts pop_relative_asm % ["ARG", 0]

    @file.puts <<~EOS
      /// SP = ARG+1 ///
      @ARG
      D=M
      @SP
      M=D+1
    EOS

    @file.puts before_frame_asm("THAT")
    @file.puts before_frame_asm("THIS")
    @file.puts before_frame_asm("ARG")
    @file.puts before_frame_asm("LCL")

    @file.puts <<~EOS
      /// goto RET ///
      @R12
      A=M
      0;JMP
    EOS
  end

  def before_frame_asm(target)
    @file.puts <<~EOS
      /// #{target} = *(FRAME-x) ///
      @R11
      D=M-1
      AM=D
      D=M
      @#{target}
      M=D
    EOS
  end
end

arg = ARGV.first

if File.directory?(arg)
  code_writer = CodeWriter.new("#{arg}/#{arg.split("/").last}.asm")
  code_writer.write_init()
  Dir.foreach(arg) do |file|
    if File.extname(file) == ".vm"
      parser = Parser.new("#{arg}/#{file}")
      code_writer.current_input_filename = File.basename(file, '.vm')
      code_writer.write(parser)
    end
  end
else
  code_writer = CodeWriter.new(File.dirname(arg) + "/" + File.basename(arg, '.vm') + ".asm")
  filename = File.readable?(arg) ? arg : arg + ".vm"
  parser = Parser.new(filename)
  code_writer.current_input_filename = File.basename(filename, '.vm')
  code_writer.write(parser)
end
