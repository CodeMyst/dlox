module dlox.parser.generator;

import std.typecons;
import std.array;
import std.string;
import std.variant;

import dlox.scanner;

const string[] expressionTypes = [
    "Assign   : Token name, Expr value",
    "Binary   : Expr left, Token operator, Expr right",
    "Call     : Expr callee, Token paren, Expr[] arguments",
    "Get      : Expr object, Token name",
    "Grouping : Expr expression",
    "Literal  : Variant value",
    "Logical  : Expr left, Token operator, Expr right",
    "Set      : Expr object, Token name, Expr value",
    "Super    : Token keyword, Token method",
    "This     : Token keyword",
    "Unary    : Token operator, Expr right",
    "Variable : Token name"
];

const string[] statementTypes = [
    "Block      : Stmt[] statements",
    "Class      : Token name, Expr.Variable superclass, Stmt.Function[] methods",
    "Expression : Expr expression",
    "Function   : Token name, Token[] params, Stmt[] body",
    "If         : Expr condition, Stmt thenBranch, Stmt elseBranch",
    "Print      : Expr expression",
    "Return     : Token keyword, Expr value",
    "Var        : Token name, Expr initializer",
    "While      : Expr condition, Stmt body",
    "Break      : "
];

string GenerateAst(string BaseName, string[] types)()
{
    string res = "abstract class " ~ BaseName ~ "{";

    res ~= "interface Visitor {";

    foreach (type; types)
    {
        string typeName = type.split(":")[0].strip();
        res ~= "Variant visit" ~ typeName ~ BaseName ~ "(" ~ typeName ~ " " ~ BaseName.toLower() ~ ");";
    }

    res ~= "}";

    res ~= "public abstract Variant accept(Visitor visitor);";

    foreach (type; types)
    {
        string className = type.split(":")[0].strip();
        string fields = type.split(":")[1].strip();

        res ~= "static class " ~ className ~ ":" ~ BaseName ~ "{";
        res ~= "public this(" ~ fields ~ ") {";

        string[] fieldsArr = fields.split(", ");
        foreach (field; fieldsArr)
        {
            string fieldName = field.split(" ")[1];
            res ~= "this." ~ fieldName ~ " = " ~ fieldName ~ ";";
        }

        res ~= "}";

        res ~= "public override Variant accept(Visitor visitor) {";
        res ~= "return visitor.visit" ~ className ~ BaseName ~ "(this);";
        res ~= "}";

        foreach (field; fieldsArr)
        {
            res ~= "public " ~ field ~ ";";
        }

        res ~= "}";
    }

    res ~= "}";

    return res;
}

mixin(GenerateAst!("Expr", expressionTypes));
mixin(GenerateAst!("Stmt", statementTypes));
