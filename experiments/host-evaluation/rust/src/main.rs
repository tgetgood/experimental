#![allow(dead_code, unused_variables, unused_imports)]

use core::hash::Hash;
use std::collections::BTreeMap;
use std::fmt;
use std::io;
use std::io::Write;
use std::sync::Arc;
use std::clone::Clone;

/// Abstractions at the bottom

trait Substitute {}

trait BetaReduction {}

#[derive(Clone, Debug, PartialEq, Eq, PartialOrd, Ord)]
enum Type {
    Bool,
    Number,
    Keyword,
    String,
    Symbol,
    List,
    Vector,
    Map,
    Set,
    Error
}
       
#[derive(Clone, Debug, PartialEq, Eq, PartialOrd, Ord)]
struct Value<T: Clone> {
    kind: Type,
    val: T
}

fn val<T: Clone>(x: Value<T>) -> T {
    x.val.clone()
}

#[derive(Clone, Debug, PartialEq, PartialOrd, Ord)]
enum Sexp {
    Bool(bool),
    Symbol(String),
    Keyword(String),
    String(String),
    Number(i64),
    List(Vec<Sexp>),
    Map(BTreeMap<Sexp, Sexp>),
    Error(String),
}

impl Eq for Sexp {}

impl fmt::Display for Sexp {
    fn fmt(&self, f: &mut fmt::Formatter) -> fmt::Result {
        let str = match self {
            Sexp::Bool(x) => x.to_string(),
            Sexp::String(x) => format!("\"{}\"", x.to_string()),
            Sexp::Keyword(x) => format!(":{}", x.to_string()),
            Sexp::Number(x) => x.to_string(),
            Sexp::Error(x) => format!("Error(\"{}\")", x),
            Sexp::Symbol(x) => x.to_string(),
            Sexp::Map(x) => String::from("{}"),
            Sexp::List(x) => {
                let xs: Vec<String> = x.iter().map(|x| x.to_string()).collect();
                format!("({})", xs.join(", "))
            }
        };

        write!(f, "{}", str)
    }
}

///// Reader
/// Missing features:
/// * keywords
/// * strings
/// * collections
/// * literals
///
/// I need a char-by-char reader (with backtracking) and a state machine. Why
/// not just copy Clojure's reader? well java is too dissimilar, but that's the
/// idea.

fn split(x: String, delim: String) -> (String, String) {
    (
        x.chars().take_while(|&x| !delim.contains(x)).collect(),
        x.chars().skip_while(|&x| !delim.contains(x)).collect(),
    )
}

fn read_atom(x: String) -> (Sexp, String) {
    let (head, tail) = split(x, "()[]{}, ".to_string());
    let v: Sexp;
    if head == "true".to_string() {
        v = Sexp::Bool(true);
    } else if head == "false".to_string() {
        v = Sexp::Bool(false);
    } else {
        match head.parse::<i64>() {
            Ok(num) => {
                v = Sexp::Number(num);
            }
            _ => {
                v = Sexp::Symbol(head);
            }
        }
    }

    (v, tail.trim().to_string())
}

fn read_seq(chars: String, acc: &mut Vec<Sexp>) -> (Sexp, String) {
    let mut c = chars.chars();
    let f = c.next();
    let rest = c.collect::<String>();
    match f {
        Some(')') => (Sexp::List(acc.clone()), rest),
        Some(']') => (Sexp::Error("Unexpected char in list ']'".to_string()), rest),
        None => (Sexp::Error("Unexpected end of input".to_string()), rest),
        _ => {
            let (n, rest) = read0(chars);
            acc.push(n);
            read_seq(rest, acc)
        }
    }
}

fn read0(code: String) -> (Sexp, String) {
    let mut chars = code.chars();
    let c = chars.next();
    let rest = chars.collect::<String>();

    match c {
        None => (Sexp::Error("unexpected end of input".to_string()), rest),
        Some('(') => read_seq(rest, &mut Vec::new()),
        Some(_) => read_atom(code),
    }
}

fn read(code: String) -> Sexp {
    if code.is_empty() {
        Sexp::Error("no input".to_string())
    } else {
        let (res, _) = read0(code.replace(",", " ").trim().to_string());
        res
    }
}

/// Meta Circular

fn apply(form: Sexp, arg: Sexp) -> Sexp {
    Sexp::Error(String::from("no apply"))
}

fn noop(x: Sexp) -> Sexp {
    Sexp::Error(String::from(""))
}

fn nil() -> Sexp {
    Sexp::Error(String::from("nil"))
}

/// Recursively walks `form` and replaces symbols with their values in
/// `context`. Symbols not in `context` are left unchanged. If `context` is not
/// a map, returns nil (which is presently an Error.
fn substitute(context: Sexp, form: Sexp) -> Sexp {
    match context {
        Sexp::Map(m) => match form {
            Sexp::Bool(_) => form,
            Sexp::Number(_) => form,
            Sexp::Keyword(_) => form,
            Sexp::String(_) => form,
            Sexp::Error(_) => form,
            Sexp::Symbol(_) => {
                if m.contains_key(&form) {
                    m.get(&form).unwrap().clone()
                } else {
                    form
                }
            }
        },
        _ => nil(),
    }
}

fn eval(context: Sexp, form: Sexp) -> Sexp {
    match form {
        Sexp::Bool(_) => form,
        Sexp::Number(_) => form,
        Sexp::Keyword(_) => form,
        Sexp::String(_) => form,
        Sexp::Error(_) => form,
        Sexp::Symbol(_) => nil(),

        Sexp::Map(ref x) => Sexp::Error(String::from("eval map not implemented")),
        Sexp::List(ref x) => {
            if x.is_empty() {
                form
            } else {
                let (f, args) = x.split_first().unwrap();
                apply(
                    eval(context.clone(), form.clone()),
                    Sexp::List(
                        args.iter()
                            .map(|x| eval(context.clone(), x.clone()))
                            .collect(),
                    ),
                )
            }
        }
    }
}

/// And a repl

fn read_line() -> String {
    let mut expr = String::new();

    io::stdin()
        .read_line(&mut expr)
        .expect("Failed to read line");

    expr
}

fn main() {
    println!("Welcome to the broken repl. Run (quit) to exit.");
    loop {
        print!("> ");
        io::stdout().flush().unwrap();
        let expr = read_line();
        if expr == String::from("(quit)\n") || expr == String::from("") {
            println!("Thanks for all the fish");
            break;
        } else {
            println!("{:?}", read(expr.clone()));
            println!("{}", eval(Sexp::Map(BTreeMap::new()), read(expr)));
        }
    }
}
