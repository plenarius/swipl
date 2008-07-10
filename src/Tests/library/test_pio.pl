/*  Part of SWI-Prolog

    Author:        Ulrich Neumerkel and Jan Wielemaker
    E-mail:        J.Wielemaker@uva.nl
    WWW:           http://www.swi-prolog.org
    Copyright (C): 2008, University of Amsterdam

    This program is free software; you can redistribute it and/or
    modify it under the terms of the GNU General Public License
    as published by the Free Software Foundation; either version 2
    of the License, or (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public
    License along with this library; if not, write to the Free Software
    Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA

    As a special exception, if you link this library with other files,
    compiled with a Free Software compiler, to produce an executable, this
    library does not by itself cause the resulting executable to be covered
    by the GNU General Public License. This exception does not however
    invalidate any other reasons why the executable file might be covered by
    the GNU General Public License.
*/


:- module(test_pio, [test_pio/0]).
:- use_module(library(plunit)).
:- use_module(library(readutil)).
:- use_module(library(pio)).

test_pio :-
	run_tests([ phrase_from_file,
		    read_pending_input,
			 put_partial_codes,
			 phrase_to_file
		  ]).


:- begin_tests(phrase_from_file, []).

... --> [] | [_], ... .

seq([]) --> [].
seq([E|Es]) -->
	[E],
	seq(Es).

cfc(Content,Tmp) :-
	tmp_file(plunit_pio,Tmp),
	open(Tmp,write,Out),
	format(Out,'~s',[Content]),
	close(Out).

df(Tmp) :-
	delete_file(Tmp).

test(null, [setup(cfc("",Null)),cleanup(df(Null)) ]) :-
	phrase_from_file([],Null).
test(null, [setup(cfc("",Null)),cleanup(df(Null)), fail]) :-
	phrase_from_file("a",Null).
test(null, [setup(cfc("",Null)),cleanup(df(Null)), nondet]) :-
	phrase_from_file(([]|"a"),Null).
test(null, [setup(cfc("",Null)),cleanup(df(Null)), nondet]) :-
	phrase_from_file(("a"|[]),Null).
test(null, [setup(cfc("",Null)),cleanup(df(Null)), nondet]) :-
	phrase_from_file(...,Null).
test(null, [setup(cfc("",Null)),cleanup(df(Null))]) :-
	phrase_from_file(([],[],{true}),Null).


test(aba, [setup(cfc("aba",ABA)),cleanup(df(ABA)) ]) :-
	phrase_from_file("aba",ABA).
test(aba, [setup(cfc("aba",ABA)),cleanup(df(ABA)) ]) :-
	phrase_from_file(("aca"|"aba"),ABA).
test(aba, [setup(cfc("aba",ABA)),cleanup(df(ABA)), nondet]) :-
	phrase_from_file(("abx"|"aba"|"ada"),ABA).
test(aba, [setup(cfc("aba",ABA)),cleanup(df(ABA)) ]) :-
	phrase_from_file([A,_,A], ABA).
test(aba, [setup(cfc("aba",ABA)),cleanup(df(ABA)), nondet ]) :-
	phrase_from_file(([A],...,[A]), ABA).
test(aba, [setup(cfc("aba",ABA)),cleanup(df(ABA)), fail ]) :-
	phrase_from_file((...,[A,A],...), ABA).
test(aba, [setup(cfc("aba",ABA)),cleanup(df(ABA)), fail ]) :-
	phrase_from_file((...,"c",...), ABA).
test(aba, [setup(cfc("aba",ABA)),cleanup(df(ABA)), nondet ]) :-
	phrase_from_file((seq(Seq),...,seq(Seq)), ABA),
	Seq = [_|_].


:- end_tests(phrase_from_file).


:- begin_tests(read_pending_input, [sto(rational_trees)]).

test_pe(N, BF, Enc) :-
	tmp_file(plunit_pio, Tmp),
	call_cleanup(test_pe(N, BF, Enc, Tmp), delete_file(Tmp)).

test_pe(N, BF, Enc, Tmp) :-
	max_char(Enc, MaxChar),
	random_list(N, MaxChar, List),
	save_list(Tmp, List, Enc),
	open(Tmp, read, In, [encoding(Enc)]),
	set_stream(In, buffer_size(BF)),
	stream_to_lazy_list(In, Lazy),
	(   Lazy = List
	->  close(In)
	;   format('List: ~w~n', [List]),
	    (	last(Lazy, _)
	    ->	format('Lazy: ~w~n', [Lazy])
	    ;	format('Lazy: cannot materialize~n')
	    ),
	    close(In),
	    read_file_to_codes(Tmp, Codes, [encoding(Enc)]),
	    (	Codes == List
	    ->	format('File content ok~n')
	    ;	Codes == Lazy
	    ->	format('File content BAD, but read consistently~n')
	    ;	format('File content BAD, and read inconsistently~n')
	    ),
	    fail
	).
	    
max_char(ascii, 127).
max_char(octet, 255).
max_char(text, 0xfffff).		% Only if Locale is UTF-8!  How to test?
max_char(iso_latin_1, 255).
max_char(utf8, Max) :-
	(   current_prolog_flag(windows, true)
	->  Max = 0xffff		% UTF-16
	;   Max = 0xfffff
	).
max_char(unicode_le, 0xffff).
max_char(unicode_be, 0xffff).
max_char(wchar_t, Max) :-
	(   current_prolog_flag(windows, true)
	->  Max = 0xffff		% UTF-16
	;   Max = 0xfffff
	).


save_list(File, Codes, Enc) :-
	open(File, write, Out, [encoding(Enc)]),
	format(Out, '~s', [Codes]),
	close(Out).

%random_list(_, _, "hello\nworld\n") :- !. % debug
random_list(0, _, []) :- !.
random_list(N, Max, [H|T]) :-
	repeat,
	H is 1+random(Max-1),
	H \== 0'\r, !,
	N2 is N - 1,
	random_list(N2, Max, T).

test(ascii) :-
	test_pe(1000, 25, ascii).
test(octet) :-
	test_pe(1000, 25, octet).
test(iso_latin_1) :-
	test_pe(1000, 25, iso_latin_1).
test(utf8) :-
	test_pe(1000, 25, utf8).
test(unicode_le) :-
	test_pe(1000, 25, unicode_le).
test(unicode_be) :-
	test_pe(1000, 25, unicode_be).
test(wchar_t) :-
	test_pe(1000, 25, wchar_t).

:- end_tests(read_pending_input).

:- begin_tests(put_partial_codes, []).

test(skip, [(N,Xs)==(0,[a]),setup(open_null_stream(Stream)), cleanup(close(Stream))]) :-
	put_partial_codes(Stream, N, [a],Xs).
test(skip, [(N,Xs)==(1,[]),setup(open_null_stream(Stream)), cleanup(close(Stream))]) :-
	put_partial_codes(Stream, N, [0'a],Xs).
test(skip, [(N,Xs)==(1,Xs0),setup(open_null_stream(Stream)), cleanup(close(Stream))]) :-
	put_partial_codes(Stream, N, [0'a|Xs0],Xs).
test(skip, [(N,Xs)==(1,[X]),setup(open_null_stream(Stream)), cleanup(close(Stream))]) :-
	put_partial_codes(Stream, N, [0'a,X],Xs).

test(skip, [Xs == Xs0,setup((Xs0=[0'a|Xs0], open_null_stream(Stream))),
			  		blocked(no_floyd_yet),
			  									cleanup(close(Stream))]) :-
	put_partial_codes(Stream, N, Xs0,Xs),
	N > 0.

:- end_tests(put_partial_codes).

:- begin_tests(phrase_to_file,[]).
ed(File) :-
	( exists_file(File) -> delete_file(File) ; true ).

seq([]) --> [].
seq([E|Es]) -->
	[E],
	seq(Es).

uglynt(x,[]).  % not a real non-terminal


test(uglynt, [error(type_error(list,_)), setup(tmp_file(plunit_pio,Fichier)), cleanup(ed(Fichier))]) :-
	phrase_to_file(("abc",uglynt),Fichier).

%UWNtest(lists,[all(Xs == []), setup(tmp_file(plunit_pio,Fichier)),cleanup(ed(Fichier))]) :-
%UWN	between(0,3,L),
%UWN	length(Xs,L),
%UWN	maplist(between(0'a,0'c),Xs),
%UWN	\+ (
%UWN		  phrase_to_file(Xs, Fichier),
%UWN		  phrase_from_file(seq(Ys), Fichier),
%UWN		  Xs == Ys
%UWN		),
%UWN	!. % To keep error messages short
%UWNtest(overwrite, [setup(tmp_file(plunit_pio,Fichier)),cleanup(ed(Fichier))]) :-
%UWN	Xs = "Das ist ein Test",
%UWN	phrase_to_file((seq("Das")," ",seq("ist ein Test"),(seq("voller Unsinn"),{1=2};[])), Fichier),
%UWN	phrase_from_file(seq(Xs),Fichier).
%UWN
%UWNtest(no_commit, [error(existence_error(source_sink,Fichier)),setup(tmp_file(plunit_pio,Fichier)),cleanup(ed(Fichier))]) :-
%UWN	phrase_to_file(([];{1=2}), Fichier),
%UWN	open(Fichier,read,_).
%UWN
%UWNtest(lists,[all(Xs == []), setup(tmp_file(plunit_pio,Fichier)),cleanup(ed(Fichier))]) :-
%UWN	between(0,3,L),
%UWN	length(Xs,L),
%UWN	maplist(between(0'a,0'c),Xs),
%UWN	\+ (
%UWN		  once(phrase_to_file((seq(Xs)|{1=2}), Fichier)),
%UWN		  phrase_from_file(seq(Ys), Fichier),
%UWN		  Xs == Ys
%UWN		),
%UWN	!.
%UWN
%UWNtest(partial,[sto(rational_trees),setup(tmp_file(plunit_pio,Fichier)),cleanup(ed(Fichier))]) :-
%UWN	phrase_to_file(([A],{A=0'a}), Fichier),
%UWN	phrase_from_file("a",Fichier).
%UWNtest(partial,[setup(tmp_file(plunit_pio,Fichier)),cleanup(ed(Fichier))]) :-
%UWN	phrase_to_file(([A],seq([]),{A=0'a}), Fichier),
%UWN	phrase_from_file("a",Fichier).
%UWNtest(partial,[setup(tmp_file(plunit_pio,Fichier)),cleanup(ed(Fichier))]) :-
%UWN	phrase_to_file(([A,B],seq([]),{A=0'a,B=0'b}), Fichier),
%UWN	phrase_from_file("ab",Fichier).
%UWN
%UWNtest(incomplete, [error(representation_error(_)),setup(tmp_file(plunit_pio,Fichier))]) :-
%UWN	phrase_to_file([_],Fichier).
%UWN
:- end_tests(phrase_to_file).

