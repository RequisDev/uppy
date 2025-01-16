if Uppy.Utils.ensure_all_loaded?([ExAws, ExAws.S3]) do
  defmodule Uppy.Storages.S3 do
    @moduledoc """
    Amazon S3

    This module implements the `Uppy.Storage` behaviour.

    ## Getting started

    1. Add the dependencies to your `mix.exs` file:

    ```elixir
    # mix.exs
    defp deps do
      [
        {:ex_aws, "~> 2.1"},
        {:ex_aws_s3, "~> 2.0"},
        {:sweet_xml, "~> 0.6"}
      ]
    end
    ```

    2. Add the adapter to your `config.exs` file:

    ```elixir
    # config.exs
    config :uppy, storage_adapter: Uppy.Storages.S3
    ```
    """
    alias Uppy.Error
    alias Uppy.Storages.S3.Parser

    @behaviour Uppy.Storage

    @config Application.compile_env(:uppy, __MODULE__, [])

    @one_minute_seconds 60

    @s3_accelerate @config[:s3_accelerate] === true

    @default_opts [
      region: "us-west-1",
      http_client: Uppy.Storages.S3.HTTP
    ]

    def object_chunk_stream(bucket, object, chunk_size, opts) do
      opts = Keyword.merge(@default_opts, opts)

      with {:ok, metadata} <- head_object(bucket, object, opts) do
        {:ok, ExAws.S3.Download.chunk_stream(metadata.content_length, chunk_size)}
      end
    end

    def get_chunk(bucket, object, start_byte, end_byte, opts) do
      opts = Keyword.merge(@default_opts, opts)

      s3_opts =
        opts
        |> Keyword.get(:s3, [])
        |> Keyword.put(:range, "bytes=#{start_byte}-#{end_byte}")

      with {:ok, body} <-
             bucket
             |> ExAws.S3.get_object(object, s3_opts)
             |> ExAws.request(opts)
             |> deserialize_response() do
        {:ok, {start_byte, body}}
      end
    end

    @impl true
    @doc """
    Implementation for `c:Uppy.Storage.list_objects/3`.

    ### Examples

        iex> Uppy.Storages.S3.list_objects("your_bucket", "your/prefix")
    """
    def list_objects(bucket, prefix \\ "", opts \\ []) do
      opts = Keyword.merge(@default_opts, opts)

      opts = if prefix in [nil, ""], do: opts, else: Keyword.put(opts, :prefix, prefix)

      bucket
      |> ExAws.S3.list_objects_v2(opts)
      |> ExAws.request(opts)
      |> deserialize_response()
    end

    @impl true
    @doc """
    Implementation for `c:Uppy.Storage.get_object/3`.

    ### Examples

        iex> Uppy.Storages.S3.get_object("your_bucket", "example_image.jpeg")
    """
    def get_object(bucket, object, opts) do
      opts = Keyword.merge(@default_opts, opts)

      bucket
      |> ExAws.S3.get_object(object, opts)
      |> ExAws.request(opts)
      |> deserialize_response()
    end

    @impl true
    @doc """
    Implementation for `c:Uppy.Storage.head_object/3`.

    ### Examples

        iex> Uppy.Storages.S3.head_object("your_bucket", "example_image.jpeg")
    """
    def head_object(bucket, object, opts) do
      opts = Keyword.merge(@default_opts, opts)

      bucket
      |> ExAws.S3.head_object(object, opts)
      |> ExAws.request(opts)
      |> deserialize_headers()
    end

    @impl true
    @doc """
    Implementation for `c:Uppy.Storage.sign_part/5`.

    ### Examples

        iex> Uppy.Storages.S3.sign_part("your_bucket", "example_image.jpeg", "upload_id", 1)
    """
    def sign_part(bucket, object, upload_id, part_number, opts \\ []) do
      query_params = %{"uploadId" => upload_id, "partNumber" => part_number}

      opts =
        @default_opts
        |> Keyword.merge(opts)
        |> Keyword.update(:query_params, query_params, &Map.merge(&1, query_params))

      case Keyword.get(opts, :http_method, :put) do
        :put ->
          pre_sign(bucket, :put, object, opts)

        :post ->
          pre_sign(bucket, :post, object, opts)

        term ->
          raise "Expected the option `:http_method` to be one of `[:put, :post]`, got: #{inspect(term)}"
      end
    end

    @impl true
    @doc """
    Implementation for `c:Uppy.Storage.pre_sign/4`.

    ### Examples

        iex> Uppy.Storages.S3.presigned_url("your_bucket", :put, "example_image.jpeg")
    """
    def pre_sign(bucket, http_method, object, opts) do
      opts = Keyword.merge(@default_opts, opts)

      opts =
        if http_method in [:post, :put] do
          Keyword.put_new(opts, :s3_accelerate, @s3_accelerate)
        else
          opts
        end

      expires_in = opts[:expires_in] || @one_minute_seconds

      with {:ok, url} <-
             :s3
             |> ExAws.Config.new(opts)
             |> ExAws.S3.presigned_url(http_method, bucket, object, opts)
             |> handle_response() do
        {:ok,
         %{
           key: object,
           url: url,
           expires_at: DateTime.add(DateTime.utc_now(), expires_in, :second)
         }}
      end
    end

    @impl true
    @doc """
    Implementation for `c:Uppy.Storage.list_multipart_uploads/2`.
    """
    def list_multipart_uploads(bucket, opts) do
      opts = Keyword.merge(@default_opts, opts)

      bucket
      |> ExAws.S3.list_multipart_uploads(opts)
      |> ExAws.request(opts)
      |> deserialize_response()
    end

    @impl true
    @doc """
    Implementation for `c:Uppy.Storage.create_multipart_upload/3`.
    """
    def create_multipart_upload(bucket, object, opts) do
      opts = Keyword.merge(@default_opts, opts)

      bucket
      |> ExAws.S3.initiate_multipart_upload(object, opts)
      |> ExAws.request(opts)
      |> deserialize_response()
    end

    @impl true
    @doc """
    Implementation for `c:Uppy.Storage.list_parts/4`.
    """
    def list_parts(bucket, object, upload_id, opts) do
      opts = Keyword.merge(@default_opts, opts)

      s3_opts =
        if Keyword.has_key?(opts, :part_number_marker) do
          query_params = %{"part-number-marker" => opts[:part_number_marker]}

          opts
          |> Keyword.delete(:part_number_marker)
          |> Keyword.update(:query_params, query_params, &Map.merge(&1, query_params))
        else
          Keyword.take(opts, [:query_params])
        end

      bucket
      |> ExAws.S3.list_parts(object, upload_id, s3_opts)
      |> ExAws.request(opts)
      |> deserialize_response()
    end

    @impl true
    @doc """
    Implementation for `c:Uppy.Storage.abort_multipart_upload/4`.
    """
    def abort_multipart_upload(bucket, object, upload_id, opts) do
      opts = Keyword.merge(@default_opts, opts)

      bucket
      |> ExAws.S3.abort_multipart_upload(object, upload_id)
      |> ExAws.request(opts)
      |> handle_response()
    end

    @impl true
    @doc """
    Implementation for `c:Uppy.Storage.complete_multipart_upload/5`.
    """
    def complete_multipart_upload(bucket, object, upload_id, parts, opts) do
      opts = Keyword.merge(@default_opts, opts)

      bucket
      |> ExAws.S3.complete_multipart_upload(object, upload_id, parts)
      |> ExAws.request(opts)
      |> deserialize_response()
    end

    @impl true
    @doc """
    Implementation for `c:Uppy.Storage.put_object_copy/5`.
    """
    def put_object_copy(dest_bucket, destination_object, src_bucket, source_object, opts) do
      opts = Keyword.merge(@default_opts, opts)

      dest_bucket
      |> ExAws.S3.put_object_copy(destination_object, src_bucket, source_object, opts)
      |> ExAws.request(opts)
      |> handle_response()
    end

    @impl true
    @doc """
    Implementation for `c:Uppy.Storage.put_object/4`.
    """
    def put_object(bucket, object, body, opts) do
      opts = Keyword.merge(@default_opts, opts)

      bucket
      |> ExAws.S3.put_object(object, body, opts)
      |> ExAws.request(opts)
      |> handle_response()
    end

    @impl true
    @doc """
    Implementation for `c:Uppy.Storage.delete_object/3`.
    """
    def delete_object(bucket, object, opts) do
      opts = Keyword.merge(@default_opts, opts)

      bucket
      |> ExAws.S3.delete_object(object, opts)
      |> ExAws.request(opts)
      |> handle_response()
    end

    defp deserialize_response({:ok, %{body: %{contents: contents}}}) do
      {:ok,
       Enum.map(contents, fn content ->
         %{
           content
           | e_tag: remove_quotations(content.e_tag),
             size: String.to_integer(content.size),
             last_modified: content.last_modified |> DateTime.from_iso8601() |> elem(1)
         }
       end)}
    end

    defp deserialize_response({:ok, %{body: %{parts: parts}}}) do
      {:ok,
       Enum.map(parts, fn part ->
         %{
           e_tag: remove_quotations(part.etag),
           size: String.to_integer(part.size),
           part_number: String.to_integer(part.part_number)
         }
       end)}
    end

    defp deserialize_response({:ok, %{body: body}}), do: {:ok, body}

    defp deserialize_response({:error, _} = e), do: handle_response(e)

    defp deserialize_headers({:ok, %{headers: headers}}) when is_list(headers) do
      deserialize_headers({:ok, %{headers: Map.new(headers)}})
    end

    defp deserialize_headers({:ok, %{headers: %{"etag" => _, "last-modified" => _} = headers}}) do
      {:ok,
       %{
         e_tag: remove_quotations(headers["etag"]),
         last_modified: Parser.date_time_from_rfc7231!(headers["last-modified"]),
         content_type: headers["content-type"],
         content_length: String.to_integer(headers["content-length"])
       }}
    end

    defp deserialize_headers({:ok, %{headers: %{"etag" => _} = headers}}) do
      {:ok,
       %{
         e_tag: remove_quotations(headers["etag"]),
         content_length: String.to_integer(headers["content-length"])
       }}
    end

    defp deserialize_headers({:ok, %{headers: headers}}) do
      {:ok, headers}
    end

    defp deserialize_headers({:error, _} = e), do: handle_response(e)

    defp handle_response({:ok, _} = res), do: res

    defp handle_response({:error, msg}) when is_binary(msg) do
      if msg =~ "there's nothing to see here" do
        {:error, Error.call(:not_found, "resource not found.", %{error: msg})}
      else
        {:error, Error.call(:service_unavailable, "storage service unavailable.", %{error: msg})}
      end
    end

    defp remove_quotations(string) do
      String.replace(string, "\"", "")
    end
  end
end
