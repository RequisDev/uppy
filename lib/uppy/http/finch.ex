if Uppy.Utils.application_loaded?(:finch) do
  defmodule Uppy.HTTP.Finch do
    @default_name :uppy_adapters_http_finch
    @default_pool_config [size: 10]
    @default_options [
      name: @default_name,
      pools: [default: @default_pool_config]
    ]

    @definition [
      name: [type: :atom, default: @default_name],
      params: [type: :any],
      stream: [type: {:fun, 2}],
      stream_origin_callback: [type: {:fun, 1}],
      stream_acc: [type: :any],
      receive_timeout: [type: :pos_integer],
      pools: [
        # it's a map.
        type: :any,
        default: %{default: [size: 10]}
      ]
    ]

    @moduledoc """
    Defines a Finch based HTTP adapter.

    This module implements `Uppy.Adapter.HTTP`

    ### Getting started

    You must start this adapter in your `application.ex` file:

    ```elixir
    defmodule YourApp.Application do
      @moduledoc false

      use Application

      @impl true
      def start(_type, _args) do
        options = [strategy: :one_for_one, name: YourApp.Supervisor]
        Supervisor.start_link(children(), options)
      end

      def children do
        [
          Uppy.HTTP.Finch
        ]
      end
    end
    ```

    ### Shared Options
    #{NimbleOptions.docs(@definition)}
    """
    alias Uppy.HTTP.Finch.Response
    alias Uppy.{Error, Utils}

    @logger_prefix "Uppy.HTTP.Finch"

    @type t_res :: {:ok, Response.t()} | {:error, term()}
    @type headers :: [{binary | atom, binary}]

    @doc """
    Starts a GenServer process linked to the current process.
    """
    @spec start_link() :: GenServer.on_start()
    @spec start_link(atom) :: GenServer.on_start()
    @spec start_link(atom, keyword()) :: GenServer.on_start()
    def start_link(name \\ @default_name, options \\ []) do
      options
      |> Keyword.put(:name, name)
      |> NimbleOptions.validate!(@definition)
      |> Keyword.update!(:pools, &ensure_default_pool_exists/1)
      |> Finch.start_link()
    end

    defp ensure_default_pool_exists(pool_configs) when is_list(pool_configs) do
      pool_configs |> Map.new() |> ensure_default_pool_exists
    end

    defp ensure_default_pool_exists(%{default: _} = pool_config), do: pool_config

    defp ensure_default_pool_exists(pool_config) do
      Map.put(pool_config, :default, @default_pool_config)
    end

    @doc "Returns a supervisor child spec."
    @spec child_spec(atom | {atom, keyword} | keyword) :: %{id: atom, start: tuple}
    def child_spec(name) when is_atom(name) do
      %{
        id: name,
        start: {Uppy.HTTP.Finch, :start_link, [name]}
      }
    end

    def child_spec({name, options}) do
      %{
        id: name,
        start: {Uppy.HTTP.Finch, :start_link, [name, options]}
      }
    end

    def child_spec(options) do
      options = Keyword.put_new(options, :name, @default_name)

      %{
        id: options[:name],
        start: {Uppy.HTTP.Finch, :start_link, [options[:name], options]}
      }
    end

    @doc false
    @spec make_head_request(binary, list, keyword) :: t_res
    def make_head_request(url, headers, options) do
      request = Finch.build(:head, url, headers)

      make_request(request, options)
    end

    @doc false
    @spec make_get_request(binary, list, keyword) :: t_res
    def make_get_request(url, headers, options) do
      request = Finch.build(:get, url, headers)

      make_request(request, options)
    end

    @doc false
    @spec make_delete_request(binary, list, keyword) :: t_res
    def make_delete_request(url, headers, options) do
      request = Finch.build(:delete, url, headers)

      make_request(request, options)
    end

    @doc false
    @spec make_patch_request(binary, nil | term, list, keyword) :: t_res
    def make_patch_request(url, body, headers, options) do
      request = Finch.build(:patch, url, headers, body)

      make_request(request, options)
    end

    @doc false
    @spec make_post_request(binary, nil | term, list, keyword) :: t_res
    def make_post_request(url, body, headers, options) do
      request = Finch.build(:post, url, headers, body)

      make_request(request, options)
    end

    @doc false
    @spec make_put_request(binary, nil | term, list, keyword) :: t_res
    def make_put_request(url, body, headers, options) do
      request = Finch.build(:put, url, headers, body)

      make_request(request, options)
    end

    defp make_request(request, options) do
      if options[:stream] do
        Finch.stream(
          request,
          options[:name],
          options[:stream_acc] || [],
          options[:stream],
          options
        )
      else
        with {:ok, response} <- Finch.request(request, options[:name], options) do
          {:ok,
           %Response{
             request: request,
             body: response.body,
             status: response.status,
             headers: response.headers
           }}
        end
      end
    end

    defp append_query_params(url, nil), do: url

    defp append_query_params(url, params) do
      "#{url}?#{params |> encode_query_params |> Enum.join("&")}"
    end

    defp encode_query_params(params) do
      Enum.flat_map(params, fn
        {k, v} when is_list(v) -> Enum.map(v, &encode_key_value(k, &1))
        {k, v} -> [encode_key_value(k, v)]
      end)
    end

    defp encode_key_value(key, value), do: URI.encode_query(%{key => value})

    @doc """
    Executes a HTTP PATCH request.

    ### Examples

        iex> Uppy.HTTP.Finch.patch("http://url.com", nil)
    """
    @spec patch(binary, map | binary) :: t_res
    @spec patch(binary, map | binary, headers) :: t_res
    @spec patch(binary, map | binary, headers, keyword()) :: t_res
    def patch(url, body, headers \\ [], options \\ []) do
      Utils.Logger.debug(@logger_prefix, "PATCH url=#{inspect(url)}")

      options = @default_options |> Keyword.merge(options) |> NimbleOptions.validate!(@definition)
      http_patch = options[:http][:patch] || (&make_patch_request/4)

      fn ->
        url
        |> append_query_params(options[:params])
        |> http_patch.(body, headers, options)
      end
      |> run_and_measure(headers, "PATCH", options)
      |> handle_response(options)
    rescue
      # Nimble pool out of workers error
      RuntimeError -> {:error, Error.service_unavailable("Out of HTTP workers")}
    catch
      # Nimble pool out of workers error
      :exit, reason ->
        {:error,
         Error.service_unavailable(
           "HTTP connection pool existed with reason:: #{inspect(reason)}",
           %{reason: reason}
         )}
    end

    @doc """
    Executes a HTTP POST request.

    ### Examples

        iex> Uppy.HTTP.Finch.post("http://url.com", nil)
    """
    @spec post(binary, map | binary) :: t_res
    @spec post(binary, map | binary, headers) :: t_res
    @spec post(binary, map | binary, headers, keyword()) :: t_res
    def post(url, body, headers \\ [], options \\ []) do
      Utils.Logger.debug(@logger_prefix, "POST url=#{inspect(url)}")

      options = @default_options |> Keyword.merge(options) |> NimbleOptions.validate!(@definition)
      http_post = options[:http][:post] || (&make_post_request/4)

      fn ->
        url
        |> append_query_params(options[:params])
        |> http_post.(body, headers, options)
      end
      |> run_and_measure(headers, "POST", options)
      |> handle_response(options)
    rescue
      # Nimble pool out of workers error
      RuntimeError -> {:error, Error.service_unavailable("Out of HTTP workers")}
    catch
      # Nimble pool out of workers error
      :exit, reason ->
        {:error,
         Error.service_unavailable(
           "HTTP connection pool existed with reason:: #{inspect(reason)}",
           %{reason: reason}
         )}
    end

    @doc """
    Executes a HTTP PUT request.

    ### Examples

        iex> Uppy.HTTP.Finch.put("http://url.com", nil)
    """
    @spec put(binary, map | binary) :: t_res
    @spec put(binary, map | binary, headers) :: t_res
    @spec put(binary, map | binary, headers, keyword()) :: t_res
    def put(url, body, headers \\ [], options \\ []) do
      Utils.Logger.debug(@logger_prefix, "PUT url=#{inspect(url)}")

      options = @default_options |> Keyword.merge(options) |> NimbleOptions.validate!(@definition)
      http_put = options[:http][:put] || (&make_put_request/4)

      fn ->
        url
        |> append_query_params(options[:params])
        |> http_put.(body, headers, options)
      end
      |> run_and_measure(headers, "PUT", options)
      |> handle_response(options)
    rescue
      # Nimble pool out of workers error
      RuntimeError -> {:error, Error.service_unavailable("Out of HTTP workers")}
    catch
      # Nimble pool out of workers error
      :exit, reason ->
        {:error,
         Error.service_unavailable(
           "HTTP connection pool existed with reason:: #{inspect(reason)}",
           %{reason: reason}
         )}
    end

    @doc """
    Executes a HTTP HEAD request.

    ### Examples

        iex> Uppy.HTTP.Finch.head("http://url.com")
    """
    @spec head(binary) :: t_res
    @spec head(binary, headers) :: t_res
    @spec head(binary, headers, keyword()) :: t_res
    def head(url, headers \\ [], options \\ []) do
      Utils.Logger.debug(@logger_prefix, "HEAD url=#{inspect(url)}")

      options = @default_options |> Keyword.merge(options) |> NimbleOptions.validate!(@definition)
      http_head = options[:http][:head] || (&make_head_request/3)

      fn ->
        url
        |> append_query_params(options[:params])
        |> http_head.(headers, options)
      end
      |> run_and_measure(headers, "HEAD", options)
      |> handle_response(options)
    rescue
      # Nimble pool out of workers error
      RuntimeError -> {:error, Error.service_unavailable("Out of HTTP workers")}
    catch
      # Nimble pool out of workers error
      :exit, reason ->
        {:error,
         Error.service_unavailable(
           "HTTP connection pool existed with reason:: #{inspect(reason)}",
           %{reason: reason}
         )}
    end

    @doc """
    Executes a HTTP GET request.

    ### Examples

        iex> Uppy.HTTP.Finch.get("http://url.com")
    """
    @spec get(binary) :: t_res
    @spec get(binary, headers) :: t_res
    @spec get(binary, headers, keyword()) :: t_res
    def get(url, headers \\ [], options \\ []) do
      Utils.Logger.debug(@logger_prefix, "GET url=#{inspect(url)}")

      options = @default_options |> Keyword.merge(options) |> NimbleOptions.validate!(@definition)
      http_get = options[:http][:get] || (&make_get_request/3)

      fn ->
        url
        |> append_query_params(options[:params])
        |> http_get.(headers, options)
      end
      |> run_and_measure(headers, "GET", options)
      |> handle_response(options)
    rescue
      # Nimble pool out of workers error
      RuntimeError -> {:error, Error.service_unavailable("Out of HTTP workers")}
    catch
      # Nimble pool out of workers error
      :exit, reason ->
        {:error,
         Error.service_unavailable(
           "HTTP connection pool existed with reason:: #{inspect(reason)}",
           %{reason: reason}
         )}
    end

    @doc """
    Executes a HTTP DELETE request.

    ### Examples

        iex> Uppy.HTTP.Finch.delete("http://url.com")
    """
    @spec delete(binary) :: t_res
    @spec delete(binary, headers) :: t_res
    @spec delete(binary, headers, keyword()) :: t_res
    def delete(url, headers \\ [], options \\ []) do
      Utils.Logger.debug(@logger_prefix, "DELETE url=#{inspect(url)}")

      options = @default_options |> Keyword.merge(options) |> NimbleOptions.validate!(@definition)
      http_delete = options[:http][:delete] || (&make_delete_request/3)

      fn ->
        url
        |> append_query_params(options[:params])
        |> http_delete.(headers, options)
      end
      |> run_and_measure(headers, "DELETE", options)
      |> handle_response(options)
    rescue
      # Nimble pool out of workers error
      RuntimeError -> {:error, Error.service_unavailable("Out of HTTP workers")}
    catch
      # Nimble pool out of workers error
      :exit, reason ->
        {:error,
         Error.service_unavailable(
           "HTTP connection pool existed with reason:: #{inspect(reason)}",
           %{reason: reason}
         )}
    end

    defp run_and_measure(fnc, headers, method, options) do
      start_time = System.monotonic_time()

      response = fnc.()

      metadata = %{
        start_time: System.system_time(),
        request: %{
          method: method,
          headers: headers
        },
        response: response,
        options: options
      }

      end_time = System.monotonic_time()
      measurements = %{elapsed_time: end_time - start_time}
      :telemetry.execute([:http, Keyword.get(options, :name)], measurements, metadata)

      response
    end

    defp handle_response({:ok, %Response{status: status}} = res, _options)
         when status in 200..299,
         do: res

    defp handle_response({:ok, %Response{status: code} = res}, options) do
      api_name = options[:name]
      details = %{response: res, http_code: code, api_name: api_name}
      error_code_map = error_code_map(api_name)

      if Map.has_key?(error_code_map, code) do
        {error, message} = Map.get(error_code_map, code)
        {:error, Error.call(error, message, details)}
      else
        message = unknown_error_message(api_name)
        {:error, Error.internal_server_error(message, details)}
      end
    end

    defp handle_response({:error, e}, options) when is_binary(e) or is_atom(e) do
      message = "#{options[:name]}: #{e}"
      {:error, Error.internal_server_error(message, %{error: e})}
    end

    defp handle_response({:error, %Mint.TransportError{reason: :timeout} = e}, options) do
      message = "#{options[:name]}: Endpoint timeout."
      {:error, Error.request_timeout(message, %{error: e})}
    end

    defp handle_response({:error, %Mint.TransportError{reason: :econnrefused} = e}, options) do
      message = "#{options[:name]}: HTTP connection refused."
      {:error, Error.service_unavailable(message, %{error: e})}
    end

    defp handle_response({:error, e}, options) do
      message = unknown_error_message(options[:name])
      {:error, Error.internal_server_error(message, %{error: e})}
    end

    defp handle_response(e, options) do
      message = unknown_error_message(options[:name])
      {:error, Error.internal_server_error(message, %{error: e})}
    end

    defp unknown_error_message(api_name) do
      "#{api_name}: unknown error occurred"
    end

    # See docs: https://uppy.org/docs/0.25.1/api/api-errors.html
    defp error_code_map(api_name) do
      %{
        400 => {
          :bad_request,
          "#{api_name}: The request could not be understood due to malformed syntax."
        },
        401 => {:unauthorized, "#{api_name}: API key is wrong."},
        404 => {:not_found, "#{api_name}: The requested resource is not found."},
        409 => {:conflict, "#{api_name}: Resource already exists."},
        422 => {
          :unprocessable_entity,
          "#{api_name}: Request is well-formed, but cannot be processed."
        },
        503 => {
          :service_unavailable,
          "#{api_name}: Uppy is temporarily offline. Please try again later."
        }
      }
    end
  end
else
  if Uppy.Config.http_adapter() === Uppy.HTTP.Finch do
    raise """
    Uppy is configured to use the http adapter `Uppy.HTTP.Finch`
    which requires the dependency `finch`. To fix this error you must add `finch`
    as a dependency to your project's mix.exs file:

    ```
    # mix.exs
    def deps do
      [
        {:finch, "~> 0.16.0"}
      ]
    end
    ```

    Don't forget add the adapter to your application supervision children:

    ```
    # application.ex
    def start(_type, _args) do
      children = [
        Uppy.HTTP.Finch
      ]

      ...
    end
    ```

    or configure a different http adapter:

    ```
    # config.exs
    config :elixir_uppy, :http_adapter, YourApp.HTTPAdapter
    ```
    """
  end
end