(ns lang.ir
  (:refer-clojure :exclude [compile])
  (:require [clojure.string :as str]))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;; Utils
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defn xor [a b]
  (or (and a (not b))
      (and (not a) b)))

(defn gen-type [t]
  (cond (keyword? t) (name t)
        (map? t)     (let [{:keys [type size vector? ptr?]} t]
                       (str
                        (if (integer? size)
                          (str
                           (if vector? "<" "[")
                           size " x " (name type)
                           (if vector? ">" "]"))
                          (name type))
                        ;; REVIEW: This is a weird way to talk about pointer
                        ;; pointer pointer pointers...
                        (when ptr?
                          (apply str (take ptr? (repeat "*"))))))))

(defn gen-ptr-type [t]
  (gen-type
   (cond (map? t)     (update t :ptr? (fnil inc 0))
         (keyword? t) {:type t
                       :ptr? 1})))

(defn gen-fn-type [[& args]]
  (str "(" (apply str (interpose ", " (map gen-type args))) ")"))

(defn gen-agg [{:keys [type vals vector?]}]
  (str (if vector? "<" "[")
       (apply str (interpose ", " (map (partial str (gen-type type) " ") vals)))
       (if vector? ">" "]")))

(defn lref
  "Local refs and literal values."
  [x]
  (cond
    (symbol? x)  (str "%" (name x))
    ;; This special case covers the varargs `...`. It's an ugly hack.
    (keyword? x) (name x)
    (integer? x) x
    (boolean? x) (str x)
    (map? x)     (gen-agg x)))

(defn gref [s]
  (str "@" (name s)))

(defn gen-arg [{:keys [type arg params]}]
  (str
   (gen-type type)
   (apply str (interleave (repeat " ") (map name params)))
   (when-not (nil? arg) (str " " (lref arg)))))

(defn gen-label [] (str (gensym "label_")))
(defn gen-local [] (str "%" (name (gensym "t_"))))
(defn gen-global [] (str "@" (name (gensym "fn_"))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;; Code gen
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defn inst-type [x]
  (cond
    (vector? x)                         ::prog
    (and (map? x) (contains? x :block)) ::block
    (map? x)                            ::inst))

(defmulti gen-ll #'inst-type)
(defmulti gen-inst :inst)

(defmethod gen-ll ::prog
  [x]
  (apply str (interleave (map gen-ll x) (repeat "\n"))))

(defn gen-block-line
  [{:keys [ret] :as x}]
  (str (when ret (str (lref ret) " = "))
       (gen-inst x)
       "\n"))

(defmethod gen-ll ::block
  [{:keys [label block]}]
  (str (if label (name label) (gen-label)) ":\n"
       (apply str (interleave (repeat "  ") (map gen-block-line block)))
       "\n"))

(defmethod gen-ll ::inst
  [{:keys [ret] :as x}]
  (gen-inst x))

(defn fn-sig
  [{:keys [inst fn-type type args attrs params unnamed blocks] :as x}]
  (str (name inst) " "
       (when (seq params)
         (apply str (interleave (map name params) (repeat " "))))
       (gen-type type) " "
       (gref (:name x))
       "("
       (apply str (interpose ", " (map gen-arg args)))
       ")" " "
       (when unnamed
         (str (name unnamed) " "))
       (when attrs
         (str attrs " "))
       (when blocks
         (str "{\n"
              (apply str (map gen-ll blocks))
              "}"))
       "\n"))

(defmethod gen-inst :declare
  [x]
  (fn-sig x))

(defmethod gen-inst :define
  [f]
  (fn-sig f))

(defmethod gen-inst :switch
  [{:keys [type switch default cases]}]
  (str "switch" " " (gen-type type) " "
       (lref switch) ", " "label" " " (lref default)
       " " "["
       (apply str (interleave (repeat "\n    ")
                              (map (fn [[v label]]
                                     (str (gen-type type ) " "
                                          (lref v) ", label "
                                          (lref label)))
                                   cases)))
       "\n" "  " "]"))

(defmethod gen-inst :call
  [{:keys [fn type fn-type args]}]
  (str "call" " "
   (gen-type type)
   " "
   (when fn-type
     (str (gen-fn-type fn-type) " "))
   (gref fn) "("
   (apply str (interpose ", " (map gen-arg args)))
   ")"))

(defn gen-simple-inst
  "Simple instructions are unary or binary instructions like `ret`, `add`, etc."
  [{:keys [inst type arg args]}]
  ;; FIXME: This strikes me as the kind of laziness I'll regret later.
  (assert (xor (nil? arg) (empty? args)))
  (str (name inst) " " (gen-type type) " "
       (if arg
         (lref arg)
         (apply str (interpose ", " (map lref args))))))

(defmethod gen-inst :ret
  [x]
  (gen-simple-inst x))

(defmethod gen-inst :add
  [x]
  (gen-simple-inst x))

(defmethod gen-inst :sub
  [x]
  (gen-simple-inst x))

(defmethod gen-inst :br
  [{:keys [cond then else]}]
  (str "br "
       (when cond
         (str (gen-type (:type cond)) " " (lref (:arg cond)) ", "))
       "label " (lref then)
       (when else
         (str ", label " (lref else)))))

(defmethod gen-inst :phi
  [{:keys [type locations]}]
  (str
   "phi" " " (gen-type type) " "
   (apply str (interpose ", " (map (fn [[v from]]
                                     (str "[ " (lref v) ", " (lref from) " ]"))
                                   locations)))))

;;;;; Type Casting

(defn gen-cast
  [{:keys [inst from to arg]}]
  (str
   (name inst) " " (gen-type from) " " (lref arg) " to " (gen-type to)))

(defmethod gen-inst :trunc
  [x]
  (gen-cast x))

(defmethod gen-inst :bitcast
  [x]
  (gen-cast x))

;;;;; Comparisons

(defmethod gen-inst :icmp
  [{:keys [type cmp args]}]
  (str "icmp " (name cmp) " " (gen-type type) " "
       (apply str (interpose ", " (map lref args)))))

;;;;; Memory

(defmethod gen-inst :alloca
  [{:keys [type size align]}]
  (str "alloca "
       (gen-type type)
       (when size
         (str ", " (gen-type (:type size)) " " (lref (:size size))))
       (when align
         (str ", align " align))))

(defmethod gen-inst :store
  [{:keys [type val ptr]}]
  (str "store " (gen-type type) " " (lref val) ", "
       (gen-ptr-type type) " " (lref ptr)))

(defmethod gen-inst :load
  [{:keys [type arg]}]
  (str "load " (gen-type type) ", " (gen-ptr-type type) " " (lref arg)))

(defmethod gen-inst :getelementptr
  [{:keys [inbounds? type ptr args]}]
  (str "getelementptr " (when inbounds? "inbounds ")
       (gen-type type) ", "
       (gen-ptr-type type) " " (lref ptr) ", "
       (apply str (interpose ", " (map gen-arg args)))))

;;;;; default

(defmethod gen-inst :default
  [x]
  [ "UNIMPLEMENTED" x])

(def preamble
  "IR header. Should be generated."
  ["source_filename = \"none\""
   "target datalayout = \"e-m:e-p270:32:32-p271:32:32-p272:64:64-i64:64-f80:128-n8:16:32:64-S128\""
   "target triple = \"x86_64-pc-linux-gnu\""])

(defn compile [p]
  (str (apply str (interpose "\n"  preamble))
       "\n\n"
       (gen-ll p)))
