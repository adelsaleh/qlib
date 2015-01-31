module qlib.asm_tokens;

import std.string;
import qlib.util;

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

Opcode to_opcode(string token) {
    /**
     * Returns an opcode enum corresponding to token. Returns
     * null if opcode is invalid.
     */
    int i = tokens.search(token);
    if(i > 0) {
        return cast(Opcode)(i);
    }
    return Opcode.NULL;
}

string to_instruction(Opcode op) {
    return tokens[op];
}
