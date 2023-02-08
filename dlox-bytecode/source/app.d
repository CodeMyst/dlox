import dlox.common;

import std.typecons;

extern(C)
int main(int argc, const char** argv)
{
	Chunk chunk;

	chunk ~= tuple(OpCode.CONSTANT, 123);
	chunk ~= tuple(chunk.addConstant(1.2), 123);
	chunk ~= tuple(OpCode.RETURN, 123);

	chunk ~= tuple(OpCode.CONSTANT, 124);
	chunk ~= tuple(chunk.addConstant(6.9), 124);
	chunk ~= tuple(OpCode.RETURN, 124);
	chunk ~= tuple(OpCode.RETURN, 125);

	chunk.disassemble("test chunk");

	chunk.free();

	return 0;
}
