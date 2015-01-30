module qlib.collections;
import qlib.asm_tokens;
import std.stdio;
import qlib.qbin;
import qlib.instruction;
import qlib.util;
import std.container.array;

struct FunctionPointer {
    Function current;
    int instruction;
}
struct Function {
    /*
     * AF(index, instructions) = [i for i in instructions] 
     */
    int index;
    Array!Instruction instructions;
}

class CollapsingQueue(T) {
    /**
     * TODO: Remove duplicates
     * A queue that can be cleared after a certain number of
     * elements are dequeued.
     */
    Array!T queue;
    /*
     * AF(queue) = [x for all x in queue]
     */

    T dequeue() {
        /**
         * REQUIRES: queue is not empty.
         * EFFECTS: AF_post = AF[1:]
         * RETURNS AF[0]
         */
        T el = queue[0];
        queue = queue[1..$];
        return el;
    }

    void enqueue(T el) {
        /**
         * EFFECTS: AF_post = AF + [el]
         */
         queue.insert(el);
    }

    void collapse() {
        /**
         * EFFECTS: AF = []
         */
        queue.empty();
    }

    ~this() {
        writeln("CollapsingQueue destructor called");
    }
}

alias FunctionList = Function[int];

struct IdentifierMap {
    /**
     *
     */

    /*
     * REP INVARIANT: indices.size == names.size,
     *                indices[names[i]] == i for all i in names.keys
     */
    private int[string] indices;
    private IdentifierType[int] types; 
    private string[int] names;
    private int maxIndex = 1;
    /*
     * AF(indices, name) = [(key, value) for each key, value in indices]
     */
    ~this() {
        writeln("IdentifierMap destructor called");
    }

    invariant {
        

    }
    

    auto byIndex() {
        return names.keys.sort;
    }

    string atIndex(int i) {
        /**
         * REQUIRES: i is a valid key in names
         * EFFECTS: Gets the identifier name at the index i
         */
         return names[i];
    }

    int indexOf(string name) {
        /**
         * EFFECTS: Gets the index of the identifier.
         */
         return indices[name];
    }

    IdentifierType typeOf(int index) {
        return types[index];
    }

    void addIndex(string name, IdentifierType type, int i = -1) 
    in{
        assert(i >= -1);
    }
    out{
        writeln(names);
        writeln(types);
        writeln(indices);
        assert(indices.length == names.length);
        foreach(string id; indices.byKey()) {
            int idx = indices[id];
            assert(names[idx] == id);
        }
    }
    body{
        /**
         * REQUIRES: neither i nor name exist in indices or names.
         * EFFECTS: adds name with the index i 
         */
        if(i == -1) { i = maxIndex; }
        assert(name !in indices);
        indices[name] = i;
        names[i] = name;
        types[i] = type;
        writeln(maxIndex);
        maxIndex = max(i, maxIndex)+1;
        writeln(maxIndex);
    }

}

class Program {
    /**
     * AF(functions, fp)=A program with functions f where
     *                   the current instruction is made by
     *                   fp.
     */

    FunctionList functions;
    FunctionPointer fp;
    bool term;
    IdentifierMap map;
    this() {
        term = false;
    }
    this(FunctionList fns, IdentifierMap m) {
        functions = fns;
        map = m;
        term = false;
    }

    void loadFromFile(string path) {
        /**
         * Load a program from a qbin file specified by path.
         */
        writeln("Reached");
        QbinFileReader qbin = QbinFileReader(path);
        foreach(Section s; qbin) {
            if(s.instanceof!FunctionSection) {
                auto fn = cast(FunctionSection)s;
                Function f = Function(fn.hvalue, Array!Instruction());
                ubyte[] buf = new ubyte[INSTRUCTION_LENGTH];
                foreach(Instruction i; fn) {
                    f.instructions.insert(i);
                }
                functions[fn.hvalue] = f;
            }else if(s.instanceof!IdentifierSection) {
                auto id = cast(IdentifierSection)s;
                writefln("Id name: %s\nId Type: %s", id.name, id.type);
                map.addIndex(id.name, id.type);
            }
            writeln("Lala");
        }
    }

    void save(string path) {
        /**
         * Stores the program in a qbin file at the specified path.
         */
        BitOutputStream bos = BitOutputStream(path);
        //Write signature
        bos.writeNumber(0x10545e38, 32);
        // Write the identifiers
        foreach(int i; map.byIndex()) {
            string id = map.atIndex(i);
            bos.writeNumber(0x1, 2); // Section ID
            bos.writeNumber(cast(int)map.typeOf(i), 2);
            bos.writeNumber(cast(int)id.length, 12); // Header Value
            bos.writeString(id);
        }

        // Write the functions
        foreach(Function f; functions.byValue()) {
            bos.writeNumber(0x0, 2);
            bos.writeNumber(f.index, 14);
            foreach(Instruction i; f.instructions) {
                bos.writeNumber(cast(int)i.opcode, 4);
                bos.writeNumber(i.qubit, 7);
                bos.writeNumber(i.op1, 7);
                bos.writeNumber(i.op2, 7);
                bos.writeNumber(i.number, 7);
                bos.writeNumber(i.lineNumber, 16);
            }
            bos.writeNumber(0, 32);
            bos.writeNumber(0, 16);
        }
        bos.flush();
    }

    Instruction front() {
        return fp.current.instructions[fp.instruction];
    }

    void popFront() {
        /**
         * Move to the next instruction in the function.
         */
        if(!endOfFunction) {
            fp.instruction += 1;
        }
    }

    bool endOfFunction() {
        return fp.current.instructions.length < fp.instruction-1;
    }

    bool empty() {
        /**
         * Returns whether the program has terminated.
         */
        return term;
    }

    void terminate() {
        /**
         * Marks the program as terminated
         */
         term = true;
    }

    void switchFunction(int index) {
        /**
         * Switches the current function to the one marked
         * at index.
         */
         fp.current = functions[index];
         fp.instruction = 0;
    }

   unittest {
        // loadFromFile tests
        writeln("loadFromFile tests");
        string path = "/tmp/programtest";
        ubyte c(char c) {
            return cast(ubyte)c;
        }

        ubyte[] validFile = [0x10, 0x54, 0x5e, 0x38
                            ,0x40, 0x01, c('A') // Qubit A
                            ,0x50, 0x02, c('F'), c('n') // Function fn
                            ,0x60, 0x01, c('C')// Classical variable C
                            ,0x00, 0x02 // Function header
                            ,0x10, 0x20, 0x00, 0x00, 0x00, 0x02 // Qubit A:2
                            ,0x10, 0x60, 0x00, 0x00, 0x00, 0x03 // var C:2
                            ,0x00, 0x00, 0x00, 0x00, 0x00, 0x00];
        File f = File(path, "w");
        f.rawWrite(validFile);
        f.flush();
        f.close();

        Program p = new Program();
        p.loadFromFile(path);
        assert(p.functions.length == 1);
        assert(p.map.atIndex(1) == "A");
        assert(p.map.typeOf(1) == IdentifierType.QUBIT);
        assert(p.map.atIndex(2) == "Fn");
        assert(p.map.typeOf(2) == IdentifierType.FUNCTION);
        assert(p.map.atIndex(3) == "C");
        assert(p.map.typeOf(3) == IdentifierType.CLASSICAL);
        
        assert(p.functions.length == 1);
        auto fn = p.functions[2];
        assert(fn.index == 2);
        assert(fn.instructions.length == 2);
        auto ins = fn.instructions[0];
        writeln(ins);
        assert(ins.opcode == Opcode.QUBIT);
        assert(ins.qubit == 1);
        assert(ins.op1 == 0);
        assert(ins.op2 == 0);
        assert(ins.number == 0);
        assert(ins.lineNumber == 2);
        
        ins = fn.instructions[1];
        assert(ins.opcode == Opcode.QUBIT);
        assert(ins.qubit == 3);
        assert(ins.op1 == 0);
        assert(ins.op2 == 0);
        assert(ins.number == 0);
        assert(ins.lineNumber == 3);

        writeln("Save test");
        string savePath = "/tmp/savetest";
        p.save(savePath);
        ubyte[] buf = new ubyte[validFile.length];
        f = File(savePath, "r");
        f.rawRead(buf);
        writeBuf(buf, buf.length);
        assert(buf.length == validFile.length);
        for(int i = 0; i < buf.length; i++) {
            write(buf[i]);
            write("  ");
            writeln(validFile[i]);
            assert(buf[i] == validFile[i]);
        }
        
    } 
}
