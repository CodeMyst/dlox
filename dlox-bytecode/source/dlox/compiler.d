module dlox.compiler;

import core.stdc.stdio;

import dlox.scanner;

void compile(const char* source)
{
    Scanner scanner = Scanner(source);

    int line = -1;
    while (true)
    {
        Token token = scanner.scanToken();
        if (token.line != line)
        {
            printf("%4d ", token.line);
            line = token.line;
        }
        else
        {
            printf("   | ");
        }

        printf("%2d '%.*s'\n", token.type, token.length, token.start);

        if (token.type == TokenType.EOF) break;
    }
}
