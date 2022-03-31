(ns lang.ir
  (:refer-clojure :exclude [ref]))

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
    (contains? x :name)  :fn))

(defn lref [x]
  (cond
    (symbol? x)  (str "%" (name x))
    (integer? x) x))

(defn gref [s]
  (str "@" (name s)))

(defn gen-arg [[t n]]
  (str (name t) " " (lref n)))

(defmulti gen-ll #'inst-type)

(defmethod gen-ll :prog
  [x]
  (str (apply str (interpose "\n"  preamble))
       "\n\n"
       (apply str (interpose "\n\n" (map gen-ll x)))))

(defmethod gen-ll :fn
  [{:keys [global? rettype args blocks] :as f}]
  (str "define dso_local " (name rettype) " "
       (when global? "@") (name (:name f))
       "("
       (apply str (interpose ", " (map gen-arg args)))
       ")"
       " " "local_unnamed_addr" "" " #0" " " "{" "\n"
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

(def fib
  {:global?    true
   :name       :fib
   :properties {}
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

(def main
  {:global? true
   :name    :main
   :rettype :i64
   :args    []
   :blocks  [{:block [{:ret 'T_1
                       :=   [:call :i64 :fib [:i32 14]]}
                      {:= [:ret :i64 'T_1]}]}]})

(def prog
  [fib
   main])
