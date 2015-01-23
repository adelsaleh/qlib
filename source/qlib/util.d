module qlib.util;

import std.stdio;
import std.conv;

T instanceof(T)(Object o) if(is(T == class)) {
    return cast(T) o;
}
int bitMask(long msb, long lsb) 
    /**
     * Generate a mask that can be used to extract
     * the bits between the most significant bit(msb) inclusive
     * and the least significant bit(lsb) exclusive
     */
in {
    assert(msb >= lsb);
    assert(msb > 0 && msb <= 8);
    assert(lsb >= 0 && lsb <= 8);
}
out(result) {
    assert(1>>8 == 0); // If this is false then a bit higher than 7 is set
}

body{
    return ((1 << msb)-1) - ((1 << lsb) - 1);
}

string toString(ubyte[] buf) {
    string ret = "";
    for(int i = 0; i < buf.length; i++) {
        ret ~= cast(char)buf[i];
    }
    return ret;
}

string zeroCondition(string var, int length) {
    /**
     * Generates a code snippet that checks whether an array
     * is a zero array.
    */
    string snippet = var~"[0] == 0";
    for(int i = 1; i < length; i++) {
        snippet ~= " || " ~ var ~ "["~to!string(i)~"] == 0";
    }
    return snippet;
}

bool is_whitespace(char c) {
    return c == ' ' || c == '\t' || c == '\r' || c == '\n';
}

bool isEmptyLine(string line) {
    foreach(char c; line) {
        if(!is_whitespace(c)) {
            return true;
        }
    }
    return false;
}


void writeBuf(ubyte[] buf) {
    writefln("[0x%x, 0x%x, 0x%x, 0x%x, 0x%x, 0x%x]", buf[0], buf[1], buf[2]
                                                   , buf[3], buf[4], buf[5]);
}

int max(int a, int b) {
    if(a > b) return a;
    return b;
}
