module qlib.asm_tokens;

import std.string;
import qlib.util;

/**
 * An enum of all possible opcodes for
 * an instruction.
 *
 * Cast to ubyte or int in order to get
 * the number of the opcode.
 */
enum Opcode {
    NULL = cast(ubyte)0
    ,QUBIT
    ,IF
    ,IFELSE
    ,MEASURE
    ,LOOP
    ,ON
    ,APPLY
    ,LOAD
    ,DUMP
    ,SREC
    ,EREC
    ,QSREC
    ,QEREC
    ,PRINT
    ,FCNOT
}

/*
 * Represents the token of each opcode.
 */
private string[] tokens = [   
    "NULL"
    ,"QUBIT"
    ,"IF"
    ,"IFELSE"
    ,"MEASURE"
    ,"LOOP"
    ,"ON"
    ,"APPLY"
    ,"LOAD"
    ,"DUMP"
    ,"SREC"
    ,"EREC"
    ,"QSREC"
    ,"QEREC"
    ,"PRINT"
    ,"FCNOT"
];

/**
 * Converts token to an instance of Opcode.
 * Params:
 *      token = The string which we want the Opcode instance of.
 * Returns:
 *      The corresponding Opcode to the token. Must be all in upper case.
 */
Opcode to_opcode(string token) {
    int i = tokens.search(token);
    if(i > 0) {
        return cast(Opcode)(i);
    }
    return Opcode.NULL;
}

/**
 * Converts an instance of Opcode to a string.
 *
 * Params:
 *      op = The opcode we want to convert to a string.
 * Returns:
 *      The string representation of this Opcode
 */
string to_instruction(Opcode op) {
    return tokens[op];
}
