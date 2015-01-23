/**
 * This module contains the functions to interact with a qbin file.
 * Definitions of the notation used in the documentation:
 *      <a_x .. a_y> is a sequence with the index starting at x and ending
 *                   at y. x, y belong to N
 */

module qlib.qbin;

import std.stdio;
import std.math;
import std.conv;
import std.container.array;
import qlib.util;
version(unittest) {
    import std.file;
}

const int SIGNATURE = 0x10545e38;
const long PAGE_SIZE = 1024*4096L;
const int BYTE_LENGTH = 8;

struct BitOutputStream {
    /**
     * A BitOutputStream is a sequence of ints of arbitrary bit-length written
     * to a file.
     */
    ubyte[PAGE_SIZE] page;
    File f;
    long byteOffset;
    long bitOffset;
    int pageNum;
    string path;
    long _size;

    this(string path) {
        f = File(path, "w");
        byteOffset = 0;
        bitOffset = 8;
        pageNum = 0;
        this.path = path;
        _size = 0;
    }

    ~this() {
        flush();
        f.flush();
        f.close();
    }
    
    long size() {
        if(bitOffset == 8) {
            return _size;
        }else{
            return _size+1;
        }
    }
    private void nextPage() {
        f.rawWrite(page);
        byteOffset = 0;
    }

    private void flush() {
        /**
         * Writes the contents of the page to the file.
         */
        if(bitOffset != 8) { 
            f.rawWrite(page[0..byteOffset+1]);
        }else{
            f.rawWrite(page[0..byteOffset]);
        }
    }

    private void toNextByte() {
        bitOffset = 8;
        byteOffset++;
        if(byteOffset == PAGE_SIZE) {
            nextPage();
        }
        // Zero out the byte just in case
        page[byteOffset] = 0x0;
        _size++;
    }

    void writeNumber(int a, int length) 
    in { assert(length >= 0 && length <= 32); }
    out {}
    body{

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
        while(bitsLeft > 8) {
            bitsLeft -= 8;
            writefln("0x%x", a >> bitsLeft);
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
            writeln("Starting test");
            writ(written, length);
            ubyte[] buf = new ubyte[check.length];
            write("Check: ");
            writeln(check);
            write("Write: ");
            writeln(written);
            write("Length:");
            writeln(length);

            File f = File(path, "r");
            f.rawRead(buf);
            write("Buffer: ");
            writeln(buf);
            assert(f.size == check.length);
            for(int i = 0; i < check.length; i++) {
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
}

class BitInputStream {
    /**
     * A bitinputstream is a sequence of bits read in big endian bit and
     * byte order from a file.
     */

    /*
     * Assuming a file is a list of buffers of size PAGE_SIZE
     * len(f) is the number of bytes in the file f
     *
     * Assume a file is a list of bytes.
     *
     * AF(f, page, pageNum, byteOffset, bitOffset) = <a_c .. a_(f.size*8)>
     *               where a_n = bit(f[n/8], n%8)
     *               c = bit(f[pageNum*PAGE_SIZE + byteOffset], bitOffset)
     *               bit(byte, offset) = (byte & 1 << (8-offset)) >> 8-offset
     *
     *
     * Abbreviations: AF = AF(f, page, pageNum, byteOffset, bitOffset)
     */
    ubyte[PAGE_SIZE] page;
    File f;
    long byteOffset;
    long bitOffset; 
    string path;
    int pageNum;
    ulong size;
    //note: current bit = 8*byteOffset + bitOffset

    this(string path) {
        f = File(path, "r");
        this.path = path;
        f.rawRead(page);
        byteOffset = 0;
        bitOffset = 8;
        pageNum = 0;
        size = f.size;
    }

    ~this() {
        f.close();
    }

    invariant() {
        /*
         * REP INVARIANT: page = f[pageNum*PAGE_SIZE..(pageNum+1)*PAGE_SIZE]
         *                0 <= byteOffset < PAGE_SIZE
         *                0 < bitOffset <= 8
         *                0 <= pageNum*PAGE_SIZE + byteOffset <= f.size
         */
        // 0 <= byteOffset < PAGE_SIZE
        assert(byteOffset >= 0 && byteOffset < PAGE_SIZE);

        // 0 < bitOffset <= 8
        assert(bitOffset > 0 && bitOffset <= 8);

        // 0 <= pageNum * PAGE_SIZE + byteOffset < f.size
        long currentByte = pageNum*PAGE_SIZE + byteOffset;
        assert(currentByte >= 0 && currentByte <= size);

        // page = f[pageNum*PAGE_SIZE..(pageNum+1)*PAGE_SIZE]
        File test = File(path, "r");
        test.seek(pageNum*PAGE_SIZE);

        ubyte[PAGE_SIZE] testPage;
        scope(exit) { test.close(); }

        test.rawRead(testPage);

        for(int i = 0; i < testPage.length; i++) {
            assert(page[i] == testPage[i]);
        }
    }
    
    private void loadNextPage() {
        /**
         * EFFECTS: Loads the next page of bytes from the file.
         * MODIFIES: pageNum, page
         */
        f.rawRead(page);
    }

    private long bytesRead() {
        return pageNum*PAGE_SIZE + byteOffset;

    }

    private void toNextByte() {
        /**
         * Moves the stream to the next byte in the buffer, and loads
         * the next page if we reached the end
         */
        if(byteOffset < PAGE_SIZE-1) { 
            byteOffset ++;
        }else{
            loadNextPage();
            byteOffset = 0;
        }
    }

    unittest {
        
    }

    private int readUntilAligned() { 
        /**
         * Reads bits until we are byte aligned.
         * 
         * EFFECTS: AF_post = <a_d .. #AF> where d = c+bitOffset
         * MODIFIES: pageNum, bitOffset, byteOffset, page,
          * RETURNS: an int containing <a_c .. a_d>
         */

        int ret = extractValue(page[byteOffset], bitOffset, 0);
        toNextByte(); 
        bitOffset = 8;
        return ret; 
    }

    
    private int extractValue(ubyte b, long top, long bottom) {
        int mask = bitMask(top, bottom);
        return (mask & b) >> (bottom);
    }

    private long bitsLeftInFile() {
        ulong totalBits = size* 8;
        ulong bitsRead = bytesRead + pageNum*PAGE_SIZE*8;
        return (size*8) - (8*bytesRead + (8 - bitOffset)); 
    }

    int readNumber(int length) 
        /**
         * Read a number from the stream and store it in an int.
         * REQUIRES: length 0 <= length <= 32
         * EFFECTS: AF_post = <AF_(c+length) .. #AF>
         *
         * RETURNS: An int containing <a_c .. a_(c+length)>.
         *
         * 1 1 1 1  1 1 1 1
         */
    in { assert(length >= 0 && length <= 32); }
    out(result) {}
    body{
        writefln("Current byte: 0x%x", page[byteOffset]);
        if(length > bitsLeftInFile) {
            length = cast(int)bitsLeftInFile;
        }
        writefln("Length: %s", length);
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
        writefln("ret: 0x%x", ret);
        bitOffset -= bitsLeft;
        if(bitOffset == 0) {
            toNextByte();
            bitOffset = 8;
        }
        
        return ret;
    }

    unittest {
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
        BitInputStream bis = new BitInputStream(path);
        // 1. length == 0
        int res = bis.readNumber(0);
        assert(res == 0x0);

        // 2. length < bitOffset
        res = bis.readNumber(2);
        writefln("Result: 0x%x", res);
        assert(res == 0x1);

        // 3. length == bitOffset
        res = bis.readNumber(6);
        writefln("Result: 0x%x", res);
        writefln("Current Byte: 0x%x", bis.page[bis.byteOffset]);
        assert(res == 0x03);
        
        // 4. 0 < length < 8 /\ bitOffset == 8(byte alignment)
        res = bis.readNumber(4);
        writefln("Result: 0x%x", res);
        writefln("Current Byte: 0x%x", bis.page[bis.byteOffset]);
        assert(res == 0x2);

        // Align the byte, and make sure it's correct
        res = bis.readNumber(4);
        assert(res == 0x5);

        // 5. length == 8 /\ bitOffset = 8
        res = bis.readNumber(8);
        assert(res == 0x33);

        // 6. length % 8 == 0 /\ length > 8 /\ bitOffset == 8
        res = bis.readNumber(16);
        writefln("Result: 0x%x", res);
        writefln("Current Byte: 0x%x", bis.page[bis.byteOffset]);
        assert(res == 0x4257);

        // 7. bitOffset < length < bitOffset + 8 /\ bitOffset != 0
        res = bis.readNumber(4);
        assert(res == 0x2);
        res = bis.readNumber(10);
        assert(res == 0x73);

        // 8. length > bitOffset + 8 
        res = bis.readNumber(15);
        writefln("Result: 0x%x", res);
        writefln("Current Byte: 0x%x", bis.page[bis.byteOffset]);
        assert(res == 0x2be0);

        delete bis;

        bis = new BitInputStream(path);
        res = bis.readNumber(32);
        writefln("Res: 0x%x", res);
        assert(res == 0x43253342);
        // Now for the EOF tests.
        writeln("START EOF TESTS");
        delete bis; 
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
            writefln("Offset: %s\n Bits: %s\n check: 0x%x", otc.offset, otc.bits, otc.check);
            writeln("Start test");
            BitInputStream test = new BitInputStream(otc.path);
            int offset = otc.offset;
            while(offset > 32) {
               test.readNumber(32);
               offset-=32;
            }
            test.readNumber(offset);
            offset = 0;
            int res = test.readNumber(otc.bits);
            writefln("Res: 0x%x", res);
            assert(res == otc.check);
            delete test;
            writeln("End test");
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
    

    char readChar(int length) {

        /**
         * Read a number from the stream and store it in a char.
         * REQUIRES: length 0 < length <= 8
         * EFFECTS: AF_post = <a_(c+length) .. a_f.size>
         *
         * RETURNS: A char containing <a_c .. a_(c+length)>.
         */
        return '\0';
    }
    
    ubyte readByte() {
        /**
         * Read a number from the stream and store it in a char.
         * REQUIRES: length 0 < length <= 8
         * EFFECTS: AF_post = <a_(c+length) .. a_f.size>
         *
         * RETURNS: A char containing <a_c .. a_(c+length)>.
         */

        ubyte ret = 0x0;
        return ret;
    }

    void readByteArray(ubyte[] buf) {
        for(int i = 0; i < buf.length; i++) {
            buf[i] = cast(ubyte)readNumber(8);
            writefln("0x%x", buf[i]);
        }
        writeBuf(buf);
    }

    bool empty() {
        return false;
    }
}
//01001100110100001001



enum SectionType {
    FUNCTION,
    IDENTIFIER
}

class Section {
    protected BitInputStream bs;
    protected int headerVal; //The 14 bit integer that follows the header.
    protected this(int hv, BitInputStream bs) {
        this.headerVal = hv;
        this.bs = bs;
    }

    static Section createSection(BitInputStream bs) {
        SectionType type = cast(SectionType)bs.readNumber(2);
        int hv = bs.readNumber(14);
        writefln("HVALUE: 0x%x", hv);
        writeln(type);
        switch(type) {
            case SectionType.FUNCTION:
                return new FunctionSection(hv, bs);
            case SectionType.IDENTIFIER:
                return new IdentifierSection(hv, bs);
            default:
                throw new Exception("Invalid section type.");
        }
    }

    int hvalue() {
        return headerVal;
    }
}



enum IdentifierType {
    QUBIT,
    FUNCTION,
    CLASSICAL
}
class IdentifierSection : Section {
    string _name;
    IdentifierType _type;
    int size;
    protected this(int hv, BitInputStream bs) {
        super(hv, bs);
        _type = cast(IdentifierType)this.hvalue >> 12;
        size = this.hvalue & 0x0fff;
        _name = readName();
    }
    
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

    string name() {
        return _name;
    }
}

const int INSTRUCTION_LENGTH = 6;

alias RawInstructionBuffer = ubyte[INSTRUCTION_LENGTH];



class FunctionSection : Section {
    bool done;
    
    int identifier() {
        return this.hvalue;
    }

    this(int hv, BitInputStream bs) {
        super(hv, bs);
        done = false;
    }

    public ubyte[] nextInstruction(ubyte[] buf) {
        writeln("Entered");
        if(!done) {
            bs.readByteArray(buf);
            done = !mixin(zeroCondition("buf", INSTRUCTION_LENGTH));
            writeBuf(buf);
        }
        return buf;
    }
}

class QbinFile {
    BitInputStream bs;
    Section current;
    bool empty;

    this(string path) {
        auto bit = new BitInputStream(path);
        bs = bit;
        int sig = bs.readNumber(32);
        writefln("Signature: 0x%x", sig);
        if(sig != SIGNATURE) {
            throw new Exception("Invalid qbin file");
        }
        empty = false;
        current = Section.createSection(bs);
    }

    Section front() {
        return current;
    }

    void popFront() {
        current = Section.createSection(bs);
    }
    
    ~this() {
        delete bs;
    }
}

unittest {
    import std.range;
    
    writeln("Start");
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
        auto qf = new QbinFile(ipath);
        assert(false);
    }catch(Exception e) {
        
    }
    writeln("*****************STARTING VALID TESTS******************");
    QbinFile qbin = new QbinFile(vpath);
    assert(isInputRange!QbinFile);
    auto ident = cast(IdentifierSection)qbin.front();
    assert(ident.name == "A");
    assert(ident.type == IdentifierType.QUBIT);
    assert(ident.hvalue == 0x0001);//0100 0000 0000 0001
    delete ident;

    qbin.popFront();

    ident = cast(IdentifierSection)qbin.front();
    assert(ident.name == "Fn");
    assert(ident.type == IdentifierType.FUNCTION);
    assert(ident.hvalue == 0x1002); //0101 0000 0000 0010
    writeln(ident.name);
    writefln("0x%x", ident.hvalue);
    delete ident;
    qbin.popFront();

    ident = cast(IdentifierSection)qbin.front();
    assert(ident.name == "C");
    assert(ident.type == IdentifierType.CLASSICAL);
    delete ident;
    qbin.popFront();
    auto fn = cast(FunctionSection)qbin.front();
    writefln("Identifier: 0x%x", fn.identifier);
    assert(fn.identifier == 0x02);
    RawInstructionBuffer buf;
    fn.nextInstruction(buf);
    writeBuf(buf);
    assert(buf[0] == cast(ubyte)0x10);
    assert(buf[1] == cast(ubyte)0x20);
    assert(buf[2] == cast(ubyte)0x00);
    assert(buf[3] == cast(ubyte)0x00);
    assert(buf[4] == cast(ubyte)0x00);
    assert(buf[5] == cast(ubyte)0x02);
    writeln("PROBLEM SECTION");
    fn.nextInstruction(buf);
    writeBuf(buf);
    assert(buf[0] == cast(ubyte)0x10);
    assert(buf[1] == cast(ubyte)0x60);
    assert(buf[2] == cast(ubyte)0x00);
    assert(buf[3] == cast(ubyte)0x00);
    assert(buf[4] == cast(ubyte)0x00);
    assert(buf[5] == cast(ubyte)0x03);

    fn.nextInstruction(buf);
    assert(buf[0] == cast(ubyte)0x00);
    assert(buf[1] == cast(ubyte)0x00);
    assert(buf[2] == cast(ubyte)0x00);
    assert(buf[3] == cast(ubyte)0x00);
    assert(buf[4] == cast(ubyte)0x00);
    assert(buf[5] == cast(ubyte)0x00);
}
