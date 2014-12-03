module instruction;

import asm_tokens;

struct Instruction {
    Opcode opcode;
    int qubit;
    int op1;
    int op2;
    int number;
    int lineNumber;
}

bool valid_instruction(Instruction i) {
    /**
     * Strictly validates the instruction, i.e. any parameters
     * that are not needed by the opcode MUST be 0.
     */
    switch(i.opcode) {
        case Opcode.NULL:
            return (i.qubit == 0 && 
                    i.op1 == 0 && 
                    i.op2 == 0 && 
                    i.number ==0 );

        case Opcode.QUBIT:
            return (i.qubit != 0 &&
                    i.op1 == 0 &&
                    i.op2 == 0 &&
                    i.number == 0);
                    
        case Opcode.IF:
            return (i.qubit != 0 &&
                    ((i.op1 == 0) != (i.op2 == 0)) &&
                    i.number == 0);

        case Opcode.IFELSE:
            return (i.qubit != 0 &&
                    i.op1 != 0 &&
                    i.op2 != 0 &&
                    i.number == 0);
         
        case Opcode.MEASURE:
            return (i.qubit != 0 &&
                    i.op1 == 0 &&
                    i.op2 == 0 &&
                    i.number == 0);

        case Opcode.LOOP:
            return (i.qubit == 0 &&
                    ((i.op1 == 0) != (i.op2 == 0)) &&
                    i.number != 0);

        case Opcode.ON:
            return (i.qubit != 0 &&
                    i.op1 == 0 &&
                    i.op2 == 0 &&
                    i.number == 0);

        case Opcode.APPLY:
            return (i.qubit == 0 &&
                    ((i.op1 == 0) != (i.op2 == 0)) &&
                    i.number == 0);

        case Opcode.LOAD:
            return (i.qubit != 0 &&
                    i.op1 == 0 &&
                    i.op2 == 0 &&
                    i.number == 0);

        case Opcode.DUMP:
            return (i.qubit == 0 &&
                    i.op1 == 0 &&
                    i.op2 == 0 &&
                    i.number == 0);

        case Opcode.SREC:
            return (i.qubit != 0 &&
                    i.op1 == 0 &&
                    i.op2 == 0 &&
                    i.number == 0);

        case Opcode.EREC:
            return (i.qubit != 0 &&
                    i.op1 == 0 &&
                    i.op2 == 0 &&
                    i.number == 0);
            
        case Opcode.QSREC:
            return (i.qubit != 0 &&
                    i.op1 == 0 &&
                    i.op2 == 0 &&
                    i.number == 0);

        case Opcode.QEREC:
            return (i.qubit != 0 &&
                    i.op1 == 0 &&
                    i.op2 == 0 &&
                    i.number == 0);

        case Opcode.PRINT:
            return (i.qubit != 0 &&
                    i.op1 == 0 &&
                    i.op2 == 0 &&
                    i.number == 0);

        case Opcode.FCNOT:
            return (i.qubit != 0 &&
                    i.op1 == 0 &&
                    i.op2 == 0 &&
                    i.number == 0);
        default:
            return false;
    }
}

Instruction to_instruction(ubyte* byte_sequence) {
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

