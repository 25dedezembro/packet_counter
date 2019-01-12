-module(packet_counter).

-behaviour(gen_server).

-export([
         init/1,
         handle_call/3,
         handle_cast/2,
         handle_info/2,
         code_change/3,
         terminate/2,
         start_link/0
        ]).

-export([receive_data/1]).

-define(DB, counterdb).
-define(PORT, 5555).

-define(INFO(M, P), io:format(M, P)).
-define(ERROR(M, P), io:format(M, P)).

start_link() ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

init(_) ->
    rets:start_link(), 
    rets:init_db(?DB), 
    udp_channel:start_link(?PORT, 5000, ?MODULE),
    {ok, #{}}.

handle_call(_, _From, S) ->
    {reply, ok, S}.

handle_cast(_, S) ->
    {noreply, S}.

handle_info({Sock, Addr, Port, Data}, S) ->
    spawn(?MODULE, receive_data, [{Sock, Addr, Port, Data}]),
    {noreply, S}.

code_change(_, _, S) ->
    {ok, S}.

terminate(_, _S) ->
    ok.

receive_data({Sock, Addr, Port, Data}) ->
    V = parse_net(Data),
    gen_udp:send(Sock, Addr, Port, to_bin(execute_cmd(V))).

execute_cmd(["SET", Key, Value]) ->
    rets:set(?DB, Key, Value);
execute_cmd(["GET", Key]) ->
    rets:get(?DB, Key);
execute_cmd(["HSET", Key, Field, Value]) ->
    rets:hset(?DB, Key, Field, Value);
execute_cmd(["HGET", Key, Field]) ->
    rets:hget(?DB, Key, Field);
execute_cmd(["HGETALL", Key]) ->
    rets:hgetall(?DB, Key);
execute_cmd(["DEL", Key]) ->
    rets:del(?DB, Key).    

parse_net(Bin) when is_binary(Bin) ->
    parse_net(binary_to_list(Bin));
parse_net(L) when is_list(L) ->
    {ok, Tokens, _} = erl_scan:string(L),
    {ok, Value} = erl_parse:parse_term(Tokens),
    Value.

to_bin(Num) when is_integer(Num) -> integer_to_binary(Num);
to_bin(Str) when is_list(Str) -> list_to_binary(Str);
to_bin(Bin) when is_binary(Bin) -> Bin;
to_bin(Atom) when is_atom(Atom) -> atom_to_binary(Atom, utf8).

-ifdef(EUNIT).
-include_lib("eunit/include/eunit.hrl").

parse_net_test() ->
    V = parse_net(<<"[\"SET\", abc, {123,[],'122', #{p => q}}].">>),
    ?assert(V == ["SET", abc, {123,[],'122', #{p => q}}]),
    ok.

-endif.