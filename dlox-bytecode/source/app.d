import std.typecons;

import dlox.common;
import dlox.vm;

extern(C)
int main(int argc, const char** argv)
{
	VM vm;
	Chunk chunk;

	chunk ~= tuple(OpCode.CONSTANT, 123);
	chunk ~= tuple(chunk.addConstant(1.2), 123);
	chunk ~= tuple(OpCode.CONSTANT, 123);
	chunk ~= tuple(chunk.addConstant(3.4), 123);
	chunk ~= tuple(OpCode.ADD, 123);
	chunk ~= tuple(OpCode.CONSTANT, 123);
	chunk ~= tuple(chunk.addConstant(5.6), 123);
	chunk ~= tuple(OpCode.DIVIDE, 123);
	chunk ~= tuple(OpCode.NEGATE, 123);
	chunk ~= tuple(OpCode.RETURN, 123);

	chunk.disassemble("test chunk");
	vm.interpret(&chunk);

	vm.free();
	chunk.free();

	return 0;
}
