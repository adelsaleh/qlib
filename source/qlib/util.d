module qlib.util;

import std.stdio;
import std.conv;
import std.range;


/**
 * Checks if an object is an instance of a class
 * Params:
 *      o = The object to be checked
 *      T = The type to be checked against.
 * Returns:
 *      null if o is not an instance of T,
 *      o cast to T otherwise.
 */
T instanceof(T)(Object o) if(is(T == class)) {
    return cast(T) o;
}

/**
 * Generate a mask that can be used to extract
 * the bits between the most significant bit(msb) inclusive
 * and the least significant bit(lsb) exclusive
 * 
 * Params:
 *      msb: The topmost bit to flag.
 *      lsb: The lowest bit to flag.
 * Returns:
 *      A mask whose only set bets are bits msb(inclusive)..lsb(exclusive)
 */

int bitMask(long msb, long lsb) 
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

/**
 * Convert a raw ascii byte array to a string.
 * Params:
 *      buf = the array to convert.
 * Returns:
 *      A string representation of buf.
 */
string toString(ubyte[] buf) {
    string ret = "";
    for(int i = 0; i < buf.length; i++) {
        ret ~= cast(char)buf[i];
    }
    return ret;
}
/**
 * Generates a code snippet that checks whether an array
 * is a zero array.
 * Params:
 *      var: Name of the array
 *      length: length of the array.
 * Returns:
 *      Code snippet to test if var is zero.
 */
string zeroCondition(string var, int length) {

    string snippet = var~"[0] == 0";
    for(int i = 1; i < length; i++) {
        snippet ~= " && " ~ var ~ "["~to!string(i)~"] == 0";
    }
    return snippet;
}

/**
 * Checks if a character is a whitespace character.
 * 
 * Params:
 *      c = char to be checked
 * Returns:
 *      true if c is a whitespace character, false otherwise.
 */
bool is_whitespace(char c) {
    return c == ' ' || c == '\t' || c == '\r' || c == '\n';
}

/**
 * Checks whether a string is all whitespace.
 * Params:
 *      line = string to be checked.
 * Returns:
 *      true if all the characters in the string are whitespace
 */
bool isEmptyLine(string line) {
    foreach(char c; line) {
        if(!is_whitespace(c)) {
            return true;
        }
    }
    return false;
}

/**
 * Output buf's elements to stdout in hex.
 * Params:
 *      buf = The array to be written.
 */
void writeBuf(T)(T[] buf, ulong count=6) {
    writef("[0x%x", buf[0]);
    for(int i = 1; i < count; i++) {
        writef(", 0x%x", buf[i]);
    }
    writeln("]");
}

int max(int a, int b) {
    if(a > b) return a;
    return b;
}
/**
 * Finds the first instance of the given element in the given range.
 *
 * Params:
 *      a = The range to be searched.
 *      el = The element to be found.
 * Returns: 
 *      the index of element el if it exists in a,
 *      else returns -1.
 */
int search(T, V)(T a, V el) if(isRandomAccessRange!T) {

    for(int i = 0; i < a.length; i++) {
        if(a[i] == el) {
            return i;
        }
    }
    return -1;
}
