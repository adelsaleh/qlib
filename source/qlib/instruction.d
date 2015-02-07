module qlib.instruction;

import qlib.asm_tokens;
import std.regex;
import std.conv;
import qlib.collections;

/**
 * Holds the different arguments of an instruction,
 * used for processing by the VM.
 */
struct Instruction {
    Opcode opcode;
    int qubit;
    int op1;
    int op2;
    int number;
    int lineNumber;
}


/**
 * The different types of possible arguments in
 * an instruction.
 */
enum InstructionArgType {
    NONE,
    QUBIT,
    OP1,
    OP2,
    NUMBER
}

alias IAT = InstructionArgType;

/**
 * When writing assembly, each instruction has a maximum
 * of 3 arguments. This array specifies what they are.
 */
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

/**
 * Return the element of instruction according to the provided type.
 *
 * Params:
 *      ins = The instruction to select from.
 *      iat = The type of parameter to select.
 * Returns:
 *      The value of the element from instruction of type iat,
 *      so select_field_by_type(ins, IAT.QUBIT) returns ins.qubit
 *      for example.
 */
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

/**
 * Strictly validates the instruction, i.e. any parameters
 * that are not needed by the opcode MUST be 0 for this function
 * to validate the instruction.
 *
 * Params:
 *      i = instruction to be validates
 * Returns:
 *      true if i is valid, false otherwise.
 */
bool valid_instruction(Instruction i) {
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
