module dlox.common;

import core.stdc.stdio;
import std.typecons;

import dlox.array;
import dlox.value;

// TODO: maybe define the CONSTANT_LONG instruction (24bit operand)
enum OpCode : ubyte
{
    CONSTANT,
    NIL,
    TRUE,
    FALSE,
    POP,
    GET_LOCAL,
    SET_LOCAL,
    GET_GLOBAL,
    DEFINE_GLOBAL,
    SET_GLOBAL,
    EQUAL,
    GREATER,
    LESS,
    ADD,
    SUBTRACT,
    MULTIPLY,
    DIVIDE,
    NOT,
    NEGATE,
    PRINT,
    RETURN
}

struct Line
{
    int line;
    int length;
}

struct Chunk
{
    Array!ubyte arr;
    alias arr this;

    Array!Value constants;

    Array!Line lines;

    void free()
    {
        arr.free();
        lines.free();
        constants.free();
    }

    ubyte addConstant(Value value)
    {
        constants ~= value;
        return cast(ubyte) (constants.length - 1u);
    }

    auto opOpAssign(string op : "~")(const Tuple!(ubyte, int) rhs)
    {
        arr ~= rhs[0];

        if (lines.length > 0 && lines[$-1].line == rhs[1]) lines[$-1].length++;
        else lines ~= Line(rhs[1], 1);

        return this;
    }

    auto opOpAssign(string op : "~")(const Tuple!(OpCode, int) rhs)
    {
        return this ~= tuple(cast(ubyte) rhs[0], cast(int) rhs[1]);
    }

    void disassemble(const char* name)
    {
        printf("== %s ==\n", name);

        for (int offset = 0; offset < length;)
        {
            offset = dissassembleInstruction(offset);
        }
    }

    int dissassembleInstruction(int offset)
    {
        printf("%04d ", offset);

        if (offset > 0 && getLine(offset) == getLine(offset - 1)) printf("   | ");
        else printf("%4d ", getLine(offset));

        OpCode instruction = cast(OpCode) data[offset];
        switch (instruction)
        {
            case OpCode.ADD:
                return simpleInstruction(OpCode.ADD.stringof, offset);
            case OpCode.SUBTRACT:
                return simpleInstruction(OpCode.SUBTRACT.stringof, offset);
            case OpCode.MULTIPLY:
                return simpleInstruction(OpCode.MULTIPLY.stringof, offset);
            case OpCode.DIVIDE:
                return simpleInstruction(OpCode.DIVIDE.stringof, offset);
            case OpCode.NEGATE:
                return simpleInstruction(OpCode.NEGATE.stringof, offset);
            case OpCode.RETURN:
                return simpleInstruction(OpCode.RETURN.stringof, offset);
            case OpCode.CONSTANT:
                return constantInstruction(OpCode.CONSTANT.stringof, offset);
            case OpCode.NIL:
                return simpleInstruction(OpCode.NIL.stringof, offset);
            case OpCode.TRUE:
                return simpleInstruction(OpCode.TRUE.stringof, offset);
            case OpCode.FALSE:
                return simpleInstruction(OpCode.FALSE.stringof, offset);
            case OpCode.NOT:
                return simpleInstruction(OpCode.NOT.stringof, offset);
            case OpCode.EQUAL:
                return simpleInstruction(OpCode.EQUAL.stringof, offset);
            case OpCode.GREATER:
                return simpleInstruction(OpCode.GREATER.stringof, offset);
            case OpCode.LESS:
                return simpleInstruction(OpCode.LESS.stringof, offset);
            case OpCode.PRINT:
                return simpleInstruction(OpCode.PRINT.stringof, offset);
            case OpCode.POP:
                return simpleInstruction(OpCode.POP.stringof, offset);
            case OpCode.DEFINE_GLOBAL:
                return constantInstruction(OpCode.DEFINE_GLOBAL.stringof, offset);
            case OpCode.GET_GLOBAL:
                return constantInstruction(OpCode.GET_GLOBAL.stringof, offset);
            case OpCode.SET_GLOBAL:
                return constantInstruction(OpCode.SET_GLOBAL.stringof, offset);
            case OpCode.GET_LOCAL:
                return byteInstruction(OpCode.GET_LOCAL.stringof, offset);
            case OpCode.SET_LOCAL:
                return byteInstruction(OpCode.SET_LOCAL.stringof, offset);
            default:
                printf("Unknown opcode %d\n", instruction);
                return offset + 1;
        }
    }

    public int getLine(ulong offset)
    {
        int lineCounter = 0;
        foreach (line; lines)
        {
            if (offset >= lineCounter && offset < lineCounter + line.length) return line.line;

            lineCounter += line.length;
        }

        return -1;
    }

    private int simpleInstruction(const char* name, int offset)
    {
        printf("%s\n", name);
        return offset + 1;
    }

    private int byteInstruction(const char* name, int offset)
    {
        ubyte slot = data[offset + 1];
        printf("%-16s %4d\n", name, slot);
        return offset + 2;
    }

    private int constantInstruction(const char* name, int offset)
    {
        ubyte constant = data[offset + 1];
        printf("%-16s %4d '", name, constant);
        printValue(constants[constant]);
        printf("'\n");
        return offset + 2;
    }
}
