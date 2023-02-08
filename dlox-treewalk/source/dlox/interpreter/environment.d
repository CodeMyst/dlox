module dlox.interpreter.environment;

import std.variant;

import dlox.error;
import dlox.scanner;

class Environment
{
    public Environment enclosing;

    private Variant[string] values;

    public this()
    {
        enclosing = null;
    }

    public this(Environment enclosing)
    {
        this.enclosing = enclosing;
    }

    public void define(string name, Variant value)
    {
        values[name] = value;
    }

    public void assign(Token name, Variant value)
    {
        if (name.lexeme in values) values[name.lexeme] = value;
        else if (enclosing !is null) enclosing.assign(name, value);
        else throw new RuntimeError(name, "Undefined variable '" ~ name.lexeme ~ "'.");
    }

    public void assignAt(int distance, Token name, Variant value)
    {
        ancestor(distance).values[name.lexeme] = value;
    }

    public Variant get(Token name)
    {
        if (name.lexeme in values) return values[name.lexeme];
        if (enclosing !is null) return enclosing.get(name);

        throw new RuntimeError(name, "Undefined variable '" ~ name.lexeme ~ "'.");
    }

    public Variant getAt(int distance, string name)
    {
        return ancestor(distance).values[name];
    }

    private Environment ancestor(int distance)
    {
        Environment environment = this;
        for (int i = 0; i < distance; i++) environment = environment.enclosing;
        return environment;
    }
}
