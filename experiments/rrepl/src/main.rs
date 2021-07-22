// use std::fmt::Display;
// use im::{HashMap, HashSet, Vector};
// use std::str::Chars;

#[derive(Clone, Debug, Hash, PartialEq)]
enum Sexp {
    Bool(bool),
    Symbol(String),
    // Keyword(String),
    // String(String),
    Number(i128),
    List(Vec<Sexp>),
    // Vector(Vector<Sexp>),
    // Map(HashMap<Sexp, Sexp>),
    // Set(HashSet<Sexp>),
}

impl Eq for Sexp {}

fn split(x: String, delim: String) -> (String, String) {
    (
        x.chars().take_while(|&x| !delim.contains(x)).collect(),
        x.chars().skip_while(|&x| !delim.contains(x)).collect(),
    )
}

fn read_atom(x: String) -> Result<(Sexp, String), String> {
    let (head, tail) = split(x, "()[]{}, ".to_string());
    let v: Sexp;
    if head == "true".to_string() {
        v = Sexp::Bool(true);
    } else if head == "false".to_string() {
        v = Sexp::Bool(false);
    } else {
        match head.parse::<i128>() {
            Ok(num) => {
                v = Sexp::Number(num);
            }
            _ => {
                v = Sexp::Symbol(head);
            }
        }
    }

    Ok((v, tail.trim().to_string()))
}

fn read_seq(chars: String, acc: &mut Vec<Sexp>) -> Result<(Sexp, String), String> {
    let mut c = chars.chars();
    match c.next() {
        Some(')') => Ok((Sexp::List(acc.clone()), c.collect::<String>())),
        Some(']') => Err("Unexpected char in list ']'".to_string()),
        None => Err("Unexpected end of input".to_string()),
        _ => {
            let (n, rest) = read0(chars)?;
            acc.push(n);
            read_seq(rest, acc)
        }
    }
}

fn read0(code: String) -> Result<(Sexp, String), String> {
    let mut chars = code.chars();
    let c = chars.next();
    let rest = chars.collect::<String>();

    match c {
        None => Err("unexpected end of input".to_string()),
        Some('(') => read_seq(rest, &mut Vec::new()),
        Some(_) => read_atom(code),
    }
}

fn read(code: String) -> Result<Sexp, String> {
    if code.is_empty() {
        Err("no input".to_string())
    } else {
        let (res, _) = read0(code.replace(",", " "))?;
        Ok(res)
    }
}

fn main() {
    let t = "(some test (true 1230))".to_string();
    // let (a, b) = split_to_stop(t);
    println!("{:?}", read(t));
}
