module qlib.blackbox;

/**
 * This module contains all the utilities needed to communicate with black box servers.
 */

import vibe.d;
import std.stdio;
import std.bitmanip;


/**
 * A client that implements the black box protocol, and can be used
 * to query black boxes.
 */
struct BlackBoxConnection {
    string host;
    ushort port;
    TCPConnection conn;
    ubyte[] outputBuffer;

    /**
     * Opens a connection to a black box server.
     * Params:
     *      host = The location of the black box
     *      port = The port of the black box. Defaults to 8888
     */
    this(string host, ushort port = 8888) {
        this.host = host;
        this.port = port;
        conn = connectTCP(host, port);
        outputBuffer = new ubyte[4];
    }

    ~this() {
        conn.close();
    }
    
    /**
     * The list of indices and the number of input bits 
     * and output bits they take. Useful for debugging.
     * Not needed to be implemented by server.
     *
     * Returns:
     *      A dictionary where the key is the index and
     *      the value is [input qubits, output qubits]
     */
    int[][int] functionList() {
        int[][int] ret;
        conn.write(cast(ubyte[])[0x00]);
        conn.flush();
        ubyte[] rawResponse = new ubyte[12];
        conn.read(rawResponse);
        int[] response = parseInts(rawResponse);
        while(response != [0, 0, 0]) {
            ret[response[0]] = response[1..$];
            conn.read(rawResponse);
            response = parseInts(rawResponse);
        }
        return ret;
    }

    /**
     * Given the index of the function, get the number
     * of input qubits nd the number of output qubits of
     * that function.
     * Params:
     *      index = the index of the function to be queried.
     * Returns:
     *      [input_qubits, output_qubits]
     */
    int[] parameterSizes(int index) {
        ubyte[] toSend = [0x01];
        toSend ~= nativeToLittleEndian(index);
        conn.write(toSend);
        conn.flush();
        ubyte[] rawResponse = new ubyte[8];
        conn.read(rawResponse);
        return parseInts(rawResponse);
    }

    /**
     * Query the function at index with a specific input value.
     * The function will ignore any bits higher than what the function
     * defines.
     *
     * Params:
     *      index = index of the function to be queried
     *      val = the input value to be given to the function
     *
     * Returns:
     *      The output of the black box function
     */
    int query(int index, int val) {
        ubyte[] rawIndex = nativeToLittleEndian(index);
        ubyte[] rawVal = nativeToLittleEndian(val);
        conn.write([cast(ubyte)0x02] ~ rawIndex ~ rawVal);
        conn.flush();
        conn.read(outputBuffer);
        writeln(outputBuffer);
        return parseInts(outputBuffer)[0];
    }
}


/**
 * Converts the given array of bytes into an
 * array of ints. The ints must be little endian.
 *
 * Params:
 *      arr = The raw array of bytes to be converted
 *
 * Returns:
 *      The parsed values.
 */
int[] parseInts(ubyte[] arr) {
    assert(arr.length % 4 == 0);

    int[] ret = new int[arr.length/4];
    for(int i = 0; i < ret.length; i++) {
        ubyte[4] tmp = arr[i*4..(i+1)*4];
        ret[i] = littleEndianToNative!int(tmp);
    }
    return ret;
}
