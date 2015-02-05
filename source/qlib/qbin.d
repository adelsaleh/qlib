/**
 * Contains the utilities necessary for writing, reading and processing
 * qbin files.
 * 
 * Definitions of the notation used in the documentation:
 *
 * Authors: George Zakhour, Adel Saleh, Bayan Rafeh
 * Date: Feb 5, 2015
 *
 */

/* 
 * AF: The abstraction function which takes all the instance variables
 * of the class.
 */

module qlib.qbin;

import std.stdio;
import std.math;
import std.conv;
import std.container.array;
import qlib.util;
import qlib.instruction;
import qlib.asm_tokens;

version(unittest) {
    import std.file;
}

const int SIGNATURE = 0x10545e38;
const long PAGE_SIZE = 1024*4096L;
const int BYTE_LENGTH = 8;

struct BitOutputStream {
    /**
     * A BitOutputStream is a sequence of bits being written to file.
     */

    /* A list notation prefixed with F indicates a file.
     * A file is a sequence of bits.
     *
     * AF_prevPage = AF(page, f, PAGE_SIZE, 0, pageNum-1, PAGE_SIZE)
     *
     * AF(page, f, byteOffset, bitOffset, pageNum, size): 
     *                      F[0..len],
     *                      len = byteOffset*BYTE_SIZE + bitOffset
     *
     * REP INVARIANT: f[p(pageNum)..p(pageNum+1)] = page[0..PAGE_SIZE]
     *                              if byteOffset = 0 && bitOffset = 8 
     *                                                && f.isOpen
     *                f[p(pageNum) .. size] = page[0..byteOffset]
     *                              if !f.isOpen
     *                where p(num) = PAGE_SIZE*(num-1)*BYTE_LENGTH
     */
    ubyte[] page;
    File f;
    long byteOffset;
    long bitOffset;
    int pageNum;
    long _size;

    string path;

    /**
     * Creates a new BitOutputStream written to the file
     * at path. If file doesn't exist, it will be created.
     * 
     * Params:
     *      path = The path of the file to be written.
     */
    this(string path) {
        page = new ubyte[PAGE_SIZE];
        f = File(path, "w");
        byteOffset = 0;
        bitOffset = BYTE_LENGTH;
        pageNum = 0;
        this.path = path;
        _size = 0;
    }

    /**
     * Writes the bits left in the buffer and
     * closes the file.
     */
    ~this() {
        if(bitOffset != BYTE_LENGTH) { 
            f.rawWrite(page[0..byteOffset+1]);
        }else{
            f.rawWrite(page[0..byteOffset]);
        }
        f.flush();
        f.close();
    }
    /**
     * Returns: The size of the file written so far.
     */
    long size() {
        if(bitOffset == BYTE_LENGTH) {
            return _size;
        }else{
            return _size+1;
        }
    }

    /**
     * Writes the contents of the current page and moves
     * clears the buffer.
     */
    private void nextPage() {
        f.rawWrite(page);
        byteOffset = 0;
    }

    private void toNextByte() {
        bitOffset = BYTE_LENGTH;
        byteOffset++;
        if(byteOffset == PAGE_SIZE) {
            nextPage();
        }
        // Zero out the byte just in case
        page[byteOffset] = 0x0;
        _size++;
    }


    /**
     * Writes length bits from a to the stream.
     *
     * More formally,
     * bin(x) = [x(i) for every 0 < i <= 32] if x is an int 
     *                      where x(i) is the ith
     *                      most significant bit in x
     * int(arr) = an int where arr[i] is the ith most significant bit
     * AF_post = AF + int(bin(a)[0..length])
     *
     * Params:
     *      a = the integer containing the bits you want to write
     *      length = the number of bits to write.
     */
    void writeNumber(int a, int length) 
    in { assert(length >= 0 && length <= 32); }
    out {}
    body{
        //writefln("a: 0x%x, length: %s", a, length);
        if(length <= bitOffset) {
            // Write int to byte
            ubyte ba = cast(ubyte) a;
            ba <<= bitOffset-length;
            page[byteOffset] |= ba;
            bitOffset-=length;
            return;
        }
        int bitsLeft = length;

        bitsLeft -= bitOffset;
        page[byteOffset] |= (a >> bitsLeft);
        toNextByte();
        while(bitsLeft > BYTE_LENGTH) {
            bitsLeft -= BYTE_LENGTH;
            //writefln("0x%x", a >> bitsLeft);
            page[byteOffset] |= a >> (bitsLeft);
            toNextByte();
        }
        page[byteOffset] |=  (a) << (8-bitsLeft);
        bitOffset -= bitsLeft;
        if(bitOffset == 0) {
            toNextByte();
            bitOffset = 8;
        }
        
    } 

    unittest {
        writeln("BitOutputStream tests");
        ubyte[] file = [0x12, 0x34, 0x56, 0x78, 0x9a];
        string path = "/tmp/outtest";
        void writ(int[] write, int[] length) {
            auto bos = BitOutputStream(path);
            for(int i = 0; i < write.length; i++) {
                bos.writeNumber(write[i], length[i]);
            }
        }

        void check(ubyte[] check, int[] written, int[] length) {
            /*
             * check: the expected contents of the file.
             * write: the int to be written to the file
             * length: the amount of bits of write to be written
             */
            //writeln("Starting test");
            writ(written, length);
            ubyte[] buf = new ubyte[check.length];
           /* write("Check: ");
            writeBuf(check, check.length);
            write("Write: ");
            writeBuf(written, written.length);
            write("Length:");*/
            //writeln(length);

            File f = File(path, "r");
            f.rawRead(buf);
            //write("Buffer: ");
            //writeln(buf);
            //writeln(f.size);
            assert(f.size == check.length);
            //writeln(check.length);
            for(int i = 0; i < check.length; i++) {
                //writeln(i);
                assert(buf[i] == check[i]);
            }
        }
        
        check([0x10], [1], [4]);
        check([0x12], [1, 2], [4, 4]);
        check([0x12], [1, 0, 2], [4, 2, 2]);
        check([0x12, 0x34], [0x1234], [16]);
        check([0x12, 0x34], [0x1, 0x23, 0x4], [4, 8, 4]);
        check([0x12, 0x34, 0x56], [0x123456], [24]);
        check([0x12, 0x30], [0x1, 0x23], [4, 8]);
        check([0x12, 0x40], [0x12, 0x1], [8, 2]);
        check([0x12, 0x34], [0x1, 0x8, 0x34], [4, 6, 6]);
    }
    void writeString(string s) {
        for(int i = 0; i < s.length; i++) {
            writeNumber(s[i], 8);
        }
    }
}

class BitInputStream {
    /**
     * A bitinputstream is a sequence of bits read in big endian bit and
     * byte order from a file.
     */

    /*
     * AF(f, page, pageNum, byteOffset, bitOffset) = a list of bits, big endian
     *                                               bit order and little endian
     *                                               byte order.
     *
     * REP INVARIANT: f[pageStart..pageEnd] = page[0..head]
     *                  where pageStart = PAGE_SIZE*pageNum*BYTE_LENGTH,
     *                        pageEnd = pageStart + PAGE_SIZE*BYTE_LENGTH
     *                0 <= byteOffset < PAGE_SIZE
     *                0 < bitOffset <= 8
     *                0 <= pageNum*PAGE_SIZE + byteOffset <= f.size
     *
     * Abbreviations: AF = AF(f, page, pageNum, byteOffset, bitOffset)
     */
    ubyte[] page;
    File f;
    long byteOffset;
    long bitOffset; 
    string path;
    int pageNum;
    ulong size;
    //note: current bit = 8*byteOffset + bitOffset
    /**
     * Creates a new BitInputStream.
     * Params:
     *      path = Path of the file to read from
     */
    this(string path) {
        //writeln("Reached");
        page = new ubyte[PAGE_SIZE];
        f = File(path, "r");
        this.path = path;
        f.rawRead(page);
        byteOffset = 0;
        bitOffset = 8;
        pageNum = 0;
        size = f.size;
    }

    ~this() {
        //writeln("BitInputStream destructor called");
    }

//    invariant() {
        /*
         */
        // 0 <= byteOffset < PAGE_SIZE
//        assert(byteOffset >= 0 && byteOffset < PAGE_SIZE);

        // 0 < bitOffset <= 8
//        assert(bitOffset > 0 && bitOffset <= 8);

        // 0 <= pageNum * PAGE_SIZE + byteOffset < f.size
//        long currentByte = pageNum*PAGE_SIZE + byteOffset;
//        assert(currentByte >= 0 && currentByte <= size);
//    }

    /**
     * Loads the next page of bytes from the file.
     */
    private void loadNextPage() {
            f.rawRead(page);
    }

    /*
     * Returns: The total number of bytes read.
     */
    private long bytesRead() {
        return pageNum*PAGE_SIZE + byteOffset;

    }
    /*
     * Moves the stream to the next byte in the buffer, and loads
     * the next page if we reached the end
     */
    private void toNextByte() {
            if(byteOffset < PAGE_SIZE-1) { 
            byteOffset ++;
        }else{
            loadNextPage();
            byteOffset = 0;
        }
    }
    /*
     * Reads bits until we are byte aligned.
     * EFFECTS: AF_post = AF[bitOffset .. AF.length]
     * MODIFIES: pageNum, bitOffset, byteOffset, page,
     * Returns: int(AF[0..8-bitOffset])
     */
    private int readUntilAligned() { 
        

        int ret = extractValue(page[byteOffset], bitOffset, 0);
        toNextByte(); 
        bitOffset = 8;
        return ret; 
    }

    /*
     * Returns: int(b[top..bottom])
     */
    private int extractValue(ubyte b, long top, long bottom) {
        int mask = bitMask(top, bottom);
        return (mask & b) >> (bottom);
    }

    private long bitsLeftInFile() {
        ulong totalBits = size* 8;
        ulong bitsRead = bytesRead + pageNum*PAGE_SIZE*8;
        return (size*8) - (8*bytesRead + (8 - bitOffset)); 
    }
    /**
     * Read a number from the stream and store it in an int.
     * Formally, AF_post = AF[length .. AF.length]
     * 
     * Params:
     *      length = a number between 0 and 32 inclusive
     * Returns: int(AF[0 .. length]).
     *
     */
    int readNumber(int length) 
    in { assert(length >= 0 && length <= 32); }
    out(result) {}
    body{
        //writefln("Current byte: 0x%x", page[byteOffset]);
        if(length > bitsLeftInFile) {
            length = cast(int)bitsLeftInFile;
        }
        //writefln("Length: %s", length);
        if(length <= bitOffset) {
            int ret = extractValue(page[byteOffset], bitOffset, bitOffset-length);
            //ret >>= (bitOffset-length);
            bitOffset -= length;
            if(bitOffset == 0) {
                bitOffset = 8;
                toNextByte();
            }
            return ret;
        }
        int bitsLeft = length;

        bitsLeft -= bitOffset;
        int ret = readUntilAligned() << bitsLeft;
        while(bitsLeft > 8) {
            bitsLeft -= 8;
            ret |= page[byteOffset] << (bitsLeft);
            toNextByte();
        }
        
        ret |= extractValue(page[byteOffset], 8, 8-bitsLeft);
        //writefln("ret: 0x%x", ret);
        bitOffset -= bitsLeft;
        if(bitOffset == 0) {
            toNextByte();
            bitOffset = 8;
        }
        return ret;
    }

    unittest {
    
        writeln("BitInputStream tests");
        //writeln("Reached");
        File test1 = File("/tmp/test1", "w");
        // The cases we need to test are the following:
        // 1. length == 0
        // 2. length < bitOffset
        // 3. length == bitOffset 
        // 4. 0 < length < 8 /\ bitOffset == 8
        // 5. length == 8 /\ bitOffset == 8
        // 6. length % 8 == 0 /\ length > 8 /\ bitOffset == 8
        // 7. bitOffset < length < bitOffset + 8 /\ bitOffset != 0 
        // 8. length > bitOffset + 8
        //  And all of the previous cases at the last byte in the file
        //  except 1, 2
        // Total cases that need testing: 14
        // 01|00 0011|  0010 0101  0011 0011  0100 0010  01|01 0111  0010 0001
        ubyte[] testBuf = [0x43, 0x25, 0x33, 0x42, 0x57, 0x21, 
                            0xcd, 0x5f, 0x02, 0xc5];
        test1.rawWrite(testBuf);
        test1.close();
        auto path = "/tmp/test1";
        //writeln("Reached");
        BitInputStream bis = new BitInputStream(path);
        //writeln("Reached");
        // 1. length == 0
        int res = bis.readNumber(0);
        assert(res == 0x0);

        // 2. length < bitOffset
        res = bis.readNumber(2);
        //writefln("Result: 0x%x", res);
        assert(res == 0x1);

        // 3. length == bitOffset
        res = bis.readNumber(6);
        //writefln("Result: 0x%x", res);
        //writefln("Current Byte: 0x%x", bis.page[bis.byteOffset]);
        assert(res == 0x03);
        
        // 4. 0 < length < 8 /\ bitOffset == 8(byte alignment)
        res = bis.readNumber(4);
        //writefln("Result: 0x%x", res);
        //writefln("Current Byte: 0x%x", bis.page[bis.byteOffset]);
        assert(res == 0x2);


        // Align the byte, and make sure it's correct
        res = bis.readNumber(4);
        assert(res == 0x5);

        // 5. length == 8 /\ bitOffset = 8
        res = bis.readNumber(8);
        assert(res == 0x33);

        // 6. length % 8 == 0 /\ length > 8 /\ bitOffset == 8
        res = bis.readNumber(16);
        //writefln("Result: 0x%x", res);
        //writefln("Current Byte: 0x%x", bis.page[bis.byteOffset]);
        assert(res == 0x4257);

        // 7. bitOffset < length < bitOffset + 8 /\ bitOffset != 0
        res = bis.readNumber(4);
        assert(res == 0x2);
        res = bis.readNumber(10);
        assert(res == 0x73);

        // 8. length > bitOffset + 8 
        res = bis.readNumber(15);
        //writefln("Result: 0x%x", res);
        //writefln("Current Byte: 0x%x", bis.page[bis.byteOffset]);
        assert(res == 0x2be0);


        bis = new BitInputStream(path);
        res = bis.readNumber(32);
 //       writefln("Res: 0x%x", res);
        assert(res == 0x43253342);
        // Now for the EOF tests.
 //       writeln("START EOF TESTS");
        struct OffsetTestCase {
            string path;
            int offset;
            int bits;
            int check;
        }
        void checkAtOffset(OffsetTestCase otc) {
            /* param path: path of file
             * param offset: bits to skip before starting test
             * param bits: bits to read for test
             * param check: the expected value returned by readNumber
             */
            //writefln("Offset: %s\n Bits: %s\n check: 0x%x", otc.offset, otc.bits, otc.check);
            //writeln("Start test");
            BitInputStream test = new BitInputStream(otc.path);
            int offset = otc.offset;
            while(offset > 32) {
               test.readNumber(32);
               offset-=32;
            }
            test.readNumber(offset);
            offset = 0;
            int res = test.readNumber(otc.bits);
            //writefln("Res: 0x%x", res);
            assert(res == otc.check);
            //writeln("End test");
        }

        // 3. length == bitOffset
        // 1100 0101
        auto tc = OffsetTestCase(path, 74, 6, 0x05);
        checkAtOffset(tc);

        // 4. 0 < length < 8 /\ bitOffset == 8(byte alignment)
        tc = OffsetTestCase(path, 72, 4, 0xc);
        checkAtOffset(tc);

        //5. length == 8 /\ bitOffset == 8
        tc = OffsetTestCase(path, 72, 8, 0xc5);
        checkAtOffset(tc);

        // 6. length % 8 == 0 /\ length > 8 /\ bitOffset == 8
        tc = OffsetTestCase(path, 72, 10, 0xc5);
        checkAtOffset(tc);

        // 7. bitOffset < length < bitOffset + 8 /\ bitOffset != 0
        tc = OffsetTestCase(path, 74, 10, 0x5);
        checkAtOffset(tc);

        // 8. length > bitOffset + 8 
        tc = OffsetTestCase(path, 74, 25, 0x5);
        checkAtOffset(tc);

        // TODO: Test page flips
        // Not a high priority since our files probably won't
        // exceed 4kb
        ubyte[] largeBuf = new ubyte[PAGE_SIZE+9];
        largeBuf[$-10..$] = testBuf[0..$];
        string lpath = "/tmp/test2";
        File large = File(lpath, "w");
        large.write(large);
        large.close();

        remove(path);
        remove(lpath);

    }
    

    /**
     * Returns: true if we reached eof, false otherwise.
     */
    bool empty() {
        return bytesRead == size;
    }
}



enum SectionType {
    FUNCTION,
    IDENTIFIER
}

/**
 * A qbin file is split into sections, each section containing a
 * different kind of information. This class just holds common
 * internal information used by the section.
 */

class Section {
    protected BitInputStream bs;
    protected int headerVal; //The 14 bit integer that follows the header.
    
    protected this(int hv, BitInputStream bs) {
        this.headerVal = hv;
        this.bs = bs;
    }

    ~this() {
        //writeln("Section destructor called");
    }
    /**
     * Reads a new section header from the provided
     * stream, and returns a Section object corresponding
     * to the type of section read from the stream.
     * 
     * Requires: The stream be set at the start of a section.
     * Params:
     *      bs = The BitInputStream to read from.
     * Returns: A according to the type read from the stream.
     */
    static Section createSection(BitInputStream bs) {
        if(bs.empty()) {
            //writeln("EMPTY");
            return null;
        }
        SectionType type = cast(SectionType)bs.readNumber(2);
        int hv = bs.readNumber(14);
        //writefln("HVALUE: 0x%x", hv);
        //writeln(type);
        switch(type) {
            case SectionType.FUNCTION:
                return new FunctionSection(hv, bs);
            case SectionType.IDENTIFIER:
                return new IdentifierSection(hv, bs);
            default:
                throw new Exception("Invalid section type.");
        }
    }
    /**
     * The header of each section in a qbin file contains 2 bits,
     * representing a type, and a 14 bit value which is defined
     * according to the section type.
     */
    int hvalue() {
        return headerVal;
    }
}



enum IdentifierType {
    QUBIT,
    FUNCTION,
    CLASSICAL
}


/**
 * An IdentifierSection is a section of a qbin file
 * containing an identifier corresponding to a qubit,
 * function etc. in a qbin file. The identifiers are
 * numbered according to order.
 */
class IdentifierSection : Section {
    string _name;
    IdentifierType _type;
    int size;
    /**
     * Reads the identifier from the stream and
     * stores it.
     */
    protected this(int hv, BitInputStream bs) {
        super(hv, bs);
        _type = cast(IdentifierType)this.hvalue >> 12;
        size = this.hvalue & 0x0fff;
        _name = readName();
    }

    ~this() {
        //writeln("IdentifierSection destructor called");
    }
    
    /**
     * Returns: The type of the identifier.
     */
    IdentifierType type() {
        return _type;
    }
    
    private string readName() {
        string name = "";
        for(int i = 0; i < size; i++) {
            name ~= cast(char)bs.readNumber(8);
        }
        return name;
    }
    
    /**
     * Gets the string stored by the identifier.
     */
    string name() {
        return _name;
    }

    bool empty() {return true;}
}

const int INSTRUCTION_LENGTH = 6;

alias RawInstructionBuffer = ubyte[INSTRUCTION_LENGTH];


/**
 * FunctionSection: A section representing a qbin function, which
 *              is a sequence of instructions.
 */
class FunctionSection : Section {
    bool done;
    Instruction current;
    int identifier() {
        return this.hvalue;
    }

    this(int hv, BitInputStream bs) {
        super(hv, bs);
        done = false;
        popFront();
    }

    ~this() {
        //writeln("FunctionSection destructor called");
    }
    /**
     * Returns: The current instruction.
     */
    public Instruction front() {
        return current;  
    }

    /**
     * Loads the next instruction from the stream.
     */
    public void popFront() {
        Opcode opcode = cast(Opcode)bs.readNumber(4);
        int qubit = bs.readNumber(7);
        int op1 = bs.readNumber(7);
        int op2 = bs.readNumber(7);
        int number = bs.readNumber(7);
        int lineNumber = bs.readNumber(16);
        current = Instruction(opcode, qubit, op1, op2, number, lineNumber);
    }
    
    /**
     * Returns: true if we reached the end of the function in the stream.
     */
    bool empty() {
        bool done = current.opcode == Opcode.NULL && current.qubit == 0
                                                  && current.op1 == 0
                                                  && current.op2 == 0
                                                  && current.number == 0
                                                  && current.lineNumber == 0;
        return done;
    }
}


/**
 * An iterator that goes through the sections in a qbin file.
 */
struct QbinFileReader {
    BitInputStream bs;
    Section current;
    bool _empty;

    this(string path) {
        auto bit = new BitInputStream(path);
        bs = bit;
        int sig = bs.readNumber(32);
        //writefln("Signature: 0x%x", sig);
        if(sig != SIGNATURE) {
            throw new Exception("Invalid qbin file");
        }
        _empty = false;
        current = Section.createSection(bs);
    }

    ~this() {
        //writeln("QbinFileReader destructor called");
    }

    Section front() {
        return current;
    }

    void popFront() {
        current = Section.createSection(bs);
        if(!current) {
            _empty = true;
        }
    }
    bool empty() {
        return _empty;
    }

    
}


unittest {
    import std.range;
    writeln("QbinFileReader tests");
    //writeln("Start");
    ubyte c(char c) {
        return cast(ubyte)c;
    }
    ubyte[] invalidFile = [0x05, 0x54, 0x34, 0x23, 0x55];
    // 0100 0000 0000 0001 
    ubyte[] validFile = [0x10, 0x54, 0x5e, 0x38
                        ,0x40, 0x01, c('A') // Qubit A
                        ,0x50, 0x02, c('F'), c('n') // Function fn
                        ,0x60, 0x01, c('C')// Classical variable C
                        ,0x00, 0x02 // Function header
                        ,0x10, 0x20, 0x00, 0x00, 0x00, 0x02 // Qubit A:2
                        ,0x10, 0x60, 0x00, 0x00, 0x00, 0x03 // var C:2
                        ,0x00, 0x00, 0x00, 0x00, 0x00, 0x00];
    auto ipath = "/tmp/invalid";
    auto vpath = "/tmp/valid";
    File i = File(ipath, "w");
    File v = File(vpath, "w");
    i.rawWrite(invalidFile);
    v.rawWrite(validFile);
    i.close();
    v.close();
    try {
        auto qf = QbinFileReader(ipath);
        assert(false);
    }catch(Exception e) {
        
    }
    //writeln("*****************STARTING VALID TESTS******************");
    QbinFileReader qbin = QbinFileReader(vpath);
    assert(isInputRange!QbinFileReader);
    auto ident = cast(IdentifierSection)qbin.front();
    assert(ident.name == "A");
    assert(ident.type == IdentifierType.QUBIT);
    assert(ident.hvalue == 0x0001);//0100 0000 0000 0001

    qbin.popFront();

    ident = cast(IdentifierSection)qbin.front();
    assert(ident.name == "Fn");
    assert(ident.type == IdentifierType.FUNCTION);
    assert(ident.hvalue == 0x1002); //0101 0000 0000 0010
    //writeln(ident.name);
    //writefln("0x%x", ident.hvalue);
    qbin.popFront();

    ident = cast(IdentifierSection)qbin.front();
    assert(ident.name == "C");
    assert(ident.type == IdentifierType.CLASSICAL);
    qbin.popFront();
    auto fn = cast(FunctionSection)qbin.front();
    //writefln("Identifier: 0x%x", fn.identifier);
    assert(fn.identifier == 0x02);
}
/**
 * Converts a string into a byte array.
 * Params:
 *      id = string to convert to a byte array
 *      buf = the buffer we need to place the byte array in
 */
void IdToByteArray(string id, ubyte[] buf) 
in{
    assert(id.length +2 < buf.length);
    assert(id.length < (1<<14));
}
out{} 
body{
    buf[0] = 0x40 | cast(ubyte)(id.length >> 8);
    buf[1] = cast(ubyte)(0xff & id.length);
    for(int i = 0; i < id.length; i++) {
        buf[i+2] = cast(ubyte)id[i];
    }
}
