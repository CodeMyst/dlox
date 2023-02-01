module dlox.error;

import std.stdio;

bool hadError = false;

void error(int line, string message)
{
	report(line, "", message);
}

void report(int line, string where, string message)
{
    import std.conv : to;

	writeln("[line " ~ line.to!string() ~ "] Error" ~ where ~ ": " ~ message);
	hadError = true;
}
