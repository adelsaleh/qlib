module qlib.collections;
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

}

alias FunctionList = Function[int];

struct IdentifierMap {
    /**
     *
     */
    private int[string] indices;
    private IdentifierType[int] types; 
    private string[int] names;
    private int maxIndex = 0;
    /*
     * AF(indices, name) = [(key, value) for each key, value in indices]
     */
    invariant {
        /*
         * REP INVARIANT: indices.size == names.size,
         *                indices[names[i]] == i for all i in names.keys
         */
        assert(indices.length == names.length);
        foreach(string id; indices.byKey()) {
            int i = indices[id];
            assert(names[i] == id);
        }

    }
    

    auto byIndex() {
        return indices.byValue();
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

    void addIndex(string name, IdentifierType type, int i = -1) {
        /**
         * REQUIRES: neither i nor name exist in indices or names.
         * EFFECTS: adds name with the index i 
         */
        if(i == -1) { i = maxIndex; }
        indices[name] = i;
        names[i] = name;
        types[i] = type;
        maxIndex = max(i, maxIndex)+1;
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
         
    }

    void loadFromFile(string path) {
        /**
         * Load a program from a qbin file specified by path.
         */
        QbinFile qbin = new QbinFile(path);
        foreach(Section s; qbin) {
            if(s.instanceof!FunctionSection) {
                auto fn = cast(FunctionSection)s;
                Function f = Function(fn.hvalue, Array!Instruction());
                ubyte[] buf = new ubyte[INSTRUCTION_LENGTH];
                while(!fn.eof()) {
                    fn.nextInstruction(buf);
                    auto i = toInstruction(buf);
                    f.instructions.insert(i);
                }
                functions[fn.hvalue] = f;
            }else if(s.instanceof!IdentifierSection) {
                auto id = cast(IdentifierSection)s;
                map.addIndex(id.name, id.type);
            }
        }
    }

    void save(string path) {
        /**
         * Stores the program in a qbin file at the specified path.
         */
        BitOutputStream bos = BitOutputStream(path);
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
                bos.writeNumber(i.number, 8);
                bos.writeNumber(i.lineNumber, 16);
            }
            bos.writeNumber(0, 32);
            bos.writeNumber(0, 16);
        }
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
}
