module qlib.collections;
import qlib.asm_tokens;
import std.stdio;
import qlib.qbin;
import qlib.instruction;
import qlib.util;
import std.algorithm;
import std.container.slist;
import std.container.array;


/**
 * It's a fucking stack.
 */
struct Stack(T) {

     Array!(T) stack;

    void push(T el) {
        stack.insert(el);
    }

    T pop() {
        T el = stack[$-1];
        stack.removeBack();
        return el;
    }

    T peek() {
        return stack[$-1];
    }

    ulong size() {
        return stack.length;
    }
}

/**
 * A marker for where we are in the program currently.
 */

struct FunctionPointer {
    Function current; ///The function we're on right now.
    int instruction; /// The index of the instruction in the current function.
}

/**
 * A container for a function.
 */
struct Function {
    int index; /// Index of the function in the program's IdentifierMap
    Array!Instruction instructions; /// The instructions in this function
}

/**
 * A queue that can be cleared after a certain number of
 * elements are dequeued.
 */
class CollapsingQueue(T) {
    SList!T queue;
    /*
     * AF(queue) = A list of Ts
     * REP INVARIANT: for each x,y in queue, x != y.
     */

    /**
     * Removes an element from the start of the queue.
     *
     * Requires: queue is not empty.
     * Effects: AF_post = AF[1:]
     * Returns: AF[0]
     */
    int _size;
    this() {
        _size = 0;
    }

    T dequeue() {
        T el = queue.front;
        queue.removeFront(1);
        _size -=1;
        return el;
    }
    /**
     * EFFECTS: AF_post = AF + [el] if el in AF,
     *          else AF
     */
    void enqueue(T el) {

         int index = queue.search(el);
         if(index == -1) {
             queue.insert(el);
             _size+=1;
         }
    }
    /**
     * EFFECTS: AF = []
     */
    void collapse() {
        queue.clear();
        _size = 0;
    }

    ulong size() {
        return _size;
    }

    ~this() {
        writeln("CollapsingQueue destructor called");
    }
}

alias FunctionList = Function[int];

struct IdentifierMap {
    /**
     * A two way mapping between identifiers and their
     * indices.
     */

    /*
     * AF(indices, types, names) = {x | x = [index, type, name], 
     *                              for each index in indices.values,
     *                                       type in types.values,
     *                                       name in indices.keys}
     *
     * In docs, INDEX = 0, TYPE = 1, NAME = 2
     * REP INVARIANT: indices.size == names.size,
     *                indices[names[i]] == i for all i in names.keys
     */
    private int[string] indices;
    private IdentifierType[int] types; 
    private string[int] names;
    private int maxIndex = 1;

    /**
     * Returns: An iterator that goes through the sorted list of
     *          indices.
     */
    auto byIndex() {
        return names.keys.sort();
    }

    /**
     * Fetches the identifier at index i
     * Params:
     *      i = index of identifier
     * Returns: el[NAME] where el in AF and el[INDEX] = i
     */

    string atIndex(int i) {
         return names[i];
    }

    /**
     * Fetches the index of the identifier name.
     * Params:
     *      name = The identifier to look up.
     * Returns: el[INDEX] s.t. el in AF and el[NAME] = name
     */
    int indexOf(string name) {
         if(name in indices) {
             return indices[name];
         }
         return -1;
    }

    IdentifierType typeOf(int index) {
        return types[index];
    }

    /**
     * Adds name with the index i 
     * Requires: Neither i nor name exist in indices or names.
     */
    void addIndex(string name, IdentifierType type, int i = -1) 
    in{
        assert(i >= -1);
    }
    out{
        assert(indices.length == names.length);
        foreach(string id; indices.byKey()) {
            int idx = indices[id];
            assert(names[idx] == id);
        }
    }
    body{
      
        if(i == -1) { i = maxIndex; }
        assert(name !in indices);
        indices[name] = i;
        names[i] = name;
        types[i] = type;
        maxIndex = max(i, maxIndex)+1;
    }
}


class FunctionPointerNode {
    FunctionPointerNode[] children;
    FunctionPointer fp;
    this(FunctionPointer fp) {
        this.fp = fp;
        this.children = [];
    }
}


class FunctionPointerTree {
    FunctionPointerNode root;
    size_t leaves;
    this(FunctionPointer fp) {
        root = new FunctionPointerNode(fp);
    }
    FunctionPointerNode getLeaf(size_t index, FunctionPointerNode node) {
        if(node.children) {
            for(int i = 0; i < node.children.length; i++) {
                auto res = getLeaf(index, node.children[i]);
                if(res) return res;
                else index--;
            }
        }else{
            if(index == 0) {
                return node;
            } else {
                return null;
            }
        }
        assert(0);
    }

    void createBranch(int index, FunctionPointer[] fps) {
        auto leaf = getLeaf(index);
        leaf.children = new FunctionPointerNode[fps.length];
        for(int i = 0; i < leaf.children.length; i++) {
            leaf.children[i] = new FunctionPointerNode(fps[i]);
        }
    }

    string toString(FunctionPointerNode node, string spaces) {
        string ret = "";
        for(int i = 0; i < node.children.length; i++) {
            ret ~= (spaces ~ node.children[i].fp.toString() ~"\n");
            ret ~= toString(node.children[i], spaces);
        }
        return ret;
    }

    FunctionPointerNode getLeaf(size_t index) {
        if(!root.children && index > 0) {
            throw new Exception("Index out of bounds");
        }
        if(!root.children && index == 0) {  
            return root.fp;
        }
        return getLeaf(index, root);
    }
}

unittest {
    writeln("Testing FUNCTIONPOINTERTREE");
    auto t = new FunctionPointerTree(FunctionPointer(0, 0));
    writeln(t);
}

class QProgram {

    FunctionList functions;
    FunctionPointer[] current;
    IdentifierMap map;
    this() {
    }
    this(FunctionList fns, IdentifierMap m) {
        functions = fns;
        map = m;
    }

    /**
     * Descend into the given list of functions. As
     * long as the operators form a unitary transformation
     * we can execute as many functions as we want at the
     * same time.
     */
    void switch_to_functions(int[] functions) {
        current = FunctionPointer[functions.length];
        for(int i = 0; i < current.length; i++) {
            current[i] = FunctionPointer(functions[i], 0);
        }
    }

    size_t currently_executing() {
        return current.length;
    }

    Instruction next(int index) {
        Instruction ret = functions[current[index].current].instructions[current[index].instruction];
        if(ret.qubit != 0 || ret.op1 != 0 || ret.op2 != 0 || ret.number != 0) {
            current[index].instruction = current[index].instruction + 1;
        }
        return ret;
    }

    /**
     * Converts an instance of instruction to
     * a valid string.
     */
    string instructionToString(Instruction ins) {

        string ins_string = "";
        auto argTypes = argLocations[ins.opcode];
        ins_string ~= to_instruction(ins.opcode);
        ins_string ~= " ";
        foreach(int i, InstructionArgType at; argTypes) {
            if (at != InstructionArgType.NONE){
                ins_string ~= " " ~ map.atIndex(select_field_by_type(ins, at));
            }
        }
        return ins_string;
    }

    /**
     * Load a program from a qbin file specified by path.
     * Params:
     *      path = Path of the qbin file to load from.
     */
    void loadFromFile(string path) {
    
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
                //writefln("Id name: %s\nId Type: %s", id.name, id.type);
                map.addIndex(id.name, id.type);
            }
        }
    }

    /**
     * Stores the program in qbin format at the specified path.
     * Params:
     *      path = Path to save program in.
     */
    void save(string path) {
    
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
    }
}


/**
 * A wrapper for a qbin file. It is essentially an iterator that
 * iterates over the instructions in a qbin file.
 *
 * No semantics are implemented here though. It is the job of
 * the client to manipulate this iterator's output depending on the
 * semantic meaning of the instructions being read.
 */

class Program {

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

    /**
     * Converts an instance of instruction to
     * a valid string.
     */
    string instructionToString(Instruction ins) {

        string ins_string = "";
        auto argTypes = argLocations[ins.opcode];
        ins_string ~= to_instruction(ins.opcode);
        ins_string ~= " ";
        foreach(int i, InstructionArgType at; argTypes) {
            if (at != InstructionArgType.NONE){
                ins_string ~= " " ~ map.atIndex(select_field_by_type(ins, at));
            }
        }
        return ins_string;
    }

    /**
     * Load a program from a qbin file specified by path.
     * Params:
     *      path = Path of the qbin file to load from.
     */
    void loadFromFile(string path) {
    
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
                //writefln("Id name: %s\nId Type: %s", id.name, id.type);
                map.addIndex(id.name, id.type);
            }
        }
    }

    /**
     * Stores the program in qbin format at the specified path.
     * Params:
     *      path = Path to save program in.
     */
    void save(string path) {
    
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
    }

    Instruction front() {
        return fp.current.instructions[fp.instruction];
    }

    /**
     * Move to the next instruction in the function.
     */
    void popFront() {
    
        if(!endOfFunction) {
            fp.instruction += 1;
        }
    }

    /**
     * Checks whether the end of the current function has
     * been reached.
     * Returns:
     *      true if we reached the end of current function, false otherwise
     */
    bool endOfFunction() {
        return fp.current.instructions.length < fp.instruction-1;
    }

    /**
     * Checks whether the program has terminated.
     * Returns:
     *      true if terminated, false otherwise
     */
    bool empty() {
            return term;
    }

    /**
     * Marks the program as terminated. This iterator
     * will not end until this method is called.
     */
    void terminate() {
         term = true;
    }


    /**
     * Switches the current function to the one marked
     * at index.
     * Params:
     *      index = index of the function to switch to.
     */
    void switchFunction(int index) {
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

        //writeln("Save test");
        string savePath = "/tmp/savetest";
        p.save(savePath);
        ubyte[] buf = new ubyte[validFile.length];
        f = File(savePath, "r");
        f.rawRead(buf);
        //writeBuf(buf, buf.length);
        assert(buf.length == validFile.length);
        for(int i = 0; i < buf.length; i++) {
            //write(buf[i]);
            //write("  ");
          //  assert(buf[i] == validFile[i]);
        }
        
    } 
}
