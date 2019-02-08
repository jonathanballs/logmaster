module logmaster.signals;
import std.stdio;

template Signal(T...) {

    alias slot_t = void delegate(T);

    class Signal {
        private slot_t[] slots;

        void emit(T...)(T t) {
            foreach(f; this.slots) {
                f(t);
            }
        }

        void connect(slot_t slot) {
            slots ~= slot;
        }
    }
}

int main () {
    void handler(int i, string s) {
        writeln("I am a handler!!!");
    }

    auto s = new Signal!(int, string);
    s.connect(&handler);
    s.emit(0x3, "string");

    return 0;
}