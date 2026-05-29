defmodule SymphonyElixir.SessionUsageStore do
  @moduledoc """
  Persists completed Symphony runner token usage to PostgreSQL.
  """

  require Logger

  @usage_table "symphony_session_usage"
  @default_port 5432
  @default_database "aidd"
  @default_timeout_ms 3_000

  @type completion_reason :: :normal | term()

  @spec persist_completion(map() | nil, completion_reason(), DateTime.t()) :: :ok
  def persist_completion(nil, _reason, _completed_at), do: :ok

  def persist_completion(running_entry, reason, completed_at) when is_map(running_entry) do
    with {:ok, config} <- config(),
         {:ok, conn} <- start_connection(config) do
      try do
        :ok = ensure_table(conn, config.query_timeout_ms)
        :ok = insert_usage(conn, usage_row(running_entry, reason, completed_at), config.query_timeout_ms)
      after
        stop_connection(conn)
      end
    else
      :disabled ->
        :ok

      {:error, reason} ->
        Logger.warning("Failed to persist Symphony session usage: #{inspect(reason)}")
        :ok
    end
  rescue
    exception ->
      Logger.warning("Failed to persist Symphony session usage: #{Exception.message(exception)}")
      :ok
  end

  defp config do
    if enabled?() do
      with {:ok, jdbc_config} <- jdbc_config(),
           {:ok, password} <- usage_db_password(jdbc_config),
           {:ok, username} <- usage_db_username(jdbc_config) do
        {:ok,
         %{
           host: jdbc_config.host,
           port: jdbc_config.port,
           database: jdbc_config.database,
           username: username,
           password: password,
           ssl: Map.get(jdbc_config, :ssl, false),
           connect_timeout_ms: env_integer("SYMPHONY_USAGE_DB_CONNECT_TIMEOUT_MS", @default_timeout_ms),
           query_timeout_ms: env_integer("SYMPHONY_USAGE_DB_QUERY_TIMEOUT_MS", @default_timeout_ms)
         }}
      end
    else
      :disabled
    end
  end

  defp enabled? do
    System.get_env("SYMPHONY_USAGE_DB_ENABLED")
    |> normalize_env()
    |> String.downcase()
    |> case do
      value when value in ["1", "true", "yes", "on"] -> true
      _ -> false
    end
  end

  defp start_connection(config) do
    opts =
      [
        hostname: config.host,
        port: config.port,
        database: config.database,
        ssl: config.ssl,
        timeout: config.connect_timeout_ms,
        connect_timeout: config.connect_timeout_ms
      ]
      |> maybe_put_username(config.username)
      |> maybe_put_password(config.password)

    Postgrex.start_link(opts)
  end

  defp stop_connection(conn) when is_pid(conn) do
    if Process.alive?(conn), do: GenServer.stop(conn)
    :ok
  catch
    :exit, _ -> :ok
  end

  defp ensure_table(conn, timeout_ms) do
    sql = """
    CREATE TABLE IF NOT EXISTS #{@usage_table} (
      id BIGSERIAL PRIMARY KEY,
      run_id TEXT NOT NULL UNIQUE,
      issue_id TEXT NOT NULL,
      issue_identifier TEXT,
      issue_title TEXT NOT NULL,
      created_by_id TEXT,
      created_by_name TEXT,
      session_id TEXT,
      started_at TIMESTAMPTZ NOT NULL,
      ended_at TIMESTAMPTZ NOT NULL,
      input_token_delta BIGINT NOT NULL DEFAULT 0,
      output_token_delta BIGINT NOT NULL DEFAULT 0,
      total_token_delta BIGINT NOT NULL DEFAULT 0,
      runtime_seconds BIGINT NOT NULL DEFAULT 0,
      turn_count INTEGER NOT NULL DEFAULT 0,
      worker_host TEXT,
      workspace_path TEXT,
      completion_reason TEXT NOT NULL,
      created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
      updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
    )
    """

    case Postgrex.query(conn, sql, [], timeout: timeout_ms) do
      {:ok, _result} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  defp insert_usage(conn, row, timeout_ms) do
    sql = """
    INSERT INTO #{@usage_table} (
      run_id,
      issue_id,
      issue_identifier,
      issue_title,
      created_by_id,
      created_by_name,
      session_id,
      started_at,
      ended_at,
      input_token_delta,
      output_token_delta,
      total_token_delta,
      runtime_seconds,
      turn_count,
      worker_host,
      workspace_path,
      completion_reason
    )
    VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16, $17)
    ON CONFLICT (run_id) DO UPDATE SET
      issue_title = EXCLUDED.issue_title,
      created_by_id = EXCLUDED.created_by_id,
      created_by_name = EXCLUDED.created_by_name,
      session_id = EXCLUDED.session_id,
      ended_at = EXCLUDED.ended_at,
      input_token_delta = EXCLUDED.input_token_delta,
      output_token_delta = EXCLUDED.output_token_delta,
      total_token_delta = EXCLUDED.total_token_delta,
      runtime_seconds = EXCLUDED.runtime_seconds,
      turn_count = EXCLUDED.turn_count,
      worker_host = EXCLUDED.worker_host,
      workspace_path = EXCLUDED.workspace_path,
      completion_reason = EXCLUDED.completion_reason,
      updated_at = now()
    """

    case Postgrex.query(conn, sql, row, timeout: timeout_ms) do
      {:ok, _result} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  defp usage_row(running_entry, reason, completed_at) do
    issue = Map.get(running_entry, :issue) || %{}
    started_at = Map.get(running_entry, :started_at) || completed_at

    [
      required_string(Map.get(running_entry, :usage_run_id) || usage_run_id(issue, running_entry, started_at)),
      required_string(Map.get(issue, :id) || Map.get(running_entry, :issue_id)),
      optional_string(Map.get(issue, :identifier) || Map.get(running_entry, :identifier)),
      required_string(Map.get(issue, :title)),
      optional_string(Map.get(issue, :creator_id)),
      optional_string(Map.get(issue, :creator_name)),
      optional_string(Map.get(running_entry, :session_id)),
      started_at,
      completed_at,
      non_negative_integer(Map.get(running_entry, :codex_input_tokens)),
      non_negative_integer(Map.get(running_entry, :codex_output_tokens)),
      non_negative_integer(Map.get(running_entry, :codex_total_tokens)),
      non_negative_integer(running_seconds(started_at, completed_at)),
      non_negative_integer(Map.get(running_entry, :turn_count)),
      optional_string(Map.get(running_entry, :worker_host)),
      optional_string(Map.get(running_entry, :workspace_path)),
      completion_reason(reason)
    ]
  end

  defp running_seconds(%DateTime{} = started_at, %DateTime{} = completed_at) do
    DateTime.diff(completed_at, started_at, :second)
  end

  defp running_seconds(_started_at, _completed_at), do: 0

  defp usage_run_id(issue, running_entry, started_at) do
    issue_key =
      Map.get(issue, :identifier) ||
        Map.get(issue, :id) ||
        Map.get(running_entry, :identifier) ||
        "issue"

    session_key =
      Map.get(running_entry, :session_id) ||
        started_at_key(started_at)

    "#{issue_key}:#{session_key}"
  end

  defp started_at_key(%DateTime{} = started_at), do: DateTime.to_unix(started_at, :microsecond)
  defp started_at_key(_started_at), do: System.unique_integer([:positive, :monotonic])

  defp completion_reason(:normal), do: "normal"
  defp completion_reason(reason), do: inspect(reason)

  defp maybe_put_username(opts, nil), do: opts
  defp maybe_put_username(opts, username), do: Keyword.put(opts, :username, username)

  defp maybe_put_password(opts, nil), do: opts
  defp maybe_put_password(opts, password), do: Keyword.put(opts, :password, password)

  defp usage_db_username(jdbc_config) do
    case optional_env("SYMPHONY_USAGE_DB_USERNAME") || Map.get(jdbc_config, :username) do
      nil -> {:error, :missing_usage_db_username}
      "" -> {:error, :missing_usage_db_username}
      username -> {:ok, username}
    end
  end

  defp usage_db_password(%{password: password}) when is_binary(password) and password != "" do
    {:error, :usage_db_password_must_not_be_in_jdbc_url}
  end

  defp usage_db_password(_jdbc_config) do
    case optional_env("SYMPHONY_USAGE_DB_PASSWORD") do
      nil -> {:ok, nil}
      "ENC(" <> _rest = encrypted_password -> decrypt_usage_db_password(encrypted_password)
      _password -> {:error, :usage_db_password_must_be_encrypted}
    end
  end

  defp decrypt_usage_db_password(encrypted_password) do
    with {:ok, key} <- usage_db_password_key(),
         {:ok, iv, ciphertext, tag} <- decode_encrypted_password(encrypted_password),
         plaintext when is_binary(plaintext) <-
           :crypto.crypto_one_time_aead(:aes_256_gcm, key, iv, ciphertext, "", tag, false) do
      {:ok, plaintext}
    else
      :error -> {:error, :invalid_usage_db_password_encrypted}
      {:error, reason} -> {:error, reason}
    end
  end

  defp usage_db_password_key do
    case optional_env("SYMPHONY_SECRET_KEY_BASE64") do
      nil -> {:error, :missing_symphony_secret_key_base64}
      key -> decode_password_key(key)
    end
  end

  defp decode_encrypted_password(value) do
    value
    |> unwrap_encrypted_password()
    |> String.split(":", trim: true)
    |> case do
      ["v1", "aes-256-gcm", iv, ciphertext, tag] ->
        decode_encrypted_password_parts(iv, ciphertext, tag)

      ["v1", iv, ciphertext, tag] ->
        decode_encrypted_password_parts(iv, ciphertext, tag)

      [iv, ciphertext, tag] ->
        decode_encrypted_password_parts(iv, ciphertext, tag)

      _ ->
        {:error, :invalid_usage_db_password_encrypted_format}
    end
  end

  defp unwrap_encrypted_password("ENC(" <> rest) do
    String.trim_trailing(rest, ")")
  end

  defp unwrap_encrypted_password(value), do: value

  defp decode_encrypted_password_parts(iv, ciphertext, tag) do
    with {:ok, iv} <- decode_base64(iv),
         {:ok, ciphertext} <- decode_base64(ciphertext),
         {:ok, tag} <- decode_base64(tag),
         :ok <- validate_encryption_parts(iv, tag) do
      {:ok, iv, ciphertext, tag}
    end
  end

  defp validate_encryption_parts(iv, tag) do
    cond do
      byte_size(iv) != 12 -> {:error, :invalid_usage_db_password_iv}
      byte_size(tag) != 16 -> {:error, :invalid_usage_db_password_tag}
      true -> :ok
    end
  end

  defp decode_password_key("base64:" <> key), do: decode_base64_key(key)
  defp decode_password_key("hex:" <> key), do: decode_hex_key(key)

  defp decode_password_key(key) do
    cond do
      Regex.match?(~r/^[0-9a-fA-F]{64}$/, key) ->
        decode_hex_key(key)

      byte_size(key) == 32 ->
        {:ok, key}

      true ->
        decode_base64_key(key)
    end
  end

  defp decode_base64_key(value) do
    with {:ok, key} <- decode_base64(value),
         32 <- byte_size(key) do
      {:ok, key}
    else
      {:error, reason} -> {:error, reason}
      _ -> {:error, :invalid_usage_db_password_decryption_key}
    end
  end

  defp decode_hex_key(value) do
    case Base.decode16(value, case: :mixed) do
      {:ok, key} when byte_size(key) == 32 -> {:ok, key}
      {:ok, _key} -> {:error, :invalid_usage_db_password_decryption_key}
      :error -> {:error, :invalid_usage_db_password_decryption_key}
    end
  end

  defp decode_base64(value) do
    Enum.find_value(
      [
        fn -> Base.decode64(value, padding: false) end,
        fn -> Base.decode64(value) end,
        fn -> Base.url_decode64(value, padding: false) end,
        fn -> Base.url_decode64(value) end
      ],
      fn decode ->
        case decode.() do
          {:ok, decoded} -> {:ok, decoded}
          :error -> nil
        end
      end
    ) || {:error, :invalid_base64}
  end

  defp jdbc_config do
    case optional_env("SYMPHONY_USAGE_DB_JDBC_URL") do
      nil -> {:error, :missing_usage_db_jdbc_url}
      value -> parse_jdbc_url(value)
    end
  end

  defp parse_jdbc_url("jdbc:postgresql://" <> _rest = value) do
    value
    |> String.replace_prefix("jdbc:", "")
    |> URI.parse()
    |> jdbc_uri_config()
  end

  defp parse_jdbc_url(value), do: {:error, {:invalid_usage_db_jdbc_url, redact_jdbc_url(value)}}

  defp jdbc_uri_config(%URI{scheme: "postgresql", host: host} = uri)
       when is_binary(host) and host != "" do
    query = URI.decode_query(uri.query || "")
    userinfo = parse_userinfo(uri.userinfo)

    {:ok,
     %{
       host: host,
       port: uri.port || @default_port,
       database: database_from_path(uri.path),
       username: query["user"] || query["username"] || userinfo[:username],
       password: query["password"] || userinfo[:password],
       ssl: ssl_from_query(query)
     }}
  end

  defp jdbc_uri_config(%URI{} = uri),
    do: {:error, {:invalid_usage_db_jdbc_url, redact_jdbc_url(URI.to_string(uri))}}

  defp database_from_path(nil), do: @default_database
  defp database_from_path(""), do: @default_database

  defp database_from_path(path) do
    path
    |> String.trim_leading("/")
    |> URI.decode()
    |> case do
      "" -> @default_database
      database -> database
    end
  end

  defp parse_userinfo(nil), do: %{}

  defp parse_userinfo(userinfo) when is_binary(userinfo) do
    case String.split(userinfo, ":", parts: 2) do
      [username, password] -> %{username: URI.decode(username), password: URI.decode(password)}
      [username] -> %{username: URI.decode(username)}
    end
  end

  defp ssl_from_query(%{"ssl" => value}), do: value |> String.downcase() |> boolean_value(false)
  defp ssl_from_query(%{"sslmode" => value}), do: String.downcase(value) in ["require", "verify-ca", "verify-full"]
  defp ssl_from_query(_query), do: false

  defp redact_jdbc_url(value) when is_binary(value) do
    value
    |> String.replace(~r/(password=)[^&]+/i, "\\1[redacted]")
    |> String.replace(~r{//([^:/@]+):([^@]+)@}, "//\\1:[redacted]@")
  end

  defp optional_env(name) do
    name
    |> System.get_env()
    |> normalize_env()
    |> case do
      "" -> nil
      value -> value
    end
  end

  defp env_integer(name, default) do
    case optional_env(name) do
      nil ->
        default

      value ->
        case Integer.parse(value) do
          {integer, ""} when integer >= 0 -> integer
          _ -> default
        end
    end
  end

  defp boolean_value(value, _default) when value in ["1", "true", "yes", "on"], do: true
  defp boolean_value(value, _default) when value in ["0", "false", "no", "off"], do: false
  defp boolean_value(_value, default), do: default

  defp normalize_env(nil), do: ""

  defp normalize_env(value) when is_binary(value) do
    String.trim(value)
  end

  defp required_string(nil), do: ""
  defp required_string(value) when is_binary(value), do: value
  defp required_string(value), do: to_string(value)

  defp optional_string(nil), do: nil
  defp optional_string(""), do: nil
  defp optional_string(value), do: required_string(value)

  defp non_negative_integer(value) when is_integer(value), do: max(value, 0)
  defp non_negative_integer(_value), do: 0
end
