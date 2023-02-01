import std.stdio;
import std.file;
import core.stdc.stdlib;

import dlox.scanner;
import dlox.token;
import dlox.error;

void main(string[] args)
{
	if (args.length > 2)
	{
		writeln("Usage: dlox [script]");
		exit(64);
	}
	else if (args.length == 2)
	{
		runFile(args[1]);
	}
	else
	{
		runPrompt();
	}
}

void runFile(string path)
{
	run(readText(path));

	if (hadError) exit(65);
}

void runPrompt()
{
	while (true)
	{
		write("> ");
		string line = readln();

		if (line == null) break;

		run(line);
		hadError = false;
	}
}

void run(string source)
{
	Scanner scanner = new Scanner(source);
	Token[] tokens = scanner.scanTokens();

	foreach (Token token; tokens)
	{
		writeln(token);
	}
}
