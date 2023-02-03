module dlox.interpreter.fun;

import std.variant;

import dlox.interpreter;
import dlox.parser;

class Fun : Callable
{
    private Stmt.Function declaration;

    public this(Stmt.Function declaration)
    {
        this.declaration = declaration;
    }

    public override Variant call(Interpreter interpreter, Variant[] arguments)
    {
        Environment environment = new Environment(interpreter.globals);
        for (int i = 0; i < declaration.params.length; i++)
        {
            environment.define(declaration.params[i].lexeme, arguments[i]);
        }

        interpreter.executeBlock(declaration.body, environment);
        
        return Variant(null);
    }

    public override int arity() => cast(int) declaration.params.length;

    public override string toString() const => "<fn " ~ declaration.name.lexeme ~ ">";
}
