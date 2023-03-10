module dlox.vm;

import core.stdc.stdio;
import core.stdc.string;

import dlox.common;
import dlox.value;
import dlox.compiler;
import dlox.object;
import dlox.memory;
import dlox.table;

enum STACK_MAX = 256;

enum InterpretResult
{
    OK,
    COMPILE_ERROR,
    RUNTIME_ERROR
}

VM vm;

struct VM
{
    Chunk* chunk;
    ubyte* ip;

    Value[STACK_MAX] stack;
    Value* stackTop;
    Table globals;
    Table strings;
    Obj* objects = null;

    InterpretResult interpret(const char* source)
    {
        stackTop = stack.ptr;

        Chunk c;

        if (!compile(source, &c))
        {
            c.free();
            return InterpretResult.COMPILE_ERROR;
        }

        this.chunk = &c;
        ip = chunk.data;

        InterpretResult result = run();

        chunk.free();

        return result;
    }

    void free()
    {
        globals.free();
        strings.free();
        freeObjects();
    }

    void repl()
    {
        char[1024] line;
        while (true)
        {
            printf("> ");

            if (!fgets(line.ptr, line.sizeof, stdin))
            {
                printf("\n");
                break;
            }

            interpret(line.ptr);
        }
    }

    private InterpretResult run()
    {
        while (true)
        {
            debug(traceExecution)
            {
                printf("          ");
                for (Value* slot = stack.ptr; slot < stackTop; slot++)
                {
                    printf("[ ");
                    printValue(*slot);
                    printf(" ]");
                }
                printf("\n");
                chunk.dissassembleInstruction(cast(int) (ip - chunk.data.ptr));
            }

            ubyte instruction;
            InterpretResult res;
            switch (instruction = readByte())
            {
                case OpCode.ADD: {
                    // TODO: Adding numbers and strings
                    if (isString(peek(0)) && isString(peek(1)))
                    {
                        concatenate();
                    }
                    else if (isNumber(peek(0)) && isNumber(peek(1)))
                    {
                        double b = asNumber(pop());
                        double a = asNumber(pop());
                        push(Value(a + b));
                    }
                    else
                    {
                        runtimeError("Operands must be two numbers or two strings.");
                        return InterpretResult.RUNTIME_ERROR;
                    }
                } break;

                case OpCode.SUBTRACT: res = binaryOp!"-"(); break;
                case OpCode.MULTIPLY: res = binaryOp!"*"(); break;
                case OpCode.DIVIDE:   res = binaryOp!"/"(); break;
                case OpCode.GREATER:  res = binaryOp!">"(); break;
                case OpCode.LESS:     res = binaryOp!"<"(); break;

                case OpCode.NOT: {
                    push(Value(isFalsey(pop())));
                } break;

                case OpCode.NEGATE: {
                    if (!isNumber(peek(0)))
                    {
                        runtimeError("Operand must be a number.");
                        return InterpretResult.RUNTIME_ERROR;
                    }

                    push(Value(-asNumber(pop())));
                } break;

                case OpCode.PRINT: {
                    printValue(pop());
                    printf("\n");
                } break;

                case OpCode.RETURN: {
                    return InterpretResult.OK;
                }

                case OpCode.CONSTANT: {
                    push(readConstant());
                } break;

                case OpCode.NIL: push(Value(null)); break;
                case OpCode.TRUE: push(Value(true)); break;
                case OpCode.FALSE: push(Value(false)); break;
                case OpCode.POP: pop(); break;

                case OpCode.GET_LOCAL: {
                    ubyte slot = readByte();
                    push(vm.stack[slot]);
                } break;

                case OpCode.SET_LOCAL: {
                    ubyte slot = readByte();
                    vm.stack[slot] = peek(0);
                } break;

                case OpCode.GET_GLOBAL: {
                    ObjString* name = readString();
                    Value value;
                    if (!vm.globals.get(name, &value))
                    {
                        runtimeError("Undefined variable '%s'.", name.chars);
                        return InterpretResult.RUNTIME_ERROR;
                    }
                    push(value);
                } break;

                case OpCode.DEFINE_GLOBAL: {
                    ObjString* name = readString();
                    vm.globals.set(name, peek(0));
                    pop();
                } break;

                case OpCode.SET_GLOBAL: {
                    ObjString* name = readString();
                    if (vm.globals.set(name, peek(0)))
                    {
                        vm.globals.remove(name);
                        runtimeError("Undefined variable '%s'.", name.chars);
                        return InterpretResult.RUNTIME_ERROR;
                    }
                } break;

                case OpCode.EQUAL: {
                    Value b = pop();
                    Value a = pop();
                    push(Value(valuesEqual(a, b)));
                } break;

                default: assert(0);
            }

            if (res == InterpretResult.COMPILE_ERROR || res == InterpretResult.RUNTIME_ERROR) return res;
        }
    }

    private void push(Value value)
    {
        *stackTop = value;
        stackTop++;
    }

    private Value pop()
    {
        stackTop--;
        return *stackTop;
    }

    private Value peek(int distance)
    {
        return stackTop[-1 - distance];
    }

    private bool isFalsey(Value value)
    {
        return isNil(value) || (isBool(value) && !asBool(value));
    }

    private void concatenate()
    {
        ObjString* b = asString(pop());
        ObjString* a = asString(pop());

        int length = a.length + b.length;
        char* chars = allocate!char(length + 1);
        memcpy(chars, a.chars, a.length);
        memcpy(chars + a.length, b.chars, b.length);
        chars[length] = '\0';

        ObjString* res = takeString(chars, length);
        push(Value(cast(Obj*) res));
    }

    private void runtimeError(T...)(const char* format, T args)
    {
        fprintf(stderr, format, args);
        fputs("\n", stderr);

        size_t instruction = ip - chunk.data - 1;
        int line = chunk.getLine(instruction);
        fprintf(stderr, "[line %d] in script\n", line);

        stackTop = stack.ptr;
    }

    pragma(inline):
    private ubyte readByte() => *ip++;

    pragma(inline):
    private Value readConstant() => chunk.constants[readByte()];

    pragma(inline):
    private ObjString* readString() => asString(readConstant());

    private InterpretResult binaryOp(string op)()
        if (op == "+" || op == "-" || op == "*" || op == "/" || op == ">" || op == "<")
    {
        if (!isNumber(peek(0)) || !isNumber(peek(1)))
        {
            runtimeError("Operands must be numbers.");
            return InterpretResult.RUNTIME_ERROR;
        }

        double b = asNumber(pop());
        double a = asNumber(pop());
        mixin("push(Value(a " ~ op ~ " b));");

        return InterpretResult.OK;
    }
}
