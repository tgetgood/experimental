// use std::fmt::Display;
// use im::{HashMap, HashSet, Vector};
// use std::str::Chars;

#[derive(Clone, Debug, Hash, PartialEq)]
enum Sexp {
    Bool(bool),
    Symbol(String),
    Keyword(String),
    String(String),
    Number(i128),
    List(Vec<Sexp>),
    // Vector(Vector<Sexp>),
    // Map(HashMap<Sexp, Sexp>),
    // Set(HashSet<Sexp>),
}

impl Eq for Sexp {}

// /// A Proper Lisp Reader doesn't tokenise, but instead reads character by
// /// character so that we can do things like special dispatch, literals, reader
// /// macros, etc.. This is an expedient, and a bit of a lazy one at that.
// fn tokenise(code: String) -> Vec<String> {
//     code.replace("(", " ( ")
//         .replace(")", " ) ")
//         .split_whitespace()
//         .map(|x| x.to_string())
//         .collect()
// }

// fn read_seq(tokens: &[String]) -> Result<Sexp, String> {
//     let i = tokens.iter().position(|x| x == ")");
//     match i {
//         None => Err("unbalanced parens, no closing ')' found.".to_string()),
//         Some(i) => {
//             let bits = tokens[0..i]
//                 .iter()
//                 .map(|x| {
//                     let v = Vec::new().clone_from_slice(x);
//                     read(v)
//                 })
//                 .into_iter()
//                 .collect();
//             match bits {
//                 Ok(v) => Sexp::List(v),
//                 Err(m) => Err(m),
//             }
//         }
//     }
// }


fn split(x: String, delim: String) -> (String, String) {
    (
        x.chars().take_while(|&x| !delim.contains(x)).collect(),
        x.chars().skip_while(|&x| !delim.contains(x)).collect(),
    )
}

fn chunk_inner(x: String, delim: String) -> Vec<String> {
    if x.is_empty() {
        return Vec::new()
    } else {
        let (head, tail) = split(x, "({[, ".to_string());
        let mut recur = chunk_inner(tail, delim);
        if !head.is_empty() {
            recur.push(head)
        }
        return recur
    }
} 

fn chunks(x: String, delim: String) -> Vec<String> {
    let mut res = chunk_inner(x, delim);
    res.reverse();
    res
}

fn read_atom(x: String) -> Result<Sexp, String> {
    Err("not implemented".to_string())
}

fn read_seq(chars: String) -> Result<Sexp, String> {
    let (seq, rest) = split(chars, ")".to_string());
    // let chunk = chars.take_while(|x| !delimiters.contains(x));
    Err("um".to_string())
}

fn read_switch(code: String) -> Result<Sexp, String> {
    match code.chars().next() {
        None => Err("unexpected end of input".to_string()),
        Some('(') => read_seq(code),
        _ => Err("um".to_string()),
    }
}

fn read(code: String) -> Result<Sexp, String> {
    if code.is_empty() {
        Err("no input".to_string())
    } else {
        read_switch(code)
    }
}


fn main() {
    let t = "(some test (expr))".to_string();
    // let (a, b) = split_to_stop(t);
    println!("{:?}", read(t));
}
