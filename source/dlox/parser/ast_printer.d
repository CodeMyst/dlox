module dlox.parser.ast_printer;

import std.variant;
import std.conv;

import dlox.parser.expression;

class AstPrinter : Expr.Visitor
{
    public string print(Expr expr)
    {
        return expr.accept(this).toString();
    }

    public override Variant visitBinaryExpr(Expr.Binary expr)
    {
        return parenthesize(expr.operator.lexeme, expr.left, expr.right).to!Variant();
    }

    public override Variant visitGroupingExpr(Expr.Grouping expr)
    {
        return parenthesize("group", expr.expression).to!Variant();
    }

    public override Variant visitLiteralExpr(Expr.Literal expr)
    {
        import std.conv : to;

        string literalString = expr.value.toString();

        return literalString == null.stringof ? Variant("nil") : Variant(literalString);
    }

    public override Variant visitUnaryExpr(Expr.Unary expr)
    {
        return parenthesize(expr.operator.lexeme, expr.right).to!Variant();
    }

    private string parenthesize(string name, Expr[] expressions...)
    {
        string res = "(" ~ name;

        foreach (expr; expressions)
        {
            res ~= " " ~ expr.accept(this).get!string();
        }

        res ~= ")";

        return res;
    }
}
