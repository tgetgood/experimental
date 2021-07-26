#![allow(dead_code, unused_variables)]

use std::fmt;
use std::io;
use std::io::Write;

#[derive(Clone, Debug, Hash, PartialEq)]
enum Sexp {
    Bool(bool),
    Symbol(String),
    Keyword(String),
    String(String),
    Number(i64),
    List(Vec<Sexp>),
    Error(String),
}

impl Eq for Sexp {}

impl fmt::Display for Sexp {
    fn fmt(&self, f: &mut fmt::Formatter) -> fmt::Result {
        let str = match self {
            Sexp::Bool(x) => x.to_string(),
            Sexp::String(x) => format!("\"{}\"", x.to_string()),
            Sexp::keyword(x) => format!(":{}", x.to_string()),
            Sexp::Number(x) => x.to_string(),
            Sexp::Error(x) => format!("Error(\"{}\")", x),
            Sexp::Symbol(x) => x.to_string(),
            Sexp::List(x) => {
                let xs: Vec<String> = x.iter().map(|x| x.to_string()).collect();
                format!("({})", xs.join(","))
            }
        };

        write!(f, "{}", str)
    }
}

///// Reader

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
        let (res, _) = read0(code.replace(",", " "));
        res
    }
}

///// Meta Circular

/// Very basic lambda construct. No destructuring of args. Every lambda takes
/// one arg.
struct Lambda {
    form: Sexp,
    arg: Sexp,
    body: Sexp,
}

fn apply(form: Sexp, arg: Sexp) -> Sexp {
    Sexp::Error(String::from("no apply"))
}

impl IFn for Lambda {
    fn apply(&self, arg: Sexp) -> Sexp {
        let Lambda {
            arg,
            form,
            body,
            ..
        } = self;
        Sexp::Error("not implemented".to_string())
    }
}

fn lambda_p(f: Sexp) -> bool {
    let fn_sym = "fn".to_string();
    match f {
        Sexp::List(l) => match l[0].clone() {
            Sexp::Symbol(fn_sym) => true,
            _ => false,
        },
        _ => false,
    }
}

fn compile_lambda(f: Sexp) -> Lambda {
    let f = Sexp::Error("not implemented".to_string());
    Lambda {
        form: f.clone(),
        arg: f.clone(),
        body: f.clone(),
    }
}

fn eval(f: Sexp) -> Sexp {
    match f {
        Sexp::Bool(x) => f,
        Sexp::Number(x) => f,
        Sexp::Keyword(x) => f,
        Sexp::String(x) => f,
        Sexp::Error(x) => f,
        Sexp::Symbol(x) => Sexp::Error(String::from("Lookup not implemented")),
        Sexp::List(x) => {
            if x.is_empty() {
                f
            } else {
                let (f, args) = x.split_first();
                apply(eval(f), args.iter().map(eval).collect())
            }
        }
    }
}

///// And a repl

fn slurp_expr() -> String {
  let mut expr = String::new();
  
  io::stdin().read_line(&mut expr)
    .expect("Failed to read line");
  
  expr
}

fn main() {
    println!("Welcome to the broken repl. Run (quit) to exit.");
    loop {
        print!("> ");
        io::stdout().flush().unwrap();
        let expr = slurp_expr();
        if expr == String::from("(quit)\n") || expr == String::from("") {
            println!("Thanks for all the fish");
            break;
        } else {
            println!("{}", eval(read(expr)));
        }
    }
}
