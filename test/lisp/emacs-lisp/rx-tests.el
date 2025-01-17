;;; rx-tests.el --- tests for rx.el              -*- lexical-binding: t -*-

;; Copyright (C) 2016-2019 Free Software Foundation, Inc.

;; This file is part of GNU Emacs.

;; GNU Emacs is free software: you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; GNU Emacs is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with GNU Emacs.  If not, see <https://www.gnu.org/licenses/>.

(require 'ert)
(require 'rx)

(ert-deftest rx-seq ()
  (should (equal (rx "a.b" "*" "c")
                 "a\\.b\\*c"))
  (should (equal (rx (seq "a" (: "b" (and "c" (sequence "d" nonl)
                                          "e")
                                 "f")
                          "g"))
                 "abcd.efg"))
  (should (equal (rx "a$" "b")
                 "a\\$b"))
  (should (equal (rx bol "a" "b" ?c eol)
                 "^abc$"))
  (should (equal (rx "a" "" "b")
                 "ab"))
  (should (equal (rx (seq))
                 ""))
  (should (equal (rx "" (or "ab" nonl) "")
                 "ab\\|.")))

(ert-deftest rx-or ()
  (should (equal (rx (or "ab" (| "c" nonl) "de"))
                 "ab\\|c\\|.\\|de"))
  (should (equal (rx (or "ab" "abc" "a"))
                 "\\(?:ab\\|abc\\|a\\)"))
  (should (equal (rx (| nonl "a") (| "b" blank))
                 "\\(?:.\\|a\\)\\(?:b\\|[[:blank:]]\\)"))
  (should (equal (rx (|))
                 "\\`a\\`")))

(ert-deftest rx-char-any ()
  "Test character alternatives with `]' and `-' (Bug#25123)."
  (should (equal
           (rx string-start (1+ (char (?\] . ?\{) (?< . ?\]) (?- . ?:)))
               string-end)
           "\\`[.-:<-{-]+\\'")))

(ert-deftest rx-char-any-range-nl ()
  "Test character alternatives with LF as a range endpoint."
  (should (equal (rx (any "\n-\r"))
                 "[\n-\r]"))
  (should (equal (rx (any "\a-\n"))
                 "[\a-\n]")))

(ert-deftest rx-char-any-raw-byte ()
  "Test raw bytes in character alternatives."

  ;; The multibyteness of the rx return value sometimes depends on whether
  ;; the test had been byte-compiled or not, so we add explicit conversions.

  ;; Separate raw characters.
  (should (equal (string-to-multibyte (rx (any "\326A\333B")))
                 (string-to-multibyte "[AB\326\333]")))
  ;; Range of raw characters, unibyte.
  (should (equal (string-to-multibyte (rx (any "\200-\377")))
                 (string-to-multibyte "[\200-\377]")))

  ;; Range of raw characters, multibyte.
  (should (equal (rx (any "Å\211\326-\377\177"))
                 "[\177Å\211\326-\377]"))
  ;; Split range; \177-\377ÿ should not be optimised to \177-\377.
  (should (equal (rx (any "\177-\377" ?ÿ))
                 "[\177ÿ\200-\377]")))

(ert-deftest rx-any ()
  (should (equal (rx (any ?A (?C . ?D) "F-H" "J-L" "M" "N-P" "Q" "RS"))
                 "[ACDF-HJ-S]"))
  (should (equal (rx (in "a!f" ?c) (char "q-z" "0-3")
                     (not-char "a-e1-5") (not (in "A-M" ?q)))
                 "[!acf][0-3q-z][^1-5a-e][^A-Mq]"))
  (should (equal (rx (any "^") (any "]") (any "-")
                     (not (any "^")) (not (any "]")) (not (any "-")))
                 "\\^]-[^^][^]][^-]"))
  (should (equal (rx (any "]" "^") (any "]" "-") (any "-" "^")
                     (not (any "]" "^")) (not (any "]" "-"))
                     (not (any "-" "^")))
                 "[]^][]-][-^][^]^][^]-][^-^]"))
  (should (equal (rx (any "]" "^" "-") (not (any "]" "^" "-")))
                 "[]^-][^]^-]"))
  (should (equal (rx (any "-" ascii) (any "^" ascii) (any "]" ascii))
                 "[[:ascii:]-][[:ascii:]^][][:ascii:]]"))
  (should (equal (rx (not (any "-" ascii)) (not (any "^" ascii))
                     (not (any "]" ascii)))
                 "[^[:ascii:]-][^[:ascii:]^][^][:ascii:]]"))
  (should (equal (rx (any "-]" ascii) (any "^]" ascii) (any "-^" ascii))
                 "[][:ascii:]-][]^[:ascii:]][[:ascii:]^-]"))
  (should (equal (rx (not (any "-]" ascii)) (not (any "^]" ascii))
                     (not (any "-^" ascii)))
                 "[^][:ascii:]-][^]^[:ascii:]][^[:ascii:]^-]"))
  (should (equal (rx (any "-]^" ascii) (not (any "-]^" ascii)))
                 "[]^[:ascii:]-][^]^[:ascii:]-]"))
  (should (equal (rx (any "^" lower upper) (not (any "^" lower upper)))
                 "[[:lower:]^[:upper:]][^[:lower:]^[:upper:]]"))
  (should (equal (rx (any "-" lower upper) (not (any "-" lower upper)))
                 "[[:lower:][:upper:]-][^[:lower:][:upper:]-]"))
  (should (equal (rx (any "]" lower upper) (not (any "]" lower upper)))
                 "[][:lower:][:upper:]][^][:lower:][:upper:]]"))
  (should (equal (rx (any "-a" "c-" "f-f" "--/*--"))
                 "[*-/acf]"))
  (should (equal (rx (any "]-a" ?-) (not (any "]-a" ?-)))
                 "[]-a-][^]-a-]"))
  (should (equal (rx (any "--]") (not (any "--]"))
                     (any "-" "^-a") (not (any "-" "^-a")))
                 "[].-\\-][^].-\\-][-^-a][^-^-a]"))
  (should (equal (rx (not (any "!a" "0-8" digit nonascii)))
                 "[^!0-8a[:digit:][:nonascii:]]"))
  (should (equal (rx (any) (not (any)))
                 "\\`a\\`\\(?:.\\|\n\\)"))
  (should (equal (rx (any "") (not (any "")))
                 "\\`a\\`\\(?:.\\|\n\\)")))

(ert-deftest rx-pcase ()
  (should (equal (pcase "a 1 2 3 1 1 b"
                   ((rx (let u (+ digit)) space
                        (let v (+ digit)) space
                        (let v (+ digit)) space
                        (backref u) space
                        (backref 1))
                    (list u v)))
                 '("1" "3")))
  (let ((k "blue"))
    (should (equal (pcase "<blue>"
                     ((rx "<" (literal k) ">") 'ok))
                   'ok))))

(ert-deftest rx-kleene ()
  "Test greedy and non-greedy repetition operators."
  (should (equal (rx (* "a") (+ "b") (\? "c") (?\s "d")
                     (*? "e") (+? "f") (\?? "g") (?? "h"))
                 "a*b+c?d?e*?f+?g??h??"))
  (should (equal (rx (zero-or-more "a") (0+ "b")
                     (one-or-more "c") (1+ "d")
                     (zero-or-one "e") (optional "f") (opt "g"))
                 "a*b*c+d+e?f?g?"))
  (should (equal (rx (minimal-match
                      (seq (* "a") (+ "b") (\? "c") (?\s "d")
                           (*? "e") (+? "f") (\?? "g") (?? "h"))))
                 "a*b+c?d?e*?f+?g??h??"))
  (should (equal (rx (minimal-match
                      (seq (zero-or-more "a") (0+ "b")
                           (one-or-more "c") (1+ "d")
                           (zero-or-one "e") (optional "f") (opt "g"))))
                 "a*?b*?c+?d+?e??f??g??"))
  (should (equal (rx (maximal-match
                      (seq (* "a") (+ "b") (\? "c") (?\s "d")
                         (*? "e") (+? "f") (\?? "g") (?? "h"))))
                 "a*b+c?d?e*?f+?g??h??"))
  (should (equal (rx "a" (*) (+ (*)) (? (*) (+)) "b")
                 "ab")))

(ert-deftest rx-repeat ()
  (should (equal (rx (= 3 "a") (>= 51 "b")
                     (** 2 11 "c") (repeat 6 "d") (repeat 4 8 "e"))
                 "a\\{3\\}b\\{51,\\}c\\{2,11\\}d\\{6\\}e\\{4,8\\}"))
  (should (equal (rx (= 0 "k") (>= 0 "l") (** 0 0 "m") (repeat 0 "n")
                     (repeat 0 0 "o"))
                 "k\\{0\\}l\\{0,\\}m\\{0\\}n\\{0\\}o\\{0\\}"))
  (should (equal (rx (opt (0+ "a")))
                 "\\(?:a*\\)?"))
  (should (equal (rx (opt (= 4 "a")))
                 "a\\{4\\}?"))
  (should (equal (rx "a" (** 3 7) (= 4) (>= 3) (= 4 (>= 7) (= 2)) "b")
                 "ab")))

(ert-deftest rx-atoms ()
  (should (equal (rx anything)
                 ".\\|\n"))
  (should (equal (rx line-start not-newline nonl any line-end)
                 "^...$"))
  (should (equal (rx bol string-start string-end buffer-start buffer-end
                     bos eos bot eot eol)
                 "^\\`\\'\\`\\'\\`\\'\\`\\'$"))
  (should (equal (rx point word-start word-end bow eow symbol-start symbol-end
                     word-boundary not-word-boundary not-wordchar)
                 "\\=\\<\\>\\<\\>\\_<\\_>\\b\\B\\W"))
  (should (equal (rx digit numeric num control cntrl)
                 "[[:digit:]][[:digit:]][[:digit:]][[:cntrl:]][[:cntrl:]]"))
  (should (equal (rx hex-digit hex xdigit blank)
                 "[[:xdigit:]][[:xdigit:]][[:xdigit:]][[:blank:]]"))
  (should (equal (rx graph graphic print printing)
                 "[[:graph:]][[:graph:]][[:print:]][[:print:]]"))
  (should (equal (rx alphanumeric alnum letter alphabetic alpha)
                 "[[:alnum:]][[:alnum:]][[:alpha:]][[:alpha:]][[:alpha:]]"))
  (should (equal (rx ascii nonascii lower lower-case)
                 "[[:ascii:]][[:nonascii:]][[:lower:]][[:lower:]]"))
  (should (equal (rx punctuation punct space whitespace white)
                 "[[:punct:]][[:punct:]][[:space:]][[:space:]][[:space:]]"))
  (should (equal (rx upper upper-case word wordchar)
                 "[[:upper:]][[:upper:]][[:word:]][[:word:]]"))
  (should (equal (rx unibyte multibyte)
                 "[[:unibyte:]][[:multibyte:]]")))

(ert-deftest rx-syntax ()
  (should (equal (rx (syntax whitespace) (syntax punctuation)
                     (syntax word) (syntax symbol)
                     (syntax open-parenthesis) (syntax close-parenthesis))
                 "\\s-\\s.\\sw\\s_\\s(\\s)"))
  (should (equal (rx (syntax string-quote) (syntax paired-delimiter)
                     (syntax escape) (syntax character-quote)
                     (syntax comment-start) (syntax comment-end)
                     (syntax string-delimiter) (syntax comment-delimiter))
                 "\\s\"\\s$\\s\\\\s/\\s<\\s>\\s|\\s!")))

(ert-deftest rx-category ()
  (should (equal (rx (category space-for-indent) (category base)
                     (category consonant) (category base-vowel)
                     (category upper-diacritical-mark)
                     (category lower-diacritical-mark)
                     (category tone-mark) (category symbol)
                     (category digit)
                     (category vowel-modifying-diacritical-mark)
                     (category vowel-sign) (category semivowel-lower)
                     (category not-at-end-of-line)
                     (category not-at-beginning-of-line))
                 "\\c \\c.\\c0\\c1\\c2\\c3\\c4\\c5\\c6\\c7\\c8\\c9\\c<\\c>"))
  (should (equal (rx (category alpha-numeric-two-byte)
                     (category chinese-two-byte) (category greek-two-byte)
                     (category japanese-hiragana-two-byte)
                     (category indian-two-byte)
                     (category japanese-katakana-two-byte)
                     (category strong-left-to-right)
                     (category korean-hangul-two-byte)
                     (category strong-right-to-left)
                     (category cyrillic-two-byte)
                     (category combining-diacritic))
                 "\\cA\\cC\\cG\\cH\\cI\\cK\\cL\\cN\\cR\\cY\\c^"))
  (should (equal (rx (category ascii) (category arabic) (category chinese)
                     (category ethiopic) (category greek) (category korean)
                     (category indian) (category japanese)
                     (category japanese-katakana) (category latin)
                     (category lao) (category tibetan))
                 "\\ca\\cb\\cc\\ce\\cg\\ch\\ci\\cj\\ck\\cl\\co\\cq"))
  (should (equal (rx (category japanese-roman) (category thai)
                     (category vietnamese) (category hebrew)
                     (category cyrillic) (category can-break))
                 "\\cr\\ct\\cv\\cw\\cy\\c|"))
  (should (equal (rx (category ?g) (not (category ?~)))
                 "\\cg\\C~")))

(ert-deftest rx-not ()
  (should (equal (rx (not word-boundary))
                 "\\B"))
  (should (equal (rx (not ascii) (not lower-case) (not wordchar))
                 "[^[:ascii:]][^[:lower:]][^[:word:]]"))
  (should (equal (rx (not (syntax punctuation)) (not (syntax escape)))
                 "\\S.\\S\\"))
  (should (equal (rx (not (category tone-mark)) (not (category lao)))
                 "\\C4\\Co")))

(ert-deftest rx-group ()
  (should (equal (rx (group nonl) (submatch "x")
                     (group-n 3 "y") (submatch-n 13 "z") (backref 1))
                 "\\(.\\)\\(x\\)\\(?3:y\\)\\(?13:z\\)\\1"))
  (should (equal (rx (group) (group-n 2))
                 "\\(\\)\\(?2:\\)")))

(ert-deftest rx-regexp ()
  (should (equal (rx (regexp "abc") (regex "[de]"))
                 "\\(?:abc\\)[de]"))
  (let ((x "a*"))
    (should (equal (rx (regexp x) "b")
                   "\\(?:a*\\)b"))
    (should (equal (rx "" (regexp x) (eval ""))
                   "a*"))))

(ert-deftest rx-eval ()
  (should (equal (rx (eval (list 'syntax 'symbol)))
                 "\\s_"))
  (should (equal (rx "a" (eval (concat)) "b")
                 "ab")))

(ert-deftest rx-literal ()
  (should (equal (rx (literal (char-to-string 42)) nonl)
                 "\\*."))
  (let ((x "a+b"))
    (should (equal (rx (opt (literal (upcase x))))
                   "\\(?:A\\+B\\)?"))))

(ert-deftest rx-to-string ()
  (should (equal (rx-to-string '(or nonl "\nx"))
                 "\\(?:.\\|\nx\\)"))
  (should (equal (rx-to-string '(or nonl "\nx") t)
                 ".\\|\nx")))

(ert-deftest rx-let ()
  (rx-let ((beta gamma)
           (gamma delta)
           (delta (+ digit))
           (epsilon (or gamma nonl)))
    (should (equal (rx bol delta epsilon)
                   "^[[:digit:]]+\\(?:[[:digit:]]+\\|.\\)")))
  (rx-let ((p () point)
           (separated (x sep) (seq x (* sep x)))
           (comma-separated (x) (separated x ","))
           (semi-separated (x) (separated x ";"))
           (matrix (v) (semi-separated (comma-separated v))))
    (should (equal (rx (p) (matrix (+ "a")) eos)
                   "\\=a+\\(?:,a+\\)*\\(?:;a+\\(?:,a+\\)*\\)*\\'")))
  (rx-let ((b bol)
           (z "B")
           (three (x) (= 3 x)))
    (rx-let ((two (x) (seq x x))
             (z "A")
             (e eol))
      (should (equal (rx b (two (three z)) e)
                     "^A\\{3\\}A\\{3\\}$"))))
  (rx-let ((f (a b &rest r) (seq "<" a ";" b ":" r ">")))
    (should (equal (rx bol (f ?x ?y) ?! (f ?u ?v ?w) ?! (f ?k ?l ?m ?n) eol)
                   "^<x;y:>!<u;v:w>!<k;l:mn>$")))

  ;; Rest parameters are expanded by splicing.
  (rx-let ((f (&rest r) (or bol r eol)))
    (should (equal (rx (f "ab" nonl))
                   "^\\|ab\\|.\\|$")))

  ;; Substitution is done in number positions.
  (rx-let ((stars (n) (= n ?*)))
    (should (equal (rx (stars 4))
                   "\\*\\{4\\}")))

  ;; Substitution is done inside dotted pairs.
  (rx-let ((f (x y z) (any x (y . z))))
    (should (equal (rx (f ?* ?a ?t))
                   "[*a-t]")))

  ;; Substitution is done in the head position of forms.
  (rx-let ((f (x) (x "a")))
    (should (equal (rx (f +))
                   "a+"))))

(ert-deftest rx-define ()
  (rx-define rx--a (seq "x" (opt "y")))
  (should (equal (rx bol rx--a eol)
                 "^xy?$"))
  (rx-define rx--c (lb rb &rest stuff) (seq lb stuff rb))
  (should (equal (rx bol (rx--c "<" ">" rx--a nonl) eol)
                 "^<xy?.>$"))
  (rx-define rx--b (* rx--a))
  (should (equal (rx rx--b)
                 "\\(?:xy?\\)*"))
  (rx-define rx--a "z")
  (should (equal (rx rx--b)
                 "z*")))

(defun rx--test-rx-to-string-define ()
  ;; `rx-define' won't expand to code inside `ert-deftest' since we use
  ;; `eval-and-compile'.  Put it into a defun as a workaround.
  (rx-define rx--d "Q")
  (rx-to-string '(seq bol rx--d) t))

(ert-deftest rx-to-string-define ()
  "Check that `rx-to-string' uses definitions made by `rx-define'."
  (should (equal (rx--test-rx-to-string-define)
                 "^Q")))

(ert-deftest rx-let-define ()
  "Test interaction between `rx-let' and `rx-define'."
  (rx-define rx--e "one")
  (rx-define rx--f "eins")
  (rx-let ((rx--e "two"))
    (should (equal (rx rx--e nonl rx--f) "two.eins"))
    (rx-define rx--e "three")
    (should (equal (rx rx--e) "two"))
    (rx-define rx--f "zwei")
    (should (equal (rx rx--f) "zwei")))
  (should (equal (rx rx--e nonl rx--f) "three.zwei")))

(ert-deftest rx-let-eval ()
  (rx-let-eval '((a (* digit))
                 (f (x &rest r) (seq x nonl r)))
    (should (equal (rx-to-string '(seq a (f bow a ?b)) t)
                   "[[:digit:]]*\\<.[[:digit:]]*b"))))

(ert-deftest rx-redefine-builtin ()
  (should-error (rx-define sequence () "x"))
  (should-error (rx-define sequence "x"))
  (should-error (rx-define nonl () "x"))
  (should-error (rx-define nonl "x"))
  (should-error (rx-let ((punctuation () "x")) nil))
  (should-error (rx-let ((punctuation "x")) nil))
  (should-error (rx-let-eval '((not-char () "x")) nil))
  (should-error (rx-let-eval '((not-char "x")) nil)))

(ert-deftest rx-constituents ()
  (let ((rx-constituents
         (append '((beta . gamma)
                   (gamma . "a*b")
                   (delta . ((lambda (form)
                               (regexp-quote (format "<%S>" form)))
                             1 nil symbolp))
                   (epsilon . delta))
                 rx-constituents)))
    (should (equal (rx-to-string '(seq (+ beta) nonl gamma) t)
                   "\\(?:a*b\\)+.\\(?:a*b\\)"))
    (should (equal (rx-to-string '(seq (delta a b c) (* (epsilon d e))) t)
                   "\\(?:<(delta a b c)>\\)\\(?:<(epsilon d e)>\\)*"))))


(provide 'rx-tests)
