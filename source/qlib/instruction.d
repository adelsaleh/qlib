module qlib.instruction;

import qlib.asm_tokens;
import std.regex;
import std.conv;
import qlib.collections;
struct Instruction {
    Opcode opcode;
    int qubit;
    int op1;
    int op2;
    int number;
    int lineNumber;
}


// TODO: Figure out a better place to put this section.
enum InstructionArgType {
    NONE,
    QUBIT,
    OP1,
    OP2,
    NUMBER
}

alias IAT = InstructionArgType;

InstructionArgType[][] argLocations = [
    /*NULL*/     [IAT.NONE  , IAT.NONE   , IAT.NONE ],
    /*QUBIT*/    [IAT.QUBIT , IAT.NONE   , IAT.NONE ],
    /*IF*/       [IAT.QUBIT , IAT.OP1    , IAT.NONE ],
    /*IFELSE*/   [IAT.QUBIT , IAT.OP1    , IAT.OP2  ],
    /*MEASURE*/  [IAT.QUBIT , IAT.NONE   , IAT.NONE ],
    /*LOOP*/     [IAT.OP1   , IAT.NUMBER , IAT.NONE ],
    /*ON*/       [IAT.QUBIT , IAT.NONE   , IAT.NONE ],
    /*APPLY*/    [IAT.OP1   , IAT.NONE   , IAT.NONE ],
    /*LOAD*/     [IAT.QUBIT , IAT.NONE   , IAT.NONE ],
    /*DUMP*/     [IAT.NONE  , IAT.NONE   , IAT.NONE ],
    /*SREC*/     [IAT.QUBIT , IAT.NONE   , IAT.NONE ],
    /*EREC*/     [IAT.QUBIT , IAT.NONE   , IAT.NONE ],
    /*QSREC*/    [IAT.QUBIT , IAT.NONE   , IAT.NONE ],
    /*QEREC*/    [IAT.QUBIT , IAT.NONE   , IAT.NONE ],
    /*PRINT*/    [IAT.QUBIT , IAT.NONE   , IAT.NONE ],
    /*FCNOT*/    [IAT.QUBIT , IAT.NONE   , IAT.NONE ]

];

int select_field_by_type(Instruction ins, InstructionArgType iat) {
    switch(iat) {
        case(InstructionArgType.QUBIT):
            return ins.qubit;

        case (InstructionArgType.OP1):
            return ins.op1; 

        case (InstructionArgType.OP2):
            return ins.op2; 

        case (InstructionArgType.NUMBER):
            return ins.number;
        
        default:
            return 0;
    }
}

//End section

bool valid_instruction(Instruction i) {
    /**
     * Strictly validates the instruction, i.e. any parameters
     * that are not needed by the opcode MUST be 0.
     */
    switch(i.opcode) {
        case Opcode.NULL:
            return (i.qubit == 0x0 && 
                    i.op1 == 0x0 && 
                    i.op2 == 0x0 && 
                    i.number == 0x0 );

        case Opcode.QUBIT:
            return (i.qubit != 0x0 &&
                    i.op1 == 0x0 &&
                    i.op2 == 0x0 &&
                    i.number == 0x0);
                    
        case Opcode.IF:
            return (i.qubit != 0x0 &&
                    ((i.op1 == 0x0) != (i.op2 == 0x0)) &&
                    i.number == 0x0);

        case Opcode.IFELSE:
            return (i.qubit != 0x0 &&
                    i.op1 != 0x0 &&
                    i.op2 != 0x0 &&
                    i.number == 0x0);
         
        case Opcode.MEASURE:
            return (i.qubit != 0x0 &&
                    i.op1 == 0x0 &&
                    i.op2 == 0x0 &&
                    i.number == 0x0);

        case Opcode.LOOP:
            return (i.qubit == 0x0 &&
                    ((i.op1 == 0x0) != (i.op2 == 0x0)) &&
                    i.number != 0x0);

        case Opcode.ON:
            return (i.qubit != 0x0 &&
                    i.op1 == 0x0 &&
                    i.op2 == 0x0 &&
                    i.number == 0x0);

        case Opcode.APPLY:
            return (i.qubit == 0x0 &&
                    ((i.op1 == 0x0) != (i.op2 == 0x0)) &&
                    i.number == 0x0);

        case Opcode.LOAD:
            return (i.qubit != 0x0 &&
                    i.op1 == 0x0 &&
                    i.op2 == 0x0 &&
                    i.number == 0x0);

        case Opcode.DUMP:
            return (i.qubit == 0x0 &&
                    i.op1 == 0x0 &&
                    i.op2 == 0x0 &&
                    i.number == 0x0);

        case Opcode.SREC:
            return (i.qubit != 0x0 &&
                    i.op1 == 0x0 &&
                    i.op2 == 0x0 &&
                    i.number == 0x0);

        case Opcode.EREC:
            return (i.qubit != 0x0 &&
                    i.op1 == 0x0 &&
                    i.op2 == 0x0 &&
                    i.number == 0x0);
            
        case Opcode.QSREC:
            return (i.qubit != 0x0 &&
                    i.op1 == 0x0 &&
                    i.op2 == 0x0 &&
                    i.number == 0x0);

        case Opcode.QEREC:
            return (i.qubit != 0x0 &&
                    i.op1 == 0x0 &&
                    i.op2 == 0x0 &&
                    i.number == 0x0);

        case Opcode.PRINT:
            return (i.qubit != 0x0 &&
                    i.op1 == 0x0 &&
                    i.op2 == 0x0 &&
                    i.number == 0x0);

        case Opcode.FCNOT:
            return (i.qubit != 0x0 &&
                    i.op1 == 0x0 &&
                    i.op2 == 0x0 &&
                    i.number == 0x0);
        default:
            return false;
    }
}

Instruction toInstruction(ubyte[] byte_sequence) {
    /**
     * Reads the instruction from the byte sequence.
     * Throws an exception if bytecode is invalid.
     */

     int opcode = (byte_sequence[0] & 0xf0) >> 4;
     int qubit = ((byte_sequence[0] & 0x0f) << 4) | (byte_sequence[1] >> 5);
     int op1 = ((byte_sequence[1] & 0x1f << 3) | (byte_sequence[2] >> 6));
     int op2 = ((byte_sequence[2] & 0x3f <<  2) | (byte_sequence[3] >> 7));
     int number = 0xef & byte_sequence[3];
     int lineNumber = (byte_sequence[4] << 8) | byte_sequence[5];
     return Instruction(cast(Opcode)opcode, qubit, op1, op2, number);
}


ubyte* instructionToByteSequence(Instruction ins, ubyte* seq) {
    ubyte opcode = cast(ubyte)ins.opcode;
    seq[0] |= opcode << 4;

    int qubit = ins.qubit;
    seq[0] |= qubit & 0x78 >> 3;
    seq[1] |= (qubit & 0x07) << 5;

    int op1 = ins.op1;
    seq[1] |= (op1 & 0x7c) >> 2;
    seq[2] |= (op1 & 0x03) << 6;

    int op2 = ins.op2;
    seq[2] |= (op2 & 0x7e) >> 1;
    seq[3] |= (op2 & 0x01) << 7;

    int number = ins.number;
    seq[3] |= 0x7f & number;

    int lineNum = ins.lineNumber;
    seq[4] = (lineNum & 0xff00) >> 8;
    seq[5] = (lineNum & 0x00ff);
    return seq;
}
/*

Instruction parseInstruction(string instruction, IdentifierMap m, int lineNumber=0 ) {
    /**
     * Get an instruction representation based on the mironment
     * of the current program.
     */
     /*

*/
string instructionToString(Instruction ins) {
    /**
     * Converts an instance of instruction to
     * a valid string.
     */
    string ins_string = "";
    auto argTypes = argLocations[ins.opcode];
    ins_string ~= to_instruction(ins.opcode);
    ins_string ~= " ";
    foreach(int i, InstructionArgType at; argTypes) {
        if (at != InstructionArgType.NONE){
            ins_string ~= " " ~ to!string(select_field_by_type(ins, at));
        }
    }
    return ins_string;
}
