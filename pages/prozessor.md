---
layout: page
title: Computer aus Nand2Tetris in HDL
permalink: prozessor/
---

Der Computer bestehend aus CPU, RAM (Memory) und ROM (ROM32K):

```vhdl
CHIP Computer {
    IN reset;

    PARTS:
    CPU (reset=reset, instruction=i, inM=j, addressM=k, writeM=l, outM=m, pc=n);
    Memory(in=m ,load=l ,address=k ,out=j);
    ROM32K (address=n, out=i);
}
```


Die CPU mit ihren Hauptbestandteilen Controll Unit, A und D Register, Rechenwerk (ALU) und Program
Counter (PC):

![CPU Schemadiagramm](/img/cpu.png)


```vhdl
CHIP CPU {
    IN  inM[16],         // M value input  (M = contents of RAM[A])
        instruction[16], // Instruction for execution
        reset;           // Signals whether to re-start the current
                         // program (reset==1) or continue executing
                         // the current program (reset==0).

    OUT outM[16],        // M value output
        writeM,          // Write to M?
        addressM[15],    // Address in data memory (of M)
        pc[15];          // address of next instruction

    PARTS:
    // a or c-type instruction?
    Not(in=instruction[15], out=aType);
    Or(a=instruction[12], b=false, out=cType);

    // where to store
    And(a=instruction[5], b=instruction[15], out=writeA);
    And(a=instruction[4], b=instruction[15], out=writeD);
    And(a=instruction[3], b=instruction[15], out=writeM);

    // logical conditions needed for the control logic
    Not(in=zr, out=jne);
    Not(in=jle, out=jgt);
    Or(a=zr, b=jgt, out=jge);
    Or(a=zr, b=ng, out=jle);

    // the actual control logic
    Mux8Way(a=false, b=jgt, c=zr, d=jge, e=ng, f=jne, g=jle, h=true, sel=instruction[0..2],
            out=jumpIfaType);
    And(a=instruction[15], b=jumpIfaType, out=doJump);

    // the mux on the left of diagam 5.9
    Mux16(a=ALUout, b=instruction, sel=aType, out=Ain);

    // A register (could use plain register, but tests want it)
    Or(a=aType, b=writeA, out=loadA);
    ARegister(in=Ain, load=loadA, out=Aout, out[0..14]=addressM);

    // D register (could use plain register, but tests want it)
    DRegister(in=ALUout, load=writeD, out=registerD);

    // the mux on the right of diagam 5.9
    Mux16(a=Aout, b=inM, sel=cType, out=inputALU);

    // alu
    ALU(x=registerD, y=inputALU, zx=instruction[11], nx=instruction[10], zy=instruction[9],
        ny=instruction[8], f=instruction[7], no=instruction[6], zr=zr, ng=ng, out=ALUout);

    // needed for feeding back as outputs of the CPU cannot be fed back
    Or16(a=false, b=ALUout, out=outM);

    // program counter
    PC(in=Aout, load=doJump, inc=true, reset=reset, out[0..14]=pc);
}
```

Das RAM mit dem inkludierten Bildschirm und der Tastatur:

```vhdl
CHIP Memory {
    IN in[16], load, address[15];
    OUT out[16];

    PARTS:
    DMux4Way(in=load, sel=address[13..14], a=a, b=b, c=c, d=d);
    Or(a=a, b=b, out=i);
    RAM16K(in=in, load=i, address=address[0..13], out=j);
    Screen(in=in, load=c, address=address[0..12], out=k);
    Keyboard(out=l);
    Mux4Way16(a=j, b=j, c=k, d=l, sel=address[13..14], out=out);
}
```