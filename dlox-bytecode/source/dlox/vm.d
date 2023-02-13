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
            InterpretResult res;
            switch (instruction = readByte())
            {
                case OpCode.ADD:      res = binaryOp!"+"(); break;
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

                case OpCode.RETURN: {
                    printValue(pop());
                    printf("\n");
                    return InterpretResult.OK;
                }

                case OpCode.CONSTANT: {
                    push(readConstant());
                } break;

                case OpCode.NIL: push(Value(null)); break;
                case OpCode.TRUE: push(Value(true)); break;
                case OpCode.FALSE: push(Value(false)); break;

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

    private void runtimeError(T...)(const char* format, T args)
    {
        fprintf(stderr, format, args);
        fputs("\n", stderr);

        size_t instruction = ip - chunk.data.ptr - 1;
        int line = chunk.getLine(instruction);
        fprintf(stderr, "[line %d] in script\n", line);

        stackTop = stack.ptr;
    }

    pragma(inline):
    private ubyte readByte() => *ip++;

    pragma(inline):
    private Value readConstant() => chunk.constants[readByte()];

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
