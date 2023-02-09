import core.stdc.stdio;
import core.stdc.stdlib;

import dlox.common;
import dlox.vm;

extern(C)
int main(int argc, const char** argv)
{
	VM vm;

	if (argc == 1)
	{
		vm.repl();
	}
	else if (argc == 2)
	{
		runFile(&vm, argv[1]);
	}
	else
	{
		fprintf(stderr, "Usage: dlox [path]\n");
		exit(64);
	}

	vm.free();

	return 0;
}

void runFile(VM* vm, const char* path)
{
	char* source = readFile(path);
	InterpretResult result = vm.interpret(source);
	free(source);

	if (result == InterpretResult.COMPILE_ERROR) exit(65);
	if (result == InterpretResult.RUNTIME_ERROR) exit(70);
}

char* readFile(const char* path)
{
	FILE* file = fopen(path, "rb");
	if (file is null)
	{
		fprintf(stderr, "Could not open file \"%s\"/\n", path);
		exit(74);
	}

	fseek(file, 0, SEEK_END);
	size_t fileSize = ftell(file);
	rewind(file);

	char* buffer = cast(char*) malloc(fileSize + 1);
	if (buffer is null)
	{
		fprintf(stderr, "Not enough memory to read \"%s\".\n", path);
		exit(74);
	}

	size_t bytesRead = fread(buffer, char.sizeof, fileSize, file);
	if (bytesRead < fileSize)
	{
		fprintf(stderr, "Could not read file \"%s\".\n", path);
		exit(74);
	}

	buffer[bytesRead] = '\0';

	fclose(file);
	return buffer;
}
