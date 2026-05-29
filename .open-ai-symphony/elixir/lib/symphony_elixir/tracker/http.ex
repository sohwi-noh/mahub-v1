defmodule SymphonyElixir.Tracker.HTTP do
  @moduledoc false

  @spec post_json(String.t(), list(), map()) :: {:ok, map()} | {:error, term()}
  def post_json(url, headers, body) do
    request(:post, url, headers, body)
  end

  @spec get_json(String.t(), list()) :: {:ok, map() | list()} | {:error, term()}
  def get_json(url, headers) do
    request(:get, url, headers, nil)
  end

  @spec patch_json(String.t(), list(), map()) :: {:ok, map() | list()} | {:error, term()}
  def patch_json(url, headers, body) do
    request(:patch, url, headers, body)
  end

  @spec request(atom(), String.t(), list(), map() | nil) ::
          {:ok, map() | list()} | {:error, term()}
  def request(method, url, headers, body) do
    opts = [headers: headers]
    opts = if is_nil(body), do: opts, else: Keyword.put(opts, :json, body)

    case Req.request([method: method, url: url] ++ opts) do
      {:ok, %{status: status, body: body}} when status in 200..299 ->
        {:ok, body}

      {:ok, %{status: status, body: body}} ->
        {:error, {:http_error, status, body}}

      {:error, reason} ->
        {:error, reason}
    end
  end
end
