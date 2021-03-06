defmodule CotoamiWeb.OAuth2.Patreon do
  use OAuth2.Strategy
  require Logger
  alias Cotoami.ExternalUser

  defp common_config do
    [
      strategy: __MODULE__,
      site: "https://www.patreon.com",
      authorize_url: "/oauth2/authorize",
      token_url: "/api/oauth2/token"
    ]
  end

  def client do
    Application.get_env(:cotoami, __MODULE__)
    |> Keyword.merge(common_config())
    |> OAuth2.Client.new()
  end

  def authorize_url!() do
    OAuth2.Client.authorize_url!(client(), [])
  end

  def get_token!(params \\ [], _headers \\ []) do
    OAuth2.Client.get_token!(
      client(), Keyword.merge(params, client_secret: client().client_secret))
  end

  @user_request_options "?fields%5Bpledge%5D=amount_cents,declined_since,is_paused"

  def get_user!(client_with_token) do
    %{body: body} = 
      client_with_token
      |> OAuth2.Client.get!("/api/oauth2/api/current_user#{@user_request_options}")

    user = body["data"]
    Logger.info "OAuth2 user: #{inspect user}"

    pledges = 
      case body["included"] do
        nil -> []
        included -> 
          included 
          |> Enum.filter(&(&1["type"] == "pledge"))
          |> Enum.map(&(&1["attributes"]))
      end

    check_pledges(%ExternalUser{
      auth_provider: "patreon",
      auth_id: user["id"],
      name: user["attributes"]["full_name"], 
      avatar_url: user["attributes"]["image_url"]
    }, pledges)
  end

  defp check_pledges(%ExternalUser{} = user, pledges) do
    Logger.info "pledges: #{Poison.encode!(pledges, pretty: true)}"
    {:ok, user}
  end

  # Strategy Callbacks

  def authorize_url(client, params) do
    OAuth2.Strategy.AuthCode.authorize_url(client, params)
  end

  def get_token(client, params, headers) do
    client
    |> put_header("Accept", "application/json")
    |> OAuth2.Strategy.AuthCode.get_token(params, headers)
  end
end

