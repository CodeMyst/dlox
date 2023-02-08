module dlox.vm;

import core.stdc.stdio;

import dlox.common;
import dlox.value;

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

    InterpretResult interpret(Chunk* chunk)
    {
        this.chunk = chunk;
        ip = chunk.data.ptr;

        stackTop = stack.ptr;

        return run();
    }

    void free()
    {

    }

    private InterpretResult run()
    {
        while (true)
        {
            debug(trace)
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
