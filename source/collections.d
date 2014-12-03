module collections;

import std.container.array;
import instruction;

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
         * EFFECTS: Gets AF[i][1] where AF[i][0] == id
         */
        return indices[id];
     }

     public void addId(string id) {
        /**
         * EFFECTS: Adds (id, sizeof(AF)) to index where sizeof(AF) is the
         *          number of elements in AF before the new element is added.
         */
         identifiers ~= id;
         indices[id] = cast(int)identifiers.length-1;
     }
}

alias Function = Array!Instruction;

class Program {
    /**
     * 
     */
}
