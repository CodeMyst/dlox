import core.stdc.stdlib;

import std.stdio;
import std.file;
import std.variant;

import dlox.error;
import dlox.scanner;
import dlox.parser;
import dlox.interpreter;

private Interpreter interpreter;

void main(string[] args)
{
    interpreter = new Interpreter();

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
    if (hadRuntimeError) exit(70);
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

    Parser parser = new Parser(tokens);
    Stmt[] statements = parser.parse();

    if (hadError) return;

    interpreter.interpret(statements);
}
