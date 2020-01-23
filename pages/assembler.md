---
layout: page
title: Assembler aus Nand2Tetris in Ruby
permalink: assembler/
---

```ruby
#!/path/to/ruby
symbolhash = {SP: 0, LCL: 1, ARG: 2, THIS:3, THAT:4, R0: 0, R1: 1, R2: 2, R3: 3, R4: 4, 
              R5: 5, R6: 6, R7: 7, R8: 8, R9: 9, R10:10, R11: 11, R12: 12, R13: 13, R14: 14, 
              R15: 15, SCREEN: 16384, KBD: 24576}

comphash = {"0": "0101010", "1": "0111111", "-1": "0111010", D: "0001100", A: "0110000",
            "!D": "0001101", "!A": "0110001", "-D": "0001111", "-A": "0110011", 
            "D+1": "0011111", "A+1": "0110111", "D-1": "0001110", "A-1": "0110010", 
            "D+A": "0000010", "D-A": "0010011", "A-D": "0000111", "D&A": "0000000", 
            "D|A": "0010101", M: "1110000", "!M": "1110001", "-M": "1110011", 
            "M+1": "1110111", "M-1": "1110010", "D+M": "1000010", "D-M": "1010011", 
            "M-D": "1000111", "D&M": "1000000", "D|M": "1010101"}

desthash = {"0": "000", M: "001", D: "010", MD: "011", A: "100", AM: "101", AD: "110", 
            AMD: 111}

jumphash = {"0": "000", JGT: "001", JEQ: "010", JGE: "011", JLT: "100", JNE: "101", 
            JLE: "110", JMP: "111"}

output_file = File.dirname(ARGV.first) + "/" + File.basename(ARGV.first) + ".hack"
file = File.read(ARGV.first)
counter = 0
next_address = 16

file.each_line do |line|
  next unless line = line.gsub(/[[:space:]]/, '')
                         .split("//")[0]

  if line.match(/@.+/) || 
     line.match(/.+=.+/) || 
     line.match(/.+;.+/) || 
     line.match(/.+=.+;.+/)
    counter += 1
  end

  if match = line.match(/\((?<label>.+)\)/)
    unless symbolhash[match[:label].to_sym]
      symbolhash[match[:label].to_sym] = counter
    end
  end
end

File.delete(output_file) if File.exists?(output_file)

File.open(output_file, "a") do |output|
  file.each_line do |line|
    next unless line = line.gsub(/[[:space:]]/, '')
                           .split("//")[0]

    if match = line.match(/@(?<addr>.+)/)
      if line.match(/@(\D+)/)
        if address = symbolhash[match[:addr].to_sym]
          output.puts address.to_s(2).rjust(16, '0')
        else
          symbolhash[match[:addr].to_sym] = next_address
          output.puts next_address.to_s(2).rjust(16, '0')
          next_address += 1
        end
      else
        output.puts match[:addr].to_i.to_s(2).rjust(16, '0')
      end
    end

    if match = line.match(/(?<dest>.+)=(?<comp>.+)/)
      output.puts "111" + comphash[match[:comp].to_sym] +
                          desthash[match[:dest].to_sym] + "000"
    end

    if match = line.match(/(?<comp>.+);(?<jump>.+)/)
      output.puts "111" + comphash[match[:comp].to_sym] +
                  "000" + jumphash[match[:jump].to_sym]
    end

    if match = line.match(/(?<dest>.+)=(?<comp>.+);(?<jump>.+)/)
      output.puts "111" + comphash[match[:comp].to_sym] +
                          desthash[match[:dest].to_sym] +
                          jumphash[match[:jump].to_sym]
    end
  end
end
```