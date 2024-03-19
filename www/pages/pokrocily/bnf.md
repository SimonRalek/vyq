```c
<program> ::= <declarations>

<declarations> ::= (<declaration> ";")*
<declaration> ::= <variable-declaration> | <function-declaration> | <statement>

<variable-declaration> ::= "prm" <identifier> "=" <expression>
<function-declaration> ::= "funkce" <identifier> "()" ":" "{" <function-body> "}"

<function-body> ::= <declarations>

<statements> ::= (<statement> ";")*
<statement> ::= (<loop> | <conditional-statement> | <switch-statement> | <expression-statement> | <print-statement> | <break-statement> | <continue-statement>) ";" | <block>
<block> ::= "{" <statements> "}"

<loop> ::= <for-loop> | <while-loop> | <enhanced-for-loop>
<for-loop> ::= "opakuj" ("prm" <identifier> ("=" <expression>)? | <expression-statement> )? ";" (<expression>)? ";" (<expression>)? ":" <statement>
<while-loop> ::= "dokud" <expression> ":" <statement>
<enhanced-for-loop> ::= "opakuj jako" <identifier> <range> ("po" <numeric-expression>)? ":" <statement>
<range> ::= <numeric-expression> ".." <numeric-expression> | <numeric-expression> "dolu" <numeric-expression>

<conditional-statement> ::= "pokud" <expression> ":" <statement> ("jinak" ":" <statement>)?
<switch-statement> ::= "prepinac" <expression> ":" "{" <case-statements> <default-case>? "}"
<case-statements> ::= (<case-statement>)*
<case-statement> ::= "pripad" <expression> "->" <statement>
<default-case> ::= "jinak" "->" <statement>

<expression-statement> ::= <assignment>
<assignment> ::= <variable-access> "=" <expression>
<print-statement> ::= "tiskni" <expression>
<break-statement> ::= "zastav"
<continue-statement> ::= "pokracuj"

<expression> ::= <literal> | <unary-expression> | <binary-expression> | <grouped-expression> | <variable-access>
<literal> ::= <number> | <string> | <boolean-literal> | <list-literal>
<boolean-literal> ::= "ano" | "ne" | "nic"
<unary-expression> ::= ("-" | "!") <expression>
<binary-expression> ::= <expression> <operator> <expression>
<grouped-expression> ::= "(" <expression> ")"
<variable-access> ::= "." <identifier>

<operator> ::= "+" | "-" | "*" | "/" | "==" | "!=" | ">" | ">=" | "<" | "<=" | "&" | "|" | "^" | ">>" | "<<" | "zaroven" | "nebo"

<identifier> ::= ("." | <alpha>) (<alpha> | <digit> | "_")*
<alpha> ::= [a-zA-Z]
<digit> ::= [0-9]

<string-value> ::= <single-quoted-string> | <double-quoted-string>
<single-quoted-string> ::= "'" <single-quote-char>* "'"
<double-quoted-string> ::= '"' <double-quote-char>* '"'
<single-quote-char> ::= <any-char-except-single-quote> | <escape-sequence>
<double-quote-char> ::= <any-char-except-double-quote> | <escape-sequence>

<any-char-except-single-quote> ::= .
<any-char-except-double-quote> ::= .
<escape-sequence> ::= "\\" | "\'" | "\"" | "\t" | "\n" | "\r"
```