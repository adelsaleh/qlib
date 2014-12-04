module collections;

import std.container.array;
import std.regex;
import std.conv;

import instruction;
import asm_tokens;

class Cabinet(T) {
    /**
     * A cabinet is a queue which is cleared once N elements
     * are dequeued.
     */
    
    private Array!T queue;

    public this() {
        /**
         * Initialize an empty cabinet.
         */
        queue = new Array!T();
    }

    public ~this() {
        delete queue;
    }

    public T[] dequeue(int N) {
        /**
         * Dequeue N elements, clear the queue and return the
         * elements.
         *
         * REQUIRES:
         *    0 < N < queue.length
         * RETURNS:
         *    An array containing the first N elements of the queue.
         */
         int[] ret = new int[N];
         ret[0..N] = queue[0..N];
         queue.clear();
         return ret;
    }

    public void enqueue(T el) {
        /**
         * Adds el to the queue.
         */
         queue ~= el;
    }
}

class Environment {
    /**
     * Container that maintains a two way mapping between
     * the identifier and the index.
     */

     private string[] identifiers;
     private int[string] indices;
     /*
      * AF(identifiers, indices) = {(identifiers[index], index)
      *                              for all 0 <= index < identifiers.length}
      * REP INVARIANT: indices[identifiers[index]] == index
      */

     
     public this() {}

     public string idByIndex(int index) {
        /**
         * EFFECTS: Gets AF[i][0] where AF[i][1] == index
         */
        return identifiers[index];
     }

     public int indexById(string id) {
        /**
         * EFFECTS: Gets AF[i][1] where AF[i][0] == id if exists, else
         *          AF_Post = AF + [(id, AF.length-1
         */
        if(!(id in indices)) {
            addId(id);
        }
        return indices[id];
     }

     private void addId(string id) {
        /**
         * EFFECTS: Adds (id, sizeof(AF)) to index where sizeof(AF) is the
         *          number of elements in AF before the new element is added.
         */
         identifiers ~= id;
         indices[id] = cast(int)identifiers.length-1;
     }
}

alias Function = Array!Instruction;
alias FunctionList = Array!Function;

bool is_whitespace(char c) {
    return c == ' ' || c == '\t' || c == '\r' || c == '\n';
}

class Program {
    /**
     * Represents a quantum program.
     */
    FunctionList fnList;
    Environment* env;
    this() {
        *env = new Environment;
    }

    ~this() {
        delete env;
    }

    Instruction getInstruction(string instruction, int lineNumber=0) {
        /**
         * Get an instruction representation based on the environment
         * of the current program.
         */
        int c = ' ';
        int i = 0;
        auto matcher = regex(r"\s*(?P<opcode>\w+)(\s+)?(?P<arg1>(\w+))?(\s+)?(?P<arg2>(\w+))?(\s+)?(?P<arg3>(\w+))?");
        auto matches = match(instruction, matcher).captures;
        string opcode = matches["opcode"];
        string[] args = [matches["arg1"], matches["arg2"], matches["arg3"]];
        Instruction ins = Instruction(Opcode.NULL, 0, 0, 0, 0, lineNumber);
        ins.opcode = to_opcode(opcode);
        auto argTypes = argLocations[ins.opcode];

        foreach(int idx, string arg; args) {
            int iarg = env.indexById(arg);
            switch(argTypes[idx]) {
                case(InstructionArgType.QUBIT):
                    ins.qubit = iarg;
                    break;

                case (InstructionArgType.OP1):
                    ins.op1 = iarg;
                    break;

                case (InstructionArgType.OP2):
                    ins.op2 = iarg;
                    break;

                case (InstructionArgType.NUMBER):
                    ins.number = iarg;
                    break;

                default:
                    break;
            }
        }

        return ins;
    }

    string instructionToString(Instruction ins) {
        /**
         * Converts an instance of instruction to
         * a valid string.
         */
        string ins_string = "";
        auto argTypes = argLocations[ins.opcode];
        ins_string ~= to_instruction(ins.opcode);
        ins_string ~= " ";
        foreach(int i, InstructionArgType at; argTypes) {
            if (at != InstructionArgType.NONE){
                ins_string ~= " " ~ to!string(select_field_by_type(ins, at));
            }
        }
        return ins_string;
    }
}
