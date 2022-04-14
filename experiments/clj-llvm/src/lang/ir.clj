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
    (vector? x)                         ::prog
    (and (map? x) (contains? x :block)) ::block
    (map? x)                            ::inst))

(defn lref [x]
  (cond
    (symbol? x)  (str "%" (name x))
    (keyword? x) (name x)
    (integer? x) x))

(defn gref [s]
  (str "@" (name s)))

(defmulti gen-ll #'inst-type)
(defmulti gen-inst :inst)

(defmethod gen-ll ::prog
  [x]
  (map gen-ll x))

(defmethod gen-ll ::block
  [{:keys [label block]}]
  [(str (if label (name label) (gen-label)) ":")
   (map gen-ll block)])

(defmethod gen-ll ::inst
  [{:keys [ret] :as x}]
  (concat (when ret [(lref ret) "="])
          (gen-inst x)))

(defn gen-arg [xs]
  (apply str (interpose " " (map lref xs))))

(defn fn-sig
  [{:keys [inst fn-type type args attrs params unnamed blocks] :as x}]
  (apply concat
         [(name inst)]
         (when (seq params)
           (map lref params))
         [(lref type)
          (when fn-type ["fn-type"])
          (gref (:name x))
          "("]
         (interpose "," (map gen-arg args))
         [")"
          (when unnamed
            (lref unnamed))
          (when attrs
            attrs)
          (when blocks "{")]
         (when blocks
           [])))

(defmethod gen-inst :declare
  [x]
  (fn-sig x))

(defmethod gen-inst :define
  [f]
  (fn-sig f))

(defmethod gen-inst :switch
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

(defmethod gen-inst :call
  [{:keys [ret fn ]}]
  #_(str
   (if ret (lref ret) (gen-local)) " = "
   "call" " " (name t) " " (gref f) "("
   (apply str (interpose ", " (map (fn [[t v]] (str (name t) " " (lref v)))
                                   (partition 2 args))))
   ")"))

(defmethod gen-inst :ret
  [x]
  (let [[_ t v] (:= x)]
    (str "ret" " " (name t) " " (lref v))))

(defmethod gen-inst :add
  [{:keys [ret] :as x}]
  (let [[_ t v1 v2] (:= x)]
    (str
     (if ret (lref ret) (gen-local))
     " = "
     "add nuw nsw" " " (name t) " " (lref v1) ", " (lref v2))))

(defmethod gen-inst :sub
  [{:keys [ret] :as x}]
  (let [[_ t v1 v2] (:= x)]
    (str
     (if ret (lref ret) (gen-local))
     " = "
     "sub nuw nsw" " " (name t) " " (lref v1) ", " (lref v2))))

(defmethod gen-inst :br
  [x]
  (let [[_ _ label] (:= x)]
    (str "br label " (lref label))))

(defmethod gen-inst :phi
  [{:keys [ret] :as x}]
  (let [[_ t & comefroms] (:= x)]
    (str
     (if ret (lref ret) (gen-local))
     " = "
     "phi" " " (name t) " "
     (apply str (interpose ", " (map (fn [[v from]]
                                       (str "[ " (lref v) ", " (lref from) "]"))
                                     comefroms))))))

(defmethod gen-inst :trunc
  [{:keys [ret] :as x}]
  (let [[_ t1 v _ t2] (:= x)]
    (str
     (if ret (lref ret) (gen-local))
     " = "
     "trunc" " " (name t1) " " (lref v) " to " (name t2))))

(defmethod gen-inst :default
  [x]
  (str "[ STUB: " (inst-type x) "]\n")
)

(defn compile [p]
  (str (apply str (interpose "\n"  preamble))
       "\n\n"
       (gen-ll p)))

(def fib
  {:global?    true
   :name       :fib
   :attrs      "#0"
   :params  [:dso_local]
   :addr-space []
   :unnamed    :local_unnamed_addr
   :meta       {}
   :type    :i64
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
   :type :i32
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
  {:inst       :define
   :name       :main
   :attrs      "#0"
   :type       :i64
   :params     [:dso_local]
   :addr-space []
   :unnamed    :local_unnamed_addr
   :args       []
   :blocks     [{:block [{:inst :call
                          :ret  'T_1
                          :type :i32
                          :fn   :readInput
                          :args []}
                         {:inst :call
                          :ret  'T_2
                          :type :i64
                          :fn   :fib
                          :args [{:type :i32
                                  :arg  'T_1}]}

                         {:ret   'A_1
                          :inst  :alloca
                          :type  {:size 5
                                  :type :i8}
                          :size  {:type :i8
                                  :size 1}
                          :align 1}
                         {:inst  :store
                          :val   {:type {:type :i8
                                         :size 5}
                                  :arg  {:type    :i8
                                         :vector? false
                                         :vals    [37 108 100 10 0]}}
                          :loc   {:type {:type :i8
                                         :size 5
                                         :ptr? true}
                                  :arg  'A_1}
                          :align 1}
                         {:ret       'A_2
                          :inst      :bitcast
                          :from-type {:type :i8
                                      :size 5
                                      :ptr? true}
                          :arg       'A_1
                          :to-type   :i8*}
                         {:inst    :call
                          :type    :i32
                          :fn-type [:i8*, :...]
                          :fn      :printf
                          :args    [{:type   :i8*
                                     :arg    'A_2
                                     :params [:nonnull "dereferenceable(5)"]}
                                    {:type :i64
                                     :arg  'T_2}]}
                         {:inst :ret
                          :type :i64
                          :arg  0}]}]})

(def imports
  [{:inst    :declare
    :name    :read
    :attrs   "#0"
    :type    :i64
    :params  [:noundef]
    :unnamed :local_unnamed_addr
    :args    [{:type   :i32
               :params [:noundef]}
              {:type   :i8*
               :params [:nocapture :noundef]}
              {:type   :i64
               :params [:noundef]}]}
   {:inst    :declare
    :name    :printf
    :attrs   "#0"
    :type    :i32
    :params  [:noundef]
    :unnamed :local_unnamed_addr
    :args    [{:type   :i8*
               :params [:nocapture :noundef :readonly]}
              {:arg :...}]}
   {:inst    :declare
    :name    :strtol
    :attrs   "#0"
    :type    :i64
    :params  [:noundef]
    :unnamed :local_unnamed_addr
    :args    [{:type   :i8*
               :params [:readonly]}
              {:type   :i8**
               :params [:nocapture]}
              {:type :i32}]}
   {:inst  :declare
    :name  :llvm.memcpy.p0i8.p0i8.i64
    :attrs "#0"
    :type  :void
    :args  [{:type   :i8*
             :params [:noalias :nocapture :writeonly]}
            {:type   :i8*
             :params [:noalias :nocapture :readonly]}
            {:type :i64}
            {:type   :i1
             :params [:immarg]}]}])

(def prog
  [fib
   imports
   main])
