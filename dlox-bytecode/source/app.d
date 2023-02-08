import dlox.common;

import std.typecons;

extern(C)
int main(int argc, const char** argv)
{
	Chunk chunk;

	chunk ~= tuple(OpCode.CONSTANT, 123);
	chunk ~= tuple(chunk.addConstant(1.2), 123);
	chunk ~= tuple(OpCode.RETURN, 123);

	chunk.disassemble("test chunk");

	chunk.free();

	return 0;
}
