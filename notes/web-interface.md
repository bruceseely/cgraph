Web interface

using public aserve 

### Example

from Lisp: 
(net.aserve:publish 
  :path "/hello"
  :content-type "text/html"
  :function (lambda (req ent)
              (net.aserve:with-http-response (req ent)
                (net.aserve:with-http-body (req ent)
                  (net.html.generator:html 
                    (:html 
                      (:head (:title "Hello"))
                      (:body (:h1 "Hello from Portable AllegroServe!"))))))))

(uiop:run-program "open http://localhost:8080/hello")

in a browser: http://localhost:8080/hello

