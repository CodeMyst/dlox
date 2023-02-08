module dlox.interpreter.instance;

import std.variant;

import dlox.interpreter;
import dlox.scanner;
import dlox.error;

class Instance
{
    private Variant[string] fields;

    private Class klass;

    public this(Class klass)
    {
        this.klass = klass;
    }

    public Variant get(Token name)
    {
        if (name.lexeme in fields) return fields[name.lexeme];

        Fun method = klass.findMethod(name.lexeme);
        if (method !is null) return Variant(method.bind(this));

        throw new RuntimeError(name, "Undefined property '" ~ name.lexeme ~ "'.");
    }

    public void set(Token name, Variant value)
    {
        fields[name.lexeme] = value;
    }

    public override string toString() const => klass.name ~ " instance";
}
