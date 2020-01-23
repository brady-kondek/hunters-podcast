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

def parse(input_file, label_count)
  output = []

  input_file.each_line do |line|
    next if line.match(/\/\/.*/) 

    if match = line.match(/push (?<segment>.+) (?<index>.+)/)
      push_constant_asm = %{
        @%s
        D=A
        @SP
        A=M
        M=D
        @SP
        M=M+1
      }
      push_relative_asm = %{
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
      }
      push_pointer_asm = %{
        @%s
        D=A
        @L#{label_count}
        D;JEQ
        @THAT
        D=M
        @L#{label_count + 1}
        0;JMP
        (L#{label_count})
        @THIS
        D=M
        (L#{label_count + 1})
        @SP
        A=M
        M=D
        @SP
        M=M+1
      }
      push_indirect_asm = %{
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
      }
      case match[:segment] 
      when "constant"
        output << (push_constant_asm % match[:index].strip).split
      when "local"
        output << (push_relative_asm % [match[:index].strip, "LCL"]).split
      when "argument"
        output << (push_relative_asm % [match[:index].strip, "ARG"]).split
      when "this"
        output << (push_relative_asm % [match[:index].strip, "THIS"]).split
      when "that"
        output << (push_relative_asm % [match[:index].strip, "THAT"]).split
      when "pointer"
        output << (push_pointer_asm % match[:index].strip).split
        label_count = label_count + 2
      when "temp"
        output << (push_indirect_asm % [match[:index].strip, "R5"]).split
      when "static"
        output << (push_indirect_asm % [match[:index].strip, "16"]).split
      end
    end

    pop_relative_asm = %{
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
    }
    pop_pointer_asm = %{
      @%s
      D=A
      @L#{label_count}
      D;JEQ
      @THAT
      D=A
      @L#{label_count + 1}
      0;JMP
      (L#{label_count})
      @THIS
      D=A
      (L#{label_count + 1})
      @R13
      M=D
      @SP
      AM=M-1
      D=M
      @R13
      A=M
      M=D
    }
    pop_indirect_asm = %{
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
    }
    if match = line.match(/pop (?<segment>.+) (?<index>.+)/)
      case match[:segment] 
      when "local"
        output << (pop_relative_asm % ["LCL", match[:index].strip]).split
      when "argument"
        output << (pop_relative_asm % ["ARG", match[:index].strip]).split
      when "this"
        output << (pop_relative_asm % ["THIS", match[:index].strip]).split
      when "that"
        output << (pop_relative_asm % ["THAT", match[:index].strip]).split
      when "pointer"
        output << (pop_pointer_asm % match[:index].strip).split
        label_count = label_count + 2
      when "temp"
        output << (pop_indirect_asm % [match[:index].strip, "R5"]).split
      when "static"
        output << (pop_indirect_asm % [match[:index].strip, "16"]).split
      end
    end

    math_asm = %{
      @SP
      D=M
      AM=D-1
      D=M
      A=A-1
      M=M%sD
    }
    output << (math_asm % "+").split if line.match(/add/)
    output << (math_asm % "-").split if line.match(/sub/)

    binary_logic_asm = %{
      @SP
      D=M
      AM=D-1
      D=M
      A=A-1
      M=D%sM
    }
    output << (binary_logic_asm % "|").split if line.match(/or/)
    output << (binary_logic_asm % "&").split if line.match(/and/)

    unary_logic_asm = %{
      @SP
      A=M-1
      D=M
      M=%sD
    }
    output << (unary_logic_asm % "-").split if line.match(/neg/)
    output << (unary_logic_asm % "!").split if line.match(/not/)

    comp_asm = %{
      @SP
      AM=M-1
      D=M
      A=A-1
      D=M-D
      @L#{label_count}
      D;%s
      D=0
      @L#{label_count + 1}
      0;JMP
      (L#{label_count})
      D=-1
      (L#{label_count + 1})
      @SP
      A=M-1
      M=D
    }
    if line.match(/eq/)
      output << (comp_asm % "JEQ").split
      label_count = label_count + 2
    end
    if line.match(/gt/)
      output << (comp_asm % "JGT").split
      label_count = label_count + 2
    end
    if line.match(/lt/)
      output << (comp_asm % "JLT").split
      label_count = label_count + 2
    end
  end
  return [output, label_count]
end

arg = ARGV.first
output = []
label_count = 1

if File.directory?(arg)
  Dir.foreach(arg) do |file| 
    parsing_result, labelcount = parse(file, label_count)
    output << parsing_result
  end
else 
  file = File.read(arg) || File.read(arg + ".vm")
  parsing_result, labelcount = parse(file, label_count)
  output << parsing_result
end

out_filename = 
  if File.directory?(arg)
    arg + "/../" + File.basename(arg, '.vm') + ".asm"
  else
    File.dirname(arg) + "/" + File.basename(arg, '.vm') + ".asm"
  end

File.delete(out_filename) if File.exists?(out_filename)

File.open(out_filename, "a") do |out_file|
  output.each do |line|
    out_file.puts line
  end
end
