(ns lang.spec
  (:require [clojure.spec.alpha :as s]
            [clojure.string :as str]))

(s/def ::line
  (s/or
   :assignment ::assignment
   :effect ::effect))

(s/def ::assignment
  (s/cat :ret-var symbol? :eq (partial = :=) :inst (s/& (s/* any?) ::call)))


(s/def ::effect ::inst)

(s/def ::inst
  (s/or
   :call ::call))

(s/def ::call
  (s/cat :inst #(= :call %)
         :ret-type keyword?
         :fn-type (s/? vector?)
         :name keyword?
         :args vector?))
