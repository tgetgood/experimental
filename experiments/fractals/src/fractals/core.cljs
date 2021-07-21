(ns ^:figwheel-hooks fractals.core
  (:require [falloleen.core :as l]
            [falloleen.hosts :as hosts]
            [falloleen.lang :as lang]
            [falloleen.math :as math]
            [falloleen.renderer.html-canvas :as html]
            [falloleen.renderer.jsc :as jsc]))

(defn edge [alpha {[x1 y1] :from [x2 y2] :to :as l}]
  (let [dx (- x2 x1)
        dy (- y2 y1)]
    (-> l
        (lang/transform (lang/translation [dx dy]) (l/frame l))
        (lang/transform (lang/rotation alpha) (l/frame l)))))

(defn regular-polygon [n]
  (let [base  (assoc l/line :to [1 0])
        alpha (math/rad->deg (* math/pi (/ (- n 2) n)))]
    [base
     (edge alpha base)
     (edge alpha (edge alpha base))]

    #_(take n (iterate (partial edge alpha) base))))

(def hexagon
  (regular-polygon 6))


(def image
  (-> hexagon

      (l/scale [200 200])
      (l/translate [400 400])))

(defonce host (hosts/default-host {:size :fullscreen}))

(defn ^:export init []
  (l/draw! image host))

(defn ^:after-load on-reload []
  (init))
