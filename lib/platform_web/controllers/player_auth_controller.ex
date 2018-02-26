defmodule PlatformWeb.PlayerAuthController do
    import Plug.Conn
    alias Platform.Accounts.Player
    
    def init(opts) do
        Keyword.fetch!(opts, :repo)
    end
    
    def call(conn, repo) do
        player_id = get_session(conn, :player_id)
        player = player_id && repo.get(Player, player_id)
        assign(conn, :current_user, player)
    end
end