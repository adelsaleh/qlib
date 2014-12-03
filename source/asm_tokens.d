module asm_tokens;

import std.string;

enum Opcode {
    NULL,
    QUBIT,
    IF,
    IFELSE,
    MEASURE,
    LOOP,
    ON,
    APPLY,
    LOAD,
    DUMP,
    SREC,
    EREC,
    QSREC,
    QEREC,
    PRINT,
    FCNOT
}

private string[] tokens = [   
    "NULL",
    "QUBIT",
    "IF",
    "IFELSE",
    "MEASURE",
    "LOOP",
    "ON",
    "APPLY",
    "LOAD",
    "DUMP",
    "SREC",
    "EREC",
    "QSREC",
    "QEREC",
    "PRINT",
    "FCNOT"
];


Opcode to_opcode(string token) {
    /**
     * Returns an opcode enum corresponding to token. Returns
     * null if opcode is invalid.
     */
    token = toUpper(token);
    foreach(int i, string t; tokens) {
        if (token == t) {
            return cast(Opcode)(i);
        }
    }
    throw new Exception("Invalid Opcode Token");
}

string to_instruction(Opcode op) {
    return tokens[op];
}
