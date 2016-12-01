%%%-------------------------------------------------------------------
%%% @copyright (C) 2012-2016, 2600Hz INC
%%% @doc
%%%
%%% @end
%%% @contributors
%%%-------------------------------------------------------------------
-module(kazoo_auth_sup).

-behaviour(supervisor).

-export([start_link/0]).
-export([init/1]).

-include("kazoo_auth.hrl").

-define(SERVER, ?MODULE).


-define(ORIGIN_BINDINGS, [[{'db', ?KZ_AUTH_DB}]
                         ]).

-define(CACHE_PROPS, [{'origin_bindings', ?ORIGIN_BINDINGS}
                     ]).

%% Helper macro for declaring children of supervisor
-define(CHILDREN, [?CACHE_ARGS(?PK_CACHE, ?CACHE_PROPS)
                  ,?CACHE_ARGS(?TOKENS_CACHE, ?CACHE_PROPS)
                  ,?CACHE_ARGS(?PROFILE_CACHE, ?CACHE_PROPS)
                  ,?WORKER('kz_auth_rsa')
                  ,?WORKER('kz_auth_init')
                  ]).

%% ===================================================================
%% API functions
%% ===================================================================

%%--------------------------------------------------------------------
%% @public
%% @doc Starts the supervisor
%%--------------------------------------------------------------------
-spec start_link() -> startlink_ret().
start_link() ->
    supervisor:start_link({'local', ?SERVER}, ?MODULE, []).

%% ===================================================================
%% Supervisor callbacks
%% ===================================================================

%%--------------------------------------------------------------------
%% @public
%% @doc
%% Whenever a supervisor is started using supervisor:start_link/[2,3],
%% this function is called by the new process to find out about
%% restart strategy, maximum restart frequency and child
%% specifications.
%% @end
%%--------------------------------------------------------------------
-spec init(any()) -> sup_init_ret().
init([]) ->
    RestartStrategy = 'one_for_one',
    MaxRestarts = 5,
    MaxSecondsBetweenRestarts = 10,

    SupFlags = {RestartStrategy, MaxRestarts, MaxSecondsBetweenRestarts},

    {'ok', {SupFlags, ?CHILDREN}}.