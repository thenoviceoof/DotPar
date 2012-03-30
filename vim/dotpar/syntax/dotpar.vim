" Vim syntax file
" Language: DotPar
" Maintainer: Sid Nair <ssn2114@columbia.edu>
" Last Change: 2012 Mar 30

" Quit when another syntax file was already loaded
if exists("b:current_syntax")
    finish
endif

syn keyword dpType boolean char number void
syn keyword dpRepeat for
syn keyword dpConditional if else elif
syn keyword dpStatement func return
syn keyword dpOperator in
syn keyword dpImport import

syn match dpBoolean 'true\|false'
syn match dpNil 'nil'

syn match dpNumber '\d\+'
syn match dpNumber '[-+]\d\+'
syn match dpNumber '\d\+\.\d+'
syn match dpNumber '[-+]\d\+\.\d+'

syn keyword dpTodo contained TODO FIXME XXX
syn match dpComment "//.*" contains=dpTodo

"TODO: string - include escape chars, make sure comments can't appear within
"TODO: multi-comment
"TODO: some matchgroup

hi def link dpType Type
hi def link dpRepeat Repeat
hi def link dpConditional Conditional
hi def link dpStatement Statement
hi def link dpOperator Operator
hi def link dpImport Include

hi def link dpBoolean Type
hi def link dpNil Type

hi def link dpNumber Number

hi def link dpTodo Todo
hi def link dpComment Comment

let b:current_syntax = "dotpar"
