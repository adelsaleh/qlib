module qlib.collections;

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
    }

    void enqueue(T el) {
        /**
         * EFFECTS: AF_post = AF + [el]
         */
    }

    void collapse() {
        /**
         * EFFECTS: AF = []
         */
    }

}

alias FunctionList = Function[int];

class IdentifierMap {
    /**
     *
     */
    private int[string] indices;
    private string[int] names;
    private int maxIndex;
    /*
     * AF(indices, name) = [(key, value) for each key, value in indices]
     */

    invariant {
        /*
         * REP INVARIANT: indices.size == names.size,
         *                indices[names[i]] == i for all i in names.keys
         */

    }
    this() {
        maxIndex = 0;
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

    void addIndex(string name, int i = -1) {
        /**
         * REQUIRES: neither i nor name exist in indices or names.
         * EFFECTS: adds name with the index i 
         */
        if(i == -1) { i = maxIndex; }
        indices[name] = i;
        names[i] = name;
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
    this() {
         
    }

    void loadFromFile(string path) {
        /**
         * Load a program from a qbin file specified by path.
         */
    }

    void save(string path) {
        /**
         * Stores the program in a qbin file at the specified path.
         */
    }

    Instruction front() {
        return fp.current.instructions[fp.instruction];
    }

    Instruction popFront() {
        /**
         * Move to the next instruction in the function.
         */
         return Instruction();
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
    }
}
