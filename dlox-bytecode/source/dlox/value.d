module dlox.value;

import std.sumtype;

import dlox.object;

alias Value = SumType!(bool, typeof(null), double, Obj*);

void printValue(Value value)
{
    import core.stdc.stdio : printf;

    value.match!(
        (bool v) => printf(v ? "true" : "false"),
        (typeof(null) v) => printf("nil"),
        (double v) => printf("%g", v),
        (Obj* v) { printObject(value); return 0; } // need to return an `int` since printf does that :)
    );
}

bool isBool(Value value)
{
    return value.match!(
        (bool _) => true,
        (typeof(null) _) => false,
        (double _) => false,
        (Obj* _) => false
    );
}

bool asBool(Value value)
{
    return value.match!(
        (bool b) => b,
        _ => assert(0)
    );
}

bool isNil(Value value)
{
    return value.match!(
        (bool _) => false,
        (typeof(null) _) => true,
        (double _) => false,
        (Obj* _) => false
    );
}

bool isNumber(Value value)
{
    return value.match!(
        (bool _) => false,
        (typeof(null) _) => true,
        (double _) => true,
        (Obj* _) => false
    );
}

double asNumber(Value value)
{
    return value.match!(
        (double b) => b,
        _ => assert(0)
    );
}

bool isObj(Value value)
{
    return value.match!(
        (bool _) => false,
        (typeof(null) _) => false,
        (double _) => true,
        (Obj* _) => true
    );
}

Obj* asObj(Value value)
{
    return value.match!(
        (Obj* b) => b,
        _ => assert(0)
    );
}

bool valuesEqual(Value a, Value b)
{
    return a == b;
}
