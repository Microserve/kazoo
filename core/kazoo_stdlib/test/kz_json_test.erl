%%%-------------------------------------------------------------------
%%% @copyright (C) 2011-2017, 2600Hz
%%% @doc
%%% proplists-like interface to json objects
%%% @end
%%% @contributors
%%%   Karl Anderson
%%%   James Aimonetti
%%%-------------------------------------------------------------------
-module(kz_json_test).

-include_lib("kazoo_stdlib/include/kazoo_json.hrl").

-ifdef(PROPER).
-include_lib("proper/include/proper.hrl").
-endif.
-include_lib("eunit/include/eunit.hrl").

%% PropEr Testing
-ifdef(PROPER).

is_json_object_proper_test_() ->
    {"Runs kz_json PropEr tests"
    ,{'timeout'
     ,10000
     ,[?_assertEqual([], proper:module(?MODULE, [{'to_file', 'user'}
                                                ,{'numtests', 500}
                                                ]
                                      ))
      ]
     }
    }.

prop_is_object() ->
    ?FORALL(JObj
           ,object()
           ,?WHENFAIL(io:format("Failed is_json_object with ~p~n", [JObj])
                     ,kz_json:is_json_object(JObj)
                     )
           ).

prop_from_list() ->
    ?FORALL(Prop
           ,json_proplist()
           ,?WHENFAIL(io:format("Failed prop_from_list with ~p~n", [Prop])
                     ,kz_json:is_json_object(kz_json:from_list(Prop))
                     )
           ).

prop_get_value() ->
    ?FORALL(Prop
           ,json_proplist()
           ,?WHENFAIL(io:format("Failed prop_get_value with ~p~n", [Prop])
                     ,begin
                          JObj = kz_json:from_list(Prop),
                          case length(Prop) > 0
                              andalso hd(Prop)
                          of
                              {K,V} ->
                                  V =:= kz_json:get_value([K], JObj, V);
                              'false' -> kz_json:new() =:= JObj
                          end
                      end)
           ).

prop_set_value() ->
    ?FORALL({JObj, Key, Value}
           ,{object(), keys(), json_term()}
           ,?WHENFAIL(io:format("Failed prop_set_value with ~p:~p -> ~p~n", [Key, Value, JObj]),
                      begin
                          JObj1 = kz_json:set_value(Key, Value, JObj),
                          Value =:= kz_json:get_value(Key, JObj1, Value)
                      end)
           ).

prop_to_proplist() ->
    ?FORALL(Prop, json_proplist(),
            ?WHENFAIL(io:format("Failed prop_to_proplist ~p~n", [Prop]),
                      begin
                          JObj = kz_json:from_list(Prop),
                          lists:all(fun(K) -> props:get_value(K, Prop) =/= 'undefined' end, kz_json:get_keys(JObj))
                      end)
           ).

prop_flatten_expand() ->
    ?FORALL(JObj
           ,test_object()
           ,?WHENFAIL(io:format("Failed to flatten/expand: ~p~n", [JObj])
                     ,kz_json:are_equal(JObj, kz_json:expand(kz_json:flatten(JObj)))
                     )
           ).

prop_expand_flatten() ->
    ?FORALL(Prop
           ,flat_proplist()
           ,begin
                L = props:unique(Prop),
                JObj = kz_json:from_list(L),
                ?WHENFAIL(io:format("Failed to expand/flatten: ~p~n", [JObj])
                         ,JObj =:= kz_json:flatten(kz_json:expand(JObj))
                         )
            end
           ).

prop_merge_right() ->
    ?FORALL({LeftJObj, RightJObj}
           ,{test_object(), test_object()}
           ,begin
                MergedJObj = kz_json:merge(fun kz_json:merge_right/2, LeftJObj, RightJObj),

                ?WHENFAIL(io:format("Failed to merge (~p, ~p)~nmerge/2: ~p~n"
                                   ,[LeftJObj, RightJObj, MergedJObj]
                                   )
                         ,are_all_properties_found(MergedJObj, RightJObj)
                         )
            end
           ).

prop_merge_left() ->
    ?FORALL({LeftJObj, RightJObj}
           ,{test_object(), test_object()}
           ,begin
                MergedJObj = kz_json:merge(fun kz_json:merge_left/2, LeftJObj, RightJObj),

                ?WHENFAIL(io:format("Failed to merge (~p, ~p)~nmerge/2: ~p~n"
                                   ,[LeftJObj, RightJObj, MergedJObj]
                                   )
                         ,are_all_properties_found(MergedJObj, LeftJObj)
                         )
            end
           ).

test_object() ->
    ?LET(JObj, object(), remove_duplicate_keys(JObj)).

remove_duplicate_keys(?EMPTY_JSON_OBJECT) -> ?EMPTY_JSON_OBJECT;
remove_duplicate_keys(?JSON_WRAPPER(_)=JObj) ->
    kz_json:foldl(fun no_dups/3, kz_json:new(), JObj);
remove_duplicate_keys(V) -> V.

no_dups(Key, ?JSON_WRAPPER(_)=JObj, Acc) ->
    DeDuped = remove_duplicate_keys(JObj),
    kz_json:set_value(Key, DeDuped, Acc);
no_dups(Key, Value, Acc) ->
    kz_json:set_value(Key, Value, Acc).

are_all_properties_found(Merged, Favored) ->
    kz_json:all(fun({K,V}) -> is_property_found(K, V, Merged) end, Favored).

is_property_found(Key, ?JSON_WRAPPER(_)=Value, Merged) ->
    case kz_json:get_value(Key, Merged) of
        ?JSON_WRAPPER(_)=MergedV -> are_all_properties_found(Value, MergedV);
        Missing ->
            log_failure(Key, Value, Missing),
            'false'
    end;
is_property_found(Key, Value, Merged) ->
    case kz_json:get_value(Key, Merged) of
        Value -> 'true';
        Missing ->
            log_failure(Key, Value, Missing),
            'false'
    end.

log_failure(Key, Value, Missing) ->
    ?debugFmt("failed to find ~p~nexpected: ~p~nfound: ~p~n", [Key, Value, Missing]).

-endif.

-define(D1, ?JSON_WRAPPER([{<<"d1k1">>, <<"d1v1">>}
                          ,{<<"d1k2">>, 'd1v2'}
                          ,{<<"d1k3">>, [<<"d1v3.1">>, <<"d1v3.2">>, <<"d1v3.3">>]}
                          ])).
-define(D1_MERGE, ?JSON_WRAPPER([{<<"d1k1">>, 'd2k2'}
                                ,{<<"d1k2">>, 'd1v2'}
                                ,{<<"d1k3">>, [<<"d1v3.1">>, <<"d1v3.2">>, <<"d1v3.3">>]}
                                ])).
-define(D2, ?JSON_WRAPPER([{<<"d2k1">>, 1}
                          ,{<<"d2k2">>, 3.14}
                          ,{<<"sub_d1">>, ?D1}
                          ])).
-define(D2_MERGE, ?JSON_WRAPPER([{<<"d2k1">>, 1}
                                ,{<<"d2k2">>, 3.14}
                                ,{<<"sub_d1">>, ?D1_MERGE}
                                ,{<<"blip">>, ?JSON_WRAPPER([{<<"blop">>, null}])}
                                ])).

-define(D3, ?JSON_WRAPPER([{<<"d3k1">>, <<"d3v1">>}
                          ,{<<"d3k2">>, []}
                          ,{<<"sub_docs">>, [?D1, ?D2]}
                          ])).
-define(D4, [?D1, ?D2, ?D3]).

-define(D6, ?JSON_WRAPPER([{<<"d2k1">>, 1}
                          ,{<<"d2k2">>, 3.14}
                          ,{<<"sub_d1">>, ?JSON_WRAPPER([{<<"d1k1">>, <<"d1v1">>}])}
                          ]
                         )).
-define(D7, ?JSON_WRAPPER([{<<"d1k1">>, <<"d1v1">>}])).

-define(SP, kz_json:decode(<<"{\"plan\":{\"phone_numbers\":{\"did_us\":{\"discounts\":{\"cumulative\":{\"rate\":1}}}}}}">>)).
-define(O, kz_json:decode(<<"{\"phone_numbers\":{\"did_us\":{\"discounts\":{\"cumulative\":{\"rate\":20}}}}}">>)).

merge_recursive_overrides_test_() ->
    AP = kz_json:merge_recursive(?SP, kz_json:from_list([{<<"plan">>, ?O}])),

    Key = [<<"plan">>, <<"phone_numbers">>, <<"did_us">>, <<"discounts">>, <<"cumulative">>, <<"rate">>],

    [?_assertEqual(1, kz_json:get_value(Key, ?SP))
    ,?_assertEqual(20, kz_json:get_value(Key, AP))
    ].

merge_overrides_test_() ->
    %% default merges left onto right
    Left = kz_json:merge(fun kz_json:merge_left/2, ?SP, kz_json:from_list([{<<"plan">>, ?O}])),
    Right = kz_json:merge(fun kz_json:merge_right/2, ?SP, kz_json:from_list([{<<"plan">>, ?O}])),

    Key = [<<"plan">>, <<"phone_numbers">>, <<"did_us">>, <<"discounts">>, <<"cumulative">>, <<"rate">>],

    [?_assertEqual(1, kz_json:get_value(Key, ?SP))
    ,?_assertEqual(20, kz_json:get_value(Key, Right))
    ,?_assertEqual(1, kz_json:get_value(Key, Left))
    ].

is_empty_test_() ->
    [?_assertEqual('true', kz_json:is_empty(kz_json:new()))
    ,?_assertEqual('false', kz_json:is_empty(?D1))
    ,?_assertEqual('false', kz_json:is_empty(?D6))
    ,?_assertEqual('false', kz_json:is_empty(123))
    ,?_assertEqual('false', kz_json:is_empty(<<"foobar">>))
    ,?_assertEqual('false', kz_json:is_empty([{'bar', 'bas'}]))
    ].

merge_jobjs_test_() ->
    JObj = kz_json:merge_jobjs(?D1, ?D2),
    [?_assertEqual('true', 'undefined' =/= kz_json:get_value(<<"d1k1">>, JObj))
    ,?_assertEqual('true', 'undefined' =/= kz_json:get_value(<<"d2k1">>, JObj))
    ,?_assertEqual('true', 'undefined' =/= kz_json:get_value(<<"sub_d1">>, JObj))
    ,?_assertEqual('true', 'undefined' =:= kz_json:get_value(<<"missing_k">>, JObj))
    ].

merge_recursive_test_() ->
    Base = kz_json:set_value([<<"blip">>, <<"blop">>], 42, ?D2),
    New = ?D2_MERGE,
    JObj = kz_json:merge_recursive(Base, New),
    JObj1 = kz_json:merge_recursive([Base, New]),
    lists:flatmap(fun do_merge_recursive/1, [JObj, JObj1]).

merge_test_() ->
    Base = kz_json:set_value([<<"blip">>, <<"blop">>], 42, ?D2),
    New = ?D2_MERGE,
    JObj = kz_json:merge(Base, New),
    JObj1 = kz_json:merge([Base, New]),
    lists:flatmap(fun do_merge_recursive/1, [JObj, JObj1]).

do_merge_recursive(J) ->
    [?_assertEqual('true', kz_json:is_json_object(J))
    ,?_assertEqual('undefined', kz_json:get_value(<<"d1k1">>, J))
    ,?_assertEqual(1, kz_json:get_value(<<"d2k1">>, J))

    ,?_assertEqual('true', 'undefined' =/= kz_json:get_value(<<"sub_d1">>, J))

     %% second JObj takes precedence
    ,?_assertEqual('d2k2',  kz_json:get_value([<<"sub_d1">>, <<"d1k1">>], J))
    ,?_assertEqual('undefined', kz_json:get_value(<<"missing_k">>, J))

    ,?_assertEqual('true', kz_json:is_empty(kz_json:get_value(<<"blip">>, J)))
    ].

get_binary_value_test_() ->
    [?_assertEqual('true', is_binary(kz_json:get_binary_value(<<"d1k1">>, ?D1)))
    ,?_assertEqual('undefined', kz_json:get_binary_value(<<"d2k1">>, ?D1))
    ,?_assertEqual('true', is_binary(kz_json:get_binary_value(<<"d1k1">>, ?D1, <<"something">>)))
    ,?_assertEqual(<<"something">>, kz_json:get_binary_value(<<"d2k1">>, ?D1, <<"something">>))
    ].

get_integer_value_test_() ->
    [?_assertEqual(1, kz_json:get_integer_value(<<"d2k1">>, ?D2))
    ,?_assertEqual('undefined', kz_json:get_integer_value(<<"d1k1">>, ?D2))
    ,?_assertEqual(1, kz_json:get_integer_value(<<"d2k1">>, ?D2, 0))
    ,?_assertEqual(0, kz_json:get_integer_value(<<"d1k1">>, ?D2, 0))
    ].

get_float_value_test_() ->
    [?_assertEqual('true', is_float(kz_json:get_float_value(<<"d2k2">>, ?D2)))
    ,?_assertEqual('undefined', kz_json:get_float_value(<<"d1k1">>, ?D2))
    ,?_assertEqual(3.14, kz_json:get_float_value(<<"d2k2">>, ?D2, 0.0))
    ,?_assertEqual(0.0, kz_json:get_float_value(<<"d1k1">>, ?D2, 0.0))
    ].

get_binary_boolean_test_() ->
    [?_assertEqual('undefined', kz_json:get_binary_boolean(<<"d1k1">>, ?D2))
    ,?_assertEqual(<<"false">>, kz_json:get_binary_boolean(<<"a_key">>, ?JSON_WRAPPER([{<<"a_key">>, 'false'}])))
    ,?_assertEqual(<<"true">>, kz_json:get_binary_boolean(<<"a_key">>, ?JSON_WRAPPER([{<<"a_key">>, 'true'}])))
    ].

is_false_test_() ->
    [?_assertEqual('false', kz_json:is_false(<<"d1k1">>, ?D1))
    ,?_assertEqual('true', kz_json:is_false(<<"a_key">>, ?JSON_WRAPPER([{<<"a_key">>, 'false'}])))
    ].

is_true_test_() ->
    [?_assertEqual('false', kz_json:is_true(<<"d1k1">>, ?D1))
    ,?_assertEqual('true', kz_json:is_true(<<"a_key">>, ?JSON_WRAPPER([{<<"a_key">>, 'true'}])))
    ].

-define(D1_FILTERED, ?JSON_WRAPPER([{<<"d1k2">>, 'd1v2'}, {<<"d1k3">>, [<<"d1v3.1">>, <<"d1v3.2">>, <<"d1v3.3">>]}])).
-define(D2_FILTERED, ?JSON_WRAPPER([{<<"sub_d1">>, ?D1}])).
-define(D3_FILTERED, ?JSON_WRAPPER([{<<"d3k1">>, <<"d3v1">>}, {<<"d3k2">>, []}, {<<"sub_docs">>, [?D1, ?D2_FILTERED]}])).
filter_test_() ->
    [?_assertEqual(?D1_FILTERED, kz_json:filter(fun({<<"d1k1">>, _}) -> 'false'; (_) -> 'true' end, ?D1))
    ,?_assertEqual(?D2_FILTERED, kz_json:filter(fun({_, V}) when is_number(V) -> 'false'; (_) -> 'true' end, ?D2))
    ,?_assertEqual(?D3_FILTERED, kz_json:filter(fun({_, V}) when is_number(V) -> 'false'; (_) -> 'true' end, ?D3, [<<"sub_docs">>, 2]))
    ].

new_test() ->
    ?assertEqual(?EMPTY_JSON_OBJECT, kz_json:new()).

is_json_object_test_() ->
    [?_assertEqual('false', kz_json:is_json_object('foo'))
    ,?_assertEqual('false', kz_json:is_json_object(123))
    ,?_assertEqual('false', kz_json:is_json_object(['boo', 'yah']))
    ,?_assertEqual('false', kz_json:is_json_object(<<"bin">>))

    ,?_assertEqual('true', kz_json:is_json_object(?D1))
    ,?_assertEqual('true', kz_json:is_json_object(?D2))
    ,?_assertEqual('true', kz_json:is_json_object(?D3))
    ,?_assertEqual('true', lists:all(fun kz_json:is_json_object/1, ?D4))
    ,?_assertEqual('true', kz_json:is_json_object(?D6))
    ,?_assertEqual('true', kz_json:is_json_object(?D7))
    ].

%% delete results
-define(D1_AFTER_K1, ?JSON_WRAPPER([{<<"d1k2">>, 'd1v2'}, {<<"d1k3">>, [<<"d1v3.1">>, <<"d1v3.2">>, <<"d1v3.3">>]}])).
-define(D1_AFTER_K3_V2, ?JSON_WRAPPER([{<<"d1k3">>, [<<"d1v3.1">>, <<"d1v3.3">>]}, {<<"d1k1">>, <<"d1v1">>}, {<<"d1k2">>, 'd1v2'}])).

-define(D6_AFTER_SUB, ?JSON_WRAPPER([{<<"sub_d1">>, ?EMPTY_JSON_OBJECT}
                                    ,{<<"d2k1">>, 1}
                                    ,{<<"d2k2">>, 3.14}
                                    ]
                                   )).
-define(D6_AFTER_SUB_PRUNE, ?JSON_WRAPPER([{<<"d2k1">>, 1}
                                          ,{<<"d2k2">>, 3.14}
                                          ]
                                         )).

-define(P1, [{<<"d1k1">>, <<"d1v1">>}, {<<"d1k2">>, d1v2}, {<<"d1k3">>, [<<"d1v3.1">>, <<"d1v3.2">>, <<"d1v3.3">>]}]).
-define(P2, [{<<"d2k1">>, 1}, {<<"d2k2">>, 3.14}, {<<"sub_d1">>, ?JSON_WRAPPER(?P1)}]).
-define(P3, [{<<"d3k1">>, <<"d3v1">>}, {<<"d3k2">>, []}, {<<"sub_docs">>, [?JSON_WRAPPER(?P1), ?JSON_WRAPPER(?P2)]}]).
-define(P4, [?P1, ?P2, ?P3]).
-define(P6, [{<<"d2k1">>, 1},{<<"d2k2">>, 3.14},{<<"sub_d1">>, ?JSON_WRAPPER([{<<"d1k1">>, <<"d1v1">>}])}]).
-define(P7, [{<<"d1k1">>, <<"d1v1">>}]).

-define(P8, [{<<"d1k1">>, <<"d1v1">>}, {<<"d1k2">>, 'd1v2'}, {<<"d1k3">>, [<<"d1v3.1">>, <<"d1v3.2">>, <<"d1v3.3">>]}]).
-define(P9, [{<<"d2k1">>, 1}, {<<"d2k2">>, 3.14}, {<<"sub_d1">>, ?P1}]).
-define(P10, [{<<"d3k1">>, <<"d3v1">>}, {<<"d3k2">>, []}, {<<"sub_docs">>, [?P8, ?P9]}]).
-define(P11, [?P8, ?P9, ?P10]).
-define(P12, [{<<"d2k1">>, 1}, {<<"d2k2">>, 3.14},{<<"sub_d1">>, [{<<"d1k1">>, <<"d1v1">>}]}]).
-define(P13, [{<<"d1k1">>, <<"d1v1">>}]).

%% deleting [k1, 1] should return empty json object
-define(D_ARR, ?JSON_WRAPPER([{<<"k1">>, [1]}])).
-define(P_ARR, ?JSON_WRAPPER([{<<"k1">>, []}])).

get_keys_test_() ->
    Keys = [<<"d1k1">>, <<"d1k2">>, <<"d1k3">>],
    [?_assertEqual('true', lists:all(fun(K) -> lists:member(K, Keys) end, kz_json:get_keys([], ?D1)))
    ,?_assertEqual('true', lists:all(fun(K) -> lists:member(K, Keys) end, kz_json:get_keys([<<"sub_docs">>, 1], ?D3)))
    ,?_assertEqual('true', lists:all(fun(K) -> lists:member(K, [1,2,3]) end, kz_json:get_keys([<<"sub_docs">>], ?D3)))
    ].

to_proplist_test_() ->
    [?_assertEqual(?P1, kz_json:to_proplist(?D1))
    ,?_assertEqual(?P2, kz_json:to_proplist(?D2))
    ,?_assertEqual(?P3, kz_json:to_proplist(?D3))
    ,?_assertEqual(?P4, lists:map(fun kz_json:to_proplist/1, ?D4))
    ,?_assertEqual(?P6, kz_json:to_proplist(?D6))
    ,?_assertEqual(?P7, kz_json:to_proplist(?D7))
    ].

recursive_to_proplist_test_() ->
    [?_assertEqual(?P8, kz_json:recursive_to_proplist(?D1))
    ,?_assertEqual(?P9, kz_json:recursive_to_proplist(?D2))
    ,?_assertEqual(?P10, kz_json:recursive_to_proplist(?D3))
    ,?_assertEqual(?P11, lists:map(fun kz_json:recursive_to_proplist/1, ?D4))
    ,?_assertEqual(?P12, kz_json:recursive_to_proplist(?D6))
    ,?_assertEqual(?P13, kz_json:recursive_to_proplist(?D7))
    ].

delete_key_test_() ->
    [?_assertEqual(?EMPTY_JSON_OBJECT, kz_json:delete_key(<<"foo">>, ?EMPTY_JSON_OBJECT))
    ,?_assertEqual(?EMPTY_JSON_OBJECT, kz_json:delete_key(<<"foo">>, ?EMPTY_JSON_OBJECT, 'prune'))
    ,?_assertEqual(?EMPTY_JSON_OBJECT, kz_json:delete_key([<<"foo">>], ?EMPTY_JSON_OBJECT))
    ,?_assertEqual(?EMPTY_JSON_OBJECT, kz_json:delete_key([<<"foo">>], ?EMPTY_JSON_OBJECT, 'prune'))
    ,?_assertEqual(?EMPTY_JSON_OBJECT, kz_json:delete_key([<<"foo">>, <<"bar">>], ?EMPTY_JSON_OBJECT))
    ,?_assertEqual(?EMPTY_JSON_OBJECT, kz_json:delete_key([<<"foo">>, <<"bar">>], ?EMPTY_JSON_OBJECT, 'prune'))
    ,?_assertEqual(?EMPTY_JSON_OBJECT, kz_json:delete_key([<<"d1k1">>], ?D7))
    ,?_assertEqual(?EMPTY_JSON_OBJECT, kz_json:delete_key([<<"d1k1">>], ?D7, 'prune'))
    ,?_assertEqual(?D1_AFTER_K1, kz_json:delete_key([<<"d1k1">>], ?D1))
    ,?_assertEqual(?D1_AFTER_K1, kz_json:delete_key([<<"d1k1">>], ?D1, 'prune'))
    ,?_assertEqual(?D1_AFTER_K3_V2, kz_json:delete_key([<<"d1k3">>, 2], ?D1))
    ,?_assertEqual(?D1_AFTER_K3_V2, kz_json:delete_key([<<"d1k3">>, 2], ?D1, 'prune'))
    ,?_assertEqual(?D6_AFTER_SUB, kz_json:delete_key([<<"sub_d1">>, <<"d1k1">>], ?D6))
    ,?_assertEqual(?D6_AFTER_SUB_PRUNE, kz_json:delete_key([<<"sub_d1">>, <<"d1k1">>], ?D6, 'prune'))
    ,?_assertEqual(?P_ARR, kz_json:delete_key([<<"k1">>, 1], ?D_ARR))
    ,?_assertEqual(?EMPTY_JSON_OBJECT, kz_json:delete_key([<<"k1">>, 1], ?D_ARR, 'prune'))
    ].

get_value_test_() ->
    %% Basic first level key
    [?_assertEqual('undefined', kz_json:get_value([<<"d1k1">>], ?EMPTY_JSON_OBJECT))
    ,?_assertEqual(<<"d1v1">>, kz_json:get_value([<<"d1k1">>], ?D1))
    ,?_assertEqual('undefined', kz_json:get_value([<<"d1k1">>], ?D2))
    ,?_assertEqual('undefined', kz_json:get_value([<<"d1k1">>], ?D3))
    ,?_assertEqual('undefined', kz_json:get_value([<<"d1k1">>], ?D4))
     %% Basic nested key
    ,?_assertEqual('undefined', kz_json:get_value([<<"sub_d1">>, <<"d1k2">>], ?EMPTY_JSON_OBJECT))
    ,?_assertEqual('undefined', kz_json:get_value([<<"sub_d1">>, <<"d1k2">>], ?D1))
    ,?_assertEqual('d1v2',      kz_json:get_value([<<"sub_d1">>, <<"d1k2">>], ?D2))
    ,?_assertEqual('undefined', kz_json:get_value([<<"sub_d1">>, <<"d1k2">>], ?D3))
    ,?_assertEqual('undefined', kz_json:get_value([<<"sub_d1">>, <<"d1k2">>], ?D4))
     %% Get the value in an object in an array in another object that is part of
     %% an array of objects
    ,?_assertEqual('undefined', kz_json:get_value([3, <<"sub_docs">>, 2, <<"d2k2">>], ?EMPTY_JSON_OBJECT))
    ,?_assertEqual('undefined', kz_json:get_value([3, <<"sub_docs">>, 2, <<"d2k2">>], ?D1))
    ,?_assertEqual('undefined', kz_json:get_value([3, <<"sub_docs">>, 2, <<"d2k2">>], ?D2))
    ,?_assertEqual('undefined', kz_json:get_value([3, <<"sub_docs">>, 2, <<"d2k2">>], ?D3))
    ,?_assertEqual(3.14,      kz_json:get_value([3, <<"sub_docs">>, 2, <<"d2k2">>], ?D4))
     %% Get the value in an object in an array in another object that is part of
     %% an array of objects, but change the default return if it is not present.
     %% Also tests the ability to have indexs represented as strings
    ,?_assertEqual(<<"not">>, kz_json:get_value([3, <<"sub_docs">>, <<"2">>, <<"d2k2">>], [], <<"not">>))
    ,?_assertEqual(<<"not">>, kz_json:get_value([3, <<"sub_docs">>, <<"2">>, <<"d2k2">>], ?D1, <<"not">>))
    ,?_assertEqual(<<"not">>, kz_json:get_value([3, <<"sub_docs">>, <<"2">>, <<"d2k2">>], ?D2, <<"not">>))
    ,?_assertEqual(<<"not">>, kz_json:get_value([3, <<"sub_docs">>, <<"2">>, <<"d2k2">>], ?D3, <<"not">>))
    ,?_assertEqual(3.14,      kz_json:get_value([3, <<"sub_docs">>, 2, <<"d2k2">>], ?D4, <<"not">>))
    ].

-define(T2R1, ?JSON_WRAPPER([{<<"d1k1">>, <<"d1v1">>}, {<<"d1k2">>, <<"update">>}, {<<"d1k3">>, [<<"d1v3.1">>, <<"d1v3.2">>, <<"d1v3.3">>]}])).
-define(T2R2, ?JSON_WRAPPER([{<<"d1k1">>, <<"d1v1">>}, {<<"d1k2">>, d1v2}, {<<"d1k3">>, [<<"d1v3.1">>, <<"d1v3.2">>, <<"d1v3.3">>]}, {<<"d1k4">>, 'new_value'}])).
-define(T2R3, ?JSON_WRAPPER([{<<"d1k1">>, <<"d1v1">>}, {<<"d1k2">>, ?JSON_WRAPPER([{<<"new_key">>, 'added_value'}])}, {<<"d1k3">>, [<<"d1v3.1">>, <<"d1v3.2">>, <<"d1v3.3">>]}])).
-define(T2R4, ?JSON_WRAPPER([{<<"d1k1">>, <<"d1v1">>}, {<<"d1k2">>, d1v2}, {<<"d1k3">>, [<<"d1v3.1">>, <<"d1v3.2">>, <<"d1v3.3">>]}, {<<"d1k4">>, ?JSON_WRAPPER([{<<"new_key">>, 'added_value'}])}])).

set_value_object_test_() ->
    %% Test setting an existing key
    [?_assertEqual(?T2R1, kz_json:set_value([<<"d1k2">>], <<"update">>, ?D1))
     %% Test setting a non-existing key
    ,?_assertEqual(?T2R2, kz_json:set_value([<<"d1k4">>], 'new_value', ?D1))
     %% Test setting an existing key followed by a non-existant key
    ,?_assertEqual(?T2R3, kz_json:set_value([<<"d1k2">>, <<"new_key">>], 'added_value', ?D1))
     %% Test setting a non-existing key followed by another non-existant key
    ,?_assertEqual(?T2R4, kz_json:set_value([<<"d1k4">>, <<"new_key">>], 'added_value', ?D1))
    ].

-define(D5,   [?JSON_WRAPPER([{<<"k1">>, 'v1'}]), ?JSON_WRAPPER([{<<"k2">>, 'v2'}])]).
-define(T3R1, [?JSON_WRAPPER([{<<"k1">>,'test'}]),?JSON_WRAPPER([{<<"k2">>,'v2'}])]).
-define(T3R2, [?JSON_WRAPPER([{<<"k1">>,'v1'},{<<"pi">>, 3.14}]),?JSON_WRAPPER([{<<"k2">>,'v2'}])]).
-define(T3R3, [?JSON_WRAPPER([{<<"k1">>,'v1'},{<<"callerid">>,?JSON_WRAPPER([{<<"name">>,<<"2600hz">>}])}]),?JSON_WRAPPER([{<<"k2">>,'v2'}])]).
-define(T3R4, [?JSON_WRAPPER([{<<"k1">>,'v1'}]),?JSON_WRAPPER([{<<"k2">>,<<"updated">>}])]).
-define(T3R5, [?JSON_WRAPPER([{<<"k1">>,'v1'}]),?JSON_WRAPPER([{<<"k2">>,'v2'}]),?JSON_WRAPPER([{<<"new_key">>,<<"added">>}])]).

set_value_multiple_object_test_() ->
    %% Set an existing key in the first kz_json:object()
    [?_assertEqual(?T3R1, kz_json:set_value([1, <<"k1">>], 'test', ?D5))
     %% Set a non-existing key in the first kz_json:object()
    ,?_assertEqual(?T3R2, kz_json:set_value([1, <<"pi">>], 3.14, ?D5))
     %% Set a non-existing key followed by another non-existant key in the first kz_json:object()
    ,?_assertEqual(?T3R3, kz_json:set_value([1, <<"callerid">>, <<"name">>], <<"2600hz">>, ?D5))
     %% Set an existing key in the second kz_json:object()
    ,?_assertEqual(?T3R4, kz_json:set_value([2, <<"k2">>], <<"updated">>, ?D5))
     %% Set a non-existing key in a non-existing kz_json:object()
    ,?_assertEqual(?T3R5, kz_json:set_value([3, <<"new_key">>], <<"added">>, ?D5))
    ].

%% <<"ÀÁÂÃÄÅÆÇÈÉÊËÌÍÎÏÐÑÒÓÔÕÖ"
-define(T4R1,  ?JSON_WRAPPER([{<<"Caller-ID">>, 1234},{list_to_binary(lists:seq(16#C0, 16#D6)), <<"Smith">>} ])).
%% <<"àáâãäåæçèéêëìíîïðñòóôõö"
-define(T4R1V, ?JSON_WRAPPER([{<<"caller_id">>, 1234},{list_to_binary(lists:seq(16#E0, 16#F6)), <<"Smith">>} ])).
%% <<"ØÙÚÛÜÝÞ"
-define(T5R1,  ?JSON_WRAPPER([{<<"Caller-ID">>, 1234},{list_to_binary(lists:seq(16#D8, 16#DE)), <<"Smith">>} ])).
%% <<"øùúûüýþ"
-define(T5R1V, ?JSON_WRAPPER([{<<"caller_id">>, 1234},{list_to_binary(lists:seq(16#F8, 16#FE)), <<"Smith">>} ])).

-define(T4R2,  ?JSON_WRAPPER([{<<"Account-ID">>, <<"45AHGJDF8DFDS2130S">>}, {<<"TRUNK">>, 'false'}, {<<"Node1">>, ?T4R1 }, {<<"Node2">>, ?T4R1 }])).
-define(T4R2V, ?JSON_WRAPPER([{<<"account_id">>, <<"45AHGJDF8DFDS2130S">>}, {<<"trunk">>, 'false'}, {<<"node1">>, ?T4R1V}, {<<"node2">>, ?T4R1V}])).
-define(T4R3,  ?JSON_WRAPPER([{<<"Node-1">>, ?JSON_WRAPPER([{<<"Node-2">>, ?T4R2  }])}, {<<"Another-Node">>, ?T4R1 }] )).
-define(T4R3V, ?JSON_WRAPPER([{<<"node_1">>, ?JSON_WRAPPER([{<<"node_2">>, ?T4R2V }])}, {<<"another_node">>, ?T4R1V}] )).
-define(T5R3,  ?JSON_WRAPPER([{<<"Node-1">>, ?JSON_WRAPPER([{<<"Node-2">>, null}])}, {<<"Another-Node">>, ?T4R1 }] )).
-define(T5R3V, ?JSON_WRAPPER([{<<"node_1">>, ?JSON_WRAPPER([                    ])}, {<<"another_node">>, ?T4R1V}] )).

set_value_normalizer_test_() ->
    %% Normalize a flat JSON object
    [?_assertEqual(kz_json:normalize_jobj(?T4R1), ?T4R1V)
     %% Normalize a single nested JSON objects
    ,?_assertEqual(kz_json:normalize_jobj(?T4R2), ?T4R2V)
     %% Normalize multiple nested JSON objects
    ,?_assertEqual(kz_json:normalize_jobj(?T4R3), ?T4R3V)
    ,?_assertEqual(kz_json:normalize_jobj(?T5R3), ?T5R3V)

    ,?_assertEqual(kz_json:normalize_jobj(?T5R1), ?T5R1V)
    ].

-define(D1_values, [<<"d1v1">>
                   ,'d1v2'
                   ,[<<"d1v3.1">>, <<"d1v3.2">>, <<"d1v3.3">>]
                   ]).

get_values_test() ->
    {Values, Keys} = kz_json:get_values(?D1),
    ?assertEqual('true', are_all_there(Values
                                      ,Keys
                                      ,?D1_values
                                      ,[<<"d1k1">>, <<"d1k2">>, <<"d1k3">>]
                                      )).

values_test() ->
    Values = kz_json:values(?D1),
    ?assertEqual('true', are_all_there(Values, [], ?D1_values, [])).

are_all_there(Values, Keys, Vs, Ks) ->
    lists:all(fun(K) -> lists:member(K, Keys) end, Ks)
        andalso lists:all(fun(V) -> lists:member(V, Values) end, Vs).

-define(K3_JOBJ, ?JSON_WRAPPER([{<<"k3.1">>, <<"v3.1">>}])).
-define(CODEC_JOBJ, ?JSON_WRAPPER([{<<"k1">>, <<"v1">>}
                                  ,{<<"k2">>, ?EMPTY_JSON_OBJECT}
                                  ,{<<"k3">>, ?K3_JOBJ}
                                  ,{<<"k4">>, [1,2,3]}
                                  ])).
codec_test() ->
    ?assertEqual(?CODEC_JOBJ, kz_json:decode(kz_json:encode(?CODEC_JOBJ))).

find_value_test_() ->
    JObjs = kz_json:decode(<<"[{\"k1\":\"v1\"},{\"k1\":\"v2\"}]">>),
    [?_assertEqual(<<"{\"k1\":\"v1\"}">>, kz_json:encode(kz_json:find_value(<<"k1">>, <<"v1">>, JObjs)))
    ,?_assertEqual(<<"{\"k1\":\"v2\"}">>, kz_json:encode(kz_json:find_value(<<"k1">>, <<"v2">>, JObjs)))
    ,?_assertEqual('undefined', kz_json:find_value(<<"k1">>, <<"v3">>, JObjs))
    ].

insert_value_test_() ->
    JObj = kz_json:decode(<<"{\"k1\":\"v1\",\"k2\":\"v2\"}">>),
    NonInsert = kz_json:insert_value(<<"k1">>, <<"v3">>, JObj),
    Insert = kz_json:insert_value(<<"k3">>, <<"v3">>, JObj),
    [?_assertEqual(<<"v1">>, kz_json:get_value(<<"k1">>, NonInsert))
    ,?_assertEqual(<<"v3">>, kz_json:get_value(<<"k3">>, Insert))
    ].

insert_values_test_() ->
    JObj = kz_json:decode(<<"{\"k1\":\"v1\",\"k2\":\"v2\"}">>),
    NonInsert = kz_json:insert_values([{<<"k1">>, <<"v3">>}], JObj),
    Insert = kz_json:insert_values([{<<"k3">>, <<"v3">>}], JObj),
    [?_assertEqual(<<"v1">>, kz_json:get_value(<<"k1">>, NonInsert))
    ,?_assertEqual(<<"v3">>, kz_json:get_value(<<"k3">>, Insert))
    ].

get_ne_json_object_test_() ->
    JObj = kz_json:decode(<<"{\"k1\":\"v1\",\"k2\":\"v2\",\"o1\":{\"k3\":\"v3\"},\"o2\":{}}">>),
    [?_assertEqual('undefined'
                  ,kz_json:get_ne_json_value(<<"k1">>, JObj)
                  )
    ,?_assertEqual(?JSON_WRAPPER([{<<"k3">>, <<"v3">>}])
                  ,kz_json:get_ne_json_value(<<"o1">>, JObj)
                  )
    ,?_assertEqual('undefined'
                  ,kz_json:get_ne_json_value(<<"o2">>, JObj)
                  )
    ].

-define(MAP_JSON,
        kz_json:from_list([{a, <<"zero">>}
                          ,{<<"B">>, true}
                          ,{<<"c">>, [1
                                     ,2
                                     ,kz_json:from_list([{42, 24}
                                                        ,{<<"42">>, 24}
                                                        ])
                                     ]}
                          ])).

-define(JSON_MAP, #{a => <<"zero">>
                   ,<<"B">> => true
                   ,<<"c">> => [1
                               ,2
                               ,#{<<"42">> => 24
                                 ,42 => 24
                                 }
                               ]
                   }).

to_map_test_() ->
    [?_assertEqual(?JSON_MAP, kz_json:to_map(?MAP_JSON))
    ,?_assertEqual(?MAP_JSON, kz_json:from_map(?JSON_MAP))
    ,?_assertEqual(?JSON_MAP, kz_json:to_map(kz_json:from_map(?JSON_MAP)))
    ,?_assertEqual(?MAP_JSON, kz_json:from_map(kz_json:to_map(?MAP_JSON)))
    ].

are_equal_test_() ->
    JObj = kz_json:from_map(kz_json:to_map(?MAP_JSON)),
    [?_assertEqual(true, kz_json:are_equal(?MAP_JSON, JObj))
    ,?_assertEqual(true, kz_json:are_equal(JObj, ?MAP_JSON))
    ,?_assertEqual(true, kz_json:are_equal(undefined, undefined))
    ,?_assertEqual(false, kz_json:are_equal(undefined, kz_json:new()))
    ,?_assertEqual(false, kz_json:are_equal(kz_json:new(), undefined))
    ].

-define(CHARGES_SIMPLE,
        kz_json:decode(<<"{\"phone_numbers\":{\"did_us\":{\"category\":\"phone_numbers\",\"item\":\"did_us\",\"name\":\"US DID\",\"quantity\":1,\"rate\":1.0,\"single_discount\":true,\"single_discount_rate\":0.0,\"cumulative_discount\":1,\"cumulative_discount_rate\":0.5,\"activation_charge\":2.0,\"minimum\":0,\"exceptions\":[],\"activation_charges\":2.0}},\"activation_charges\":2.0}">>)).
-define(CHARGES_DOUBLE,
        kz_json:decode(<<"{\"phone_numbers\":{\"did_us\":{\"category\":\"phone_numbers\",\"item\":\"did_us\",\"name\":\"US DID\",\"quantity\":2,\"rate\":2.0,\"single_discount\":true,\"single_discount_rate\":0.0,\"cumulative_discount\":2,\"cumulative_discount_rate\":1.0,\"activation_charge\":4.0,\"minimum\":0,\"exceptions\":[],\"activation_charges\":4.0}},\"activation_charges\":4.0}">>)).

sum_test_() ->
    E = kz_json:new(),
    A42 = kz_json:from_list([{<<"a">>, 42}]),
    A40 = kz_json:from_list([{<<"a">>, 40}]),
    A2 = kz_json:from_list([{<<"a">>, 2}]),
    A42Bhi = kz_json:from_list([{<<"a">>, 42}, {<<"b">>, <<"hi">>}]),
    A2Bhi = kz_json:from_list([{<<"a">>, 2}, {<<"b">>, <<"hi">>}]),
    [?_assertEqual(E, kz_json:sum(E, E))
    ,?_assertEqual(A42, kz_json:sum(A42, E))
    ,?_assertEqual(A42, kz_json:sum(E, A42))
    ,?_assertEqual(A42Bhi, kz_json:sum(A42Bhi, E))
    ,?_assertEqual(A42Bhi, kz_json:sum(E, A42Bhi))
    ,?_assertEqual(A42, kz_json:sum(A40, A2))
    ,?_assertEqual(A42, kz_json:sum(A2, A40))
    ,?_assertEqual(A42Bhi, kz_json:sum(A40, A2Bhi))
    ,?_assertEqual(A42Bhi, kz_json:sum(A2Bhi, A40))
    ,?_assertEqual(?CHARGES_DOUBLE, kz_json:sum(?CHARGES_SIMPLE, ?CHARGES_SIMPLE))
    ].

order_by_test_() ->
    Unordered = [H1, H2|T] =
        [kz_json:from_list_recursive([{<<"a">>, [{<<"k">>, <<"3">>}]}])
        ,kz_json:from_list_recursive([{<<"a">>, [{<<"k">>, <<"5">>}]}])
        ,kz_json:from_list_recursive([{<<"a">>, [{<<"k">>, <<"1">>}]}])
        ,kz_json:from_list_recursive([{<<"a">>, [{<<"k">>, <<"2">>}]}])
        ,kz_json:from_list_recursive([{<<"a">>, [{<<"k">>, <<"4">>}]}])
        ],
    InOrder = [kz_json:from_list_recursive([{<<"a">>, [{<<"k">>, <<"1">>}]}])
              ,kz_json:from_list_recursive([{<<"a">>, [{<<"k">>, <<"2">>}]}])
              ,kz_json:from_list_recursive([{<<"a">>, [{<<"k">>, <<"3">>}]}])
              ,kz_json:from_list_recursive([{<<"a">>, [{<<"k">>, <<"4">>}]}])
              ,kz_json:from_list_recursive([{<<"a">>, [{<<"k">>, <<"5">>}]}])
              ],
    Ids = [<<"1">>, <<"2">>, <<"3">>, <<"4">>, <<"5">>],
    [?_assertEqual([], kz_json:order_by([<<"a">>, <<"k">>], [], []))
    ,?_assertEqual([], kz_json:order_by([<<"a">>, <<"k">>], [], [[]]))
    ,?_assertEqual(InOrder, kz_json:order_by([<<"a">>, <<"k">>], Ids, [Unordered]))
    ,?_assertEqual(InOrder, kz_json:order_by([<<"a">>, <<"k">>], Ids, [[H1,H2], T]))
    ].

from_list_recursive_test() ->
    Obj1 = kz_json:from_list([{<<"send_to">>, [<<"someone@somedomain.com">>]}]),
    Obj2 = kz_json:from_list([{<<"email">>, Obj1}]),
    L1 = [{<<"fax_hangup_codes">>, [200, 201, 202]}
         ,{<<"fax_hangup_cause">>, <<"NORMAL_CLEARING">>}
         ],
    L3 = [{<<"fax">>, [{<<"id">>, "201702-1b6cfec4e3ab0b7bb97ced78bf431f39"}
                      ,{<<"info">>, L1}
                      ,{<<"notifications">>, Obj2}
                      ]}],
    Obj3 = kz_json:from_list([{<<"id">>,<<"201702-1b6cfec4e3ab0b7bb97ced78bf431f39">>}
                             ,{<<"info">>, kz_json:from_list(L1)}
                             ,{<<"notifications">>, Obj2}
                             ]),
    JObj1 = kz_json:from_list([{<<"fax">>, Obj3}]),
    JObj2 = kz_json:from_list_recursive(L3),
    Key1 = [<<"fax">>, <<"info">>, <<"fax_hangup_code">>],
    Key2 = [<<"fax">>, <<"notifications">>, <<"email">>, <<"send_to">>],
    [?_assertEqual(kz_json:get_integer_value(Key1, JObj1), kz_json:get_integer_value(Key1, JObj2))
    ,?_assertEqual(kz_json:get_ne_binary_value(Key2, JObj1), kz_json:get_ne_binary_value(Key2, JObj2))
    ,?_assertEqual('true', kz_json:are_equal(JObj1, JObj2))
    ].

flatten_expand_diff_test() ->
    X = kz_json:set_value([k10, k11, k12], v10, kz_json:new()),
    X2 = kz_json:set_value(k20, v20, X),
    Delta = kz_json:set_value(k20, v20, X),
    [
     ?_assertEqual(kz_json:expand(kz_json:flatten(X2)), X2)
    ,?_assertEqual(kz_json:diff(X, X2), Delta)
    ].

-define(REQUEST, kz_json:from_list([{<<"a">>, 1}
                                   ,{<<"b">>, [2, 3, 4]}
                                   ,{<<"c">>, kz_json:from_list([{<<"c.a">>, 1.1}])}
                                   ])).
-define(DOCUMENT, kz_json:from_list([{<<"a">>, 99}
                                    ,{<<"b">>, [98, 97, 96]}
                                    ,{<<"c">>, kz_json:from_list([{<<"c.a">>, 99.99}])}
                                    ])).

merge_vs_merge_recursive_test_() ->
    M1 = kz_json:merge(fun kz_json:merge_left/2, ?DOCUMENT, ?REQUEST),
    M2 = kz_json:merge_recursive(?DOCUMENT, ?REQUEST),
    M3 = kz_json:merge(fun kz_json:merge_right/2, ?DOCUMENT, ?REQUEST),

    [?_assert(kz_json:are_equal(M1, ?DOCUMENT))
    ,?_assert(kz_json:are_equal(M2, ?REQUEST))
    ,?_assert(kz_json:are_equal(M3, ?REQUEST))
    ].

-ifdef(PERF).
-define(REPEAT, 100000).

horse_merge() ->
    horse:repeat(?REPEAT
                ,kz_json:merge(?D1, ?D2)
                ).

horse_merge_recursive() ->
    horse:repeat(?REPEAT
                ,kz_json:merge_recursive(?D1, ?D2)
                ).

-endif.
