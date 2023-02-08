module dlox.common;

import core.stdc.stdio;
import std.typecons;

import dlox.array;
import dlox.value;

enum OpCode : ubyte
{
    CONSTANT,
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

    private int dissassembleInstruction(int offset)
    {
        printf("%04d ", offset);

        if (offset > 0 && getLine(offset) == getLine(offset - 1)) printf("   | ");
        else printf("%4d ", getLine(offset));

        OpCode instruction = cast(OpCode) data[offset];
        switch (instruction)
        {
            case OpCode.RETURN:
                return simpleInstruction(OpCode.RETURN.stringof, offset);
            case OpCode.CONSTANT:
                return constantInstruction(OpCode.CONSTANT.stringof, offset);
            default:
                printf("Unknown opcode %d\n", instruction);
                return offset + 1;
        }
    }

    private int getLine(int offset)
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

    private int constantInstruction(const char* name, int offset)
    {
        ubyte constant = data[offset + 1];
        printf("%-16s %4d '", name, constant);
        printValue(constants[constant]);
        printf("'\n");
        return offset + 2;
    }
}
