(ns lang.ir
  (:refer-clojure :exclude [compile]))

(def preamble
  ["source_filename = \"none\""
   "target datalayout = \"e-m:e-p270:32:32-p271:32:32-p272:64:64-i64:64-f80:128-n8:16:32:64-S128\""
   "target triple = \"x86_64-pc-linux-gnu\""])

(defn gen-label [] (str (gensym "label_")))
(defn gen-local [] (str "%" (name (gensym "t_"))))
(defn gen-global [] (str "@" (name (gensym "fn_"))))

(defn inst-type [x]
  (cond
    (vector? x)          :prog
    (contains? x :=)     (first (:= x))
    (contains? x :block) :block
    (true? (:global? x)) (cond (contains? x :blocks) :fn
                               :else                 :declare)))

(defn lref [x]
  (cond
    (symbol? x)  (str "%" (name x))
    (keyword? x) (name x)
    (integer? x) x))

(defn gref [s]
  (str "@" (name s)))

(defn gen-arg [xs]
  (apply str (interpose " " (map lref xs))))

(defmulti gen-ll #'inst-type)

(defmethod gen-ll :prog
  [x]
  (apply str (interpose "\n\n" (map gen-ll x))))

(defn fn-sig
  [{:keys [global? rettype args attrs ret-attrs unnamed] :as x}]
  (str
   (when (seq ret-attrs)
     (apply str (interleave (map lref ret-attrs) (repeat " "))))
   (lref rettype) " "
   (when global? "@") (name (:name x))
   "("
   (apply str (interpose ", " (map gen-arg args)))
   ")"
   (when unnamed
     (str " " (lref unnamed)))
   (when attrs
     (str " " attrs))))

(defmethod gen-ll :declare
  [x]
  (str "declare" " " (fn-sig x)))

(defmethod gen-ll :fn
  [{:keys [global? rettype args blocks attrs] :as f}]
  (str "define "
       (fn-sig f)
       " " "{"
       (apply str (map gen-ll blocks))
       "}"))

(defmethod gen-ll :block
  [{:keys [label block]}]
  (str
   "\n"
   (if label (name label) (gen-label)) ":"
   (apply str (interleave (repeat "\n  ") (map gen-ll block)))
   "\n"))

(defmethod gen-ll :switch
  [x]
  (let [[_ t v _ default & dests] (:= x)]
    (str "switch" " " (name t) " " (lref v) ", " "label" " " (lref default)
          " " "["
          (apply str (interleave (repeat "\n    ")
                                 (map (fn [[t v _ label]]
                                        (str (name t) " " (lref v) ", label "
                                             (lref label)))
                                      dests)))
          "\n" "  " "]")))

(defmethod gen-ll :call
  [{:keys [ret] :as x}]
  (let [[_ t f args & rest] (:= x)]
    (str
     (if ret (lref ret) (gen-local)) " = "
     "call" " " (name t) " " (gref f) "("
     (apply str (interpose ", " (map (fn [[t v]] (str (name t) " " (lref v)))
                                    (partition 2 args))))
     ")")))

(defmethod gen-ll :ret
  [x]
  (let [[_ t v] (:= x)]
    (str "ret" " " (name t) " " (lref v))))

(defmethod gen-ll :add
  [{:keys [ret] :as x}]
  (let [[_ t v1 v2] (:= x)]
    (str
     (if ret (lref ret) (gen-local))
     " = "
     "add nuw nsw" " " (name t) " " (lref v1) ", " (lref v2))))

(defmethod gen-ll :sub
  [{:keys [ret] :as x}]
  (let [[_ t v1 v2] (:= x)]
    (str
     (if ret (lref ret) (gen-local))
     " = "
     "sub nuw nsw" " " (name t) " " (lref v1) ", " (lref v2))))

(defmethod gen-ll :br
  [x]
  (let [[_ _ label] (:= x)]
    (str "br label " (lref label))))

(defmethod gen-ll :phi
  [{:keys [ret] :as x}]
  (let [[_ t & comefroms] (:= x)]
    (str
     (if ret (lref ret) (gen-local))
     " = "
     "phi" " " (name t) " "
     (apply str (interpose ", " (map (fn [[v from]]
                                       (str "[ " (lref v) ", " (lref from) "]"))
                                     comefroms))))))

(defmethod gen-ll :trunc
  [{:keys [ret] :as x}]
  (let [[_ t1 v _ t2] (:= x)]
    (str
     (if ret (lref ret) (gen-local))
     " = "
     "trunc" " " (name t1) " " (lref v) " to " (name t2))))

#_(defmethod gen-ll :default
  [x]
  (println (inst-type x))
  (throw (Exception. "unknown instruction")))

(defn compile [p]
  (str (apply str (interpose "\n"  preamble))
       "\n\n"
       (gen-ll p)))

(def fib
  {:global?    true
   :name       :fib
   :attrs      "#0"
   :ret-attrs  [:dso_local]
   :addr-space []
   :unnamed    :local_unnamed_addr
   :meta       {}
   :rettype    :i64
   :args       [[:i32 'i]]
   :blocks     [{:label 'entry
                 :block [{:=
                          [:switch :i32 'i :label 'default
                           [:i32 0 :label 'return]
                           [:i32 1 :label 'jump]]}]}
                {:label 'jump
                 :block [{:= [:br :label 'return]}]}
                {:label 'default
                 :block [{:ret 'T_1
                          :=   [:sub :i32 'i 1]}
                         {:ret 'T_2
                          :=   [:call :i64 :fib [:i32 'T_1]]}
                         {:ret 'T_3
                          :=   [:sub :i32 'T_1 1]}
                         {:ret 'T_4
                          :=   [:call :i64 :fib [:i32 'T_3]]}
                         {:ret 'T_5
                          :=   [:add :i64 'T_2 'T_4]}
                         {:= [:br :label 'return]}]}
                {:label 'return
                 :block [{:ret 'res
                          :=   [:phi :i64 [1 'jump] ['T_5 'default] [0 'entry]]}
                         {:= [:ret :i64 'res]}]}]})

(def read-input
  {:global? true
   :name    :readInput
   :attrs   "#0"
   :rettype :i32
   :args    []
   :blocks  [{:label 'entry
              :block [{:ret 'A_1
                       := [:alloca [10 :x :i8] :align 1]}
                      {:ret 'A_2
                       := [:alloca :i8 :align 1]}
                      {:= [:call :i64 :read [[:i32 0] [:i8* 'A_2] [:i64 1]] :#0]}
                      {:ret 'T_1
                       := [:load :i8 :i8* 'A_2]}
                      {:ret 'T_2
                       := [:icmp :eq :i8 'T_1 10]}
                      {:= [:br :i1 'T_1 :label 'endread :label 'loopread]}]}
             {:label 'loopread
              :block []}
             {:label 'endread
              :block []}
             {:label 'memcpy
              :block []}
             {:label 'return
              :block []}]})

(def main
  {:global?    true
   :name       :main
   :attrs      "#0"
   :rettype    :i64
   :ret-attrs  [:dso_local]
   :addr-space []
   :unnamed    :local_unnamed_addr
   :args       []
   :blocks     [{:block [{:ret 'T_1
                          :=   [:call :i32 :readInput []]}
                         {:ret 'T_2
                          :=   [:call :i64 :fib [[:i32 'T_1]]]}
                         {:ret 'A_1
                          :=   [:alloca [5 :x :i8] :i8 1 :align 1]}
                         {:= [:store [5 :x :i8]
                              [:i8 37 :i8 108 :i8 100 :i8 10 :i8 0]
                              [5 :x :i8 :*] 'A_1 :align 1]}
                         {:ret 'A_2
                          :=   [:bitcast [5 x :i8 :*] 'A_1 :to :i8*]}
                         {:= [:call :i32 [:i8*, :...] :printf [[:i8* :nonnull "dereferenceable(5)" 'A_2] [:i64 'T_2]]]}
                         {:= [:ret :i64 0]}]}]})

(def imports
  [{:global?   true
    :name      :read
    :attrs     "#0"
    :rettype   :i64
    :ret-attrs [:noundef]
    :unnamed   :local_unnamed_addr
    :args      [[:i32 :noundef] [:i8* :nocapture :noundef] [:i64 :noundef]]}
   {:global?   true
    :name      :printf
    :attrs     "#0"
    :rettype   :i32
    :ret-attrs [:noundef]
    :unnamed   :local_unnamed_addr
    :args      [[:i8* :nocapture :noundef :readonly] [:...]]}
   {:global?   true
    :name      :strtol
    :attrs     "#0"
    :rettype   :i64
    :ret-attrs [:noundef]
    :unnamed   :local_unnamed_addr
    :args      [[:i8* :readonly] [:i8** :nocapture] [:i32]]}
   {:global?   true
    :name      :llvm.memcpy.p0i8.p0i8.i64
    :attrs     "#0"
    :rettype   :void
    :ret-attrs []
    :args      [[:i8* :noalias :nocapture :writeonly]
                [:i8* :noalias :nocapture :readonly]
                [:i64]
                [:i1 :immarg]]}])

(def prog
  [fib
   imports
   main])
