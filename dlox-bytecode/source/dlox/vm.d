module dlox.vm;

import core.stdc.stdio;

import dlox.common;
import dlox.value;
import dlox.compiler;

enum STACK_MAX = 256;

enum InterpretResult
{
    OK,
    COMPILE_ERROR,
    RUNTIME_ERROR
}

struct VM
{
    Chunk* chunk;
    ubyte* ip;

    Value[STACK_MAX] stack;
    Value* stackTop;

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
        ip = chunk.data.ptr;

        InterpretResult result = run();

        chunk.free();

        return result;
    }

    void free()
    {

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
            switch (instruction = readByte())
            {
                case OpCode.ADD:      binaryOp!"+"(); break;
                case OpCode.SUBTRACT: binaryOp!"-"(); break;
                case OpCode.MULTIPLY: binaryOp!"*"(); break;
                case OpCode.DIVIDE:   binaryOp!"/"(); break;

                case OpCode.NEGATE: {
                    *(stackTop - 1) = - *(stackTop - 1);
                } break;

                case OpCode.RETURN: {
                    printValue(pop());
                    printf("\n");
                    return InterpretResult.OK;
                }

                case OpCode.CONSTANT: {
                    push(readConstant());
                } break;

                default: assert(0);
            }
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

    pragma(inline):
    private ubyte readByte() => *ip++;

    pragma(inline):
    private Value readConstant() => chunk.constants[readByte()];

    pragma(inline):
    private void binaryOp(string op)()
        if (op == "+" || op == "-" || op == "*" || op == "/")
    {
        Value b = pop();
        Value a = pop();
        mixin("push(a " ~ op ~ " b);");
    }
}
